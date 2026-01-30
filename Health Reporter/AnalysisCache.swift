//
//  AnalysisCache.swift
//  Health Reporter
//
//  מטמון נתוני ניתוח AION – שומר תוצאות ומונע קריאות מיותרות ל-Gemini
//  אם לא השתנו נתוני הבריאות, לא קוראים ל-Gemini מחדש.
//

import Foundation
import CryptoKit

enum AnalysisCache {
    // MARK: - Keys
    static let keyInsights = "AION.CachedInsights"
    static let keyLastDate = "AION.LastAnalysisDate"
    static let keyHealthDataHash = "AION.HealthDataHash"
    static let fileName = "last_analysis.json"

    // Weekly Stats Keys
    static let keyAvgSleepHours = "AION.WeeklyStats.AvgSleepHours"
    static let keyAvgReadiness = "AION.WeeklyStats.AvgReadiness"
    static let keyAvgStrain = "AION.WeeklyStats.AvgStrain"
    static let keyAvgHRV = "AION.WeeklyStats.AvgHRV"
    static let keyHealthScore = "AION.WeeklyStats.HealthScore"

    // Selected Car Keys (שמירת הרכב שנבחר ע"י Gemini)
    static let keyLastCarName = "AION.SelectedCar.Name"
    static let keyLastCarWikiName = "AION.SelectedCar.WikiName"
    static let keyLastCarExplanation = "AION.SelectedCar.Explanation"

    // Pending Car Reveal Keys (כשרכב חדש ממתין לחשיפה)
    static let keyPendingCarReveal = "AION.PendingCarReveal"
    static let keyNewCarName = "AION.NewCar.Name"
    static let keyNewCarWikiName = "AION.NewCar.WikiName"
    static let keyNewCarExplanation = "AION.NewCar.Explanation"
    static let keyPreviousCarName = "AION.PreviousCar.Name"

    // Daily Activity Keys (לשיתוף עם ווידג'ט)
    static let keyDailySteps = "AION.DailyActivity.Steps"
    static let keyDailyCalories = "AION.DailyActivity.Calories"
    static let keyDailyExercise = "AION.DailyActivity.ExerciseMinutes"
    static let keyDailyStandHours = "AION.DailyActivity.StandHours"
    static let keyDailyRestingHR = "AION.DailyActivity.RestingHR"

    // MARK: - Cache Duration
    /// מטמון תקף ל-24 שעות (לא נקרא ל-Gemini שוב גם אם יש שינוי)
    static let maxAgeSeconds: TimeInterval = 24 * 3600

