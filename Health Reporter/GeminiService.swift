//
//  GeminiService.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import Foundation

class GeminiService {
    static let shared = GeminiService()
    
    private var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["GeminiAPIKey"] as? String,
              key != "YOUR_GEMINI_API_KEY_HERE" else {
            fatalError("אנא הגדר את מפתח ה-API של Gemini ב-Config.plist")
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

    /// בודק אם יש ניתוח בתהליך כרגע
    var isRunning: Bool {
        return isAnalysisInProgress
    }

    /// שגיאות שכדאי לנסות שוב
    private func isRetryableError(_ error: Error) -> Bool {
        let ns = error as NSError
        // Timeout, network connection lost, not connected to internet
        return ns.code == NSURLErrorTimedOut ||
               ns.code == NSURLErrorNetworkConnectionLost ||
               ns.code == NSURLErrorNotConnectedToInternet ||
               ns.code == -8 // HTTP error (e.g., 503 Service Unavailable)
    }

    /// מבטל בקשה ל‑Gemini שנמצאת כרגע בביצוע (למשל ברענון / שינוי טווח).
    func cancelCurrentRequest() {
        taskQueue.async { [weak self] in
            self?.currentTask?.cancel()
            self?.currentTask = nil
        }
    }

    /// מנתח נתוני בריאות ומחזיר תובנות
    func analyzeHealthData(_ healthData: HealthDataModel, completion: @escaping (String?, [String]?, [String]?, Error?) -> Void) {
        guard let summary = createHealthSummary(from: healthData),
              let jsonString = summary.toJSONString() else {
            completion(nil, nil, nil, NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "שגיאה ביצירת סיכום נתונים"]))
            return
        }
        
        let prompt = """
        # MISSION
        אתה "מנוע סינתזה בריאותי מרכזי" לאפליקציית בריאות אישית מתקדמת. אתה פועל כצוות מומחים רב-תחומי: רופא ספורט, דיאטן קליני, ומאמן ביצועים.

        # DATA INPUT
        נתוני בריאות (30 הימים האחרונים):
        \(jsonString)

        # ANALYSIS REQUIREMENTS
        1. ניתוח שבועי (Week-over-Week):
           - זהה שינויים באחוזים ב: דופק במנוחה (RHR), משך שינה, קלוריות פעילות, ו-VO2 Max (אם זמין).
           - הדגש "דגלים אדומים" (למשל: RHR עלה >5% ומשך שינה ירד >10% מצביע על אימון יתר/מחלה).

        2. סקירה הוליסטית משלושה מומחים:
           - רופא ספורט: התמקד במגמות קרדיווסקולריות וסמני התאוששות.
           - דיאטן קליני: קשר בין הוצאה אנרגטית לצריכת קלוריות (אם זמין) או הצע התאמות מקרונוטריינטים בהתבסס על עוצמת האימון.
           - מאמן ביצועים: נתח עומס אימון מול התאוששות. האם המשתמש מוכן ל"שבוע דחיפה" או "שבוע הפחתה"?

        3. המלצות מעשיות ("ה-3 היומיות"):
           - ספק בדיוק 3 פעולות ספציפיות ולא גנריות לשבוע הקרוב.
           - דוגמה: "הגדל חלבון ב-20ג' ביום שלישי/חמישי כדי להתאים לסשני חתירה בעוצמה גבוהה."

        # OUTPUT FORMAT
        אנא תן תשובה בעברית בפורמט הבא:
        
        ## תובנות כלליות
        [סקירה כללית של מצב הבריאות]
        
        ## ניתוח שבועי
        [שינויים באחוזים וזיהוי דגלים אדומים]
        
        ## דעת המומחים
        ### רופא ספורט
        [ניתוח קרדיווסקולרי וסמני התאוששות]
        
        ### דיאטן קליני
        [ניתוח תזונתי והמלצות]
        
        ### מאמן ביצועים
        [ניתוח עומס אימון והתאוששות]
        
        ## 🎯 ACTIONABLE DIRECTIVES (STOP/START/WATCH)
        - **STOP:** [משפט אחד – מה להפסיק]
        - **START:** [משפט אחד – מה להתחיל]
        - **WATCH:** [משפט אחד – מה לעקוב]

        ## 3 המלצות מעשיות לשבוע הקרוב
        1. [המלצה ספציפית ומעשית]
        2. [המלצה ספציפית ומעשית]
        3. [המלצה ספציפית ומעשית]
        
        ## גורמי סיכון (אם יש)
        [רשימת גורמי סיכון פוטנציאליים]
        """
        
