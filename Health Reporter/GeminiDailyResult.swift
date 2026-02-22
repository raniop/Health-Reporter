//
//  GeminiDailyResult.swift
//  Health Reporter
//
//  Model representing the full daily result from Gemini AI.
//  This is the single source of truth — no local scoring, no UserDefaults cache.
//

import Foundation

/// The complete daily result from a single Gemini API call.
/// Contains all scores, car identity, text analysis, and home recommendations.
struct GeminiDailyResult: Codable {

    // MARK: - Metadata

    /// When this result was generated
    let date: Date

    // MARK: - Scores (all from Gemini)

    let scores: GeminiScores

    // MARK: - Car Identity

    let carModelHe: String
    let carModelEn: String
    let carWikiName: String
    let carExplanationHe: String
    let carExplanationEn: String

    // MARK: - Home Recommendations

    let homeRecommendationMedicalHe: String
    let homeRecommendationMedicalEn: String
    let homeRecommendationSportsHe: String
    let homeRecommendationSportsEn: String
    let homeRecommendationNutritionHe: String
    let homeRecommendationNutritionEn: String

    // MARK: - Full Analysis JSON (for Insights tab parsing)

    let rawAnalysisJSON: String

    // MARK: - Language-Aware Computed Properties

    private var isHebrew: Bool {
        LocalizationManager.shared.currentLanguage == .hebrew
    }

    var carModel: String { isHebrew ? carModelHe : carModelEn }
    var carExplanation: String { isHebrew ? carExplanationHe : carExplanationEn }
    var homeRecommendationMedical: String { isHebrew ? homeRecommendationMedicalHe : homeRecommendationMedicalEn }
    var homeRecommendationSports: String { isHebrew ? homeRecommendationSportsHe : homeRecommendationSportsEn }
    var homeRecommendationNutrition: String { isHebrew ? homeRecommendationNutritionHe : homeRecommendationNutritionEn }
}

// MARK: - Gemini Scores

struct GeminiScores: Codable {
    /// Overall daily health score (0-100)
    let healthScore: Int?
    let healthScoreExplanation: String?

    /// Sleep quality score (0-100)
    let sleepScore: Int?
    let sleepScoreExplanation: String?

    /// Recovery readiness score (0-100)
    let readinessScore: Int?
    let readinessScoreExplanation: String?

    /// Predicted energy level (0-100)
    let energyScore: Int?
    let energyScoreExplanation: String?

    /// Training strain (0.0-10.0)
    let trainingStrain: Double?
    let trainingStrainExplanation: String?

    /// Nervous system balance (0-100)
    let nervousSystemBalance: Int?
    let nervousSystemBalanceExplanation: String?

    /// Recovery debt (0-100, higher = more debt)
    let recoveryDebt: Int?
    let recoveryDebtExplanation: String?

    /// Activity level vs baseline (0-100)
    let activityScore: Int?
    let activityScoreExplanation: String?

    /// Acute/chronic load balance (0-100)
    let loadBalance: Int?
    let loadBalanceExplanation: String?

    /// Car card score (0-100)
    let carScore: Int?
    let carScoreExplanation: String?

    /// Stress load index (0-100, higher = more stress)
    let stressLoadIndex: Int?
    let stressLoadIndexExplanation: String?

    /// Morning freshness (0-100)
    let morningFreshness: Int?
    let morningFreshnessExplanation: String?

    /// Sleep consistency (0-100)
    let sleepConsistency: Int?
    let sleepConsistencyExplanation: String?

    /// Sleep debt (0-100, higher = more debt)
    let sleepDebt: Int?
    let sleepDebtExplanation: String?

    /// Workout readiness (0-100)
    let workoutReadiness: Int?
    let workoutReadinessExplanation: String?

    /// Daily goals completion (0-100)
    let dailyGoals: Int?
    let dailyGoalsExplanation: String?

    /// Cardio fitness trend (0-100)
    let cardioFitnessTrend: Int?
    let cardioFitnessTrendExplanation: String?

    // MARK: - Factory