    // MARK: - Storage Directory
    static var storageDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("HealthReporter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var fileURL: URL? { storageDirectory?.appendingPathComponent(fileName) }

    // MARK: - Save

    /// שומר את תשובת Gemini + hash של נתוני הבריאות
    static func save(insights: String, healthDataHash: String) {
        let now = Date()

        // שמירה ב-UserDefaults
        UserDefaults.standard.set(insights, forKey: keyInsights)
        UserDefaults.standard.set(now, forKey: keyLastDate)
        UserDefaults.standard.set(healthDataHash, forKey: keyHealthDataHash)

        // שמירה בקובץ
        guard let url = fileURL else { return }
        let payload: [String: Any] = [
            "insights": insights,
            "healthDataHash": healthDataHash,
            "date": ISO8601DateFormatter().string(from: now)
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? data.write(to: url)

        print("=== ANALYSIS CACHE SAVED ===")
        print("Insights length: \(insights.count)")
        print("Health data hash: \(healthDataHash)")
        print("Date: \(now)")
    }

    /// שומר סטטיסטיקות שבועיות (נגזרות מ-chartBundle) + ציון הבריאות
    static func saveWeeklyStats(from bundle: AIONChartDataBundle, score: Int? = nil) {
        // Calculate average sleep
        let sleepValues = bundle.sleep.points.compactMap { $0.totalHours }
        let avgSleep = sleepValues.isEmpty ? 0 : sleepValues.reduce(0, +) / Double(sleepValues.count)

        // Calculate average readiness (recovery)
        let readinessValues = bundle.readiness.points.map { $0.recovery }
        let avgReadiness = readinessValues.isEmpty ? 0 : readinessValues.reduce(0, +) / Double(readinessValues.count)

        // Calculate average strain
        let strainValues = bundle.readiness.points.map { $0.strain }
        let avgStrain = strainValues.isEmpty ? 0 : strainValues.reduce(0, +) / Double(strainValues.count)

        // Calculate average HRV
        let hrvValues = bundle.hrvTrend.points.map { $0.value }
        let avgHRV = hrvValues.isEmpty ? 0 : hrvValues.reduce(0, +) / Double(hrvValues.count)

        UserDefaults.standard.set(avgSleep, forKey: keyAvgSleepHours)
        UserDefaults.standard.set(avgReadiness, forKey: keyAvgReadiness)
        UserDefaults.standard.set(avgStrain, forKey: keyAvgStrain)
        UserDefaults.standard.set(avgHRV, forKey: keyAvgHRV)

        // שמירת הציון עצמו (לא חישוב מחדש ב-Insights)
        if let s = score {
            UserDefaults.standard.set(s, forKey: keyHealthScore)
            print("=== WEEKLY STATS SAVED (with score) ===")
            print("Score: \(s), Avg Sleep: \(avgSleep)h, Readiness: \(avgReadiness), Strain: \(avgStrain), HRV: \(avgHRV)ms")
        } else {
            print("=== WEEKLY STATS SAVED ===")
            print("Avg Sleep: \(avgSleep)h, Readiness: \(avgReadiness), Strain: \(avgStrain), HRV: \(avgHRV)ms")
        }
    }

    /// מחזיר את הסטטיסטיקות השבועיות השמורות
    static func loadWeeklyStats() -> (sleepHours: Double, readiness: Double, strain: Double, hrv: Double)? {
        let sleep = UserDefaults.standard.double(forKey: keyAvgSleepHours)
        let readiness = UserDefaults.standard.double(forKey: keyAvgReadiness)
        let strain = UserDefaults.standard.double(forKey: keyAvgStrain)
        let hrv = UserDefaults.standard.double(forKey: keyAvgHRV)

        // אם כל הערכים 0, כנראה אין נתונים
        if sleep == 0 && readiness == 0 && strain == 0 && hrv == 0 {
            return nil
        }

        return (sleep, readiness, strain, hrv)
    }

    /// מחזיר את ציון הבריאות השמור (שחושב ב-Dashboard)
    static func loadHealthScore() -> Int? {
        let score = UserDefaults.standard.integer(forKey: keyHealthScore)
        // אם 0, זה יכול להיות שלא נשמר או שבאמת 0
        // אבל ציון 0 אמיתי לא צפוי, אז נחזיר nil
        return score > 0 ? score : nil
    }

    /// שומר את ציון הבריאות (מחושב ע"י HealthScoreEngine)
    static func saveHealthScore(_ score: Int) {
        UserDefaults.standard.set(score, forKey: keyHealthScore)
        print("=== HEALTH SCORE SAVED: \(score) ===")
    }

    // MARK: - Health Score Result (עם Breakdown)

    private static let keyHealthScoreResult = "AION.HealthScoreResult"

    /// שומר את תוצאת HealthScoreEngine המלאה (כולל breakdown)
    static func saveHealthScoreResult(_ result: HealthScoringResult) {
        UserDefaults.standard.set(result.healthScoreInt, forKey: keyHealthScore)

        // שמירת הפירוט כ-JSON
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: keyHealthScoreResult)
        }
        print("=== HEALTH SCORE RESULT SAVED: \(result.healthScoreInt), reliability: \(result.reliabilityScoreInt) ===")
    }

