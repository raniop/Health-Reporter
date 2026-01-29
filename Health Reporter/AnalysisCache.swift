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

    /// שומר סטטיסטיקות שבועיות (נגזרות מ-chartBundle)
    static func saveWeeklyStats(from bundle: AIONChartDataBundle) {
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

        print("=== WEEKLY STATS SAVED ===")
        print("Avg Sleep: \(avgSleep)h, Readiness: \(avgReadiness), Strain: \(avgStrain), HRV: \(avgHRV)ms")
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
    /// 3. המטמון פג תוקף (יותר מ-24 שעות)
    /// 4. ה-hash של נתוני הבריאות השתנה
    static func shouldRunAnalysis(forceAnalysis: Bool, currentHealthDataHash: String) -> Bool {
        if forceAnalysis {
            print("=== SHOULD RUN ANALYSIS: force=true ===")
            return true
        }

        // בדיקה מ-UserDefaults
        if let cached = loadFromUserDefaults() {
            if !cached.isValid {
                print("=== SHOULD RUN ANALYSIS: cache expired ===")
                return true
            }
            if cached.healthDataHash != currentHealthDataHash {
                print("=== SHOULD RUN ANALYSIS: health data changed ===")
                print("Cached hash: \(cached.healthDataHash)")
                print("Current hash: \(currentHealthDataHash)")
                return true
            }
            print("=== USING CACHE: data unchanged ===")
            return false
        }

        // בדיקה מקובץ
        if let cached = loadFromFile() {
            if !cached.isValid {
                print("=== SHOULD RUN ANALYSIS: file cache expired ===")
                return true
            }
            if cached.healthDataHash != currentHealthDataHash {
                print("=== SHOULD RUN ANALYSIS: health data changed (file) ===")
                return true
            }
            print("=== USING FILE CACHE: data unchanged ===")
            return false
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
    static func generateHealthDataHash(from bundle: AIONChartDataBundle) -> String {
        var components: [String] = []

        // Readiness data
        let readinessValues = bundle.readiness.points.map { "\($0.date.timeIntervalSince1970):\($0.recovery):\($0.strain)" }
        components.append(contentsOf: readinessValues)

        // Sleep data
        let sleepValues = bundle.sleep.points.compactMap { point -> String? in
            guard let hours = point.totalHours else { return nil }
            return "\(point.date.timeIntervalSince1970):\(hours)"
        }
        components.append(contentsOf: sleepValues)

        // HRV data
        let hrvValues = bundle.hrvTrend.points.map { "\($0.date.timeIntervalSince1970):\($0.value)" }
        components.append(contentsOf: hrvValues)

        // RHR data
        let rhrValues = bundle.rhrTrend.points.map { "\($0.date.timeIntervalSince1970):\($0.value)" }
        components.append(contentsOf: rhrValues)

        // Steps data
        let stepsValues = bundle.steps.points.map { "\($0.date.timeIntervalSince1970):\($0.steps)" }
        components.append(contentsOf: stepsValues)

        // Active energy
        let energyValues = bundle.glucoseEnergy.points.compactMap { point -> String? in
            guard let energy = point.activeEnergy else { return nil }
            return "\(point.date.timeIntervalSince1970):\(energy)"
        }
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
