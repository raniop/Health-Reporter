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
    # ROLE: AION Integrated Health Panel
    You combine Sports Physician (Injury/Recovery), Professional Trainer (Performance/Load), and Clinical Dietitian (Metabolism/Fueling). Analyze Health App data. Deliver a daily performance brief and Week-over-Week (WoW) comparison.

    # RULES
    - Be CONCISE. No long paragraphs. 1–2 sentences per bullet. Use Temperature 0.2 style: factual, minimal.
    - Output in Hebrew unless a metric label (e.g. HRV, RHR) is standard in English.
    - "Check Engine" light: Flag red-flag correlations (e.g. rising body temp + falling HRV = impending illness/overtraining).
    - Efficiency = Output vs. Heart Rate. Recovery Balance = Strain vs. HRV.

    # FORMATTING RULES
    - Return the answer as clean plain text only.
    - Do NOT use bullet points, asterisks (*), dashes, emojis, or markdown.
    - Do NOT use numbered lists.
    - Use short section titles in ALL CAPS followed by a single line break.
    - Separate paragraphs using a single blank line.
    - No special characters at the start of lines.
    - No decorative symbols.
    - Text must be easy to copy-paste into an app.
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
    func analyzeHealthDataWithWeeklyComparison(_ healthData: HealthDataModel, currentWeek: WeeklyHealthSnapshot, previousWeek: WeeklyHealthSnapshot, chartBundle: AIONChartDataBundle? = nil, completion: @escaping (String?, [String]?, [String]?, Error?) -> Void) {
        guard let summary = createHealthSummary(from: healthData, currentWeek: currentWeek, previousWeek: previousWeek),
              let jsonString = summary.toJSONString() else {
            completion(nil, nil, nil, NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "שגיאה ביצירת סיכום נתונים"]))
            return
        }
        
        let currentWeekJSON = currentWeek.toJSON()
        let previousWeekJSON = previousWeek.toJSON()
        
        // הדפסת תקופת הזמן שנשלחת
        print("=== DATE RANGES SENT TO GEMINI ===")
        print("Current Week: \(currentWeek.weekStartDate) to \(currentWeek.weekEndDate)")
        print("Previous Week: \(previousWeek.weekStartDate) to \(previousWeek.weekEndDate)")
        print("Health Data Range (3 months): \(summary.dateRange.start) to \(summary.dateRange.end)")
        print("=== END DATE RANGES ===\n")
        
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
        Act as an elite sports physician, performance coach, and data analyst.
        RESPOND IN HEBREW ONLY.

        Analyze all of my health and fitness data from the past three months, not just the most recent day. Always evaluate trends using a rolling 3-month window (sleep, HRV, resting heart rate, training load, recovery, steps, VO₂ max, body composition, stress, injuries, and any available metrics).

        Based on this analysis, answer the following IN HEBREW:

        ## 1. איזה רכב אני עכשיו?
        בחר דגם רכב ספציפי (לא גנרי).
        הסבר למה הרכב הזה מתאים לפרופיל הביצועים הפיזי והמנטלי שלי כרגע.
        **חשוב:** כתוב גם את שם הדגם המדויק באנגלית כפי שמופיע בוויקיפדיה, בפורמט: [CAR_WIKI: English Name]
        לדוגמה: [CAR_WIKI: Porsche 911 (993)] או [CAR_WIKI: Subaru Forester]

        ## 2. סקירת ביצועים מלאה
        - **מנוע** (כושר קרדיו, סיבולת, VO₂ max)
        - **תיבת הילוכים** (התאוששות, איכות שינה, עקביות HRV)
        - **מתלים** (עמידות לפציעות, גמישות, בריאות מפרקים)
        - **יעילות דלק** (רמות אנרגיה, ניהול מתח, תזונה)
        - **אלקטרוניקה** (ריכוז, עקביות, איזון מערכת העצבים)

        ## 3. מה מגביל את הביצועים עכשיו?
        זהה 2-3 צווארי בקבוק מרכזיים על סמך מגמות הנתונים.
        סמן סימני אזהרה מוקדמים (אימון יתר, תת-התאוששות, חוסר איזון).

        ## 4. תוכנית אופטימיזציה
        - אילו "שדרוגים" ישפרו הכי את הביצועים?
        - איזה טיפול אני מדלג עליו?
        - מה אני צריך להפסיק לעשות מיד?

        ## 5. תוכנית כוונון ל-30-60 הימים הבאים
        - **התאמות אימון**: [פירוט]
        - **שינויים בהתאוששות ושינה**: [פירוט]
        - **הרגל אחד בעל השפעה גבוהה להוסיף**: [פירוט]
        - **הרגל אחד להסיר**: [פירוט]

        ## 6. הנחיות פעולה
        - **STOP:** [משפט אחד – מה להפסיק]
        - **START:** [משפט אחד – מה להתחיל]
        - **WATCH:** [משפט אחד – מה לעקוב]

        ## 7. סיכום
        "אם הרכב הזה ימשיך לנסוע באותו אופן, הנה איפה הוא יהיה בעוד שלושה חודשים."

        שמור על טון תובנתי, כנה ומעורר מוטיבציה.
        השתמש בהסברים ברורים, ללא אזעקות רפואיות וללא מילוי מיותר.

        # DATA INPUT
        - Current Week: \(formatJSONForPrompt(currentWeekJSON))
        - Previous Week: \(formatJSONForPrompt(previousWeekJSON))
        - Health Data (3 months): \(jsonString)
        \(graphsBlock)
        """
        
        // הדפסת ה-prompt המלא שנשלח ל-Gemini
        print("=== FULL PROMPT SENT TO GEMINI ===")
        print(prompt)
        print("=== END FULL PROMPT ===\n")
        
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
            if let error = error {
                let ns = error as NSError
                if ns.code == NSURLErrorCancelled { return }
                completion(nil, error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let userMessage = Self.parseAPIError(statusCode: httpResponse.statusCode, data: data)
                completion(nil, NSError(domain: "GeminiService", code: -8, userInfo: [NSLocalizedDescriptionKey: userMessage]))
                return
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
                        
                        print("=== GEMINI RAW RESPONSE RECEIVED ===")
                        print("Finish reason: \(finishReason ?? "nil")")
                        print("Response length: \(text.count)")
                        print("First 1000 chars: \(String(text.prefix(1000)))")
                        print("=== END GEMINI RAW RESPONSE ===\n")
                        
                        if finishReason == "MAX_TOKENS" && !text.isEmpty {
                            let truncated = text + "\n\n_(התשובה נקטעה בסוף – הוגדל maxOutputTokens להרצה הבאה.)_"
                            print("=== WARNING: Response truncated (MAX_TOKENS) ===")
                            completion(truncated, nil)
                        } else if finishReason != "STOP" && finishReason != nil {
                            print("=== GEMINI ERROR: Finish reason = \(finishReason!) ===")
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
        print("=== PARSING GEMINI RESPONSE ===")
        print("Input length: \(response.count)")
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
        
        print("=== PARSED RESPONSE RESULTS ===")
        print("Insights length: \(insights.count)")
        print("Recommendations count: \(recommendations.count)")
        print("Risk factors count: \(riskFactors.count)")
        if !recommendations.isEmpty {
            print("First recommendation (first 200 chars): \(String(recommendations[0].prefix(200)))")
        }
        print("=== END PARSED RESPONSE ===\n")
        
        return (insights, recommendations, riskFactors)
    }
}