    /// טוען את תוצאת HealthScoreEngine המלאה
    static func loadHealthScoreResult() -> HealthScoringResult? {
        guard let data = UserDefaults.standard.data(forKey: keyHealthScoreResult) else { return nil }
        return try? JSONDecoder().decode(HealthScoringResult.self, from: data)
    }

    /// מייצר הסבר קצר לציון (לתצוגה ב-Tooltip)
    static func generateScoreExplanation() -> String {
        guard let result = loadHealthScoreResult() else {
            return "אין מספיק נתונים לחישוב"
        }

        var parts: [String] = []

        // הסבר כללי
        parts.append("הציון מבוסס על שילוב של התאוששות, שינה, כושר, עומס אימונים ורמת פעילות ב־3 החודשים האחרונים, עם דגש על השבועיים האחרונים.")
        parts.append("")
        parts.append("נתונים שלא נמדדו לא נכנסים לחישוב, ולכן לא \"מענישים\" על חוסר מדידה.")
        parts.append("")

        // הוספת הדומיינים שנכללו בחישוב
        parts.append("פירוט:")
        for domain in result.includedDomains {
            let scoreInt = Int(round(domain.domainScore))
            let weightPercent = Int(round(domain.normalizedWeight * 100))

            let domainHebrew: String
            switch domain.domainName {
            case "Recovery": domainHebrew = "התאוששות"
            case "Sleep": domainHebrew = "שינה"
            case "Fitness": domainHebrew = "כושר"
            case "Load Balance": domainHebrew = "איזון עומס"
            case "Activity": domainHebrew = "פעילות"
            default: domainHebrew = domain.domainName
            }

            parts.append("• \(domainHebrew): \(scoreInt) (\(weightPercent)%)")
        }

        // הוספת הדומיינים שלא נכללו
        if !result.excludedDomains.isEmpty {
            let excludedHebrew = result.excludedDomains.map { domain -> String in
                switch domain {
                case "Recovery": return "התאוששות"
                case "Sleep": return "שינה"
                case "Fitness": return "כושר"
                case "Load Balance": return "איזון עומס"
                case "Activity": return "פעילות"
                default: return domain
                }
            }.joined(separator: ", ")
            parts.append("")
            parts.append("לא נמדד: \(excludedHebrew)")
        }

        // הוספת אמינות
        parts.append("")
        parts.append("ציון האמינות מציין כמה הנתונים שלך מלאים: \(result.reliabilityScoreInt)%")

        return parts.joined(separator: "\n")
    }

    // MARK: - Daily Activity (לשיתוף עם ווידג'ט)

    /// שומר נתוני פעילות יומית מה-Dashboard
    static func saveDailyActivity(steps: Int, calories: Int, exerciseMinutes: Int, standHours: Int, restingHR: Int?) {
        UserDefaults.standard.set(steps, forKey: keyDailySteps)
        UserDefaults.standard.set(calories, forKey: keyDailyCalories)
        UserDefaults.standard.set(exerciseMinutes, forKey: keyDailyExercise)
        UserDefaults.standard.set(standHours, forKey: keyDailyStandHours)
        if let hr = restingHR {
            UserDefaults.standard.set(hr, forKey: keyDailyRestingHR)
        }
        print("=== DAILY ACTIVITY SAVED: steps=\(steps), cal=\(calories), ex=\(exerciseMinutes), stand=\(standHours) ===")
    }

    /// טוען נתוני פעילות יומית
    static func loadDailyActivity() -> (steps: Int, calories: Int, exerciseMinutes: Int, standHours: Int, restingHR: Int)? {
        let steps = UserDefaults.standard.integer(forKey: keyDailySteps)
        let calories = UserDefaults.standard.integer(forKey: keyDailyCalories)
        let exerciseMinutes = UserDefaults.standard.integer(forKey: keyDailyExercise)
        let standHours = UserDefaults.standard.integer(forKey: keyDailyStandHours)
        let restingHR = UserDefaults.standard.integer(forKey: keyDailyRestingHR)
        return (steps, calories, exerciseMinutes, standHours, restingHR)
    }

