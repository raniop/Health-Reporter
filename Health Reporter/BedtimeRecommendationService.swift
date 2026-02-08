//
//  BedtimeRecommendationService.swift
//  Health Reporter
//
//  Calls Gemini at 19:00 with last 48h health data to compute a recommended bedtime.
//  Self-contained Gemini call (independent of GeminiService/AION analysis).
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

    // MARK: - System Instruction

    private static let systemInstruction = """
    You are a professional sports monitor, strength & conditioning coach, sleep coach, and sports nutrition coach.
    Your mission: compute the user's recommended bedtime for tonight using the last 48 hours of data, and generate a concise notification message + the exact logic outputs used.
    Return ONLY valid JSON. No text before or after.
    All notification text fields must have both Hebrew (_he) and English (_en) versions.
    """

    // MARK: - Prompt Template

    private static let promptTemplate = """
    ROLE
    You are a professional sports monitor, strength & conditioning coach, sleep coach, and sports nutrition coach.
    Your mission: At 19:00 local time, compute the user's recommended bedtime for tonight using the last 48 hours of data, and generate a concise notification message + the exact logic outputs used.

    CONTEXT
    The app tracks health and training data from Apple Watch / HealthKit and other sources.
    Data quality varies; you must handle missing fields safely and explain what was assumed.

    INPUTS (JSON)
    {{PAYLOAD}}

    REQUIREMENTS
    1) Output EXACT bedtime recommendation as local time: "HH:MM".
    2) Compute "sleepNeedTonightMinutes" using: baseNeed + sleepDebt + recoveryPenalty + riskAdjustment.
    3) Use only last 48h + baselines21d. Do not use older raw data.
    4) Handle missing fields:
       - If hrvMs missing: rely more on restingHR + sleep + training load.
       - If restingHR missing: rely more on HRV + sleep.
       - If sleep stages missing: use total sleep only.
    5) If data is inconsistent or flagged as sensor error, down-weight that metric and note it.

    ALGORITHM (must follow)
    A) Determine wakeTimeTarget (tomorrow)
    Priority:
      1. upcoming.wakeTimeTomorrow
      2. userProfile.preferredWakeTime
      3. baselines21d.wakeTimeBaseline
      4. default 07:00
    Return wakeTimeTarget in local time.

    B) Determine baseSleepNeedMinutes
    Priority:
      1. userProfile.typicalSleepNeedHours * 60
      2. baselines21d.sleepBaselineHours * 60
      3. default 450 (7h30m)

    C) Sleep Debt from last 48h
    sleepDebtMinutes = clamp(
      max(0, baseSleepNeedMinutes - sleepHoursYesterday*60) +
      max(0, baseSleepNeedMinutes - sleepHoursTwoDaysAgo*60),
      0,
      90
    )

    D) Recovery penalty (physiology) using baselines21d
    Compute:
      hrvDeltaPct = (hrvMsYesterday - hrvBaselineMs) / hrvBaselineMs
      rhrDelta = restingHRYesterday - rhrBaselineBpm

    Rules (additive, clamp 0..90):
      penalty = 0
      - If hrv available and hrvDeltaPct <= -0.15: penalty += 30
      - Else if hrv available and hrvDeltaPct <= -0.10: penalty += 20
      - If rhr available and rhrDelta >= +5: penalty += 25
      - Else if rhr available and rhrDelta >= +3: penalty += 15
      - If deepSleepHoursYesterday available and deepSleepHoursYesterday < (deepSleepHoursTwoDaysAgo * 0.6): penalty += 15
      - If sleepHoursYesterday < 6.0: penalty += 20
      - If there was a workout ending after 19:00 in last 48h: penalty += 20
      penalty = clamp(penalty, 0, 90)

    E) Training/Activity load adjustment (last 48h)
    Compute a simple load score:
      loadScore = normalize( activeCaloriesYesterday + activeCaloriesTwoDaysAgo, using a reasonable range 600..2000 per day )
    Rules:
      - If totalActiveCalories48h is very high OR steps48h very high: add 10-20 minutes to sleepNeedTonight
      - If very low load and good recovery: add 0

    F) Sleep-onset latency (how long it will take the user to fall asleep)
    Default latency = 20 minutes.
    Clamp latency to 20..60 minutes.

    G) Compute final bedtime
    sleepNeedTonightMinutes =
      baseSleepNeedMinutes +
      sleepDebtMinutes +
      recoveryPenaltyMinutes +
      loadAdjustmentMinutes

    bedtimeTime =
      wakeTimeTarget - sleepNeedTonightMinutes - latencyMinutes

    If bedtimeTime would be earlier than 20:30, do not push earlier than 20:30 unless:
      (sleepDebtMinutes >= 60 AND recoveryPenaltyMinutes >= 40).
    Otherwise cap at 20:30 and warn user.

    If bedtimeTime would be later than 01:00, cap at 01:00 and warn user.

    H) Create notification content
    Must be short, actionable, and explain 2-3 main drivers.
    IMPORTANT: All notification text must be bilingual (Hebrew + English).
    Format:
      Title: "Recommended bedtime: HH:MM" (in both languages)
      Body: "Because: <reason1>, <reason2>. Tip: <one tip>." (in both languages)
    Reasons should cite metrics like HRV drop, RHR rise, short sleep, late workout.

    OUTPUT FORMAT (JSON ONLY)
    {
      "recommendedBedtimeLocal": "HH:MM",
      "wakeTimeTargetLocal": "HH:MM",
      "sleepNeedTonightMinutes": 0,
      "components": {
        "baseSleepNeedMinutes": 0,
        "sleepDebtMinutes": 0,
        "recoveryPenaltyMinutes": 0,
        "loadAdjustmentMinutes": 0,
        "latencyMinutes": 0
      },
      "drivers": [
        {"key":"hrv","value":"...", "impactMinutes":0},
        {"key":"rhr","value":"...", "impactMinutes":0},
        {"key":"sleep","value":"...", "impactMinutes":0},
        {"key":"training","value":"...", "impactMinutes":0}
      ],
      "notification": {
        "title_en": "Recommended bedtime: HH:MM",
        "title_he": "שעת שינה מומלצת: HH:MM",
        "body_en": "Because: ... Tip: ...",
        "body_he": "בגלל: ... טיפ: ..."
      },
      "assumptions": [
        "List any assumptions due to missing data"
      ],
      "dataQualityNotes": [
        "If any metric appears inconsistent or flagged as sensor error, note it here"
      ]
    }

    NOW DO IT
    Use the provided JSON inputs, apply the algorithm exactly, and return JSON only.
    """

    // MARK: - Generate Recommendation

    func generateRecommendation(completion: @escaping (BedtimeRecommendation?, Error?) -> Void) {
        // Fetch 21 days of health data (enough for baselines + last 48h)
        HealthKitManager.shared.fetchDailyHealthData(days: 21) { [weak self] entries in
            guard let self = self else {
                completion(nil, NSError(domain: "BedtimeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                return
            }

            guard !entries.isEmpty else {
                completion(nil, NSError(domain: "BedtimeService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No health data available"]))
                return
            }

            // Build payload
            let builder = BedtimePayloadBuilder()
            let payload = builder.build(from: entries)

            guard let payloadJSON = payload.toJSONString() else {
                completion(nil, NSError(domain: "BedtimeService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to build payload JSON"]))
                return
            }

            // Build prompt
            let prompt = Self.promptTemplate.replacingOccurrences(of: "{{PAYLOAD}}", with: payloadJSON)

            // Call Gemini
            self.callGemini(prompt: prompt, retryCount: 0) { responseText, error in
                if let error = error {
                    completion(nil, error)
                    return
                }

                guard let text = responseText else {
                    completion(nil, NSError(domain: "BedtimeService", code: -4, userInfo: [NSLocalizedDescriptionKey: "No response from Gemini"]))
                    return
                }

                // Parse JSON response
                do {
                    let recommendation = try self.parseResponse(text)
                    // Cache the result
                    AnalysisCache.saveBedtimeRecommendation(recommendation)
                    completion(recommendation, nil)
                } catch {
                    print("🌙 [Bedtime] Failed to parse Gemini response: \(error)")
                    print("🌙 [Bedtime] Raw response: \(text.prefix(500))")
                    completion(nil, error)
                }
            }
        }
    }

    // MARK: - Parse Response

    private func parseResponse(_ text: String) throws -> BedtimeRecommendation {
        // Strip markdown code fences if present
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

        return try JSONDecoder().decode(BedtimeRecommendation.self, from: data)
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
        request.timeoutInterval = 120

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "systemInstruction": [
                "parts": [["text": Self.systemInstruction]]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "topP": 0.95,
                "maxOutputTokens": 4096,
                "responseMimeType": "text/plain"
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, error)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                let ns = error as NSError
                if ns.code == NSURLErrorCancelled { return }

                // Retry on network errors
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

                // Retry on server errors
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

            // Parse Gemini response envelope
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
