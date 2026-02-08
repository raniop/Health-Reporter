//
//  AnalysisCache.swift
//  Health Reporter
//
//  AION analysis data cache – saves results and prevents unnecessary Gemini API calls.
//  If health data hasn't changed, Gemini is not called again.
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

    // Selected Car Keys (saving the car selected by Gemini)
    static let keyLastCarName = "AION.SelectedCar.Name"
    static let keyLastCarWikiName = "AION.SelectedCar.WikiName"
    static let keyLastCarExplanation = "AION.SelectedCar.Explanation"

    // Pending Car Reveal Keys (when a new car is waiting to be revealed)
    static let keyPendingCarReveal = "AION.PendingCarReveal"
    static let keyNewCarName = "AION.NewCar.Name"
    static let keyNewCarWikiName = "AION.NewCar.WikiName"
    static let keyNewCarExplanation = "AION.NewCar.Explanation"
    static let keyPreviousCarName = "AION.PreviousCar.Name"

    // Daily Activity Keys (for sharing with widget)
    static let keyDailySteps = "AION.DailyActivity.Steps"
    static let keyDailyCalories = "AION.DailyActivity.Calories"
    static let keyDailyExercise = "AION.DailyActivity.ExerciseMinutes"
    static let keyDailyStandHours = "AION.DailyActivity.StandHours"
    static let keyDailyRestingHR = "AION.DailyActivity.RestingHR"

    // Yesterday Activity Keys (for morning notification)
    static let keyYesterdaySteps = "AION.YesterdayActivity.Steps"
    static let keyYesterdayCalories = "AION.YesterdayActivity.Calories"

    // Main Score (the daily main score - from InsightsMetrics)
    static let keyMainScore = "AION.MainScore"
    static let keyMainScoreStatus = "AION.MainScoreStatus"

    // Score Breakdown Keys (for sending to the watch)
    static let keyRecoveryScore = "AION.ScoreBreakdown.Recovery"
    static let keySleepScore = "AION.ScoreBreakdown.Sleep"
    static let keyNervousSystemScore = "AION.ScoreBreakdown.NervousSystem"
    static let keyEnergyScore = "AION.ScoreBreakdown.Energy"
    static let keyActivityScore = "AION.ScoreBreakdown.Activity"
    static let keyLoadBalanceScore = "AION.ScoreBreakdown.LoadBalance"

    // Bedtime Recommendation Keys
    static let keyBedtimeRecommendation = "AION.BedtimeRecommendation"
    static let keyBedtimeLastDate = "AION.BedtimeLastDate"

    // User Personal Notes Key
    static let keyUserNotes = "AION.UserPersonalNotes"

    // MARK: - Cache Duration
    /// Cache is valid for 24 hours (Gemini is not called again even if there is a change)
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

    /// Saves the Gemini response + hash of the health data
    static func save(insights: String, healthDataHash: String) {
        let now = Date()

        // Save to UserDefaults
        UserDefaults.standard.set(insights, forKey: keyInsights)
        UserDefaults.standard.set(now, forKey: keyLastDate)
        UserDefaults.standard.set(healthDataHash, forKey: keyHealthDataHash)

        // Save to file
        guard let url = fileURL else { return }
        let payload: [String: Any] = [
            "insights": insights,
            "healthDataHash": healthDataHash,
            "date": ISO8601DateFormatter().string(from: now)
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? data.write(to: url)
    }

    /// Saves weekly statistics (derived from chartBundle) + health score
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

        // Save the score itself (no recalculation in Insights)
        if let s = score {
            UserDefaults.standard.set(s, forKey: keyHealthScore)
        }
    }

    /// Returns the saved weekly statistics
    static func loadWeeklyStats() -> (sleepHours: Double, readiness: Double, strain: Double, hrv: Double)? {
        let sleep = UserDefaults.standard.double(forKey: keyAvgSleepHours)
        let readiness = UserDefaults.standard.double(forKey: keyAvgReadiness)
        let strain = UserDefaults.standard.double(forKey: keyAvgStrain)
        let hrv = UserDefaults.standard.double(forKey: keyAvgHRV)

        // If all values are 0, there is probably no data
        if sleep == 0 && readiness == 0 && strain == 0 && hrv == 0 {
            return nil
        }

        return (sleep, readiness, strain, hrv)
    }

    /// Returns the saved health score (calculated in Dashboard)
    static func loadHealthScore() -> Int? {
        let score = UserDefaults.standard.integer(forKey: keyHealthScore)
        // If 0, it could mean it was never saved or it is actually 0
        // But a real score of 0 is not expected, so we return nil
        return score > 0 ? score : nil
    }

    /// Saves the health score (calculated by HealthScoreEngine)
    static func saveHealthScore(_ score: Int) {
        UserDefaults.standard.set(score, forKey: keyHealthScore)
        UserDefaults.standard.synchronize()
    }

    // MARK: - Main Score (the daily main score)

    /// Saves the daily main score (from InsightsMetrics.mainScore) with the status
    static func saveMainScore(_ score: Int, status: String? = nil) {
        UserDefaults.standard.set(score, forKey: keyMainScore)
        if let status = status {
            UserDefaults.standard.set(status, forKey: keyMainScoreStatus)
        } else {
            // Automatic calculation of the status from the score
            let level = RangeLevel.from(score: Double(score))
            let computedStatus = "score.description.\(level.rawValue)".localized
            UserDefaults.standard.set(computedStatus, forKey: keyMainScoreStatus)
        }
    }

    /// Loads the daily main score
    static func loadMainScore() -> Int? {
        let score = UserDefaults.standard.integer(forKey: keyMainScore)
        return score > 0 ? score : nil
    }

    /// Loads the status of the main score
    static func loadMainScoreStatus() -> String? {
        return UserDefaults.standard.string(forKey: keyMainScoreStatus)
    }

    // MARK: - Score Breakdown (for sending to the watch)

    /// Saves the score breakdown from DailyMetrics
    static func saveScoreBreakdown(
        recovery: Int?,
        sleep: Int?,
        nervousSystem: Int?,
        energy: Int?,
        activity: Int?,
        loadBalance: Int?
    ) {
        if let v = recovery { UserDefaults.standard.set(v, forKey: keyRecoveryScore) }
        if let v = sleep { UserDefaults.standard.set(v, forKey: keySleepScore) }
        if let v = nervousSystem { UserDefaults.standard.set(v, forKey: keyNervousSystemScore) }
        if let v = energy { UserDefaults.standard.set(v, forKey: keyEnergyScore) }
        if let v = activity { UserDefaults.standard.set(v, forKey: keyActivityScore) }
        if let v = loadBalance { UserDefaults.standard.set(v, forKey: keyLoadBalanceScore) }
    }

    /// Loads the score breakdown
    static func loadScoreBreakdown() -> (recovery: Int?, sleep: Int?, nervousSystem: Int?, energy: Int?, activity: Int?, loadBalance: Int?) {
        let recovery = UserDefaults.standard.integer(forKey: keyRecoveryScore)
        let sleep = UserDefaults.standard.integer(forKey: keySleepScore)
        let nervousSystem = UserDefaults.standard.integer(forKey: keyNervousSystemScore)
        let energy = UserDefaults.standard.integer(forKey: keyEnergyScore)
        let activity = UserDefaults.standard.integer(forKey: keyActivityScore)
        let loadBalance = UserDefaults.standard.integer(forKey: keyLoadBalanceScore)

        return (
            recovery: recovery > 0 ? recovery : nil,
            sleep: sleep > 0 ? sleep : nil,
            nervousSystem: nervousSystem > 0 ? nervousSystem : nil,
            energy: energy > 0 ? energy : nil,
            activity: activity > 0 ? activity : nil,
            loadBalance: loadBalance > 0 ? loadBalance : nil
        )
    }

    // MARK: - Health Score Result (with Breakdown)

    private static let keyHealthScoreResult = "AION.HealthScoreResult"

    /// Saves the full HealthScoreEngine result (including breakdown)
    static func saveHealthScoreResult(_ result: HealthScoringResult) {
        UserDefaults.standard.set(result.healthScoreInt, forKey: keyHealthScore)

        // Save the breakdown as JSON
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: keyHealthScoreResult)
        }

        // Force sync to disk (important for cross-thread access)
        UserDefaults.standard.synchronize()
    }

    /// Loads the full HealthScoreEngine result
    static func loadHealthScoreResult() -> HealthScoringResult? {
        guard let data = UserDefaults.standard.data(forKey: keyHealthScoreResult) else { return nil }
        return try? JSONDecoder().decode(HealthScoringResult.self, from: data)
    }

    /// Generates a short explanation for the score (for display in Tooltip)
    static func generateScoreExplanation() -> String {
        guard let result = loadHealthScoreResult() else {
            return "Not enough data to calculate"
        }

        var parts: [String] = []

        // General explanation
        parts.append("The score is based on a combination of recovery, sleep, fitness, training load, and activity level over the last 3 months, with emphasis on the last two weeks.")
        parts.append("")
        parts.append("Unmeasured data is excluded from the calculation, so you're not penalized for missing measurements.")
        parts.append("")

        // Add included domains
        parts.append("Breakdown:")
        for domain in result.includedDomains {
            let scoreInt = Int(round(domain.domainScore))
            let weightPercent = Int(round(domain.normalizedWeight * 100))

            parts.append("• \(domain.domainName): \(scoreInt) (\(weightPercent)%)")
        }

        // Add excluded domains
        if !result.excludedDomains.isEmpty {
            let excludedNames = result.excludedDomains.joined(separator: ", ")
            parts.append("")
            parts.append("Not measured: \(excludedNames)")
        }

        // Add reliability
        parts.append("")
        parts.append("Reliability score indicates how complete your data is: \(result.reliabilityScoreInt)%")

        return parts.joined(separator: "\n")
    }

    // MARK: - Daily Activity (for sharing with widget)

    /// Saves daily activity data from the Dashboard
    static func saveDailyActivity(steps: Int, calories: Int, exerciseMinutes: Int, standHours: Int, restingHR: Int?) {
        UserDefaults.standard.set(steps, forKey: keyDailySteps)
        UserDefaults.standard.set(calories, forKey: keyDailyCalories)
        UserDefaults.standard.set(exerciseMinutes, forKey: keyDailyExercise)
        UserDefaults.standard.set(standHours, forKey: keyDailyStandHours)
        if let hr = restingHR {
            UserDefaults.standard.set(hr, forKey: keyDailyRestingHR)
        }
    }

    /// Loads daily activity data
    static func loadDailyActivity() -> (steps: Int, calories: Int, exerciseMinutes: Int, standHours: Int, restingHR: Int)? {
        let steps = UserDefaults.standard.integer(forKey: keyDailySteps)
        let calories = UserDefaults.standard.integer(forKey: keyDailyCalories)
        let exerciseMinutes = UserDefaults.standard.integer(forKey: keyDailyExercise)
        let standHours = UserDefaults.standard.integer(forKey: keyDailyStandHours)
        let restingHR = UserDefaults.standard.integer(forKey: keyDailyRestingHR)

        // Return nil if no meaningful data was saved
        if steps == 0 && calories == 0 && exerciseMinutes == 0 {
            return nil
        }

        return (steps, calories, exerciseMinutes, standHours, restingHR)
    }

    /// Saves yesterday's activity data (for morning notification)
    static func saveYesterdayActivity(steps: Int, calories: Int) {
        UserDefaults.standard.set(steps, forKey: keyYesterdaySteps)
        UserDefaults.standard.set(calories, forKey: keyYesterdayCalories)
    }

    /// Loads yesterday's activity data
    static func loadYesterdaySteps() -> Int? {
        let steps = UserDefaults.standard.integer(forKey: keyYesterdaySteps)
        return steps > 0 ? steps : nil
    }

    // MARK: - Selected Car (saving the car from Gemini)

    /// Saves the car selected by Gemini
    static func saveSelectedCar(name: String, wikiName: String, explanation: String) {
        UserDefaults.standard.set(name, forKey: keyLastCarName)
        UserDefaults.standard.set(wikiName, forKey: keyLastCarWikiName)
        UserDefaults.standard.set(explanation, forKey: keyLastCarExplanation)
    }

    /// Loads the saved car
    static func loadSelectedCar() -> (name: String, wikiName: String, explanation: String)? {
        guard let name = UserDefaults.standard.string(forKey: keyLastCarName),
              !name.isEmpty else { return nil }
        let wikiName = UserDefaults.standard.string(forKey: keyLastCarWikiName) ?? ""
        let explanation = UserDefaults.standard.string(forKey: keyLastCarExplanation) ?? ""
        return (name, wikiName, explanation)
    }

    // MARK: - Car Name Normalization

    /// Normalizes a car name for comparison - trims whitespace, converts to lowercase, removes parentheses
    /// This prevents false positives when the car is the same but the name differs slightly (spaces, case, parentheses)
    private static func normalizeCarName(_ name: String) -> String {
        var normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Remove content in parentheses (e.g.: "Porsche Taycan (2024)" -> "porsche taycan")
        if let parenIndex = normalized.firstIndex(of: "(") {
            normalized = String(normalized[..<parenIndex])
                .trimmingCharacters(in: .whitespaces)
        }

        // Remove special characters
        normalized = normalized
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        // Remove double spaces
        while normalized.contains("  ") {
            normalized = normalized.replacingOccurrences(of: "  ", with: " ")
        }

        return normalized
    }

    // MARK: - Pending Car Reveal (new car waiting to be revealed)

    /// Checks if the car has changed and saves as pending reveal if so
    /// Uses normalized comparison + wikiName to prevent false positives
    static func checkAndSetCarChange(newCarName: String, newWikiName: String, newExplanation: String) {
        // If there is already a pending reveal for the same car - do nothing
        if hasPendingCarReveal() {
            if let pending = getPendingCar() {
                // Normalized comparison
                if normalizeCarName(pending.name) == normalizeCarName(newCarName) {
                    return
                }
            }
        }

        // Load the current car (not the pending one)
        if let currentCar = loadSelectedCar() {
            // Normalized comparison of names
            let normalizedCurrent = normalizeCarName(currentCar.name)
            let normalizedNew = normalizeCarName(newCarName)

            // Additional check: if the wikiName is identical - it's the same car!
            // wikiName is always in English and is not affected by language changes
            let wikiMatch = !currentCar.wikiName.isEmpty &&
                            !newWikiName.isEmpty &&
                            normalizeCarName(currentCar.wikiName) == normalizeCarName(newWikiName)

            // Only if the names are different AND the wikiName is different - then it's truly a new car
            if normalizedCurrent != normalizedNew && !wikiMatch {
                UserDefaults.standard.set(true, forKey: keyPendingCarReveal)
                UserDefaults.standard.set(newCarName, forKey: keyNewCarName)
                UserDefaults.standard.set(newWikiName, forKey: keyNewCarWikiName)
                UserDefaults.standard.set(newExplanation, forKey: keyNewCarExplanation)
                UserDefaults.standard.set(currentCar.name, forKey: keyPreviousCarName)
                return
            }
        }
        // If there is no change or no previous car - just save
        saveSelectedCar(name: newCarName, wikiName: newWikiName, explanation: newExplanation)
    }

    /// Checks if there is a new car waiting to be revealed
    static func hasPendingCarReveal() -> Bool {
        UserDefaults.standard.bool(forKey: keyPendingCarReveal)
    }

    /// Returns the details of the new car waiting to be revealed
    static func getPendingCar() -> (name: String, wikiName: String, explanation: String, previousName: String)? {
        guard hasPendingCarReveal(),
              let name = UserDefaults.standard.string(forKey: keyNewCarName) else { return nil }
        let wikiName = UserDefaults.standard.string(forKey: keyNewCarWikiName) ?? ""
        let explanation = UserDefaults.standard.string(forKey: keyNewCarExplanation) ?? ""

        // Priority 1: the car from the previous query in history (most accurate)
        // Priority 2: the car saved in keyPreviousCarName (fallback)
        let previousName: String
        if let historyPrevious = GeminiDebugStore.getPreviousCarFromHistory(), !historyPrevious.isEmpty {
            previousName = historyPrevious
        } else {
            previousName = UserDefaults.standard.string(forKey: keyPreviousCarName) ?? ""
        }

        return (name, wikiName, explanation, previousName)
    }

    /// Clears the pending reveal and saves the new car as the current one
    static func clearPendingCarReveal() {
        // Save the new car as the current car
        if let pending = getPendingCar() {
            saveSelectedCar(name: pending.name, wikiName: pending.wikiName, explanation: pending.explanation)
        }
        // Clear the pending
        UserDefaults.standard.removeObject(forKey: keyPendingCarReveal)
        UserDefaults.standard.removeObject(forKey: keyNewCarName)
        UserDefaults.standard.removeObject(forKey: keyNewCarWikiName)
        UserDefaults.standard.removeObject(forKey: keyNewCarExplanation)
        UserDefaults.standard.removeObject(forKey: keyPreviousCarName)
    }

    /// Checks if there is a significant change in the data that justifies a new Gemini call
    /// Significant change = both conditions together:
    /// 1. At least 3 days have passed since the last analysis
    /// 2. HRV change of at least 10% (for better or worse)
    static func hasSignificantChange(currentBundle: AIONChartDataBundle) -> Bool {
        guard let stats = loadWeeklyStats() else {
            return true // No previous data - need first analysis
        }

        // Time check - have at least 3 days passed?
        guard let lastDate = lastUpdateDate() else {
            return true
        }

        let daysSince = Date().timeIntervalSince(lastDate) / (24 * 3600)
        guard daysSince >= 3 else {
            return false // 3 days have not passed - no change
        }

        // Calculate HRV change
        let hrvValues = currentBundle.hrvTrend.points.map(\.value)
        let currentHRV = hrvValues.isEmpty ? 0 : hrvValues.reduce(0, +) / Double(hrvValues.count)

        let hrvChange = stats.hrv > 0 ? abs(currentHRV - stats.hrv) / stats.hrv : 0

        return hrvChange >= 0.10
    }

    // MARK: - Load

    /// Loads the cache if valid (within 24 hours)
    static func load() -> String? {
        if let fromUD = loadFromUserDefaults(), fromUD.isValid {
            return fromUD.insights
        }
        if let fromFile = loadFromFile(), fromFile.isValid {
            return fromFile.insights
        }
        return nil
    }

    /// Loads the latest cache even if 24 hours have passed (for viewing the insights page)
    static func loadLatest() -> String? {
        if let fromUD = loadFromUserDefaults() { return fromUD.insights }
        if let fromFile = loadFromFile() { return fromFile.insights }
        return nil
    }

    /// Checks if a new analysis needs to be run
    /// Returns true if:
    /// 1. forceAnalysis = true
    /// 2. There is no cache
    /// 3. The health data hash has changed
    /// Note: If the hash is identical (data hasn't changed), Gemini is not called even if a long time has passed!
    /// This prevents car changes when the data hasn't changed.
    static func shouldRunAnalysis(forceAnalysis: Bool, currentHealthDataHash: String) -> Bool {
        if forceAnalysis {
            return true
        }

        // Check from UserDefaults - first check the hash!
        if let cached = loadFromUserDefaults() {
            // If the hash is identical - data hasn't changed - no need to call Gemini!
            if cached.healthDataHash == currentHealthDataHash {
                return false
            }
            // Only if the hash is different - need a new analysis
            return true
        }

        // Check from file
        if let cached = loadFromFile() {
            // If the hash is identical - no need to call Gemini!
            if cached.healthDataHash == currentHealthDataHash {
                return false
            }
            return true
        }

        return true
    }

    /// Last update date
    static func lastUpdateDate() -> Date? {
        if let last = UserDefaults.standard.object(forKey: keyLastDate) as? Date { return last }
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data),
              let json = raw as? [String: Any],
              let dateStr = json["date"] as? String,
              let d = ISO8601DateFormatter().date(from: dateStr) else { return nil }
        return d
    }

    /// Clears all cached data
    static func clear() {
        // Clear AION Memory
        AIONMemoryManager.clear()

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

        // Clear bedtime recommendation
        UserDefaults.standard.removeObject(forKey: keyBedtimeRecommendation)
        UserDefaults.standard.removeObject(forKey: keyBedtimeLastDate)

        // Clear pending car reveal
        UserDefaults.standard.removeObject(forKey: keyPendingCarReveal)
        UserDefaults.standard.removeObject(forKey: keyNewCarName)
        UserDefaults.standard.removeObject(forKey: keyNewCarWikiName)
        UserDefaults.standard.removeObject(forKey: keyNewCarExplanation)
        UserDefaults.standard.removeObject(forKey: keyPreviousCarName)

        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
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

        // Sync with UserDefaults
        UserDefaults.standard.set(insights, forKey: keyInsights)
        UserDefaults.standard.set(last, forKey: keyLastDate)
        UserDefaults.standard.set(hash, forKey: keyHealthDataHash)

        return CachedData(insights: insights, healthDataHash: hash, date: last, isValid: isValid)
    }

    // MARK: - Bedtime Recommendation

    /// Saves the bedtime recommendation from Gemini
    static func saveBedtimeRecommendation(_ recommendation: BedtimeRecommendation) {
        if let data = try? JSONEncoder().encode(recommendation) {
            UserDefaults.standard.set(data, forKey: keyBedtimeRecommendation)
            UserDefaults.standard.set(Date(), forKey: keyBedtimeLastDate)
            UserDefaults.standard.synchronize()
        }
    }

    /// Loads the cached bedtime recommendation
    static func loadBedtimeRecommendation() -> BedtimeRecommendation? {
        guard let data = UserDefaults.standard.data(forKey: keyBedtimeRecommendation) else { return nil }
        return try? JSONDecoder().decode(BedtimeRecommendation.self, from: data)
    }

    /// Last bedtime recommendation date
    static func lastBedtimeUpdateDate() -> Date? {
        return UserDefaults.standard.object(forKey: keyBedtimeLastDate) as? Date
    }
}

