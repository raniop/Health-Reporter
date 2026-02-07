//
//  GeminiService.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import Foundation
import FirebaseAuth

class GeminiService {
    static let shared = GeminiService()
    
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
    
    private static let aionSystemInstruction = """
    # ROLE: AION Health Analysis Engine
    You are an Elite Sports Physician, Performance Coach, and Data Analyst combined.

    # OUTPUT REQUIREMENTS
    - Return ONLY valid JSON - no text before or after the JSON block
    - All text fields MUST have both Hebrew (_he) and English (_en) versions
    - Follow the exact JSON schema provided in the prompt
    - Be concise: 2-3 sentences per field maximum

    # DATA INTERPRETATION
    - Values of 0, null, "", "N/A", "unknown" = missing data (exclude from analysis)
    - Each metric includes validDays - lower values mean lower confidence
    - Never fabricate or estimate missing data - only analyze what's provided

    # CAR IDENTITY RULES
    - Car model MUST be a REAL car searchable on Wikipedia (e.g., "Porsche 911 GT3")
    - NOT concepts like "Zone 2", "Recovery Mode", "Base Model", etc.
    - Keep the same car unless significant performance changes (detailed rules in prompt)
    """
    
    private var currentTask: URLSessionDataTask?
    private let taskQueue = DispatchQueue(label: "GeminiService.task")
    private var isAnalysisInProgress = false
    private let maxRetries = 2

    private init() {}

    /// Checks if an analysis is currently in progress
    var isRunning: Bool {
        return isAnalysisInProgress
    }

    /// Errors worth retrying
    private func isRetryableError(_ error: Error) -> Bool {
        let ns = error as NSError
        // Timeout, network connection lost, not connected to internet
        return ns.code == NSURLErrorTimedOut ||
               ns.code == NSURLErrorNetworkConnectionLost ||
               ns.code == NSURLErrorNotConnectedToInternet ||
               ns.code == -8 // HTTP error (e.g., 503 Service Unavailable)
    }

    /// Cancels a Gemini request currently in progress (e.g., on refresh / range change).
    func cancelCurrentRequest() {
        taskQueue.async { [weak self] in
            self?.currentTask?.cancel()
            self?.currentTask = nil
        }
    }

