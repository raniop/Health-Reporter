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
    # PERSONA
    You are the AION Performance Director. You are a world-class expert in Sports Science, Metabolic Health, and Autonomic Nervous System (ANS) recovery. Your goal is to analyze week-over-week (WoW) health data to identify trends that the user cannot see.

    # DATA ANALYSIS PROTOCOL
    When provided with health graphs or JSON data:
    1. COMPARISON: Compare 'Current Week' vs. 'Previous Week' for every metric.
    2. CORRELATION: Look for links. (e.g., "Sleep quality dropped on days where Active Energy exceeded 1,000 kcal").
    3. PHYSIOLOGICAL STATE: Determine if the user is in a 'Productive,' 'Overreaching,' or 'Recovery' state.

    # VISUAL GRAPH DESCRIPTION
    Describe the visual trends:
    - "The slope of your HRV is trending upward by 15% WoW."
    - "Your Resting Heart Rate shows a 'valley' pattern, peaking on weekends."

    # THE WEEKLY DIRECTIVE
    Always conclude with:
    - ONE THING TO IMPROVE: A specific nutritional or habit shift.
    - ONE TRAINING ADJUSTMENT: Increase or decrease intensity based on the data.
    """
    
    private var currentTask: URLSessionDataTask?
    private let taskQueue = DispatchQueue(label: "GeminiService.task")

    private init() {}

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
        
        ## 3 המלצות מעשיות לשבוע הקרוב
        1. [המלצה ספציפית ומעשית]
        2. [המלצה ספציפית ומעשית]
        3. [המלצה ספציפית ומעשית]
        
        ## גורמי סיכון (אם יש)
        [רשימת גורמי סיכון פוטנציאליים]
        """
        
        sendRequest(prompt: prompt) { response, error in
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
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
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
    func analyzeHealthDataWithWeeklyComparison(_ healthData: HealthDataModel, currentWeek: WeeklyHealthSnapshot, previousWeek: WeeklyHealthSnapshot, chartBundle: AIONChartDataBundle? = nil, completion: @escaping (String?, [String]?, [String]?, Error?) -> Void) {
        guard let summary = createHealthSummary(from: healthData, currentWeek: currentWeek, previousWeek: previousWeek),
              let jsonString = summary.toJSONString() else {
            completion(nil, nil, nil, NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "שגיאה ביצירת סיכום נתונים"]))
            return
        }
        
        let currentWeekJSON = currentWeek.toJSON()
        let previousWeekJSON = previousWeek.toJSON()
        let graphsBlock: String
        if let bundle = chartBundle, let payload = bundle.toAIONReviewPayload().toJSONString() {
            graphsBlock = """
            # 6 הגרפים המקצועיים (JSON)
            נתח את ה־"intersectionality" של הגרפים. דוגמה: "בגרף 1 (Readiness) ו־3 (Sleep): גם שהעומס נמוך, ההתאוששות לא קפצה. בהתבסס על טמפ' השינה – האם הסביבה הבעיה או התזונה?"
            \(payload)
            """
        } else {
            graphsBlock = ""
        }
        
        let prompt = """
        # ROLE
        אתה AION Performance Director. Head of Human Performance. המטרה שלך היא למקסם את 'Athletic Longevity' ו-'Peak Output' של המשתמש.

        # DATA INPUT
        - Current Week Data: \(formatJSONForPrompt(currentWeekJSON))
        - Previous Week Data: \(formatJSONForPrompt(previousWeekJSON))
        - Full Health Data: \(jsonString)
        \(graphsBlock)

        # ANALYSIS ENGINE: THE THREE-LIGHT SYSTEM
        לכל דוח שבועי, קטלג מדדים ל:
        1. 🟢 GREEN (Optimal): המשך התקדמות (+5-10% עומס).
        2. 🟡 YELLOW (Functional Overreach): החזק עומס נוכחי. התמקד במיקרו-נוטריינטים (מגנזיום/אבץ).
        3. 🔴 RED (Non-Functional Overreach): הפחתה מיידית. עדיפות ל-9 שעות שינה והפעלה פאראסימפתטית.

        # DEEP BIOMETRIC INSIGHTS - שלושת העמודים המקצועיים

        A. AUTONOMIC BALANCE (התמחות ה-Ring)
           - Metric: HRV Trend (ממוצע 7 ימים). מספר HRV בודד חסר משמעות.
           - Pro Insight: אם ה-HRV שלך 10% מתחת לממוצע 7 הימים, מערכת העצבים שלך תקועה ב-"Sympathetic" (fight or flight).
           - The Directive: בימים אלה, אימון "מקצועי" משמעותו שינוי. במקום הרמה כבדה, בצע ניידות ו-Zone 1 blood flow. אימון דרך HRV קרס הוא איך מקצוענים נפצעים.

        B. INTERNAL vs. EXTERNAL LOAD (התמחות ה-Watch)
           - Metric: TRIMP (Training Impulse) vs. Output. השווה Heart Rate (Internal Load) ל-Power/Pace (External Load).
           - Pro Insight: אם אתה רץ בקצב הרגיל 5:00/ק"מ אבל ה-HR שלך גבוה ב-10bpm מהרגיל, ה-Efficiency Factor (EF) שלך יורד. זה סימן אזהרה מוקדם למחלה מתקרבת או עייפות מערכתית לפני שאתה אפילו מרגיש "עייף".
           - The Directive: אם EF יורד, הפחת עומס והתמקד בהתאוששות.

        C. SLEEP ARCHITECTURE & THERMAL REGULATION
           - Metric: Basal Body Temperature (BBT) & REM/Deep Ratios.
           - Pro Insight: עלייה ב-BBT (מעקב על ידי ה-ring) לרוב מקדימה חום ב-24 שעות.
           - The Directive: אם BBT מוגבר ב-+0.3°C, התזונה חייבת לעבור למזונות עתירי נוגדי חמצון, אנטי-דלקתיים (דובדבן חמוץ, כורכום, הידרציה גבוהה) מיד כדי להקהות את התגובה הדלקתית.

        # CORRELATIONS & CALCULATIONS
        - CORRELATE יעילות שינה עם עוצמת אימון למחרת.
        - CALCULATE "Recovery-to-Strain Ratio": אם Strain >8/10 למשך 3 ימים אבל Recovery <50%, הפעל 'Burnout Alert'.
        - NUTRITION PROTOCOL: המלץ על תדלוק ספציפי בהתבסס על 'Glycogen Demand' של האימונים המעקבים (למשל: "יום עתיר פחמימות נדרש לאימון Threshold של 90 דקות מחר").

        # PROFESSIONAL STRATEGIES (2026 Gold Standards)
        | Pillar | Professional Strategy | Why It Matters |
        |--------|----------------------|----------------|
        | Movement | Polarized Training (80/20) | בלה 80% מהזמן ב-Zone 2. זה בונה את הבסיס המיטוכונדריאלי שמאפשר לך לשרוד את ה-20% "High Intensity" בלי לקרוס. |
        | Nutrition | Circadian Fueling | אכל 80% מהקלוריות שלך לפני 18:00. עיכול במהלך שינה מעלה RHR ומוריד HRV, גונב את ההתאוששות שלך. |
        | Recovery | The 3-2-1 Rule | 3 שעות ללא אוכל לפני שינה, 2 שעות ללא עבודה, שעה אחת ללא אור כחול. ה-ring שלך יראה קפיצה מסיבית ב-"Deep Sleep" duration. |
        | Mindset | Subjective vs. Objective | כל בוקר, דרג את "Perceived Readiness" (1-10) לפני שאתה מסתכל על האפליקציה. אם ההרגשה תואמת את הנתונים, אתה מסונכרן. אם לא, נחקור "לחצים נסתרים". |

        # OUTPUT FORMAT
        שמור על כל סעיף תמציתי (2–4 משפטים). הימנע מחזרות.
        אנא תן תשובה בעברית בפורמט הבא:
        
        ## 🚦 THREE-LIGHT SYSTEM STATUS
        [קטגוריזציה של כל המדדים ל-GREEN/YELLOW/RED עם הסבר]

        ## 📊 השוואה שבועית (Week-over-Week)
        [שינויים באחוזים וזיהוי דגלים אדומים]

        ## 🔬 DEEP BIOMETRIC INSIGHTS
        ### A. Autonomic Balance (HRV Analysis)
        [ניתוח HRV trends ו-sympathetic/parasympathetic balance]

        ### B. Internal vs. External Load (Efficiency Factor)
        [ניתוח TRIMP, EF, והשוואת Internal/External Load]

        ### C. Sleep Architecture & Thermal Regulation
        [ניתוח BBT, REM/Deep ratios, וזיהוי סימנים מוקדמים]

        ## 📈 CORRELATIONS & ALERTS
        - Sleep Efficiency → Next Day Workout Intensity: [קורלציה]
        - Recovery-to-Strain Ratio: [חישוב והתרעות]
        - Burnout Alert: [אם רלוונטי]

        ## 🎯 NUTRITION PROTOCOL
        [המלצות תזונתיות ספציפיות בהתבסס על Glycogen Demand]

        ## 💡 PROFESSIONAL DIRECTIVES
        ### מה להפסיק לעשות:
        [רשימה ספציפית]

        ### מה להתחיל לעשות:
        [רשימה ספציפית]

        ### המדד הקריטי ל-48 השעות הבאות:
        [מדד אחד ספציפי לעקוב אחריו]

        ## 🏋️ 3 המלצות מעשיות לשבוע הקרוב
        1. [המלצה ספציפית ומעשית]
        2. [המלצה ספציפית ומעשית]
        3. [המלצה ספציפית ומעשית]

        ## 📌 THE WEEKLY DIRECTIVE (חובה)
        - **ONE THING TO IMPROVE**: [שינוי אחד ספציפי בתזונה או בהרגל]
        - **ONE TRAINING ADJUSTMENT**: [הגבר או הפחת עוצמה בהתבסס על הנתונים]

        ## ⚠️ גורמי סיכון (אם יש)
        [רשימת גורמי סיכון פוטנציאליים]
        """
        
        sendRequest(prompt: prompt, temperature: 0.25) { response, error in
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
    
    private func sendRequest(prompt: String, systemInstruction: String? = nil, temperature: Double = 0.2, completion: @escaping (String?, Error?) -> Void) {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
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
            "maxOutputTokens": 8192,
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
            if let error = error {
                let ns = error as NSError
                if ns.code == NSURLErrorCancelled { return }
                print("Network error: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            // בדיקת status code
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let userMessage = Self.parseAPIError(statusCode: httpResponse.statusCode, data: data)
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("Error response: \(errorString)")
                    }
                    completion(nil, NSError(domain: "GeminiService", code: -8, userInfo: [NSLocalizedDescriptionKey: userMessage]))
                    return
                }
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "אין נתונים בתשובה"]))
                return
            }
            
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
                            completion(text + "\n\n_(התשובה נקטעה בסוף – הוגדל maxOutputTokens להרצה הבאה.)_", nil)
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
                
                // אם הגענו לכאן, הפורמט לא תקין - נדפיס את התשובה לדיבוג
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Gemini response (raw): \(jsonString)")
                }
                
                completion(nil, NSError(domain: "GeminiService", code: -5, userInfo: [NSLocalizedDescriptionKey: "פורמט תשובה לא תקין. בדוק את הקונסול לפרטים נוספים."]))
            } catch {
                // אם יש שגיאה ב-JSON parsing, נדפיס אותה
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Gemini response (raw): \(jsonString)")
                }
                print("JSON parsing error: \(error.localizedDescription)")
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
        
        // ניסיון לפרק את התשובה לחלקים
        let lines = response.components(separatedBy: .newlines)
        var currentSection: String? = nil
        var inRecommendationsSection = false
        var inRiskFactorsSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // זיהוי סעיפים
            if trimmed.contains("3 המלצות מעשיות") || trimmed.contains("המלצות מעשיות") || trimmed.contains("המלצות לשבוע") {
                inRecommendationsSection = true
                inRiskFactorsSection = false
                currentSection = "recommendations"
                continue
            } else if trimmed.contains("גורמי סיכון") || trimmed.contains("סיכון") {
                inRiskFactorsSection = true
                inRecommendationsSection = false
                currentSection = "risks"
                continue
            } else if trimmed.hasPrefix("##") || trimmed.hasPrefix("###") {
                // כותרת חדשה - איפוס הסעיף
                if !trimmed.contains("המלצות") && !trimmed.contains("סיכון") {
                    inRecommendationsSection = false
                    inRiskFactorsSection = false
                    currentSection = nil
                }
            }
            
            // איסוף המלצות
            if inRecommendationsSection || currentSection == "recommendations" {
                if trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.") ||
                   trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                    let item = trimmed.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "^[-•*]\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    
                    if !item.isEmpty && item.count > 10 { // רק אם זה לא רק מספר או סימן
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
