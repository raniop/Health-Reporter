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
            אתה רופא ספורט בכיר (Elite Sports Physician), מאמן ביצועים (Performance Coach) ו-Data Analyst.
            אסור להמציא נתונים.

            המטרה:
            לנתח מגמות ביצועים ל-90 הימים האחרונים, על בסיס נתונים שבועיים + 14 ימים אחרונים יומיים,
            ולהפיק אבחון, תוכנית פעולה, ותוספים מבוססי נתונים.

            ==================================================
            כללי פרשנות נתונים
            ==================================================

            - כל ערך שהוא 0, null, "", "N/A", "unknown" = נתון חסר.
            - נתון חסר לא נכנס לממוצעים, מגמות או מסקנות.
            - לכל מדד מצורף validDays (כמה ימים תקינים).
            - אם validDays נמוך – הורד ביטחון וציין זאת.

            ==================================================
            נעילת זהות רכב (Car Identity Lock)
            ==================================================

            תקבל גם:
            lastCarModel – הדגם שנבחר בניתוח הקודם.
            lastCarReason – סיבת הבחירה הקודמת.

            כללים:

            1) אם לא זוהה שינוי מהותי בפרופיל הביצועים הכללי
            (VO2max, HRV, דופק מנוחה, עומס אימונים, שינה, התאוששות),
            עליך להחזיר את אותו הדגם בדיוק: lastCarModel.

            2) מותר לשנות רכב רק אם מתקיימים לפחות שניים מהבאים:
            - שינוי ≥10% ב-VO2max
            - שינוי עקבי ≥15% ב-HRV
            - שינוי ברור בדופק מנוחה (±5 bpm)
            - שינוי קטגוריית עומס (נמוך↔בינוני↔גבוה)
            - שינוי משמעותי באיכות שינה

            3) אם הרכב הוחלף:
            ציין:
            "הרכב הוחלף מ-[CAR_WIKI: old model] ל-[CAR_WIKI: new model]"
            והסבר בדיוק אילו מדדים הצדיקו זאת.

            4) אסור לבחור רכב חדש לשם גיוון.

            ==================================================
            מבנה הנתונים שקיבלת
            ==================================================

            - weeklySummary: סיכום שבועי ל-90 יום (13 שבועות) – מקור עיקרי למגמות
            - dailyLast14: פירוט יומי ל-14 ימים אחרונים – מקור עיקרי למצב נוכחי
            - coverageValidDays: כיסוי גלובלי לכל מדד
            - lastCarModel
            - lastCarReason

            ==================================================
            פלט נדרש - JSON ONLY עם תמיכה בשתי שפות
            ==================================================

            חשוב ביותר לגבי בחירת הרכב:
            - הרכב חייב להיות מכונית אמיתית שקיימת בויקיפדיה (לא מושג כמו "Zone 2" או "Recovery Mode")
            - wikiName חייב להיות שם רכב אמיתי באנגלית שניתן לחפש בויקיפדיה
            - בחר רכב שמייצג את רמת הביצועים והמאפיינים הספציפיים של המשתמש לפי הנתונים
            - אתה חופשי לבחור כל רכב אמיתי שקיים - אל תוגבל לדוגמאות!
            - הדוגמאות הבאות הן רק להמחשה של קטגוריות (אל תשתמש בהן אלא אם הן באמת מתאימות):
              * ספורט/על: Ferrari, Lamborghini, McLaren, Porsche 911 GT3
              * ביצועים: BMW M, Mercedes-AMG, Audi RS
              * יומיומי ספורטיבי: Golf GTI, Civic Type R
              * יומיומי: Camry, Accord
            - אל תבחר דוגמה רק כי היא מופיעה כאן! בחר רכב שבאמת מתאים לפרופיל

            דרישה קריטית - שתי שפות:
            כל שדה טקסטואלי חייב להיות בשתי גרסאות: עברית (_he) ואנגלית (_en).
            זה חיוני לתמיכה בשני השפות באפליקציה.

            החזר את התשובה כ-JSON בלבד, בפורמט הבא בדיוק:

            ```json
            {
              "carIdentity": {
                "model_he": "שם הרכב בעברית (לדוגמה: פורשה טייקאן)",
                "model_en": "Car name in English (e.g., Porsche Taycan)",
                "wikiName": "שם רכב אמיתי באנגלית לחיפוש בויקיפדיה (e.g., Porsche Taycan)",
                "explanation_he": "הסבר למה הרכב הזה מתאים לפרופיל הביצועים של המשתמש (2-3 משפטים מפורטים)",
                "explanation_en": "Explanation why this car matches the user's performance profile (2-3 detailed sentences)"
              },
              "performanceReview": {
                "engine_he": "תיאור מפורט של הכושר הקרדיו, הסיבולת ו-VO2max (2-3 משפטים)",
                "engine_en": "Detailed description of cardio fitness, endurance and VO2max (2-3 sentences)",
                "transmission_he": "תיאור מפורט של ההתאוששות, השינה ו-HRV (2-3 משפטים)",
                "transmission_en": "Detailed description of recovery, sleep and HRV (2-3 sentences)",
                "suspension_he": "תיאור מצב הפציעות, הגמישות והמפרקים (2-3 משפטים)",
                "suspension_en": "Description of injury status, flexibility and joints (2-3 sentences)",
                "fuelEfficiency_he": "תיאור האנרגיה, הסטרס והתזונה (2-3 משפטים)",
                "fuelEfficiency_en": "Description of energy, stress and nutrition (2-3 sentences)",
                "electronics_he": "תיאור הריכוז, העקביות ואיזון מערכת העצבים (2-3 משפטים)",
                "electronics_en": "Description of focus, consistency and nervous system balance (2-3 sentences)"
              },
              "bottlenecks_he": [
                "צוואר בקבוק ראשון - תיאור מפורט",
                "צוואר בקבוק שני - תיאור מפורט"
              ],
              "bottlenecks_en": [
                "First bottleneck - detailed description",
                "Second bottleneck - detailed description"
              ],
              "optimizationPlan": {
                "upgrades_he": ["שדרוג 1 - פירוט", "שדרוג 2 - פירוט"],
                "upgrades_en": ["Upgrade 1 - details", "Upgrade 2 - details"],
                "skippedMaintenance_he": ["טיפול חסר 1 - פירוט"],
                "skippedMaintenance_en": ["Skipped maintenance 1 - details"],
                "stopImmediately_he": ["דבר להפסיק מיד - פירוט"],
                "stopImmediately_en": ["Stop immediately - details"]
              },
              "tuneUpPlan": {
                "trainingAdjustments_he": "התאמות מפורטות לאימון לחודש-חודשיים הקרובים",
                "trainingAdjustments_en": "Detailed training adjustments for the next 1-2 months",
                "recoveryChanges_he": "שינויים מפורטים בהתאוששות ושינה",
                "recoveryChanges_en": "Detailed recovery and sleep changes",
                "habitToAdd_he": "הרגל אחד חדש להוסיף עם הסבר למה",
                "habitToAdd_en": "One new habit to add with explanation",
                "habitToRemove_he": "הרגל אחד להסיר עם הסבר למה",
                "habitToRemove_en": "One habit to remove with explanation"
              },
              "directives": {
                "stop_he": "משפט אחד ברור - מה להפסיק לעשות מיד",
                "stop_en": "One clear sentence - what to stop doing immediately",
                "start_he": "משפט אחד ברור - מה להתחיל לעשות",
                "start_en": "One clear sentence - what to start doing",
                "watch_he": "משפט אחד ברור - מה לעקוב אחריו",
                "watch_en": "One clear sentence - what to monitor"
              },
              "forecast_he": "תחזית מפורטת ל-3 חודשים קדימה - אם המגמה הנוכחית תימשך, איפה אהיה",
              "forecast_en": "Detailed 3-month forecast - where will I be if current trends continue",
              "supplements": [
                {
                  "name_he": "שם התוסף בעברית",
                  "name_en": "Supplement Name in English",
                  "dosage_he": "מינון ותזמון מדויקים",
                  "dosage_en": "Exact dosage and timing",
                  "reason_he": "סיבה ספציפית מהנתונים",
                  "reason_en": "Specific reason from the data",
                  "category": "sleep"
                }
              ]
            }
            ```

            חשוב מאוד:
            - החזר JSON בלבד, ללא טקסט נוסף לפני או אחרי
            - כל השדות חובה - אל תשמיט שום שדה
            - כל שדה טקסטואלי חייב להופיע בשתי גרסאות: _he (עברית) ו-_en (אנגלית)
            - קטגוריות תקפות ל-supplements: sleep, performance, recovery, general
            - wikiName חייב להיות שם של מכונית אמיתית (לא מושג כמו Zone 2)
            - אם lastCarModel קיים ואין שינוי מהותי, השתמש בו ב-wikiName (רק אם זה שם מכונית אמיתית)

            ==================================================
            הנתונים:
            ==================================================

            lastCarModel: \(lastCarModel ?? "null")
            lastCarReason: \(lastCarReason ?? "null")

            \(payloadJSON)
            \(graphsBlock)
            \(dataSourceContext)

            ==================================================
            הניתוח הקודם שלך (לרפרנס והמשכיות)
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

    /// בונה הקשר מקור נתונים להתאמת הניתוח
    private func buildDataSourceContext() -> String {
        let source = DataSourceManager.shared.effectiveSource()
        let strengths = source.strengths
        let isCalculated = source == .autoDetect || source == .appleWatch

        var context = """
        # מקור נתונים
        המשתמש משתמש ב-**\(source.displayNameHebrew)**.
        """

        if !strengths.isEmpty {
            context += "\n\nחוזקות המכשיר:\n"
            context += strengths.map { "- \($0)" }.joined(separator: "\n")
        }

        // Add device-specific guidance
        switch source {
        case .garmin:
            context += """

            ## הערות ספציפיות ל-Garmin
            - נתוני HRV מדויקים במיוחד (24/7 או בשינה)
            - שלבי שינה מפורטים (Deep, Light, REM, Awake)
            - VO2 Max ו-Training Status זמינים
            - הערה: Body Battery ו-Training Load לא מסתנכרנים לאפל הלט׳ - הציון שמוצג מחושב לפי HRV, דופק ושינה
            - התמקד בטרנדים של HRV ו-RHR כאינדיקטורים להתאוששות
            """
        case .oura:
            context += """

            ## הערות ספציפיות ל-Oura
            - HRV לילי מדויק ביותר (אלגוריתם 5 דקות)
            - שלבי שינה מפורטים עם ציון יעילות
            - סטיית טמפרטורת גוף - אינדיקטור מוקדם למחלה/מתח
            - הערה: Readiness Score של Oura לא מסתנכרן - הציון שמוצג מחושב לפי HRV, דופק ושינה
            - אם יש סטיית טמפרטורה חיובית (>0.5°C), שקול להמליץ על הפחתת עומס
            """
        case .whoop:
            context += """

            ## הערות ספציפיות ל-WHOOP
            - מדידת HRV רציפה ומדויקת
            - Recovery Score ו-Strain לא מסתנכרנים - מחושבים מקומית
            - התמקד ביחס Recovery-to-Strain
            """
        case .appleWatch:
            context += """

            ## הערות ספציפיות ל-Apple Watch
            - מדידת דופק וקלוריות מדויקת
            - HRV נמדד בנקודות ספציפיות (לא רציף)
            - שלבי שינה בסיסיים יותר (Core, Deep, REM)
            - נתוני VO2 Max ו-Walking HRR זמינים
            """
        case .autoDetect:
            context += """

            ## מצב אוטומטי
            המערכת מזהה אוטומטית את מקור הנתונים הפעיל ביותר.
            הציונים (Readiness, Strain) מחושבים לפי האלגוריתם של AION מנתוני HealthKit.
            """
        default:
            break
        }

        if isCalculated {
            context += """

            ## הערה על ציונים מחושבים
            ציון המוכנות (Readiness) והעומס (Strain) **מחושבים** על ידי האפליקציה ולא מגיעים ישירות מהמכשיר.
            החישוב מבוסס על: HRV (35%), דופק מנוחה (25%), איכות שינה (30%), והתאוששות (10%).
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