    // MARK: - Selected Car (שמירת הרכב מ-Gemini)

    /// שומר את הרכב שנבחר ע"י Gemini
    static func saveSelectedCar(name: String, wikiName: String, explanation: String) {
        UserDefaults.standard.set(name, forKey: keyLastCarName)
        UserDefaults.standard.set(wikiName, forKey: keyLastCarWikiName)
        UserDefaults.standard.set(explanation, forKey: keyLastCarExplanation)
        print("=== SELECTED CAR SAVED ===")
        print("Name: \(name), Wiki: \(wikiName)")
    }

    /// טוען את הרכב השמור
    static func loadSelectedCar() -> (name: String, wikiName: String, explanation: String)? {
        guard let name = UserDefaults.standard.string(forKey: keyLastCarName),
              !name.isEmpty else { return nil }
        let wikiName = UserDefaults.standard.string(forKey: keyLastCarWikiName) ?? ""
        let explanation = UserDefaults.standard.string(forKey: keyLastCarExplanation) ?? ""
        return (name, wikiName, explanation)
    }

    // MARK: - Pending Car Reveal (רכב חדש ממתין לחשיפה)

    /// בודק אם הרכב השתנה ושומר כ-pending reveal אם כן
    static func checkAndSetCarChange(newCarName: String, newWikiName: String, newExplanation: String) {
        // טוען את הרכב הקודם
        if let previousCar = loadSelectedCar() {
            // אם הרכב שונה - שומר כ-pending reveal
            if previousCar.name != newCarName {
                UserDefaults.standard.set(true, forKey: keyPendingCarReveal)
                UserDefaults.standard.set(newCarName, forKey: keyNewCarName)
                UserDefaults.standard.set(newWikiName, forKey: keyNewCarWikiName)
                UserDefaults.standard.set(newExplanation, forKey: keyNewCarExplanation)
                UserDefaults.standard.set(previousCar.name, forKey: keyPreviousCarName)
                print("=== CAR CHANGED: \(previousCar.name) → \(newCarName) ===")
                return
            }
        }
        // אם אין שינוי או אין רכב קודם - פשוט שומר
        saveSelectedCar(name: newCarName, wikiName: newWikiName, explanation: newExplanation)
    }

    /// בודק אם יש רכב חדש ממתין לחשיפה
    static func hasPendingCarReveal() -> Bool {
        UserDefaults.standard.bool(forKey: keyPendingCarReveal)
    }

    /// מחזיר את פרטי הרכב החדש הממתין לחשיפה
    static func getPendingCar() -> (name: String, wikiName: String, explanation: String, previousName: String)? {
        guard hasPendingCarReveal(),
              let name = UserDefaults.standard.string(forKey: keyNewCarName) else { return nil }
        let wikiName = UserDefaults.standard.string(forKey: keyNewCarWikiName) ?? ""
        let explanation = UserDefaults.standard.string(forKey: keyNewCarExplanation) ?? ""
        let previousName = UserDefaults.standard.string(forKey: keyPreviousCarName) ?? ""
        return (name, wikiName, explanation, previousName)
    }

    /// מנקה את ה-pending reveal ושומר את הרכב החדש כנוכחי
    static func clearPendingCarReveal() {
        // שומר את הרכב החדש כרכב הנוכחי
        if let pending = getPendingCar() {
            saveSelectedCar(name: pending.name, wikiName: pending.wikiName, explanation: pending.explanation)
        }
        // מנקה את ה-pending
        UserDefaults.standard.removeObject(forKey: keyPendingCarReveal)
        UserDefaults.standard.removeObject(forKey: keyNewCarName)
        UserDefaults.standard.removeObject(forKey: keyNewCarWikiName)
        UserDefaults.standard.removeObject(forKey: keyNewCarExplanation)
        UserDefaults.standard.removeObject(forKey: keyPreviousCarName)
        print("=== PENDING CAR REVEAL CLEARED ===")
    }