    /// Analyzes health data with weekly comparison (optional: 6 chart bundle for AION)
    /// Gemini selects the car on its own based on the analysis
    /// Includes data source context (Garmin/Oura/Apple Watch) for personalization
    func analyzeHealthDataWithWeeklyComparison(_ healthData: HealthDataModel, currentWeek: WeeklyHealthSnapshot, previousWeek: WeeklyHealthSnapshot, chartBundle: AIONChartDataBundle? = nil, completion: @escaping (String?, [String]?, [String]?, Error?) -> Void) {

        // Fetch 90 days of daily data to build the new Payload
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { [weak self] dailyEntries in
            guard let self = self else { return }

            #if DEBUG
            // Test user - don't overwrite the score already computed from mock data
            let isTestUser = DebugTestHelper.isTestUser(email: Auth.auth().currentUser?.email)
            if !isTestUser {
                // === Local HealthScore calculation with HealthScoreEngine ===
                let healthResult = HealthScoreEngine.shared.calculate(from: dailyEntries)
                // Save the score and breakdown in Cache for UI usage
                AnalysisCache.saveHealthScoreResult(healthResult)
            } else {
                print("🧪 [GeminiService] Test user - preserving mock health score")
            }
            #else
            // === Local HealthScore calculation with HealthScoreEngine ===
            let healthResult = HealthScoreEngine.shared.calculate(from: dailyEntries)
            // Save the score and breakdown in Cache for UI usage
            AnalysisCache.saveHealthScoreResult(healthResult)
            #endif

            // Build the new Payload with filtering of missing values and outliers
            let builder = GeminiHealthPayloadBuilder()
            let payload = builder.build(from: dailyEntries)

            guard let payloadJSON = payload.toJSONString() else {
                completion(nil, nil, nil, NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error creating analysis payload"]))
                return
            }

            let graphsBlock: String
            if let bundle = chartBundle, let graphPayload = bundle.toAIONReviewPayload().toJSONString() {
                graphsBlock = """
                # 6 Professional Charts (JSON)
                Analyze the "intersectionality" of the charts. Example: "In chart 1 (Readiness) and 3 (Sleep): even though load was low, recovery didn't spike. Based on sleep temperature - is the environment or nutrition the issue?"
                \(graphPayload)
                """
            } else {
                graphsBlock = ""
            }

            // Data source context for tailored analysis
            let dataSourceContext = self.buildDataSourceContext()

            // Personal notes from the user (e.g., "I drank alcohol yesterday")
            let userNotesBlock: String
            if let notes = AnalysisCache.loadUserNotes(), !notes.isEmpty {
                userNotesBlock = """

                ==================================================
                USER PERSONAL CONTEXT
                ==================================================
                The user provided these personal notes. Factor them into your analysis
                and mention them where relevant (e.g., how alcohol affects HRV/sleep):
                \(notes)
                """
            } else {
                userNotesBlock = ""
            }

            // Retrieve the previous car from cache (Car Identity Lock)
            var lastCarModel: String? = nil
            var lastCarReason: String? = nil
            if let savedCar = AnalysisCache.loadSelectedCar() {
                lastCarModel = savedCar.wikiName.isEmpty ? savedCar.name : savedCar.wikiName
                lastCarReason = savedCar.explanation
            }

            // Retrieve the previous response for context
            let previousAnalysis = AnalysisCache.loadLatest() ?? ""
            let previousAnalysisBlock = previousAnalysis.isEmpty ? "No previous analysis available" : previousAnalysis

            let prompt = """
            MISSION: Analyze 90-day health performance trends and provide actionable insights.
            Data sources: Weekly summaries (13 weeks) + daily data (last 14 days).

            ==================================================
            CAR IDENTITY LOCK
            ==================================================

            Previous car: \(lastCarModel ?? "none")
            Previous reason: \(lastCarReason ?? "none")

            RULES:
            1. If no significant performance changes detected, return the SAME car model.
            2. Car change allowed ONLY if 2+ of these criteria are met:
               - VO2max change ≥10%
               - HRV consistent change ≥15%
               - Resting HR change ±5 bpm
               - Training load category shift (low↔medium↔high)
               - Significant sleep quality change
            3. If car changes, explain which metrics justified it.
            4. Car MUST be a real car model searchable on Wikipedia (e.g., "BMW M3", "Tesla Model S").
               NOT concepts like "Zone 2", "Recovery Mode", "Base Model".

            ==================================================
            REQUIRED JSON OUTPUT (Bilingual)
            ==================================================

            Return ONLY valid JSON. Every text field must have both _he (Hebrew) and _en (English) versions.

            {
              "carIdentity": {
                "model_he": "Car name in Hebrew",
                "model_en": "Car name in English",
                "wikiName": "Wikipedia-searchable English car name",
                "explanation_he": "Why this car fits the user's profile (2-3 sentences, Hebrew)",
                "explanation_en": "Why this car fits the user's profile (2-3 sentences, English)"
              },
              "performanceReview": {
                "engine_he": "Cardio fitness, endurance, VO2max analysis (Hebrew)",
                "engine_en": "Cardio fitness, endurance, VO2max analysis (English)",
                "transmission_he": "Recovery, sleep, HRV analysis (Hebrew)",
                "transmission_en": "Recovery, sleep, HRV analysis (English)",
                "suspension_he": "Injury status, flexibility, joints (Hebrew)",
                "suspension_en": "Injury status, flexibility, joints (English)",
                "fuelEfficiency_he": "Energy, stress, nutrition (Hebrew)",
                "fuelEfficiency_en": "Energy, stress, nutrition (English)",
                "electronics_he": "Focus, consistency, nervous system balance (Hebrew)",
                "electronics_en": "Focus, consistency, nervous system balance (English)"
              },
              "bottlenecks_he": ["Bottleneck 1 in Hebrew", "Bottleneck 2 in Hebrew"],
              "bottlenecks_en": ["Bottleneck 1 in English", "Bottleneck 2 in English"],
              "optimizationPlan": {
                "upgrades_he": ["Upgrade 1 Hebrew", "Upgrade 2 Hebrew"],
                "upgrades_en": ["Upgrade 1 English", "Upgrade 2 English"],
                "skippedMaintenance_he": ["Skipped maintenance Hebrew"],
                "skippedMaintenance_en": ["Skipped maintenance English"],
                "stopImmediately_he": ["Stop immediately Hebrew"],
                "stopImmediately_en": ["Stop immediately English"]
              },
              "tuneUpPlan": {
                "trainingAdjustments_he": "Training adjustments for next 1-2 months (Hebrew)",
                "trainingAdjustments_en": "Training adjustments for next 1-2 months (English)",
                "recoveryChanges_he": "Recovery and sleep changes (Hebrew)",
                "recoveryChanges_en": "Recovery and sleep changes (English)",
                "habitToAdd_he": "One new habit to add with explanation (Hebrew)",
                "habitToAdd_en": "One new habit to add with explanation (English)",
                "habitToRemove_he": "One habit to remove with explanation (Hebrew)",
                "habitToRemove_en": "One habit to remove with explanation (English)"
              },
              "directives": {
                "stop_he": "One sentence - what to stop (Hebrew)",
                "stop_en": "One sentence - what to stop (English)",
                "start_he": "One sentence - what to start (Hebrew)",
                "start_en": "One sentence - what to start (English)",
                "watch_he": "One sentence - what to monitor (Hebrew)",
                "watch_en": "One sentence - what to monitor (English)"
              },
              "forecast_he": "3-month forecast if current trends continue (Hebrew)",
              "forecast_en": "3-month forecast if current trends continue (English)",
              "energyForecast": {
                "text_he": "Today's energy prediction based on HRV, sleep, and recent activity (1-2 sentences, Hebrew)",
                "text_en": "Today's energy prediction based on HRV, sleep, and recent activity (1-2 sentences, English)",
                "trend": "rising|falling|stable (based on recent recovery and sleep trends)"
              },
              "supplements": [
                {
                  "name_he": "Supplement name (Hebrew)",
                  "name_en": "Supplement name (English)",
                  "dosage_he": "Exact dosage and timing (Hebrew)",
                  "dosage_en": "Exact dosage and timing (English)",
                  "reason_he": "Specific reason from data (Hebrew)",
                  "reason_en": "Specific reason from data (English)",
                  "category": "sleep|performance|recovery|general"
                }
              ]
            }

            CRITICAL RULES:
            - Return JSON ONLY, no text before or after
            - ALL fields are required - do not omit any
            - Every text field must have both _he and _en versions
            - Valid supplement categories: sleep, performance, recovery, general
            - wikiName must be a REAL car (not a concept)
            - If lastCarModel exists and is a real car with no major changes, keep it

            ==================================================
            DATA
            ==================================================

            lastCarModel: \(lastCarModel ?? "null")
            lastCarReason: \(lastCarReason ?? "null")

            \(payloadJSON)
            \(graphsBlock)
            \(dataSourceContext)
            \(userNotesBlock)

            ==================================================
            PREVIOUS ANALYSIS (for continuity)
            ==================================================

            \(previousAnalysisBlock)
            """

            // Save for debug (before sending)
            GeminiDebugStore.lastPrompt = prompt

            self.sendRequest(prompt: prompt, temperature: 0.2) { response, error in
                if let error = error {
                    completion(nil, nil, nil, error)
                    return
                }

                guard let response = response else {
                    completion(nil, nil, nil, NSError(domain: "GeminiService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No response received from Gemini"]))
                    return
                }

                // Save for debug (after receiving the response)
                GeminiDebugStore.save(prompt: prompt, response: response)

                // Parse the response into parts
                let (insights, recommendations, riskFactors) = self.parseResponse(response)
                completion(insights, recommendations, riskFactors, nil)
            }
        }
    }
    