    /// Create from ScoresJSON (Gemini response model)
    static func from(_ scoresJSON: ScoresJSON?, language: AppLanguage) -> GeminiScores {
        let isHe = language == .hebrew
        guard let s = scoresJSON else {
            return GeminiScores(
                healthScore: nil, healthScoreExplanation: nil,
                sleepScore: nil, sleepScoreExplanation: nil,
                readinessScore: nil, readinessScoreExplanation: nil,
                energyScore: nil, energyScoreExplanation: nil,
                trainingStrain: nil, trainingStrainExplanation: nil,
                nervousSystemBalance: nil, nervousSystemBalanceExplanation: nil,
                recoveryDebt: nil, recoveryDebtExplanation: nil,
                activityScore: nil, activityScoreExplanation: nil,
                loadBalance: nil, loadBalanceExplanation: nil,
                carScore: nil, carScoreExplanation: nil,
                stressLoadIndex: nil, stressLoadIndexExplanation: nil,
                morningFreshness: nil, morningFreshnessExplanation: nil,
                sleepConsistency: nil, sleepConsistencyExplanation: nil,
                sleepDebt: nil, sleepDebtExplanation: nil,
                workoutReadiness: nil, workoutReadinessExplanation: nil,
                dailyGoals: nil, dailyGoalsExplanation: nil,
                cardioFitnessTrend: nil, cardioFitnessTrendExplanation: nil
            )
        }

        func pick(_ he: String?, _ en: String?) -> String? {
            let val = isHe ? (he ?? en) : (en ?? he)
            return val?.isEmpty == true ? nil : val
        }

        return GeminiScores(
            healthScore: s.healthScore.map { Int($0) },
            healthScoreExplanation: pick(s.healthScoreExplanation_he, s.healthScoreExplanation_en),
            sleepScore: s.sleepScore.map { Int($0) },
            sleepScoreExplanation: pick(s.sleepScoreExplanation_he, s.sleepScoreExplanation_en),
            readinessScore: s.readinessScore.map { Int($0) },
            readinessScoreExplanation: pick(s.readinessScoreExplanation_he, s.readinessScoreExplanation_en),
            energyScore: s.energyScore.map { Int($0) },
            energyScoreExplanation: pick(s.energyScoreExplanation_he, s.energyScoreExplanation_en),
            trainingStrain: s.trainingStrain,
            trainingStrainExplanation: pick(s.trainingStrainExplanation_he, s.trainingStrainExplanation_en),
            nervousSystemBalance: s.nervousSystemBalance.map { Int($0) },
            nervousSystemBalanceExplanation: pick(s.nervousSystemBalanceExplanation_he, s.nervousSystemBalanceExplanation_en),
            recoveryDebt: s.recoveryDebt.map { Int($0) },
            recoveryDebtExplanation: pick(s.recoveryDebtExplanation_he, s.recoveryDebtExplanation_en),
            activityScore: s.activityScore.map { Int($0) },
            activityScoreExplanation: pick(s.activityScoreExplanation_he, s.activityScoreExplanation_en),
            loadBalance: s.loadBalance.map { Int($0) },
            loadBalanceExplanation: pick(s.loadBalanceExplanation_he, s.loadBalanceExplanation_en),
            carScore: s.carScore.map { Int($0) },
            carScoreExplanation: pick(s.carScoreExplanation_he, s.carScoreExplanation_en),
            stressLoadIndex: s.stressLoadIndex.map { Int($0) },
            stressLoadIndexExplanation: pick(s.stressLoadIndexExplanation_he, s.stressLoadIndexExplanation_en),
            morningFreshness: s.morningFreshness.map { Int($0) },
            morningFreshnessExplanation: pick(s.morningFreshnessExplanation_he, s.morningFreshnessExplanation_en),
            sleepConsistency: s.sleepConsistency.map { Int($0) },
            sleepConsistencyExplanation: pick(s.sleepConsistencyExplanation_he, s.sleepConsistencyExplanation_en),
            sleepDebt: s.sleepDebt.map { Int($0) },
            sleepDebtExplanation: pick(s.sleepDebtExplanation_he, s.sleepDebtExplanation_en),
            workoutReadiness: s.workoutReadiness.map { Int($0) },
            workoutReadinessExplanation: pick(s.workoutReadinessExplanation_he, s.workoutReadinessExplanation_en),
            dailyGoals: s.dailyGoals.map { Int($0) },
            dailyGoalsExplanation: pick(s.dailyGoalsExplanation_he, s.dailyGoalsExplanation_en),
            cardioFitnessTrend: s.cardioFitnessTrend.map { Int($0) },
            cardioFitnessTrendExplanation: pick(s.cardioFitnessTrendExplanation_he, s.cardioFitnessTrendExplanation_en)
        )
    }
}