    /// בודק אם יש שינוי משמעותי בנתונים שמצדיק קריאה חדשה ל-Gemini
    /// שינוי משמעותי = שני התנאים יחד:
    /// 1. עברו לפחות 3 ימים מהניתוח האחרון
    /// 2. שינוי ב-HRV של לפחות 10% (לטובה או לרעה)
    static func hasSignificantChange(currentBundle: AIONChartDataBundle) -> Bool {
        guard let stats = loadWeeklyStats() else {
            print("=== NO PREVIOUS STATS - SIGNIFICANT CHANGE: YES ===")
            return true // אין נתונים קודמים - צריך ניתוח ראשון
        }

        // בדיקת זמן - האם עברו לפחות 3 ימים?
        guard let lastDate = lastUpdateDate() else {
            print("=== NO LAST DATE - SIGNIFICANT CHANGE: YES ===")
            return true
        }

        let daysSince = Date().timeIntervalSince(lastDate) / (24 * 3600)
        guard daysSince >= 3 else {
            print("=== ONLY \(Int(daysSince)) DAYS SINCE LAST ANALYSIS - NO CHANGE ===")
            return false // לא עברו 3 ימים - לא משנים
        }

        // חישוב שינוי ב-HRV
        let hrvValues = currentBundle.hrvTrend.points.map(\.value)
        let currentHRV = hrvValues.isEmpty ? 0 : hrvValues.reduce(0, +) / Double(hrvValues.count)

        let hrvChange = stats.hrv > 0 ? abs(currentHRV - stats.hrv) / stats.hrv : 0

        if hrvChange >= 0.10 {
            print("=== SIGNIFICANT CHANGE: HRV changed by \(Int(hrvChange * 100))% AND \(Int(daysSince)) days passed ===")
            return true
        }

        print("=== NO SIGNIFICANT CHANGE ===")
        print("Days since last: \(Int(daysSince)), HRV change: \(Int(hrvChange * 100))%")
        print("Both conditions required: 3+ days AND 10%+ HRV change")
        return false
    }

    // MARK: - Load

    /// טוען את המטמון אם תקף (תוך 24 שעות)
    static func load() -> String? {
        if let fromUD = loadFromUserDefaults(), fromUD.isValid {
            return fromUD.insights
        }
        if let fromFile = loadFromFile(), fromFile.isValid {
            return fromFile.insights
        }
        return nil
    }

    /// טוען את המטמון האחרון גם אם עברו 24 שעות (לצפייה בעמוד תובנות)
    static func loadLatest() -> String? {
        if let fromUD = loadFromUserDefaults() { return fromUD.insights }
        if let fromFile = loadFromFile() { return fromFile.insights }
        return nil
    }