    private static func parseAPIError(statusCode: Int, data: Data?) -> String {
        if statusCode == 429 {
            let quotaMessage = "You've exceeded the daily Gemini quota (20 free requests). Try again tomorrow, or upgrade to a paid plan on Google AI Studio."
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let error = json["error"] as? [String: Any] else {
                return quotaMessage
            }
            let status = error["status"] as? String ?? ""
            let message = error["message"] as? String ?? ""
            if status == "RESOURCE_EXHAUSTED" || message.lowercased().contains("quota") || message.contains("quota") {
                return quotaMessage
            }
            if message.lowercased().contains("retry") || message.contains("41") {
                return quotaMessage + " (The system recommends retrying in about 40 seconds if this is a rate limit.)"
            }
            return quotaMessage
        }
        if statusCode == 503 {
            return "Gemini service is currently unavailable. Try again in a few minutes."
        }
        if statusCode != 200 {
            return "Server error: \(statusCode)"
        }
        return "Error from Gemini"
    }

    private func formatJSONForPrompt(_ json: [String: Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }

    /// Builds data source context for tailored analysis
    private func buildDataSourceContext() -> String {
        let source = DataSourceManager.shared.effectiveSource()
        let strengths = source.strengths
        let isCalculated = source == .autoDetect || source == .appleWatch

        var context = """
        # DATA SOURCE
        User device: **\(source.displayName)**.
        """

        if !strengths.isEmpty {
            context += "\n\nDevice strengths:\n"
            context += strengths.map { "- \($0)" }.joined(separator: "\n")
        }

        // Add device-specific guidance
        switch source {
        case .garmin:
            context += """

            ## Garmin-Specific Notes
            - Highly accurate HRV data (24/7 or sleep-based)
            - Detailed sleep stages (Deep, Light, REM, Awake)
            - VO2 Max and Training Status available
            - Note: Body Battery and Training Load don't sync to HealthKit - displayed scores are calculated from HRV, HR, and sleep
            - Focus on HRV and RHR trends as recovery indicators
            """
        case .oura:
            context += """

            ## Oura-Specific Notes
            - Highly accurate nighttime HRV (5-minute algorithm)
            - Detailed sleep stages with efficiency score
            - Body temperature deviation - early indicator for illness/stress
            - Note: Oura Readiness Score doesn't sync - displayed score is calculated from HRV, HR, and sleep
            - If positive temperature deviation (>0.5°C), consider recommending load reduction
            """
        case .whoop:
            context += """

            ## WHOOP-Specific Notes
            - Continuous and accurate HRV measurement
            - Recovery Score and Strain don't sync - calculated locally
            - Focus on Recovery-to-Strain ratio
            """
        case .appleWatch:
            context += """

            ## Apple Watch-Specific Notes
            - Accurate heart rate and calorie tracking
            - HRV measured at specific points (not continuous)
            - Basic sleep stages (Core, Deep, REM)
            - VO2 Max and Walking HRR available
            """
        case .autoDetect:
            context += """

            ## Auto-Detect Mode
            System automatically detects the most active data source.
            Scores (Readiness, Strain) are calculated by AION algorithm from HealthKit data.
            """
        default:
            break
        }

        if isCalculated {
            context += """

            ## Note on Calculated Scores
            Readiness and Strain scores are **calculated** by the app, not from the device directly.
            Calculation based on: HRV (35%), Resting HR (25%), Sleep Quality (30%), Recovery (10%).
            """
        }

        return context
    }
    
    private func sendRequest(prompt: String, systemInstruction: String? = nil, temperature: Double = 0.2, completion: @escaping (String?, Error?) -> Void) {
        // Prevent duplicate calls
        guard !isAnalysisInProgress else {
            completion(nil, NSError(domain: "GeminiService", code: -10, userInfo: [NSLocalizedDescriptionKey: "Analysis already in progress"]))
            return
        }
        isAnalysisInProgress = true

        sendRequestInternal(prompt: prompt, systemInstruction: systemInstruction, temperature: temperature, retryCount: 0, completion: completion)
    }

    private func sendRequestInternal(prompt: String, systemInstruction: String?, temperature: Double, retryCount: Int, completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            isAnalysisInProgress = false
            completion(nil, NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        
        var requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [ ["text": prompt] ]
                ]
            ]
        ]
        let sys = systemInstruction ?? Self.aionSystemInstruction
        requestBody["systemInstruction"] = [ "parts": [ ["text": sys] ] ]
        requestBody["generationConfig"] = [
            "temperature": temperature,
            "topP": 0.95,
            "maxOutputTokens": 16384,
            "responseMimeType": "text/plain"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(nil, error)
            return
        }

