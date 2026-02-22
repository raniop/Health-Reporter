//
//  WeeklyGoalStore.swift
//  Health Reporter
//
//  File-based persistence for weekly goals. Follows GeminiResultStore pattern.
//

import Foundation

enum WeeklyGoalStore {

    // MARK: - File Path

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HealthReporter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("weekly_goals.json")
    }

    private static let maxWeeksToKeep = 8

    // MARK: - Save / Load All

    static func save(_ sets: [WeeklyGoalSet]) {
        // Trim to last N weeks
        let trimmed = Array(sets.suffix(maxWeeksToKeep))
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(trimmed)
            try data.write(to: fileURL, options: .atomic)
            print("✅ [WeeklyGoalStore] Saved \(trimmed.count) goal sets")
        } catch {
            print("❌ [WeeklyGoalStore] Failed to save: \(error)")
        }
    }

    static func loadAll() -> [WeeklyGoalSet] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WeeklyGoalSet].self, from: data)
        } catch {
            print("⚠️ [WeeklyGoalStore] Failed to load: \(error)")
            return []
        }
    }

    // MARK: - Current Week

    static func currentWeek() -> WeeklyGoalSet? {
        let all = loadAll()
        let calendar = Calendar.current
        let now = Date()
        // Find the set whose weekStartDate is within the current week
        return all.last { set in
            let start = set.weekStartDate
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return now >= start && now < end
        } ?? all.last // Fallback to latest set if no exact match
    }

    // MARK: - Update Goal Status

    static func updateGoalStatus(goalId: String, status: GoalStatus) {
        var all = loadAll()
        for i in all.indices.reversed() {
            for j in all[i].goals.indices {
                if all[i].goals[j].id == goalId {
                    all[i].goals[j].status = status
                    switch status {
                    case .completed:
                        all[i].goals[j].completedDate = Date()
                    case .skipped:
                        all[i].goals[j].skippedDate = Date()
                    case .pending:
                        all[i].goals[j].completedDate = nil
                        all[i].goals[j].skippedDate = nil
                    }
                    save(all)
                    return
                }
            }
        }
    }

    // MARK: - After Metrics

    static func addAfterMetrics(goalId: String, metrics: [String: Double]) {
        var all = loadAll()
        for i in all.indices.reversed() {
            for j in all[i].goals.indices {
                if all[i].goals[j].id == goalId {
                    all[i].goals[j].afterMetrics = metrics
                    save(all)
                    return
                }
            }
        }
    }

    // MARK: - Save New Goal Set

    static func saveNewGoalSet(_ goalSet: WeeklyGoalSet) {
        var all = loadAll()
        // Remove existing set for the same week if any
        all.removeAll { Calendar.current.isDate($0.weekStartDate, equalTo: goalSet.weekStartDate, toGranularity: .weekOfYear) }
        all.append(goalSet)
        save(all)
    }

    // MARK: - Build Goal History for Gemini Prompt

    static func buildGoalHistoryForPrompt() -> String {
        let all = loadAll()
        guard !all.isEmpty else {
            return "WEEKLY GOALS HISTORY: No previous goals. This is the first time generating goals."
        }

        let recentSets = all.suffix(2)
        var lines: [String] = ["WEEKLY GOALS HISTORY (last \(recentSets.count) weeks):"]

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for set in recentSets {
            lines.append("  Week of \(formatter.string(from: set.weekStartDate)):")
            for goal in set.goals {
                var line = "    - [\(goal.status.rawValue)] \(goal.textEn) (category: \(goal.category.rawValue))"
                if let after = goal.afterMetrics, !after.isEmpty {
                    let improvements = goal.linkedMetricIds.compactMap { metricId -> String? in
                        guard let baseline = goal.baselineMetrics[metricId],
                              let current = after[metricId] else { return nil }
                        let delta = current - baseline
                        let sign = delta >= 0 ? "+" : ""
                        return "\(metricId): \(sign)\(Int(delta))"
                    }
                    if !improvements.isEmpty {
                        line += " | metrics: \(improvements.joined(separator: ", "))"
                    }
                }
                lines.append(line)
            }
            lines.append("    Completed: \(set.completedCount)/\(set.goals.count)")
        }

        // Summary stats
        let allGoals = all.flatMap { $0.goals }
        let completed = allGoals.filter { $0.status == .completed }.count
        let total = allGoals.count
        if total > 0 {
            let rate = Int(Double(completed) / Double(total) * 100)
            lines.append("  Overall completion rate: \(rate)% (\(completed)/\(total) goals)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Clear Current Week

    /// Removes the current week's goal set so Gemini generates fresh goals.
    static func clearCurrentWeek() {
        var all = loadAll()
        let calendar = Calendar.current
        all.removeAll { set in
            calendar.isDate(set.weekStartDate, equalTo: Date(), toGranularity: .weekOfYear)
        }
        save(all)
        print("🔄 [WeeklyGoalStore] Cleared current week's goals for regeneration")
    }

    // MARK: - Clear All

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ [WeeklyGoalStore] Cleared stored goals")
    }
}
