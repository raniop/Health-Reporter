//
//  AIONMemory.swift
//  Health Reporter
//
//  Per-user persistent memory for AION – stores compressed user profile,
//  longitudinal insights, and recent analysis summaries so Gemini can
//  give personalized, context-aware responses across sessions.
//

import Foundation

// MARK: - Top-Level Memory Container

struct AIONMemory: Codable, Sendable {
    var userProfile: AIONUserProfile
    var longitudinalInsights: AIONLongitudinalInsights
    var recentAnalyses: [AIONAnalysisSummary]

    var interactionCount: Int
    var firstAnalysisDate: Date
    var lastUpdatedDate: Date

    /// Bump when the schema changes to allow migration.
    var schemaVersion: Int = 1
}

// MARK: - User Profile (stable characteristics)

struct AIONUserProfile: Codable, Sendable {
    var displayName: String?
    var dataSource: String?           // "Garmin", "Oura", "Apple Watch", etc.
    var typicalSleepHours: Double?    // e.g. 7.2
    var baselineHRV: Double?          // e.g. 45 ms
    var baselineRHR: Double?          // e.g. 58 bpm
    var vo2maxRange: String?          // e.g. "42-45"
    var fitnessLevel: String?         // "beginner", "intermediate", "advanced", "elite"
    var knownConditions: [String]     // e.g. ["shift worker", "marathon training"]
    var currentCarModel: String?      // e.g. "BMW M3"
    var carHistoryBrief: String?      // e.g. "Started as Honda Civic, upgraded to BMW M3"
}

// MARK: - Longitudinal Insights (evolving patterns)

struct AIONLongitudinalInsights: Codable, Sendable {
    var sleepTrend: String?           // e.g. "Improving over 3 months, deep sleep up 15%"
    var recoveryPattern: String?      // e.g. "Slow recovery after intense sessions, needs 48h"
    var trainingPattern: String?      // e.g. "Consistent 4-5x/week, heavy on cardio"
    var keyStrengths: [String]        // e.g. ["Consistent sleep schedule", "Good HRV baseline"]
    var persistentWeaknesses: [String] // e.g. ["Deep sleep below optimal", "High RHR trend"]
    var supplementHistory: String?    // e.g. "Previously recommended Mg, Omega-3"
    var notableEvents: [String]       // e.g. ["Jan 2026: significant HRV drop, recovered in 2 weeks"]
}

// MARK: - Single Analysis Summary (compressed)

struct AIONAnalysisSummary: Codable, Sendable {
    var date: Date
    var carModel: String
    var healthScore: Int
    var keyFindings_en: String        // 2-3 sentence summary
    var keyFindings_he: String
    var directiveStop: String?
    var directiveStart: String?
    var directiveWatch: String?
    var supplements: [String]         // Just supplement names
}