        taskQueue.sync { [weak self] in
            self?.currentTask?.cancel()
            self?.currentTask = nil
        }
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            self?.taskQueue.async { self?.currentTask = nil }

            // Handle errors with retry
            if let error = error {
                let ns = error as NSError
                if ns.code == NSURLErrorCancelled {
                    self?.isAnalysisInProgress = false
                    return
                }

                // Check if it's worth retrying
                if let self = self, self.isRetryableError(error), retryCount < self.maxRetries {
                    let delay = Double(retryCount + 1) * 2.0 // Exponential backoff: 2s, 4s
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.sendRequestInternal(prompt: prompt, systemInstruction: systemInstruction, temperature: temperature, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }

                self?.isAnalysisInProgress = false
                completion(nil, error)
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let userMessage = Self.parseAPIError(statusCode: httpResponse.statusCode, data: data)
                let httpError = NSError(domain: "GeminiService", code: -8, userInfo: [NSLocalizedDescriptionKey: userMessage])

                // Retry on certain HTTP errors (503, 429, 500)
                if let self = self, [500, 502, 503, 429].contains(httpResponse.statusCode), retryCount < self.maxRetries {
                    let delay = Double(retryCount + 1) * 2.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.sendRequestInternal(prompt: prompt, systemInstruction: systemInstruction, temperature: temperature, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }

                self?.isAnalysisInProgress = false
                completion(nil, httpError)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data in response"]))
                return
            }
            
            // Success - analysis complete
            self?.isAnalysisInProgress = false

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(nil, NSError(domain: "GeminiService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid response format - not JSON"]))
                    return
                }

