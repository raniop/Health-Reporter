//
//  BedtimeRecommendationService.swift
//  Health Reporter
//
//  Two-phase bedtime recommendation:
//  1. Swift (BedtimeCalculator) computes the bedtime deterministically
//  2. Gemini generates only the notification text
//

import Foundation

// MARK: - Response Models

struct BedtimeRecommendation: Codable {
    let recommendedBedtimeLocal: String
    let wakeTimeTargetLocal: String
    let sleepNeedTonightMinutes: Int
    let components: BedtimeComponents
    let drivers: [BedtimeDriver]
    let notification: BedtimeNotificationContent
    let assumptions: [String]?
    let dataQualityNotes: [String]?

    struct BedtimeComponents: Codable {
        let baseSleepNeedMinutes: Int
        let sleepDebtMinutes: Int
        let recoveryPenaltyMinutes: Int
        let loadAdjustmentMinutes: Int
        let latencyMinutes: Int
    }

    struct BedtimeDriver: Codable {
        let key: String
        let value: String
        let impactMinutes: Int
    }

    struct BedtimeNotificationContent: Codable {
        let title_en: String
        let title_he: String
        let body_en: String
        let body_he: String
    }
}

// MARK: - Service

final class BedtimeRecommendationService {
    static let shared = BedtimeRecommendationService()
    private init() {}

    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["GeminiAPIKey"] as? String,
              key != "YOUR_GEMINI_API_KEY_HERE" else {
            fatalError("Please set the Gemini API key in Config.plist")
        }
        return key
    }

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    private let maxRetries = 2

    // MARK: - Gemini Prompt (text generation only)

    private static let systemInstruction = """
    You are a professional sleep coach.
    Given pre-computed bedtime recommendation data, generate a concise, friendly notification message.
    Return ONLY valid JSON. No text before or after.
    All text fields must have both Hebrew (_he) and English (_en) versions.
    """

    private static let textPromptTemplate = """
    The app has already calculated the user's recommended bedtime using health data.
    Your job is ONLY to write the notification text. Do NOT recalculate anything.

    CALCULATED RESULTS:
    {{RESULTS_JSON}}

    Write a short, friendly notification message as a sleep coach would say.
    - Body: 1-2 sentences explaining the 2-3 main drivers and one actionable tip.
    - Do NOT start with "Because:" or "בגלל:".
    - Cite specific metrics like sleep debt, HRV drop, RHR rise, short sleep, high activity.

    OUTPUT FORMAT (JSON ONLY):
    {
      "title_en": "Recommended bedtime: HH:MM",
      "title_he": "שעת שינה מומלצת: HH:MM",
      "body_en": "...",
      "body_he": "..."
    }
    """

    // MARK: - Generate Recommendation (Two-Phase)

    func generateRecommendation(completion: @escaping (BedtimeRecommendation?, Error?) -> Void) {
        print("🌙 [Bedtime] generateRecommendation() called (two-phase)")

        // Fetch 21 days of health data
        HealthKitManager.shared.fetchDailyHealthData(days: 21) { [weak self] entries in
            print("🌙 [Bedtime] HealthKit returned \(entries.count) daily entries")
            guard let self = self else {
                completion(nil, NSError(domain: "BedtimeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                return
            }

            guard !entries.isEmpty else {
                print("🌙 [Bedtime] ERROR: No health data entries returned from HealthKit")
                completion(nil, NSError(domain: "BedtimeService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No health data available"]))
                return
            }

            // --- PHASE 1: Swift calculation (deterministic) ---
            let calculator = BedtimeCalculator()
            let sleepGoal = BedtimeNotificationManager.shared.sleepGoalHours
            let calcResult = calculator.calculate(entries: entries, sleepGoalHours: sleepGoal)

            print("🌙 [Bedtime] ✅ Swift calc: bedtime=\(calcResult.recommendedBedtimeLocal), wake=\(calcResult.wakeTimeTargetLocal), need=\(calcResult.sleepNeedTonightMinutes)min")
            print("🌙 [Bedtime] Components: base=\(calcResult.components.baseSleepNeedMinutes) debt=\(calcResult.components.sleepDebtMinutes) recovery=\(calcResult.components.recoveryPenaltyMinutes) load=\(calcResult.components.loadAdjustmentMinutes) latency=\(calcResult.components.latencyMinutes)")
            print("🌙 [Bedtime] Drivers: \(calcResult.drivers.map { "\($0.key)(\($0.impactMinutes)min)" }.joined(separator: ", "))")

            // --- PHASE 2: Gemini text generation ---
            let resultsJSON = self.buildResultsJSON(from: calcResult)
            let prompt = Self.textPromptTemplate.replacingOccurrences(of: "{{RESULTS_JSON}}", with: resultsJSON)

            self.callGemini(prompt: prompt, retryCount: 0) { responseText, error in
                let notification: BedtimeRecommendation.BedtimeNotificationContent

                if let text = responseText {
                    print("🌙 [Bedtime] Gemini text response: \(String(text.prefix(300)))")
                    if let parsed = try? self.parseNotificationResponse(text) {
                        notification = parsed
                        print("🌙 [Bedtime] ✅ Gemini text parsed: \(notification.body_he)")
                    } else {
                        print("🌙 [Bedtime] ⚠️ Gemini text parse failed, using fallback")
                        notification = self.buildFallbackNotification(from: calcResult)
                    }
                } else {
                    print("🌙 [Bedtime] ⚠️ Gemini call failed (\(error?.localizedDescription ?? "unknown")), using fallback text")
                    notification = self.buildFallbackNotification(from: calcResult)
                }

                // Assemble BedtimeRecommendation (unchanged struct)
                let recommendation = BedtimeRecommendation(
                    recommendedBedtimeLocal: calcResult.recommendedBedtimeLocal,
                    wakeTimeTargetLocal: calcResult.wakeTimeTargetLocal,
                    sleepNeedTonightMinutes: calcResult.sleepNeedTonightMinutes,
                    components: BedtimeRecommendation.BedtimeComponents(
                        baseSleepNeedMinutes: calcResult.components.baseSleepNeedMinutes,
                        sleepDebtMinutes: calcResult.components.sleepDebtMinutes,
                        recoveryPenaltyMinutes: calcResult.components.recoveryPenaltyMinutes,
                        loadAdjustmentMinutes: calcResult.components.loadAdjustmentMinutes,
                        latencyMinutes: calcResult.components.latencyMinutes
                    ),
                    drivers: calcResult.drivers.map {
                        BedtimeRecommendation.BedtimeDriver(key: $0.key, value: $0.value, impactMinutes: $0.impactMinutes)
                    },
                    notification: notification,
                    assumptions: calcResult.assumptions.isEmpty ? nil : calcResult.assumptions,
                    dataQualityNotes: nil
                )

                print("🌙 [Bedtime] ✅ Final recommendation: bedtime=\(recommendation.recommendedBedtimeLocal)")
                AnalysisCache.saveBedtimeRecommendation(recommendation)
                completion(recommendation, nil)
            }
        }
    }

    // MARK: - Build Results JSON for Gemini

    private func buildResultsJSON(from result: BedtimeCalculationResult) -> String {
        let driversArray = result.drivers.map { driver -> [String: Any] in
            ["key": driver.key, "value": driver.value, "impactMinutes": driver.impactMinutes]
        }
        let dict: [String: Any] = [
            "recommendedBedtimeLocal": result.recommendedBedtimeLocal,
            "wakeTimeTargetLocal": result.wakeTimeTargetLocal,
            "sleepNeedTonightMinutes": result.sleepNeedTonightMinutes,
            "components": [
                "baseSleepNeedMinutes": result.components.baseSleepNeedMinutes,
                "sleepDebtMinutes": result.components.sleepDebtMinutes,
                "recoveryPenaltyMinutes": result.components.recoveryPenaltyMinutes,
                "loadAdjustmentMinutes": result.components.loadAdjustmentMinutes,
                "latencyMinutes": result.components.latencyMinutes
            ],
            "drivers": driversArray,
            "assumptions": result.assumptions
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    // MARK: - Parse Gemini Notification Text Response

    private func parseNotificationResponse(_ text: String) throws -> BedtimeRecommendation.BedtimeNotificationContent {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw NSError(domain: "BedtimeService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 in response"])
        }

        return try JSONDecoder().decode(BedtimeRecommendation.BedtimeNotificationContent.self, from: data)
    }

    // MARK: - Fallback Notification Text

    private func buildFallbackNotification(from result: BedtimeCalculationResult) -> BedtimeRecommendation.BedtimeNotificationContent {
        let bedtime = result.recommendedBedtimeLocal

        // Build context-aware fallback from drivers
        let hasDebt = result.drivers.contains { $0.key == "sleep_debt" }
        let hasShortSleep = result.drivers.contains { $0.key == "short_sleep" }
        let hasHrvDrop = result.drivers.contains { $0.key == "hrv" }
        let hasHighLoad = result.drivers.contains { $0.key == "training_load" }

        let bodyEn: String
        let bodyHe: String

        if hasDebt && hasShortSleep {
            bodyEn = "You've accumulated significant sleep debt over the last two days. Your body needs extra recovery, so try to wind down by \(bedtime) tonight."
            bodyHe = "צברת חוב שינה משמעותי ביומיים האחרונים. הגוף שלך צריך התאוששות נוספת, נסה להירגע עד \(bedtime) הערב."
        } else if hasDebt {
            bodyEn = "You accumulated sleep debt recently. Try to get to bed by \(bedtime) to start catching up."
            bodyHe = "צברת חוב שינה לאחרונה. נסה ללכת לישון עד \(bedtime) כדי להתחיל להשלים."
        } else if hasHrvDrop {
            bodyEn = "Your HRV dropped below baseline, suggesting your body needs more recovery. Aim for bed by \(bedtime)."
            bodyHe = "ה-HRV שלך ירד מתחת לבסיס, מה שמרמז שהגוף שלך צריך יותר התאוששות. כדאי לישון עד \(bedtime)."
        } else if hasHighLoad {
            bodyEn = "High activity levels in the last 48 hours mean your body needs extra rest. Try to be in bed by \(bedtime)."
            bodyHe = "רמת פעילות גבוהה ב-48 השעות האחרונות, הגוף שלך צריך מנוחה נוספת. נסה לישון עד \(bedtime)."
        } else {
            bodyEn = "Based on your health data, we recommend getting to bed by \(bedtime) for optimal recovery."
            bodyHe = "על סמך נתוני הבריאות שלך, מומלץ ללכת לישון עד \(bedtime) לשיקום מיטבי."
        }

        return BedtimeRecommendation.BedtimeNotificationContent(
            title_en: "Recommended bedtime: \(bedtime)",
            title_he: "שעת שינה מומלצת: \(bedtime)",
            body_en: bodyEn,
            body_he: bodyHe
        )
    }

    // MARK: - Gemini API Call (self-contained)

    private func callGemini(prompt: String, retryCount: Int, completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            completion(nil, NSError(domain: "BedtimeService", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "systemInstruction": [
                "parts": [["text": Self.systemInstruction]]
            ],
            "generationConfig": [
                "temperature": 0.4,
                "topP": 0.95,
                "maxOutputTokens": 1024,
                "responseMimeType": "text/plain"
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, error)
            return
        }

        print("🌙 [Bedtime] Sending Gemini text request (attempt \(retryCount + 1)/\(maxRetries + 1))...")
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let httpResp = response as? HTTPURLResponse {
                print("🌙 [Bedtime] Gemini HTTP status: \(httpResp.statusCode)")
            }

            if let error = error {
                let ns = error as NSError
                if ns.code == NSURLErrorCancelled { return }

                if retryCount < self.maxRetries && self.isRetryableError(error) {
                    let delay = Double(retryCount + 1) * 2.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.callGemini(prompt: prompt, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                completion(nil, error)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let statusCode = httpResponse.statusCode

                if retryCount < self.maxRetries && [500, 502, 503, 429].contains(statusCode) {
                    let delay = Double(retryCount + 1) * 2.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.callGemini(prompt: prompt, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }

                completion(nil, NSError(domain: "BedtimeService", code: -7, userInfo: [NSLocalizedDescriptionKey: "Gemini API error: \(statusCode)"]))
                return
            }

            guard let data = data else {
                completion(nil, NSError(domain: "BedtimeService", code: -8, userInfo: [NSLocalizedDescriptionKey: "No data in response"]))
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let firstPart = parts.first,
                      let text = firstPart["text"] as? String else {
                    completion(nil, NSError(domain: "BedtimeService", code: -9, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini response format"]))
                    return
                }
                completion(text, nil)
            } catch {
                completion(nil, error)
            }
        }
        task.resume()
    }

    private func isRetryableError(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.code == NSURLErrorTimedOut ||
               ns.code == NSURLErrorNetworkConnectionLost ||
               ns.code == NSURLErrorNotConnectedToInternet
    }
}
