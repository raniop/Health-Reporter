//
//  WeeklyGoal.swift
//  Health Reporter
//
//  Data models for the weekly actionable goals system.
//

import UIKit

// MARK: - Goal Category

enum GoalCategory: String, Codable, CaseIterable {
    case sleep
    case exercise
    case nutrition
    case recovery
    case stress

    var iconName: String {
        switch self {
        case .sleep:     return "bed.double.fill"
        case .exercise:  return "figure.run"
        case .nutrition: return "fork.knife"
        case .recovery:  return "heart.fill"
        case .stress:    return "brain.head.profile"
        }
    }

    var color: UIColor {
        switch self {
        case .sleep:     return UIColor(hex: "#5C4D7D")!
        case .exercise:  return AIONDesign.accentSecondary
        case .nutrition: return AIONDesign.accentSuccess
        case .recovery:  return AIONDesign.accentPrimary
        case .stress:    return AIONDesign.accentWarning
        }
    }

    var localizedName: String {
        "goals.category.\(rawValue)".localized
    }
}

// MARK: - Goal Difficulty

enum GoalDifficulty: String, Codable {
    case easy
    case moderate
    case challenging
}

// MARK: - Goal Status

enum GoalStatus: String, Codable {
    case pending
    case completed
    case skipped
}

// MARK: - Weekly Goal

struct WeeklyGoal: Codable, Identifiable, Equatable {
    let id: String
    let textHe: String
    let textEn: String
    let category: GoalCategory
    let difficulty: GoalDifficulty
    let weekStartDate: Date
    let linkedMetricIds: [String]

    var status: GoalStatus
    var completedDate: Date?
    var skippedDate: Date?

    /// Metric baselines captured when the goal was assigned
    var baselineMetrics: [String: Double]
    /// Metric values captured after goal completion
    var afterMetrics: [String: Double]?

    var text: String {
        LocalizationManager.shared.currentLanguage == .hebrew ? textHe : textEn
    }
}

// MARK: - Weekly Goal Set

struct WeeklyGoalSet: Codable {
    let weekStartDate: Date
    var goals: [WeeklyGoal]
    let generatedDate: Date
    /// Progress assessment from Gemini (bilingual)
    var progressAssessmentHe: String
    var progressAssessmentEn: String

    var progressAssessment: String {
        LocalizationManager.shared.currentLanguage == .hebrew ? progressAssessmentHe : progressAssessmentEn
    }

    var completedCount: Int { goals.filter { $0.status == .completed }.count }
    var pendingCount: Int { goals.filter { $0.status == .pending }.count }
    var isAllCompleted: Bool { goals.allSatisfy { $0.status != .pending } }
}

// MARK: - Gemini JSON Response Models

struct WeeklyGoalJSON: Codable {
    let text_he: String?
    let text_en: String?
    let category: String?
    let difficulty: String?
    let linkedMetrics: [String]?
}

struct WeeklyGoalsResponseJSON: Codable {
    let goals: [WeeklyGoalJSON]?
    let shouldGenerateNewGoals: Bool?
    let progressAssessment_he: String?
    let progressAssessment_en: String?
}