        sendRequest(prompt: prompt, temperature: 0.2) { response, error in
            if let error = error {
                completion(nil, nil, nil, error)
                return
            }
            
            guard let response = response else {
                completion(nil, nil, nil, NSError(domain: "GeminiService", code: -2, userInfo: [NSLocalizedDescriptionKey: "לא התקבלה תשובה מ-Gemini"]))
                return
            }
            
            // פענוח התשובה לחלקים
            let (insights, recommendations, riskFactors) = self.parseResponse(response)
            completion(insights, recommendations, riskFactors, nil)
        }
    }
    
    private func createHealthSummary(from healthData: HealthDataModel, currentWeek: WeeklyHealthSnapshot? = nil, previousWeek: WeeklyHealthSnapshot? = nil) -> HealthSummary? {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        var keyMetrics: [String: Any] = [:]
        
        if let steps = healthData.steps {
            keyMetrics["steps"] = steps
        }
        if let heartRate = healthData.heartRate {
            keyMetrics["heart_rate"] = heartRate
        }
        if let bmi = healthData.bodyMassIndex {
            keyMetrics["bmi"] = bmi
        }
        if let sleepHours = healthData.sleepHours {
            keyMetrics["sleep_hours"] = sleepHours
        }
        
        return HealthSummary(dataModel: healthData, dateRange: dateRange, keyMetrics: keyMetrics, currentWeek: currentWeek, previousWeek: previousWeek)
    }
    
    /// מנתח נתוני בריאות עם השוואה שבועית (אופציונלי: צרור 6 הגרפים ל־AION)
    /// Gemini בוחר את הרכב בעצמו בהתבסס על הניתוח
    /// כולל הקשר מקור נתונים (Garmin/Oura/Apple Watch) להתאמה אישית
    func analyzeHealthDataWithWeeklyComparison(_ healthData: HealthDataModel, currentWeek: WeeklyHealthSnapshot, previousWeek: WeeklyHealthSnapshot, chartBundle: AIONChartDataBundle? = nil, completion: @escaping (String?, [String]?, [String]?, Error?) -> Void) {

        // שליפת 90 ימים של נתונים יומיים לבניית ה-Payload החדש
        HealthKitManager.shared.fetchDailyHealthData(days: 90) { [weak self] dailyEntries in
            guard let self = self else { return }

            // === חישוב HealthScore מקומי עם HealthScoreEngine ===
            let healthResult = HealthScoreEngine.shared.calculate(from: dailyEntries)

            // שמירת הציון והפירוט ב-Cache לשימוש ב-UI
            AnalysisCache.saveHealthScoreResult(healthResult)

            // בניית ה-Payload החדש עם סינון ערכים חסרים ו-outliers
            let builder = GeminiHealthPayloadBuilder()
            let payload = builder.build(from: dailyEntries)

            guard let payloadJSON = payload.toJSONString() else {
                completion(nil, nil, nil, NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "שגיאה ביצירת payload לניתוח"]))
                return
            }

            let graphsBlock: String
            if let bundle = chartBundle, let graphPayload = bundle.toAIONReviewPayload().toJSONString() {
                graphsBlock = """
                # 6 הגרפים המקצועיים (JSON)
                נתח את ה־"intersectionality" של הגרפים. דוגמה: "בגרף 1 (Readiness) ו־3 (Sleep): גם שהעומס נמוך, ההתאוששות לא קפצה. בהתבסס על טמפ' השינה – האם הסביבה הבעיה או התזונה?"
                \(graphPayload)
                """
            } else {
                graphsBlock = ""
            }

            // Data source context for tailored analysis
            let dataSourceContext = self.buildDataSourceContext()

            // שליפת הרכב הקודם מה-cache (Car Identity Lock)
            var lastCarModel: String? = nil
            var lastCarReason: String? = nil
            if let savedCar = AnalysisCache.loadSelectedCar() {
                lastCarModel = savedCar.wikiName.isEmpty ? savedCar.name : savedCar.wikiName
                lastCarReason = savedCar.explanation
            }

            // שליפת התשובה הקודמת להקשר
            let previousAnalysis = AnalysisCache.loadLatest() ?? ""
            let previousAnalysisBlock = previousAnalysis.isEmpty ? "אין ניתוח קודם זמין" : previousAnalysis

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

            ==================================================
            PREVIOUS ANALYSIS (for continuity)
            ==================================================

            \(previousAnalysisBlock)
            """

            // שמירה לדיבאג (לפני השליחה)
            GeminiDebugStore.lastPrompt = prompt

            self.sendRequest(prompt: prompt, temperature: 0.2) { response, error in
                if let error = error {
                    completion(nil, nil, nil, error)
                    return
                }

                guard let response = response else {
                    completion(nil, nil, nil, NSError(domain: "GeminiService", code: -2, userInfo: [NSLocalizedDescriptionKey: "לא התקבלה תשובה מ-Gemini"]))
                    return
                }

                // שמירה לדיבאג (אחרי קבלת התשובה)
                GeminiDebugStore.save(prompt: prompt, response: response)

                // פענוח התשובה לחלקים
                let (insights, recommendations, riskFactors) = self.parseResponse(response)
                completion(insights, recommendations, riskFactors, nil)
            }
        }
    }
    
    private static func parseAPIError(statusCode: Int, data: Data?) -> String {
        if statusCode == 429 {
            let quotaMessage = "חסמת את המכסה היומית ל‑Gemini (20 בקשות בחינם). נסה שוב מחר, או שדרג לתוכנית בתשלום ב־Google AI Studio."
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let error = json["error"] as? [String: Any] else {
                return quotaMessage
            }
            let status = error["status"] as? String ?? ""
            let message = error["message"] as? String ?? ""
            if status == "RESOURCE_EXHAUSTED" || message.lowercased().contains("quota") || message.contains("מכסה") {
                return quotaMessage
            }
            if message.lowercased().contains("retry") || message.contains("41") {
                return quotaMessage + " (המערכת ממליצה לנסות שוב בעוד כ־40 שניות אם זו מגבלת קצב.)"
            }
            return quotaMessage
        }
        if statusCode == 503 {
            return "שירות Gemini לא זמין כרגע. נסה שוב בעוד דקות."
        }
        if statusCode != 200 {
            return "שגיאת שרת: \(statusCode)"
        }
        return "שגיאה מ‑Gemini"
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
        // מניעת קריאות כפולות
        guard !isAnalysisInProgress else {
            completion(nil, NSError(domain: "GeminiService", code: -10, userInfo: [NSLocalizedDescriptionKey: "ניתוח כבר בתהליך"]))
            return
        }
        isAnalysisInProgress = true

        sendRequestInternal(prompt: prompt, systemInstruction: systemInstruction, temperature: temperature, retryCount: 0, completion: completion)
    }

    private func sendRequestInternal(prompt: String, systemInstruction: String?, temperature: Double, retryCount: Int, completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            isAnalysisInProgress = false
            completion(nil, NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "URL לא תקין"]))
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

            // טיפול בשגיאות עם retry
            if let error = error {
                let ns = error as NSError
                if ns.code == NSURLErrorCancelled {
                    self?.isAnalysisInProgress = false
                    return
                }

                // בדוק אם שווה לנסות שוב
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

                // Retry על שגיאות HTTP מסוימות (503, 429, 500)
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
                completion(nil, NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "אין נתונים בתשובה"]))
                return
            }
            
            // הצלחה - סיום הניתוח
            self?.isAnalysisInProgress = false

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(nil, NSError(domain: "GeminiService", code: -5, userInfo: [NSLocalizedDescriptionKey: "פורמט תשובה לא תקין - לא JSON"]))
                    return
                }

                // בדיקה אם יש שגיאה בתשובה (תשובה 200 אבל error ב-JSON)
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    let userMessage = Self.parseAPIError(statusCode: 200, data: data) ?? "שגיאה מ-Gemini: \(message)"
                    completion(nil, NSError(domain: "GeminiService", code: -6, userInfo: [NSLocalizedDescriptionKey: userMessage]))
                    return
                }

                // ניסיון לפרסר את התשובה
                if let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first {

                    if let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        let finishReason = firstCandidate["finishReason"] as? String

                        if finishReason == "MAX_TOKENS" && !text.isEmpty {
                            let truncated = text + "\n\n_(התשובה נקטעה בסוף – הוגדל maxOutputTokens להרצה הבאה.)_"
                            completion(truncated, nil)
                        } else if finishReason != "STOP" && finishReason != nil {
                            completion(nil, NSError(domain: "GeminiService", code: -7, userInfo: [NSLocalizedDescriptionKey: "סיבה: \(finishReason!)"]))
                        } else {
                            completion(text, nil)
                        }
                        return
                    }

                    let finishReason = firstCandidate["finishReason"] as? String
                    if finishReason == "MAX_TOKENS" {
                        completion(nil, NSError(domain: "GeminiService", code: -7, userInfo: [NSLocalizedDescriptionKey: "התשובה נקטעה - יותר מדי מילים"]))
                        return
                    }
                }

                completion(nil, NSError(domain: "GeminiService", code: -5, userInfo: [NSLocalizedDescriptionKey: "פורמט תשובה לא תקין. בדוק את הקונסול לפרטים נוספים."]))
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
        
        // חילוץ סעיף "תוכנית כוונון" או "תוכנית אופטימיזציה" כהמלצה אחת
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
                // מחפש את סוף הסעיף - סיכום או סעיף חדש
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
        
        // ניסיון לפרק את התשובה לחלקים
        let lines = response.components(separatedBy: .newlines)
        var currentSection: String? = nil
        var inRecommendationsSection = false
        var inRiskFactorsSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // זיהוי סעיפים - תמיכה במספר פורמטים
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
                // כותרת חדשה - איפוס הסעיף רק אם זה לא חלק מהמלצות
                // תת-כותרות בתוך תוכנית כוונון עדיין נחשבות חלק מההמלצות
                if !trimmed.contains("המלצות") && 
                   !trimmed.contains("סיכון") &&
                   !trimmed.contains("תוכנית") &&
                   !trimmed.contains("Plan") &&
                   !trimmed.contains("Tune") &&
                   !trimmed.contains("Optimization") &&
                   !trimmed.contains("Training") &&
                   !trimmed.contains("Recovery") &&
                   !trimmed.contains("התאמות") &&
                   !trimmed.contains("שינויים") &&
                   !trimmed.contains("הרגל") &&
                   !trimmed.contains("habit") {
                    inRecommendationsSection = false
                    inRiskFactorsSection = false
                    currentSection = nil
                }
            }
            
            // אם אנחנו בתוך סעיף המלצות, גם שורות רגילות (לא רק רשימות) יכולות להיות המלצות
            if inRecommendationsSection && !trimmed.isEmpty && 
               !trimmed.hasPrefix("#") && 
               !trimmed.contains("---") &&
               trimmed.count > 20 {
                // אם זה לא רשימה אבל זה חלק מסעיף המלצות, נשמור את זה
                if !recommendations.contains(where: { $0 == trimmed }) {
                    // נבדוק אם זה לא חלק מהמלצה קיימת
                    let isPartOfExisting = recommendations.contains { existing in
                        trimmed.contains(existing) || existing.contains(trimmed)
                    }
                    if !isPartOfExisting {
                        recommendations.append(trimmed)
                    }
                }
            }
            
            // איסוף המלצות - תמיכה במספר פורמטים
            if inRecommendationsSection || currentSection == "recommendations" {
                // תמיכה בפורמטים שונים: 1. 2. 3., -, •, *, או תת-כותרות עם **
                if trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.") ||
                   trimmed.hasPrefix("4.") || trimmed.hasPrefix("5.") || trimmed.hasPrefix("6.") ||
                   trimmed.hasPrefix("7.") || trimmed.hasPrefix("8.") ||
                   trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") ||
                   (trimmed.hasPrefix("**") && trimmed.contains(":")) {
                    
                    var item = trimmed
                    
                    // הסרת מספרים ותווים בתחילה
                    item = item.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    item = item.replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                    
                    // אם יש ** בתחילה ובסוף, נסיר אותם
                    if item.hasPrefix("**") && item.hasSuffix("**") {
                        item = String(item.dropFirst(2).dropLast(2))
                    }
                    
                    // אם יש : נקח רק את החלק אחרי הנקודתיים
                    if let colonRange = item.range(of: ":") {
                        item = String(item[colonRange.upperBound...])
                    }
                    
                    item = item.trimmingCharacters(in: .whitespaces)
                    
                    // רק אם זה לא רק מספר או סימן, וזה ארוך מספיק
                    if !item.isEmpty && item.count > 10 {
                        recommendations.append(item)
                    }
                }
            }
            
            // איסוף גורמי סיכון
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
        
        // אם לא מצאנו המלצות או גורמי סיכון מובנים, נשתמש בכל התשובה כתובנות
        if recommendations.isEmpty && riskFactors.isEmpty {
            insights = response
        } else {
            // נשמור את כל התשובה כתובנות אבל נדגיש את ההמלצות
            insights = response
        }

        return (insights, recommendations, riskFactors)
    }
}