// MARK: - Health Data Hash Generator

extension AnalysisCache {

    /// Generates a hash from the health data - if the hash is identical, there is no reason to call Gemini again
    /// Uses date (day) instead of exact timestamp to prevent unnecessary changes
    static func generateHealthDataHash(from bundle: AIONChartDataBundle) -> String {
        var components: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Readiness data - rounded to day
        let readinessValues = bundle.readiness.points.map {
            "\(dateFormatter.string(from: $0.date)):\(Int($0.recovery)):\(String(format: "%.1f", $0.strain))"
        }
        components.append(contentsOf: readinessValues)

        // Sleep data - rounded to hours
        let sleepValues = bundle.sleep.points.compactMap { point -> String? in
            guard let hours = point.totalHours else { return nil }
            return "\(dateFormatter.string(from: point.date)):\(String(format: "%.1f", hours))"
        }
        components.append(contentsOf: sleepValues)

        // HRV data - rounded daily average
        let hrvByDay = Dictionary(grouping: bundle.hrvTrend.points) { dateFormatter.string(from: $0.date) }
        let hrvValues = hrvByDay.map { day, points in
            let avg = points.map(\.value).reduce(0, +) / Double(points.count)
            return "\(day):\(Int(avg))"
        }.sorted()
        components.append(contentsOf: hrvValues)

        // RHR data - rounded daily average
        let rhrByDay = Dictionary(grouping: bundle.rhrTrend.points) { dateFormatter.string(from: $0.date) }
        let rhrValues = rhrByDay.map { day, points in
            let avg = points.map(\.value).reduce(0, +) / Double(points.count)
            return "\(day):\(Int(avg))"
        }.sorted()
        components.append(contentsOf: rhrValues)

        // Steps data - daily total
        let stepsByDay = Dictionary(grouping: bundle.steps.points) { dateFormatter.string(from: $0.date) }
        let stepsValues = stepsByDay.map { day, points in
            let total = points.map(\.steps).reduce(0, +)
            return "\(day):\(total)"
        }.sorted()
        components.append(contentsOf: stepsValues)

        // Active energy - rounded daily total
        let energyByDay = Dictionary(grouping: bundle.glucoseEnergy.points) { dateFormatter.string(from: $0.date) }
        let energyValues = energyByDay.compactMap { day, points -> String? in
            let total = points.compactMap(\.activeEnergy).reduce(0, +)
            guard total > 0 else { return nil }
            return "\(day):\(Int(total))"
        }.sorted()
        components.append(contentsOf: energyValues)

        // Include personal notes in hash to force re-analysis when notes change
        if let notes = loadUserNotes(), !notes.isEmpty {
            components.append("notes:\(notes)")
        }

        // Create a single string and its hash
        let combined = components.joined(separator: "|")
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Generates a hash from HealthDataModel data (simpler)
    static func generateHealthDataHash(from model: HealthDataModel) -> String {
        var components: [String] = []

        if let steps = model.steps { components.append("steps:\(steps)") }
        if let hr = model.heartRate { components.append("hr:\(hr)") }
        if let rhr = model.restingHeartRate { components.append("rhr:\(rhr)") }
        if let sleep = model.sleepHours { components.append("sleep:\(sleep)") }
        if let active = model.activeEnergy { components.append("active:\(active)") }
        if let vo2 = model.vo2Max { components.append("vo2:\(vo2)") }
        if let bmi = model.bodyMassIndex { components.append("bmi:\(bmi)") }

        // Include personal notes in hash to force re-analysis when notes change
        if let notes = loadUserNotes(), !notes.isEmpty {
            components.append("notes:\(notes)")
        }

        let combined = components.joined(separator: "|")
        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - User Personal Notes

    /// Saves personal notes that will be attached to the Gemini analysis
    static func saveUserNotes(_ notes: String) {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: keyUserNotes)
        } else {
            UserDefaults.standard.set(trimmed, forKey: keyUserNotes)
        }
    }

    /// Loads personal notes
    static func loadUserNotes() -> String? {
        return UserDefaults.standard.string(forKey: keyUserNotes)
    }

    /// Deletes personal notes
    static func clearUserNotes() {
        UserDefaults.standard.removeObject(forKey: keyUserNotes)
    }
}
