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

    /// True when the last `generateHomeRecommendations` call returned nil because
    /// there was no meaningful health data to send (all metrics were zero / missing).
    /// The dashboard uses this to decide whether to hide the section vs. show a retry.
    var lastHomeRecsHadNoData = false

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

    # PERSONALIZATION & MEMORY
    - You have persistent memory of this user's health journey (provided in AION MEMORY block)
    - Reference their PERSONAL baselines when analyzing data (e.g., "Your HRV is 12% above YOUR baseline of 45ms")
    - Acknowledge progress or regressions from previous analyses
    - Use the user's name if provided in the memory block
    - Build on previous advice - don't repeat the same generic suggestions
    - If a previous STOP directive was followed (metric improved), acknowledge it
    - Compare current metrics against their personal baselines, not population averages
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

            // Don't send empty data to Gemini
            if dailyEntries.isEmpty {
                print("⚠️ [GeminiService] No daily health entries — skipping Gemini analysis")
                completion(nil, nil, nil, nil)
                return
            }

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

            // Don't send empty data to Gemini — skip if no meaningful health data available
            if payload.dataReliabilityScore == 0 && payload.totalDays == 0 {
                print("⚠️ [GeminiService] No health data available — skipping Gemini analysis")
                completion(nil, nil, nil, nil)
                return
            }

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

            // Build AION Memory block (replaces raw previous analysis)
            let memory = AIONMemoryManager.loadFromCache()
            let memoryBlock = self.buildMemoryBlock(memory)
            print("🧠 [AION Memory] Loaded: \(memory != nil ? "YES (interactions: \(memory!.interactionCount))" : "nil (first analysis)")")

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
            \(memoryBlock)
            \(userNotesBlock)
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

                // Update AION Memory in the background
                if let parsed = CarAnalysisParser.parseJSON(response) {
                    let score = AnalysisCache.loadHealthScore() ?? 0
                    DispatchQueue.global(qos: .utility).async {
                        let updated = AIONMemoryExtractor.updateMemory(
                            existingMemory: memory,
                            parsedAnalysis: parsed,
                            healthPayload: payload,
                            healthScore: score
                        )
                        AIONMemoryManager.save(updated)
                        print("🧠 [AION Memory] Saved! Interactions: \(updated.interactionCount), Car: \(updated.userProfile.currentCarModel ?? "?"), HRV baseline: \(updated.userProfile.baselineHRV.map { "\(Int($0))ms" } ?? "?"), Recent analyses: \(updated.recentAnalyses.count)")
                    }
                } else {
                    print("🧠 [AION Memory] Could not parse response for memory update")
                }

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

    /// Builds the AION Memory block to inject into the prompt.
    private func buildMemoryBlock(_ memory: AIONMemory?) -> String {
        guard let memory = memory, memory.interactionCount > 0 else {
            return """

            ==================================================
            AION MEMORY - USER CONTEXT
            ==================================================
            This is the FIRST analysis for this user. No previous history available.
            Provide a thorough initial assessment and establish baseline observations.
            """
        }

        let profile = memory.userProfile
        let insights = memory.longitudinalInsights
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        var block = """

        ==================================================
        AION MEMORY - USER CONTEXT
        ==================================================
        This is analysis #\(memory.interactionCount + 1) for this user.
        You have been their health advisor since \(dateFormatter.string(from: memory.firstAnalysisDate)).

        USER PROFILE:
        """

        if let name = profile.displayName, !name.isEmpty {
            block += "\n- Name: \(name)"
        }
        if let device = profile.dataSource, !device.isEmpty {
            block += "\n- Device: \(device)"
        }
        if let fitness = profile.fitnessLevel, !fitness.isEmpty {
            block += "\n- Fitness level: \(fitness)"
        }
        if let sleep = profile.typicalSleepHours {
            block += "\n- Typical sleep: \(sleep)h"
        }
        if let hrv = profile.baselineHRV {
            block += "\n- Baseline HRV: \(Int(hrv)) ms"
        }
        if let rhr = profile.baselineRHR {
            block += "\n- Baseline RHR: \(Int(rhr)) bpm"
        }
        if let vo2 = profile.vo2maxRange, !vo2.isEmpty {
            block += "\n- VO2max range: \(vo2)"
        }
        if let car = profile.currentCarModel, !car.isEmpty {
            block += "\n- Current car: \(car)"
        }
        if let history = profile.carHistoryBrief, !history.isEmpty {
            block += "\n- Car journey: \(history)"
        }
        if !profile.knownConditions.isEmpty {
            block += "\n- Known conditions: \(profile.knownConditions.joined(separator: ", "))"
        }

        // Longitudinal observations
        var hasLongitudinal = false
        var longBlock = "\n\nLONG-TERM OBSERVATIONS:"

        if let sleepTrend = insights.sleepTrend, !sleepTrend.isEmpty {
            longBlock += "\n- Sleep trend: \(sleepTrend)"
            hasLongitudinal = true
        }
        if let recoveryPattern = insights.recoveryPattern, !recoveryPattern.isEmpty {
            longBlock += "\n- Recovery pattern: \(recoveryPattern)"
            hasLongitudinal = true
        }
        if let trainingPattern = insights.trainingPattern, !trainingPattern.isEmpty {
            longBlock += "\n- Training pattern: \(trainingPattern)"
            hasLongitudinal = true
        }
        if !insights.keyStrengths.isEmpty {
            longBlock += "\n- Strengths: \(insights.keyStrengths.joined(separator: "; "))"
            hasLongitudinal = true
        }
        if !insights.persistentWeaknesses.isEmpty {
            longBlock += "\n- Persistent issues: \(insights.persistentWeaknesses.joined(separator: "; "))"
            hasLongitudinal = true
        }
        if let supplements = insights.supplementHistory, !supplements.isEmpty {
            longBlock += "\n- Previous supplements: \(supplements)"
            hasLongitudinal = true
        }
        if !insights.notableEvents.isEmpty {
            longBlock += "\n- Notable events: \(insights.notableEvents.joined(separator: "; "))"
            hasLongitudinal = true
        }

        if hasLongitudinal {
            block += longBlock
        }

        // Recent analyses
        if !memory.recentAnalyses.isEmpty {
            block += "\n\nRECENT ANALYSES (last \(memory.recentAnalyses.count)):"
            for (i, analysis) in memory.recentAnalyses.enumerated() {
                block += "\n[\(i + 1)] \(dateFormatter.string(from: analysis.date)) | Car: \(analysis.carModel) | Score: \(analysis.healthScore)"
                if !analysis.keyFindings_en.isEmpty {
                    block += "\n    Findings: \(analysis.keyFindings_en)"
                }
                if let stop = analysis.directiveStop, !stop.isEmpty {
                    block += "\n    STOP: \(stop)"
                }
                if let start = analysis.directiveStart, !start.isEmpty {
                    block += "\n    START: \(start)"
                }
                if let watch = analysis.directiveWatch, !watch.isEmpty {
                    block += "\n    WATCH: \(watch)"
                }
            }
        }

        block += """

        \nCONTINUITY INSTRUCTIONS:
        - Reference specific improvements or regressions you've tracked in their history
        - If a previous directive was followed and the metric improved, acknowledge it
        - Compare current metrics against their PERSONAL baselines listed above, not population averages
        - Build on previous recommendations - evolve your advice, don't repeat the same generic suggestions
        """

        return block
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

    // MARK: - Home Screen Recommendations (3 categories)

    /// Generates 3 personalised recommendations: medical, sports, nutrition.
    /// Uses a dedicated lightweight Gemini call (separate from the main analysis).
    func generateHomeRecommendations(
        healthData: HealthDataModel,
        dailyMetrics: DailyMetrics,
        completion: @escaping (HomeRecommendations?) -> Void
    ) {
        print("🤖 [HomeRecs] generateHomeRecommendations() START")
        let lang = LocalizationManager.shared.currentLanguage == .hebrew ? "Hebrew" : "English"
        print("🤖 [HomeRecs] Language: \(lang)")

        // Build a summary from raw HealthKit data (real measurements, not calculated scores)
        // Filter out zero values — 0 means "no data" for most health metrics
        var lines: [String] = []

        // Sleep
        if let sleep = healthData.sleepHours, sleep > 0 { lines.append("Sleep last night: \(String(format: "%.1f", sleep)) hours") }
        if let deep = healthData.sleepDeepHours, deep > 0 { lines.append("Deep sleep: \(String(format: "%.1f", deep)) hours") }
        if let rem = healthData.sleepRemHours, rem > 0 { lines.append("REM sleep: \(String(format: "%.1f", rem)) hours") }
        if let efficiency = healthData.sleepEfficiency, efficiency > 0 { lines.append("Sleep efficiency: \(Int(efficiency))%") }

        // Heart / Recovery
        if let hrv = healthData.heartRateVariability, hrv > 0 { lines.append("HRV: \(Int(hrv)) ms") }
        if let rhr = healthData.restingHeartRate, rhr > 0 { lines.append("Resting heart rate: \(Int(rhr)) bpm") }
        if let hr = healthData.heartRate, hr > 0 { lines.append("Current heart rate: \(Int(hr)) bpm") }
        if let spo2 = healthData.oxygenSaturation, spo2 > 0 { lines.append("Blood oxygen: \(Int(spo2 * 100))%") }
        if let recovery = healthData.heartRateRecovery, recovery > 0 { lines.append("Heart rate recovery: \(Int(recovery)) bpm") }

        // Activity
        if let steps = healthData.steps, steps > 0 { lines.append("Steps today: \(Int(steps))") }
        if let active = healthData.activeEnergy, active > 0 { lines.append("Active calories: \(Int(active)) kcal") }
        if let exercise = healthData.exerciseMinutes, exercise > 0 { lines.append("Exercise minutes: \(Int(exercise))") }
        if let standHours = healthData.standHours, standHours > 0 { lines.append("Stand hours: \(Int(standHours))") }

        // Workouts
        if let workoutMin = healthData.totalWorkoutMinutes, workoutMin > 0 {
            lines.append("Workout today: \(Int(workoutMin)) minutes")
        }
        if let types = healthData.workoutTypes, !types.isEmpty {
            lines.append("Workout types: \(types.joined(separator: ", "))")
        }

        // Fitness
        if let vo2 = healthData.vo2Max, vo2 > 0 { lines.append("VO2 Max: \(String(format: "%.1f", vo2))") }

        // Body
        if let temp = healthData.bodyTemperatureDeviation, abs(temp) > 0.01 {
            lines.append("Body temperature deviation: \(String(format: "%+.1f", temp))°C")
        }
        if let resp = healthData.respiratoryRate, resp > 0 { lines.append("Respiratory rate: \(String(format: "%.1f", resp)) breaths/min") }

        let metricsBlock = lines.joined(separator: "\n")
        print("🤖 [HomeRecs] Metrics block (\(lines.count) lines):\n\(metricsBlock)")

        // Don't send empty data to Gemini — skip if no meaningful metrics available
        if lines.isEmpty {
            print("🤖 [HomeRecs] ⚠️ No health data available — skipping Gemini call")
            lastHomeRecsHadNoData = true
            completion(nil)
            return
        }
        lastHomeRecsHadNoData = false

        let prompt = """
        You are given today's REAL health data from Apple Health / wearable device for a user.
        Analyze the raw data and provide EXACTLY 3 short, personalised recommendations (2-3 sentences each).

        Be specific and reference actual numbers from the data.
        If the data looks good (e.g. good sleep, low resting HR, high HRV), acknowledge it positively.
        Focus advice on areas that actually need improvement based on the data.
        Write in \(lang).

        TODAY'S HEALTH DATA:
        \(metricsBlock)

        Return ONLY valid JSON with this exact schema — no text before or after:
        {
          "medical": "Health/medical observation and advice based on the real data",
          "sports": "Training and exercise recommendation based on today's recovery and activity",
          "nutrition": "Dietary recommendation based on today's activity and recovery needs"
        }
        """

        let systemInstruction = """
        You are an elite health advisor. Provide concise, actionable advice.
        Output ONLY valid JSON. No markdown, no code fences.
        """

        // Use a separate URLSession call so we don't block the main analysis pipeline
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            print("🤖 [HomeRecs] ❌ Invalid URL!")
            completion(nil)
            return
        }
        print("🤖 [HomeRecs] URL created OK, sending request...")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "systemInstruction": ["parts": [["text": systemInstruction]]],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 4096,
                "responseMimeType": "text/plain"
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            print("🤖 [HomeRecs] ❌ Failed to serialize request body!")
            completion(nil)
            return
        }
        request.httpBody = httpBody
        print("🤖 [HomeRecs] Request body: \(httpBody.count) bytes, firing URLSession...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("⚠️ [HomeRecommendations] Request failed: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }

            // Log HTTP status for debugging
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                let raw = String(data: data, encoding: .utf8) ?? "(no body)"
                print("⚠️ [HomeRecommendations] HTTP \(httpResp.statusCode): \(raw.prefix(300))")
                completion(nil)
                return
            }

            // Parse Gemini response envelope
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                let raw = String(data: data, encoding: .utf8) ?? "(no body)"
                print("⚠️ [HomeRecommendations] Failed to parse Gemini envelope: \(raw.prefix(500))")
                completion(nil)
                return
            }

            // Log finishReason for debugging
            let finishReason = firstCandidate["finishReason"] as? String ?? "unknown"
            print("🤖 [HomeRecs] finishReason: \(finishReason), parts count: \(parts.count)")

            // Concatenate ALL text parts (Gemini may split the response across multiple parts)
            let text = parts.compactMap { $0["text"] as? String }.joined()
            guard !text.isEmpty else {
                let raw = String(data: data, encoding: .utf8) ?? "(no body)"
                print("⚠️ [HomeRecommendations] Empty text in parts. Raw: \(raw.prefix(500))")
                completion(nil)
                return
            }

            // Clean markdown code fences that Gemini may wrap around the JSON
            var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if jsonString.hasPrefix("```json") {
                jsonString = String(jsonString.dropFirst(7))
            } else if jsonString.hasPrefix("```") {
                jsonString = String(jsonString.dropFirst(3))
            }
            if jsonString.hasSuffix("```") {
                jsonString = String(jsonString.dropLast(3))
            }
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse the inner JSON
            guard let innerData = jsonString.data(using: .utf8) else {
                print("⚠️ [HomeRecommendations] Failed to convert jsonString to Data")
                completion(nil)
                return
            }

            // Log full JSON for debugging
            print("🤖 [HomeRecs] Full JSON response (\(jsonString.count) chars):\n\(jsonString)")

            // Try decoding with detailed error
            let recs: HomeRecommendations
            do {
                recs = try JSONDecoder().decode(HomeRecommendations.self, from: innerData)
            } catch {
                print("⚠️ [HomeRecommendations] Decode error: \(error)")
                print("⚠️ [HomeRecommendations] JSON string: \(jsonString)")

                // Fallback: try parsing as generic JSON dict to extract fields manually
                if let dict = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] {
                    let medical = dict["medical"] as? String ?? ""
                    let sports = dict["sports"] as? String ?? ""
                    let nutrition = dict["nutrition"] as? String ?? ""
                    if !medical.isEmpty || !sports.isEmpty || !nutrition.isEmpty {
                        let fallbackRecs = HomeRecommendations(medical: medical, sports: sports, nutrition: nutrition)
                        print("✅ [HomeRecommendations] Recovered via manual dict parsing!")
                        completion(fallbackRecs)
                        return
                    }
                }

                completion(nil)
                return
            }

            print("✅ [HomeRecommendations] Successfully loaded recommendations")
            completion(recs)
        }.resume()
    }
}
