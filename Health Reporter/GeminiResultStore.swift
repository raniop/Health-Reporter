//
//  GeminiResultStore.swift
//  Health Reporter
//
//  Single-file storage for the daily Gemini result.
//  Replaces AnalysisCache as the primary source of truth for scores and analysis.
//  No UserDefaults. No hash-based invalidation. Just one JSON file.
//

import Foundation

enum GeminiResultStore {

    // MARK: - File Path

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HealthReporter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last_gemini_result.json")
    }

    // MARK: - Save

    static func save(_ result: GeminiDailyResult) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(result)
            try data.write(to: fileURL, options: .atomic)
            print("✅ [GeminiResultStore] Saved daily result for \(result.date)")
        } catch {
            print("❌ [GeminiResultStore] Failed to save: \(error)")
        }
    }

    // MARK: - Load

    static func load() -> GeminiDailyResult? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(GeminiDailyResult.self, from: data)
        } catch {
            print("⚠️ [GeminiResultStore] Failed to load: \(error)")
            return nil
        }
    }

    // MARK: - Check

    /// Returns true if a result exists and was generated today
    static func hasTodayResult() -> Bool {
        guard let result = load() else { return false }
        return Calendar.current.isDateInToday(result.date)
    }

    // MARK: - Typed Accessors (for widget, watch, notifications)

    static func loadHealthScore() -> Int? {
        load()?.scores.healthScore
    }

    static func loadCarScore() -> Int? {
        load()?.scores.carScore
    }

    static func loadCarName() -> String? {
        guard let result = load() else { return nil }
        return result.carModel.isEmpty ? nil : result.carModel
    }

    static func loadCarWikiName() -> String? {
        guard let result = load() else { return nil }
        return result.carWikiName.isEmpty ? nil : result.carWikiName
    }

    /// Returns a dictionary of metric ID → score for widget/watch display
    static func loadScoreBreakdown() -> [String: Int]? {
        guard let scores = load()?.scores else { return nil }
        var breakdown: [String: Int] = [:]
        if let v = scores.healthScore { breakdown["health"] = v }
        if let v = scores.sleepScore { breakdown["sleep"] = v }
        if let v = scores.readinessScore { breakdown["readiness"] = v }
        if let v = scores.energyScore { breakdown["energy"] = v }
        if let v = scores.nervousSystemBalance { breakdown["nervousSystem"] = v }
        if let v = scores.activityScore { breakdown["activity"] = v }
        if let v = scores.loadBalance { breakdown["loadBalance"] = v }
        if let v = scores.recoveryDebt { breakdown["recoveryDebt"] = v }
        if let v = scores.carScore { breakdown["car"] = v }
        return breakdown.isEmpty ? nil : breakdown
    }

    /// Load the raw analysis JSON (for Insights tab parsing via CarAnalysisParser)
    static func loadRawAnalysis() -> String? {
        guard let result = load() else { return nil }
        return result.rawAnalysisJSON.isEmpty ? nil : result.rawAnalysisJSON
    }

    // MARK: - Clear

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ [GeminiResultStore] Cleared stored result")
    }
}