    /// בודק אם צריך להריץ ניתוח חדש
    /// מחזיר true אם:
    /// 1. forceAnalysis = true
    /// 2. אין מטמון
    /// 3. ה-hash של נתוני הבריאות השתנה
    /// הערה: אם ה-hash זהה (הנתונים לא השתנו), לא קוראים ל-Gemini גם אם עבר זמן רב!
    /// זה מונע שינוי רכב כשהנתונים לא השתנו.
    static func shouldRunAnalysis(forceAnalysis: Bool, currentHealthDataHash: String) -> Bool {
        if forceAnalysis {
            print("=== SHOULD RUN ANALYSIS: force=true ===")
            return true
        }

        // בדיקה מ-UserDefaults - קודם כל בודקים hash!
        if let cached = loadFromUserDefaults() {
            // אם ה-hash זהה - הנתונים לא השתנו - לא צריך לקרוא ל-Gemini!
            if cached.healthDataHash == currentHealthDataHash {
                print("=== USING CACHE: health data unchanged (hash match) ===")
                return false
            }
            // רק אם ה-hash שונה - צריך ניתוח חדש
            print("=== SHOULD RUN ANALYSIS: health data changed ===")
            print("Cached hash: \(cached.healthDataHash)")
            print("Current hash: \(currentHealthDataHash)")
            return true
        }

        // בדיקה מקובץ
        if let cached = loadFromFile() {
            // אם ה-hash זהה - לא צריך לקרוא ל-Gemini!
            if cached.healthDataHash == currentHealthDataHash {
                print("=== USING FILE CACHE: health data unchanged (hash match) ===")
                return false
            }
            print("=== SHOULD RUN ANALYSIS: health data changed (file) ===")
            return true
        }

        print("=== SHOULD RUN ANALYSIS: no cache found ===")
        return true
    }

    /// תאריך עדכון אחרון
    static func lastUpdateDate() -> Date? {
        if let last = UserDefaults.standard.object(forKey: keyLastDate) as? Date { return last }
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let json = raw as? [String: Any],
              let dateStr = json["date"] as? String,
              let d = ISO8601DateFormatter().date(from: dateStr) else { return nil }
        return d
    }

    /// מנקה את כל הנתונים השמורים במטמון
    static func clear() {
        UserDefaults.standard.removeObject(forKey: keyInsights)
        UserDefaults.standard.removeObject(forKey: keyLastDate)
        UserDefaults.standard.removeObject(forKey: keyHealthDataHash)

        // Clear weekly stats too
        UserDefaults.standard.removeObject(forKey: keyAvgSleepHours)
        UserDefaults.standard.removeObject(forKey: keyAvgReadiness)
        UserDefaults.standard.removeObject(forKey: keyAvgStrain)
        UserDefaults.standard.removeObject(forKey: keyAvgHRV)
        UserDefaults.standard.removeObject(forKey: keyHealthScore)

        // Clear selected car
        UserDefaults.standard.removeObject(forKey: keyLastCarName)
        UserDefaults.standard.removeObject(forKey: keyLastCarWikiName)
        UserDefaults.standard.removeObject(forKey: keyLastCarExplanation)

        // Clear pending car reveal
        UserDefaults.standard.removeObject(forKey: keyPendingCarReveal)
        UserDefaults.standard.removeObject(forKey: keyNewCarName)
        UserDefaults.standard.removeObject(forKey: keyNewCarWikiName)
        UserDefaults.standard.removeObject(forKey: keyNewCarExplanation)
        UserDefaults.standard.removeObject(forKey: keyPreviousCarName)

        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }

        print("=== ANALYSIS CACHE CLEARED ===")
    }

    // MARK: - Private Helpers

    private struct CachedData {
        let insights: String
        let healthDataHash: String
        let date: Date
        let isValid: Bool
    }

    private static func loadFromUserDefaults() -> CachedData? {
        guard let last = UserDefaults.standard.object(forKey: keyLastDate) as? Date,
              let insights = UserDefaults.standard.string(forKey: keyInsights),
              let hash = UserDefaults.standard.string(forKey: keyHealthDataHash),
              !insights.isEmpty else { return nil }

        let isValid = Date().timeIntervalSince(last) < maxAgeSeconds
        return CachedData(insights: insights, healthDataHash: hash, date: last, isValid: isValid)
    }

    private static func loadFromFile() -> CachedData? {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let json = raw as? [String: Any],
              let insights = json["insights"] as? String, !insights.isEmpty,
              let hash = json["healthDataHash"] as? String,
              let dateStr = json["date"] as? String,
              let last = ISO8601DateFormatter().date(from: dateStr) else { return nil }

        let isValid = Date().timeIntervalSince(last) < maxAgeSeconds

        // סנכרון עם UserDefaults
        UserDefaults.standard.set(insights, forKey: keyInsights)
        UserDefaults.standard.set(last, forKey: keyLastDate)
        UserDefaults.standard.set(hash, forKey: keyHealthDataHash)

        return CachedData(insights: insights, healthDataHash: hash, date: last, isValid: isValid)
    }
}