                // Check if there's an error in the response (200 response but error in JSON)
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    let userMessage = Self.parseAPIError(statusCode: 200, data: data) ?? "Error from Gemini: \(message)"
                    completion(nil, NSError(domain: "GeminiService", code: -6, userInfo: [NSLocalizedDescriptionKey: userMessage]))
                    return
                }

                // Attempt to parse the response
                if let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first {

                    if let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        let finishReason = firstCandidate["finishReason"] as? String

                        if finishReason == "MAX_TOKENS" && !text.isEmpty {
                            let truncated = text + "\n\n_(Response was truncated - maxOutputTokens increased for next run.)_"
                            completion(truncated, nil)
                        } else if finishReason != "STOP" && finishReason != nil {
                            completion(nil, NSError(domain: "GeminiService", code: -7, userInfo: [NSLocalizedDescriptionKey: "Reason: \(finishReason!)"]))
                        } else {
                            completion(text, nil)
                        }
                        return
                    }

                    let finishReason = firstCandidate["finishReason"] as? String
                    if finishReason == "MAX_TOKENS" {
                        completion(nil, NSError(domain: "GeminiService", code: -7, userInfo: [NSLocalizedDescriptionKey: "Response truncated - too many words"]))
                        return
                    }
                }

                completion(nil, NSError(domain: "GeminiService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid response format. Check the console for more details."]))
            } catch {
                completion(nil, error)
            }
        }
        taskQueue.async { [weak self] in
            self?.currentTask = task
        }
        task.resume()
    }
    
    private func parseResponse(_ response: String) -> (insights: String, recommendations: [String], riskFactors: [String]) {
        var insights = response
        var recommendations: [String] = []
        var riskFactors: [String] = []
        
        // Extract the "Tune-Up Plan" or "Optimization Plan" section as a single recommendation
        let tuneUpMarkers = [
            "תוכנית כוונון ל-30-60 הימים הבאים",
            "תוכנית כוונון",
            "Next 30–60 Day Tune-Up Plan",
            "Next 30-60 Day Tune-Up Plan",
            "תוכנית אופטימיזציה",
            "Optimization Plan"
        ]
        
        for marker in tuneUpMarkers {
            if let range = response.range(of: marker, options: .caseInsensitive) {
                let afterMarker = String(response[range.upperBound...])
                // Look for the end of the section - summary or a new section
                let endMarkers = ["סיכום:", "**סיכום**", "Summary:", "---", "\n\n\n"]
                var endIndex = afterMarker.endIndex
                for endMarker in endMarkers {
                    if let endRange = afterMarker.range(of: endMarker) {
                        if endRange.lowerBound < endIndex {
                            endIndex = endRange.lowerBound
                        }
                    }
                }
                let tuneUpSection = String(afterMarker[..<endIndex])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !tuneUpSection.isEmpty && tuneUpSection.count > 50 {
                    recommendations.append(tuneUpSection)
                    break
                }
            }
        }
        
        // Attempt to break the response into parts
        let lines = response.components(separatedBy: .newlines)
        var currentSection: String? = nil
        var inRecommendationsSection = false
        var inRiskFactorsSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Identify sections - support multiple formats
            if trimmed.contains("3 המלצות מעשיות") ||
               trimmed.contains("המלצות מעשיות") ||
               trimmed.contains("המלצות לשבוע") ||
               trimmed.contains("תוכנית כוונון") ||
               trimmed.contains("תוכנית אופטימיזציה") ||
               trimmed.contains("Tune-Up Plan") ||
               trimmed.contains("Optimization Plan") ||
               trimmed.contains("Next 30") ||
               trimmed.contains("Next 60") {
                inRecommendationsSection = true
                inRiskFactorsSection = false
                currentSection = "recommendations"
                continue
            } else if trimmed.contains("גורמי סיכון") ||
                      trimmed.contains("סיכון") ||
                      trimmed.contains("Check Engine") ||
                      trimmed.contains("early warning") {
                inRiskFactorsSection = true
                inRecommendationsSection = false
                currentSection = "risks"
                continue
            } else if trimmed.hasPrefix("##") || trimmed.hasPrefix("###") {
                // New heading - reset section only if it's not part of recommendations
                // Sub-headings within a tune-up plan are still considered part of recommendations
                if !trimmed.contains("המלצות") &&
                   !trimmed.contains("סיכון") &&
                   !trimmed.contains("תוכנית") &&
                   !trimmed.contains("Plan") &&
                   !trimmed.contains("Tune") &&
                   !trimmed.contains("Optimization") &&
                   !trimmed.contains("Training") &&
                   !trimmed.contains("Recovery") &&
                   !trimmed.contains("התאמות") &&    // "adjustments" in Hebrew
                   !trimmed.contains("שינויים") &&    // "changes" in Hebrew
                   !trimmed.contains("הרגל") &&       // "habit" in Hebrew
                   !trimmed.contains("habit") {
                    inRecommendationsSection = false
                    inRiskFactorsSection = false
                    currentSection = nil
                }
            }
            
            // If we're inside a recommendations section, regular lines (not just lists) can also be recommendations
            if inRecommendationsSection && !trimmed.isEmpty &&
               !trimmed.hasPrefix("#") &&
               !trimmed.contains("---") &&
               trimmed.count > 20 {
                // If it's not a list but it's part of the recommendations section, keep it
                if !recommendations.contains(where: { $0 == trimmed }) {
                    // Check if it's not part of an existing recommendation
                    let isPartOfExisting = recommendations.contains { existing in
                        trimmed.contains(existing) || existing.contains(trimmed)
                    }
                    if !isPartOfExisting {
                        recommendations.append(trimmed)
                    }
                }
            }
            
            // Collect recommendations - support multiple formats
            if inRecommendationsSection || currentSection == "recommendations" {
                // Support various formats: 1. 2. 3., -, bullet, *, or sub-headings with **
                if trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.") ||
                   trimmed.hasPrefix("4.") || trimmed.hasPrefix("5.") || trimmed.hasPrefix("6.") ||
                   trimmed.hasPrefix("7.") || trimmed.hasPrefix("8.") ||
                   trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") ||
                   (trimmed.hasPrefix("**") && trimmed.contains(":")) {
                    
                    var item = trimmed
                    
                    // Remove numbers and leading characters
                    item = item.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    item = item.replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                    
                    // If there are ** at the start and end, remove them
                    if item.hasPrefix("**") && item.hasSuffix("**") {
                        item = String(item.dropFirst(2).dropLast(2))
                    }
                    
                    // If there's a colon, take only the part after it
                    if let colonRange = item.range(of: ":") {
                        item = String(item[colonRange.upperBound...])
                    }
                    
                    item = item.trimmingCharacters(in: .whitespaces)
                    
                    // Only if it's not just a number or symbol, and it's long enough
                    if !item.isEmpty && item.count > 10 {
                        recommendations.append(item)
                    }
                }
            }
            
            // Collect risk factors
            if inRiskFactorsSection || currentSection == "risks" {
                if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") ||
                   trimmed.range(of: "^\\d+\\.", options: .regularExpression) != nil {
                    let item = trimmed.replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    
                    if !item.isEmpty && item.count > 10 {
                        riskFactors.append(item)
                    }
                }
            }
        }
        
        // If no structured recommendations or risk factors found, use the entire response as insights
        if recommendations.isEmpty && riskFactors.isEmpty {
            insights = response
        } else {
            // Keep the entire response as insights but highlight the recommendations
            insights = response
        }

        return (insights, recommendations, riskFactors)
    }
}
