//
//  WeeklyGoalEngine.swift
//  Health Reporter
//
//  Progressive logic for the weekly goals system.
//  Determines when new goals should be generated and tracks metric improvement.
//

import Foundation

enum WeeklyGoalEngine {

    // MARK: - Should Generate New Goals

    /// Returns true when new goals should be generated:
    /// - No current goals exist, OR
    /// - All current goals are done (completed/skipped) AND linked metrics show improvement
    static func shouldGenerateNewGoals(
        currentGoals: WeeklyGoalSet?,
        currentScores: GeminiScores
    ) -> Bool {
        guard let goalSet = currentGoals else {
            // No goals exist — generate initial set
            return true
        }

        guard goalSet.isAllCompleted else {
            // Still have pending goals — don't generate yet
            return false
        }

        // All goals are done — check if at least some metrics improved
        let completedGoals = goalSet.goals.filter { $0.status == .completed }
        guard !completedGoals.isEmpty else {
            // All skipped, no completed — generate new ones anyway
            return true
        }

        // Check if metrics improved for completed goals
        var improvedCount = 0
        for goal in completedGoals {
            let improvement = computeImprovement(goal: goal, currentScores: currentScores)
            if improvement.contains(where: { $0.improved }) {
                improvedCount += 1
            }
        }

        // Generate new goals if at least one goal showed improvement
        return improvedCount > 0 || completedGoals.allSatisfy { $0.afterMetrics != nil }
    }

    // MARK: - Compute Improvement

    struct MetricImprovement {
        let metricId: String
        let before: Double
        let after: Double
        var improved: Bool { after > before }
        var changePercent: Double {
            guard before != 0 else { return 0 }
            return ((after - before) / before) * 100
        }
    }

    static func computeImprovement(
        goal: WeeklyGoal,
        currentScores: GeminiScores
    ) -> [MetricImprovement] {
        return goal.linkedMetricIds.compactMap { metricId in
            guard let baseline = goal.baselineMetrics[metricId] else { return nil }
            let current = scoreValue(for: metricId, from: currentScores) ?? baseline
            return MetricImprovement(metricId: metricId, before: baseline, after: current)
        }
    }

    // MARK: - Snapshot After Metrics

    /// Captures current metric values as "after" values when all goals are completed.
    /// Returns updated goals with afterMetrics populated.
    static func snapshotAfterMetrics(
        goals: [WeeklyGoal],
        scores: GeminiScores
    ) -> [WeeklyGoal] {
        return goals.map { goal in
            var updated = goal
            if goal.status == .completed && goal.afterMetrics == nil {
                var after: [String: Double] = [:]
                for metricId in goal.linkedMetricIds {
                    if let value = scoreValue(for: metricId, from: scores) {
                        after[metricId] = value
                    }
                }
                updated.afterMetrics = after
            }
            return updated
        }
    }

    // MARK: - Capture Baseline Metrics

    /// Captures current metric values as baseline when goals are first assigned.
    static func captureBaselines(
        for metricIds: [String],
        from scores: GeminiScores
    ) -> [String: Double] {
        var baselines: [String: Double] = [:]
        for metricId in metricIds {
            if let value = scoreValue(for: metricId, from: scores) {
                baselines[metricId] = value
            }
        }
        return baselines
    }

    // MARK: - Auto-Verify Goals

    /// Auto-verifies pending goals by comparing current scores against baselines.
    /// Returns updated goals with status changes applied.
    static func autoVerifyGoals(
        goals: [WeeklyGoal],
        currentScores: GeminiScores
    ) -> [WeeklyGoal] {
        return goals.map { goal in
            var updated = goal
            guard goal.status == .pending else { return updated }

            let improvements = computeImprovement(goal: goal, currentScores: currentScores)
            // Mark completed if at least half of linked metrics improved
            let improvedCount = improvements.filter { $0.improved }.count
            if !improvements.isEmpty && improvedCount > 0 && improvedCount >= (improvements.count + 1) / 2 {
                updated.status = .completed
                updated.completedDate = Date()
                // Capture after metrics
                var after: [String: Double] = [:]
                for metricId in goal.linkedMetricIds {
                    if let value = scoreValue(for: metricId, from: currentScores) {
                        after[metricId] = value
                    }
                }
                updated.afterMetrics = after
                print("✅ [WeeklyGoals] Auto-verified goal: \(goal.textEn)")
            }
            return updated
        }
    }

    // MARK: - Score Lookup

    static func scoreValue(for metricId: String, from scores: GeminiScores) -> Double? {
        switch metricId {
        case "healthScore":          return scores.healthScore.map(Double.init)
        case "sleepScore":           return scores.sleepScore.map(Double.init)
        case "readinessScore":       return scores.readinessScore.map(Double.init)
        case "energyScore":          return scores.energyScore.map(Double.init)
        case "trainingStrain":       return scores.trainingStrain
        case "nervousSystemBalance": return scores.nervousSystemBalance.map(Double.init)
        case "recoveryDebt":         return scores.recoveryDebt.map(Double.init)
        case "activityScore":        return scores.activityScore.map(Double.init)
        case "loadBalance":          return scores.loadBalance.map(Double.init)
        case "carScore":             return scores.carScore.map(Double.init)
        case "stressLoadIndex":      return scores.stressLoadIndex.map(Double.init)
        case "morningFreshness":     return scores.morningFreshness.map(Double.init)
        case "sleepConsistency":     return scores.sleepConsistency.map(Double.init)
        case "sleepDebt":            return scores.sleepDebt.map(Double.init)
        case "workoutReadiness":     return scores.workoutReadiness.map(Double.init)
        case "dailyGoals":           return scores.dailyGoals.map(Double.init)
        case "cardioFitnessTrend":   return scores.cardioFitnessTrend.map(Double.init)
        default:                     return nil
        }
    }
}