// MARK: - Health Data Hash Generator

extension AnalysisCache {

    /// יוצר hash מנתוני הבריאות - אם ה-hash זהה, אין סיבה לקרוא ל-Gemini שוב
    /// משתמש בתאריך (יום) במקום timestamp מדויק כדי למנוע שינויים מיותרים
    static func generateHealthDataHash(from bundle: AIONChartDataBundle) -> String {
        var components: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Readiness data - מעוגל ליום
        let readinessValues = bundle.readiness.points.map {
            "\(dateFormatter.string(from: $0.date)):\(Int($0.recovery)):\(String(format: "%.1f", $0.strain))"
        }
        components.append(contentsOf: readinessValues)

        // Sleep data - מעוגל לשעות
        let sleepValues = bundle.sleep.points.compactMap { point -> String? in
            guard let hours = point.totalHours else { return nil }
            return "\(dateFormatter.string(from: point.date)):\(String(format: "%.1f", hours))"
        }
        components.append(contentsOf: sleepValues)

        // HRV data - ממוצע יומי מעוגל
        let hrvByDay = Dictionary(grouping: bundle.hrvTrend.points) { dateFormatter.string(from: $0.date) }
        let hrvValues = hrvByDay.map { day, points in
            let avg = points.map(\.value).reduce(0, +) / Double(points.count)
            return "\(day):\(Int(avg))"
        }.sorted()
        components.append(contentsOf: hrvValues)

        // RHR data - ממוצע יומי מעוגל
        let rhrByDay = Dictionary(grouping: bundle.rhrTrend.points) { dateFormatter.string(from: $0.date) }
        let rhrValues = rhrByDay.map { day, points in
            let avg = points.map(\.value).reduce(0, +) / Double(points.count)
            return "\(day):\(Int(avg))"
        }.sorted()
        components.append(contentsOf: rhrValues)

        // Steps data - סכום יומי
        let stepsByDay = Dictionary(grouping: bundle.steps.points) { dateFormatter.string(from: $0.date) }
        let stepsValues = stepsByDay.map { day, points in
            let total = points.map(\.steps).reduce(0, +)
            return "\(day):\(total)"
        }.sorted()
        components.append(contentsOf: stepsValues)

        // Active energy - סכום יומי מעוגל
        let energyByDay = Dictionary(grouping: bundle.glucoseEnergy.points) { dateFormatter.string(from: $0.date) }
        let energyValues = energyByDay.compactMap { day, points -> String? in
            let total = points.compactMap(\.activeEnergy).reduce(0, +)
            guard total > 0 else { return nil }
            return "\(day):\(Int(total))"
        }.sorted()
        components.append(contentsOf: energyValues)

        // יצירת string אחד וה-hash שלו
        let combined = components.joined(separator: "|")
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// יוצר hash מנתוני HealthDataModel (פשוט יותר)
    static func generateHealthDataHash(from model: HealthDataModel) -> String {
        var components: [String] = []

        if let steps = model.steps { components.append("steps:\(steps)") }
        if let hr = model.heartRate { components.append("hr:\(hr)") }
        if let rhr = model.restingHeartRate { components.append("rhr:\(rhr)") }
        if let sleep = model.sleepHours { components.append("sleep:\(sleep)") }
        if let active = model.activeEnergy { components.append("active:\(active)") }
        if let vo2 = model.vo2Max { components.append("vo2:\(vo2)") }
        if let bmi = model.bodyMassIndex { components.append("bmi:\(bmi)") }

        let combined = components.joined(separator: "|")
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
