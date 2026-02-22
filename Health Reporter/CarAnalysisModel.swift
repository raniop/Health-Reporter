//
//  CarAnalysisModel.swift
//  Health Reporter
//
//  Data model for car analysis from Gemini – matches the prompt exactly.
//

import Foundation

// MARK: - JSON Response Models (Codable)

/// Structured JSON model for Gemini response
struct CarAnalysisJSONResponse: Codable {
    let carIdentity: CarIdentityJSON
    let performanceReview: PerformanceReviewJSON

    // Bilingual bottlenecks (optional - Gemini may return only one language)
    let bottlenecks_he: [String]?
    let bottlenecks_en: [String]?
    let bottlenecks: [String]?  // Legacy

    let optimizationPlan: OptimizationPlanJSON
    let tuneUpPlan: TuneUpPlanJSON
    let directives: DirectivesJSON

    // Bilingual forecast/summary (optional - Gemini may return only one language)
    let forecast_he: String?
    let forecast_en: String?
    let forecast: String?  // Legacy

    // Energy Forecast (optional - new field)
    let energyForecast: EnergyForecastJSON?

    let supplements: [SupplementJSON]

    // Scores (all calculated by Gemini)
    let scores: ScoresJSON?

    // Home Recommendations (merged into main call)
    let homeRecommendations: HomeRecommendationsJSON?

    // Weekly Goals (actionable improvement goals)
    let weeklyGoals: WeeklyGoalsResponseJSON?
}

// MARK: - Scores (Gemini-calculated)

struct ScoresJSON: Codable {
    let healthScore: Double?
    let healthScoreExplanation_he: String?
    let healthScoreExplanation_en: String?
    let sleepScore: Double?
    let sleepScoreExplanation_he: String?
    let sleepScoreExplanation_en: String?
    let readinessScore: Double?
    let readinessScoreExplanation_he: String?
    let readinessScoreExplanation_en: String?
    let energyScore: Double?
    let energyScoreExplanation_he: String?
    let energyScoreExplanation_en: String?
    let trainingStrain: Double?
    let trainingStrainExplanation_he: String?
    let trainingStrainExplanation_en: String?
    let nervousSystemBalance: Double?
    let nervousSystemBalanceExplanation_he: String?
    let nervousSystemBalanceExplanation_en: String?
    let recoveryDebt: Double?
    let recoveryDebtExplanation_he: String?
    let recoveryDebtExplanation_en: String?
    let activityScore: Double?
    let activityScoreExplanation_he: String?
    let activityScoreExplanation_en: String?
    let loadBalance: Double?
    let loadBalanceExplanation_he: String?
    let loadBalanceExplanation_en: String?
    let carScore: Double?
    let carScoreExplanation_he: String?
    let carScoreExplanation_en: String?
    let stressLoadIndex: Double?
    let stressLoadIndexExplanation_he: String?
    let stressLoadIndexExplanation_en: String?
    let morningFreshness: Double?
    let morningFreshnessExplanation_he: String?
    let morningFreshnessExplanation_en: String?
    let sleepConsistency: Double?
    let sleepConsistencyExplanation_he: String?
    let sleepConsistencyExplanation_en: String?
    let sleepDebt: Double?
    let sleepDebtExplanation_he: String?
    let sleepDebtExplanation_en: String?
    let workoutReadiness: Double?
    let workoutReadinessExplanation_he: String?
    let workoutReadinessExplanation_en: String?
    let dailyGoals: Double?
    let dailyGoalsExplanation_he: String?
    let dailyGoalsExplanation_en: String?
    let cardioFitnessTrend: Double?
    let cardioFitnessTrendExplanation_he: String?
    let cardioFitnessTrendExplanation_en: String?
}

// MARK: - Home Recommendations (merged into main Gemini call)

struct HomeRecommendationsJSON: Codable {
    let medical_he: String?
    let medical_en: String?
    let sports_he: String?
    let sports_en: String?
    let nutrition_he: String?
    let nutrition_en: String?
    // Legacy single-language fields
    let medical: String?
    let sports: String?
    let nutrition: String?
}

struct EnergyForecastJSON: Codable {
    let text_he: String?
    let text_en: String?
    let trend: String  // "rising", "falling", "stable"
}

struct CarIdentityJSON: Codable {
    // Bilingual fields (optional - Gemini may return only one language)
    let model_he: String?
    let model_en: String?
    let wikiName: String
    let explanation_he: String?
    let explanation_en: String?

    // Backward compatibility - single language fields (legacy)
    let model: String?
    let explanation: String?
}

struct PerformanceReviewJSON: Codable {
    // Bilingual fields (optional - Gemini may return only one language)
    let engine_he: String?
    let engine_en: String?
    let transmission_he: String?
    let transmission_en: String?
    let suspension_he: String?
    let suspension_en: String?
    let fuelEfficiency_he: String?
    let fuelEfficiency_en: String?
    let electronics_he: String?
    let electronics_en: String?

    // Backward compatibility - single language fields (legacy)
    let engine: String?
    let transmission: String?
    let suspension: String?
    let fuelEfficiency: String?
    let electronics: String?
}

struct OptimizationPlanJSON: Codable {
    // Bilingual fields (optional - Gemini may return only one language)
    let upgrades_he: [String]?
    let upgrades_en: [String]?
    let skippedMaintenance_he: [String]?
    let skippedMaintenance_en: [String]?
    let stopImmediately_he: [String]?
    let stopImmediately_en: [String]?

    // Backward compatibility - single language fields (legacy)
    let upgrades: [String]?
    let skippedMaintenance: [String]?
    let stopImmediately: [String]?
}

struct TuneUpPlanJSON: Codable {
    // Bilingual fields (optional - Gemini may return only one language)
    let trainingAdjustments_he: String?
    let trainingAdjustments_en: String?
    let recoveryChanges_he: String?
    let recoveryChanges_en: String?
    let habitToAdd_he: String?
    let habitToAdd_en: String?
    let habitToRemove_he: String?
    let habitToRemove_en: String?

    // Backward compatibility - single language fields (legacy)
    let trainingAdjustments: String?
    let recoveryChanges: String?
    let habitToAdd: String?
    let habitToRemove: String?
}

struct DirectivesJSON: Codable {
    // Bilingual fields (optional - Gemini may return only one language)
    let stop_he: String?
    let stop_en: String?
    let start_he: String?
    let start_en: String?
    let watch_he: String?
    let watch_en: String?

    // Backward compatibility - single language fields (legacy)
    let stop: String?
    let start: String?
    let watch: String?
}

struct SupplementJSON: Codable {
    // Bilingual fields - all optional to handle missing fields gracefully
    let name_he: String?
    let name_en: String?
    let dosage_he: String?
    let dosage_en: String?
    let reason_he: String?
    let reason_en: String?
    let category: String?

    // Backward compatibility - single language fields (legacy)
    let name: String?
    let englishName: String?
    let dosage: String?
    let reason: String?
}

// MARK: - Supplement Recommendation Model

/// Supplement recommendation model - supports two languages
struct SupplementRecommendation {
    // Bilingual storage
    let nameHe: String
    let nameEn: String
    let dosageHe: String
    let dosageEn: String
    let reasonHe: String
    let reasonEn: String
    let category: SupplementCategory

    // Language-aware computed properties
    private var isHebrew: Bool {
        LocalizationManager.shared.currentLanguage == .hebrew
    }

    var name: String { isHebrew ? nameHe : nameEn }
    var dosage: String { isHebrew ? dosageHe : dosageEn }
    var reason: String { isHebrew ? reasonHe : reasonEn }

    // Convenience initializer for legacy single-language usage
    init(nameHe: String, nameEn: String, dosageHe: String, dosageEn: String, reasonHe: String, reasonEn: String, category: SupplementCategory) {
        self.nameHe = nameHe
        self.nameEn = nameEn
        self.dosageHe = dosageHe
        self.dosageEn = dosageEn
        self.reasonHe = reasonHe
        self.reasonEn = reasonEn
        self.category = category
    }

    // Legacy initializer - uses same value for both languages
    init(name: String, dosage: String, reason: String, category: SupplementCategory) {
        self.nameHe = name
        self.nameEn = name
        self.dosageHe = dosage
        self.dosageEn = dosage
        self.reasonHe = reason
        self.reasonEn = reason
        self.category = category
    }
}

/// Supplement categories
enum SupplementCategory: String, CaseIterable {
    case performance = "Performance & Training"
    case recovery = "Recovery & Inflammation"
    case sleep = "Sleep & Recovery"
    case general = "General Health"
}

// MARK: - Car Analysis Response

/// Model representing the full Gemini response
/// Supports two languages (Hebrew and English) with computed properties that return based on current language
struct CarAnalysisResponse {
    // MARK: - Bilingual Storage (Hebrew + English)

    // 1. Which car am I now?
    var carModelHe: String
    var carModelEn: String
    var carExplanationHe: String
    var carExplanationEn: String
    var carImageURL: String  // Link to car image (loaded from Wikipedia)
    var carWikiName: String  // Car name in English for Wikipedia search

    // 2. Full performance review
    var engineHe: String
    var engineEn: String
    var transmissionHe: String
    var transmissionEn: String
    var suspensionHe: String
    var suspensionEn: String
    var fuelEfficiencyHe: String
    var fuelEfficiencyEn: String
    var electronicsHe: String
    var electronicsEn: String

    // 3. What limits the performance
    var bottlenecksHe: [String]
    var bottlenecksEn: [String]
    var warningSignals: [String]

    // 4. Optimization plan
    var upgradesHe: [String]
    var upgradesEn: [String]
    var skippedMaintenanceHe: [String]
    var skippedMaintenanceEn: [String]
    var stopImmediatelyHe: [String]
    var stopImmediatelyEn: [String]

    // 5. Tune-up plan
    var trainingAdjustmentsHe: String
    var trainingAdjustmentsEn: String
    var recoveryChangesHe: String
    var recoveryChangesEn: String
    var habitToAddHe: String
    var habitToAddEn: String
    var habitToRemoveHe: String
    var habitToRemoveEn: String

    // 6. Action directives
    var directiveStopHe: String
    var directiveStopEn: String
    var directiveStartHe: String
    var directiveStartEn: String
    var directiveWatchHe: String
    var directiveWatchEn: String

    // 7. Summary
    var summaryHe: String
    var summaryEn: String

    // 8. Recommended supplements
    var supplements: [SupplementRecommendation]

    // 9. Energy forecast
    var energyForecastTextHe: String
    var energyForecastTextEn: String
    var energyForecastTrend: String  // "rising", "falling", "stable"

    // 10. Scores (from Gemini)
    var scores: ScoresJSON?

    // 11. Home Recommendations (from Gemini)
    var homeRecommendationMedicalHe: String
    var homeRecommendationMedicalEn: String
    var homeRecommendationSportsHe: String
    var homeRecommendationSportsEn: String
    var homeRecommendationNutritionHe: String
    var homeRecommendationNutritionEn: String

    // 12. Weekly Goals (actionable improvement goals)
    var weeklyGoals: [WeeklyGoalJSON]
    var weeklyGoalsShouldGenerate: Bool
    var weeklyGoalsProgressAssessmentHe: String
    var weeklyGoalsProgressAssessmentEn: String

    // The original response (for fallback purposes)
    var rawResponse: String

    // MARK: - Language-Aware Computed Properties

    private var isHebrew: Bool {
        LocalizationManager.shared.currentLanguage == .hebrew
    }

    // 1. Car Identity
    var carModel: String { isHebrew ? carModelHe : carModelEn }
    var carExplanation: String { isHebrew ? carExplanationHe : carExplanationEn }

    // 2. Performance Review
    var engine: String { isHebrew ? engineHe : engineEn }
    var transmission: String { isHebrew ? transmissionHe : transmissionEn }
    var suspension: String { isHebrew ? suspensionHe : suspensionEn }
    var fuelEfficiency: String { isHebrew ? fuelEfficiencyHe : fuelEfficiencyEn }
    var electronics: String { isHebrew ? electronicsHe : electronicsEn }

    // 3. Bottlenecks
    var bottlenecks: [String] { isHebrew ? bottlenecksHe : bottlenecksEn }

    // 4. Optimization Plan
    var upgrades: [String] { isHebrew ? upgradesHe : upgradesEn }
    var skippedMaintenance: [String] { isHebrew ? skippedMaintenanceHe : skippedMaintenanceEn }
    var stopImmediately: [String] { isHebrew ? stopImmediatelyHe : stopImmediatelyEn }

    // 5. Tune Up Plan
    var trainingAdjustments: String { isHebrew ? trainingAdjustmentsHe : trainingAdjustmentsEn }
    var recoveryChanges: String { isHebrew ? recoveryChangesHe : recoveryChangesEn }
    var habitToAdd: String { isHebrew ? habitToAddHe : habitToAddEn }
    var habitToRemove: String { isHebrew ? habitToRemoveHe : habitToRemoveEn }

    // 6. Directives
    var directiveStop: String { isHebrew ? directiveStopHe : directiveStopEn }
    var directiveStart: String { isHebrew ? directiveStartHe : directiveStartEn }
    var directiveWatch: String { isHebrew ? directiveWatchHe : directiveWatchEn }

    // 7. Summary
    var summary: String { isHebrew ? summaryHe : summaryEn }

    // 9. Energy Forecast
    var energyForecastText: String { isHebrew ? energyForecastTextHe : energyForecastTextEn }

    // 11. Home Recommendations
    var homeRecommendationMedical: String { isHebrew ? homeRecommendationMedicalHe : homeRecommendationMedicalEn }
    var homeRecommendationSports: String { isHebrew ? homeRecommendationSportsHe : homeRecommendationSportsEn }
    var homeRecommendationNutrition: String { isHebrew ? homeRecommendationNutritionHe : homeRecommendationNutritionEn }
}

/// Parser that extracts data from the Gemini response
enum CarAnalysisParser {

    // MARK: - JSON Parsing (Primary)

    /// Attempts to parse the response as structured JSON
    static func parseJSON(_ response: String) -> CarAnalysisResponse? {
        // Cleanup - remove ```json and ``` if present
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Decode
        guard let data = cleaned.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONDecoder().decode(CarAnalysisJSONResponse.self, from: data)
            return convertJSONToResponse(json, rawResponse: response)
        } catch {
            print("⚠️ CarAnalysisParser: JSON decode failed - \(error)")
            // Try manual JSON parsing as fallback
            if let manualResult = parseJSONManually(cleaned, rawResponse: response) {
                print("✅ CarAnalysisParser: Manual JSON parsing succeeded")
                return manualResult
            }
            return nil
        }
    }

    /// Fallback manual JSON parsing using JSONSerialization when Codable fails
    private static func parseJSONManually(_ jsonString: String, rawResponse: String) -> CarAnalysisResponse? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("⚠️ CarAnalysisParser: Manual JSON parsing failed - invalid JSON")
            return nil
        }

        // Extract nested objects
        let carIdentity = json["carIdentity"] as? [String: Any] ?? [:]
        let performanceReview = json["performanceReview"] as? [String: Any] ?? [:]
        let optimizationPlan = json["optimizationPlan"] as? [String: Any] ?? [:]
        let tuneUpPlan = json["tuneUpPlan"] as? [String: Any] ?? [:]
        let directives = json["directives"] as? [String: Any] ?? [:]

        // Helper function to safely get string
        func str(_ dict: [String: Any], _ key: String) -> String {
            return dict[key] as? String ?? ""
        }

        // Helper function to safely get string array
        func strArr(_ dict: [String: Any], _ key: String) -> [String] {
            return dict[key] as? [String] ?? []
        }

        // Helpers: resolve bilingual fields - pick whichever language is present, fill both slots
        func biStr(_ dict: [String: Any], he: String, en: String, legacy: String? = nil) -> (String, String) {
            let h = str(dict, he).isEmpty ? nil : str(dict, he)
            let e = str(dict, en).isEmpty ? nil : str(dict, en)
            let l = legacy != nil ? (str(dict, legacy!).isEmpty ? nil : str(dict, legacy!)) : nil
            let resolved = h ?? e ?? l ?? ""
            return (h ?? resolved, e ?? resolved)
        }
        func biArr(_ dict: [String: Any], he: String, en: String, legacy: String? = nil) -> ([String], [String]) {
            let h = strArr(dict, he).isEmpty ? nil : strArr(dict, he)
            let e = strArr(dict, en).isEmpty ? nil : strArr(dict, en)
            let l = legacy != nil ? (strArr(dict, legacy!).isEmpty ? nil : strArr(dict, legacy!)) : nil
            let resolved = h ?? e ?? l ?? []
            return (h ?? resolved, e ?? resolved)
        }

        // Parse supplements manually
        var supplements: [SupplementRecommendation] = []
        if let supplementsArray = json["supplements"] as? [[String: Any]] {
            for s in supplementsArray {
                let catStr = (s["category"] as? String ?? "general").lowercased()
                let category: SupplementCategory
                switch catStr {
                case "sleep": category = .sleep
                case "performance": category = .performance
                case "recovery": category = .recovery
                default: category = .general
                }

                let (nameHe, nameEn) = biStr(s, he: "name_he", en: "name_en", legacy: "name")
                let (dosageHe, dosageEn) = biStr(s, he: "dosage_he", en: "dosage_en", legacy: "dosage")
                let (reasonHe, reasonEn) = biStr(s, he: "reason_he", en: "reason_en", legacy: "reason")

                supplements.append(SupplementRecommendation(
                    nameHe: nameHe,
                    nameEn: nameEn,
                    dosageHe: dosageHe,
                    dosageEn: dosageEn,
                    reasonHe: reasonHe,
                    reasonEn: reasonEn,
                    category: category
                ))
            }
        }

        let (modelHe, modelEn) = biStr(carIdentity, he: "model_he", en: "model_en", legacy: "model")
        let (explHe, explEn) = biStr(carIdentity, he: "explanation_he", en: "explanation_en", legacy: "explanation")
        let (engineHe, engineEn) = biStr(performanceReview, he: "engine_he", en: "engine_en", legacy: "engine")
        let (transHe, transEn) = biStr(performanceReview, he: "transmission_he", en: "transmission_en", legacy: "transmission")
        let (suspHe, suspEn) = biStr(performanceReview, he: "suspension_he", en: "suspension_en", legacy: "suspension")
        let (fuelHe, fuelEn) = biStr(performanceReview, he: "fuelEfficiency_he", en: "fuelEfficiency_en", legacy: "fuelEfficiency")
        let (elecHe, elecEn) = biStr(performanceReview, he: "electronics_he", en: "electronics_en", legacy: "electronics")
        let root = json as [String: Any]
        let (bnHe, bnEn) = biArr(root, he: "bottlenecks_he", en: "bottlenecks_en", legacy: "bottlenecks")
        let (upgHe, upgEn) = biArr(optimizationPlan, he: "upgrades_he", en: "upgrades_en", legacy: "upgrades")
        let (skipHe, skipEn) = biArr(optimizationPlan, he: "skippedMaintenance_he", en: "skippedMaintenance_en", legacy: "skippedMaintenance")
        let (stopHe, stopEn) = biArr(optimizationPlan, he: "stopImmediately_he", en: "stopImmediately_en", legacy: "stopImmediately")
        let (trainHe, trainEn) = biStr(tuneUpPlan, he: "trainingAdjustments_he", en: "trainingAdjustments_en", legacy: "trainingAdjustments")
        let (recHe, recEn) = biStr(tuneUpPlan, he: "recoveryChanges_he", en: "recoveryChanges_en", legacy: "recoveryChanges")
        let (addHe, addEn) = biStr(tuneUpPlan, he: "habitToAdd_he", en: "habitToAdd_en", legacy: "habitToAdd")
        let (remHe, remEn) = biStr(tuneUpPlan, he: "habitToRemove_he", en: "habitToRemove_en", legacy: "habitToRemove")
        let (dStopHe, dStopEn) = biStr(directives, he: "stop_he", en: "stop_en", legacy: "stop")
        let (dStartHe, dStartEn) = biStr(directives, he: "start_he", en: "start_en", legacy: "start")
        let (dWatchHe, dWatchEn) = biStr(directives, he: "watch_he", en: "watch_en", legacy: "watch")
        let (sumHe, sumEn) = biStr(root, he: "forecast_he", en: "forecast_en", legacy: "forecast")

        let ef = json["energyForecast"] as? [String: Any] ?? [:]
        let (eTextHe, eTextEn) = biStr(ef, he: "text_he", en: "text_en")

        return CarAnalysisResponse(
            carModelHe: modelHe, carModelEn: modelEn,
            carExplanationHe: explHe, carExplanationEn: explEn,
            carImageURL: "",
            carWikiName: str(carIdentity, "wikiName"),

            engineHe: engineHe, engineEn: engineEn,
            transmissionHe: transHe, transmissionEn: transEn,
            suspensionHe: suspHe, suspensionEn: suspEn,
            fuelEfficiencyHe: fuelHe, fuelEfficiencyEn: fuelEn,
            electronicsHe: elecHe, electronicsEn: elecEn,

            bottlenecksHe: bnHe, bottlenecksEn: bnEn,
            warningSignals: [],

            upgradesHe: upgHe, upgradesEn: upgEn,
            skippedMaintenanceHe: skipHe, skippedMaintenanceEn: skipEn,
            stopImmediatelyHe: stopHe, stopImmediatelyEn: stopEn,

            trainingAdjustmentsHe: trainHe, trainingAdjustmentsEn: trainEn,
            recoveryChangesHe: recHe, recoveryChangesEn: recEn,
            habitToAddHe: addHe, habitToAddEn: addEn,
            habitToRemoveHe: remHe, habitToRemoveEn: remEn,

            directiveStopHe: dStopHe, directiveStopEn: dStopEn,
            directiveStartHe: dStartHe, directiveStartEn: dStartEn,
            directiveWatchHe: dWatchHe, directiveWatchEn: dWatchEn,

            summaryHe: sumHe, summaryEn: sumEn,

            supplements: supplements,

            energyForecastTextHe: eTextHe, energyForecastTextEn: eTextEn,
            energyForecastTrend: str(ef, "trend").isEmpty ? "stable" : str(ef, "trend"),

            scores: parseScoresManually(from: root),

            homeRecommendationMedicalHe: "", homeRecommendationMedicalEn: "",
            homeRecommendationSportsHe: "", homeRecommendationSportsEn: "",
            homeRecommendationNutritionHe: "", homeRecommendationNutritionEn: "",

            weeklyGoals: parseWeeklyGoalsManually(from: root),
            weeklyGoalsShouldGenerate: (root["weeklyGoals"] as? [String: Any])?["shouldGenerateNewGoals"] as? Bool ?? true,
            weeklyGoalsProgressAssessmentHe: (root["weeklyGoals"] as? [String: Any])?["progressAssessment_he"] as? String ?? "",
            weeklyGoalsProgressAssessmentEn: (root["weeklyGoals"] as? [String: Any])?["progressAssessment_en"] as? String ?? "",

            rawResponse: rawResponse
        )
    }

    /// Parse weekly goals from manual JSON dictionary
    private static func parseWeeklyGoalsManually(from root: [String: Any]) -> [WeeklyGoalJSON] {
        guard let wg = root["weeklyGoals"] as? [String: Any],
              let goalsArray = wg["goals"] as? [[String: Any]] else { return [] }
        return goalsArray.map { g in
            WeeklyGoalJSON(
                text_he: g["text_he"] as? String,
                text_en: g["text_en"] as? String,
                category: g["category"] as? String,
                difficulty: g["difficulty"] as? String,
                linkedMetrics: g["linkedMetrics"] as? [String]
            )
        }
    }

    /// Parse scores from manual JSON dictionary
    private static func parseScoresManually(from root: [String: Any]) -> ScoresJSON? {
        guard let s = root["scores"] as? [String: Any] else { return nil }
        return ScoresJSON(
            healthScore: s["healthScore"] as? Double,
            healthScoreExplanation_he: s["healthScoreExplanation_he"] as? String,
            healthScoreExplanation_en: s["healthScoreExplanation_en"] as? String,
            sleepScore: s["sleepScore"] as? Double,
            sleepScoreExplanation_he: s["sleepScoreExplanation_he"] as? String,
            sleepScoreExplanation_en: s["sleepScoreExplanation_en"] as? String,
            readinessScore: s["readinessScore"] as? Double,
            readinessScoreExplanation_he: s["readinessScoreExplanation_he"] as? String,
            readinessScoreExplanation_en: s["readinessScoreExplanation_en"] as? String,
            energyScore: s["energyScore"] as? Double,
            energyScoreExplanation_he: s["energyScoreExplanation_he"] as? String,
            energyScoreExplanation_en: s["energyScoreExplanation_en"] as? String,
            trainingStrain: s["trainingStrain"] as? Double,
            trainingStrainExplanation_he: s["trainingStrainExplanation_he"] as? String,
            trainingStrainExplanation_en: s["trainingStrainExplanation_en"] as? String,
            nervousSystemBalance: s["nervousSystemBalance"] as? Double,
            nervousSystemBalanceExplanation_he: s["nervousSystemBalanceExplanation_he"] as? String,
            nervousSystemBalanceExplanation_en: s["nervousSystemBalanceExplanation_en"] as? String,
            recoveryDebt: s["recoveryDebt"] as? Double,
            recoveryDebtExplanation_he: s["recoveryDebtExplanation_he"] as? String,
            recoveryDebtExplanation_en: s["recoveryDebtExplanation_en"] as? String,
            activityScore: s["activityScore"] as? Double,
            activityScoreExplanation_he: s["activityScoreExplanation_he"] as? String,
            activityScoreExplanation_en: s["activityScoreExplanation_en"] as? String,
            loadBalance: s["loadBalance"] as? Double,
            loadBalanceExplanation_he: s["loadBalanceExplanation_he"] as? String,
            loadBalanceExplanation_en: s["loadBalanceExplanation_en"] as? String,
            carScore: s["carScore"] as? Double,
            carScoreExplanation_he: s["carScoreExplanation_he"] as? String,
            carScoreExplanation_en: s["carScoreExplanation_en"] as? String,
            stressLoadIndex: s["stressLoadIndex"] as? Double,
            stressLoadIndexExplanation_he: s["stressLoadIndexExplanation_he"] as? String,
            stressLoadIndexExplanation_en: s["stressLoadIndexExplanation_en"] as? String,
            morningFreshness: s["morningFreshness"] as? Double,
            morningFreshnessExplanation_he: s["morningFreshnessExplanation_he"] as? String,
            morningFreshnessExplanation_en: s["morningFreshnessExplanation_en"] as? String,
            sleepConsistency: s["sleepConsistency"] as? Double,
            sleepConsistencyExplanation_he: s["sleepConsistencyExplanation_he"] as? String,
            sleepConsistencyExplanation_en: s["sleepConsistencyExplanation_en"] as? String,
            sleepDebt: s["sleepDebt"] as? Double,
            sleepDebtExplanation_he: s["sleepDebtExplanation_he"] as? String,
            sleepDebtExplanation_en: s["sleepDebtExplanation_en"] as? String,
            workoutReadiness: s["workoutReadiness"] as? Double,
            workoutReadinessExplanation_he: s["workoutReadinessExplanation_he"] as? String,
            workoutReadinessExplanation_en: s["workoutReadinessExplanation_en"] as? String,
            dailyGoals: s["dailyGoals"] as? Double,
            dailyGoalsExplanation_he: s["dailyGoalsExplanation_he"] as? String,
            dailyGoalsExplanation_en: s["dailyGoalsExplanation_en"] as? String,
            cardioFitnessTrend: s["cardioFitnessTrend"] as? Double,
            cardioFitnessTrendExplanation_he: s["cardioFitnessTrendExplanation_he"] as? String,
            cardioFitnessTrendExplanation_en: s["cardioFitnessTrendExplanation_en"] as? String
        )
    }

    /// Converts the parsed JSON to a CarAnalysisResponse model
    /// Supports both the new bilingual format (_he/_en) and the legacy format (single field)
    private static func convertJSONToResponse(_ json: CarAnalysisJSONResponse, rawResponse: String) -> CarAnalysisResponse {
        // Convert supplements - handle single-language and nil values gracefully
        let supplements = json.supplements.map { s in
            let category: SupplementCategory
            switch (s.category ?? "general").lowercased() {
            case "sleep": category = .sleep
            case "performance": category = .performance
            case "recovery": category = .recovery
            default: category = .general
            }
            // Resolve: pick whichever language is present, fill both
            func resolve(he: String?, en: String?, legacy: String?) -> (String, String) {
                let h = (he ?? "").isEmpty ? nil : he
                let e = (en ?? "").isEmpty ? nil : en
                let l = (legacy ?? "").isEmpty ? nil : legacy
                let r = h ?? e ?? l ?? ""
                return (h ?? r, e ?? r)
            }
            let (nameHe, nameEn) = resolve(he: s.name_he, en: s.name_en, legacy: s.name ?? s.englishName)
            let (dosageHe, dosageEn) = resolve(he: s.dosage_he, en: s.dosage_en, legacy: s.dosage)
            let (reasonHe, reasonEn) = resolve(he: s.reason_he, en: s.reason_en, legacy: s.reason)

            return SupplementRecommendation(
                nameHe: nameHe,
                nameEn: nameEn,
                dosageHe: dosageHe,
                dosageEn: dosageEn,
                reasonHe: reasonHe,
                reasonEn: reasonEn,
                category: category
            )
        }

        // Helpers: resolve bilingual string/array - pick whichever language is available, fill both slots
        func biStr(he: String?, en: String?, legacy: String?) -> (String, String) {
            let h = (he ?? "").isEmpty ? nil : he
            let e = (en ?? "").isEmpty ? nil : en
            let l = (legacy ?? "").isEmpty ? nil : legacy
            let resolved = h ?? e ?? l ?? ""
            return (h ?? resolved, e ?? resolved)
        }
        func biArr(he: [String]?, en: [String]?, legacy: [String]?) -> ([String], [String]) {
            let h = (he ?? []).isEmpty ? nil : he
            let e = (en ?? []).isEmpty ? nil : en
            let l = (legacy ?? []).isEmpty ? nil : legacy
            let resolved = h ?? e ?? l ?? []
            return (h ?? resolved, e ?? resolved)
        }

        let carIdentity = json.carIdentity
        let perf = json.performanceReview
        let opt = json.optimizationPlan
        let tune = json.tuneUpPlan
        let dir = json.directives

        let (modelHe, modelEn) = biStr(he: carIdentity.model_he, en: carIdentity.model_en, legacy: carIdentity.model)
        let (explHe, explEn) = biStr(he: carIdentity.explanation_he, en: carIdentity.explanation_en, legacy: carIdentity.explanation)
        let (engineHe, engineEn) = biStr(he: perf.engine_he, en: perf.engine_en, legacy: perf.engine)
        let (transHe, transEn) = biStr(he: perf.transmission_he, en: perf.transmission_en, legacy: perf.transmission)
        let (suspHe, suspEn) = biStr(he: perf.suspension_he, en: perf.suspension_en, legacy: perf.suspension)
        let (fuelHe, fuelEn) = biStr(he: perf.fuelEfficiency_he, en: perf.fuelEfficiency_en, legacy: perf.fuelEfficiency)
        let (elecHe, elecEn) = biStr(he: perf.electronics_he, en: perf.electronics_en, legacy: perf.electronics)
        let (bnHe, bnEn) = biArr(he: json.bottlenecks_he, en: json.bottlenecks_en, legacy: json.bottlenecks)
        let (upgHe, upgEn) = biArr(he: opt.upgrades_he, en: opt.upgrades_en, legacy: opt.upgrades)
        let (skipHe, skipEn) = biArr(he: opt.skippedMaintenance_he, en: opt.skippedMaintenance_en, legacy: opt.skippedMaintenance)
        let (stopHe, stopEn) = biArr(he: opt.stopImmediately_he, en: opt.stopImmediately_en, legacy: opt.stopImmediately)
        let (trainHe, trainEn) = biStr(he: tune.trainingAdjustments_he, en: tune.trainingAdjustments_en, legacy: tune.trainingAdjustments)
        let (recHe, recEn) = biStr(he: tune.recoveryChanges_he, en: tune.recoveryChanges_en, legacy: tune.recoveryChanges)
        let (addHe, addEn) = biStr(he: tune.habitToAdd_he, en: tune.habitToAdd_en, legacy: tune.habitToAdd)
        let (remHe, remEn) = biStr(he: tune.habitToRemove_he, en: tune.habitToRemove_en, legacy: tune.habitToRemove)
        let (dStopHe, dStopEn) = biStr(he: dir.stop_he, en: dir.stop_en, legacy: dir.stop)
        let (dStartHe, dStartEn) = biStr(he: dir.start_he, en: dir.start_en, legacy: dir.start)
        let (dWatchHe, dWatchEn) = biStr(he: dir.watch_he, en: dir.watch_en, legacy: dir.watch)
        let (sumHe, sumEn) = biStr(he: json.forecast_he, en: json.forecast_en, legacy: json.forecast)
        let (eTextHe, eTextEn) = biStr(he: json.energyForecast?.text_he, en: json.energyForecast?.text_en, legacy: nil)
        let homeRec = biStr(he: json.homeRecommendations?.medical_he, en: json.homeRecommendations?.medical_en, legacy: json.homeRecommendations?.medical)
        let homeSports = biStr(he: json.homeRecommendations?.sports_he, en: json.homeRecommendations?.sports_en, legacy: json.homeRecommendations?.sports)
        let homeNutrition = biStr(he: json.homeRecommendations?.nutrition_he, en: json.homeRecommendations?.nutrition_en, legacy: json.homeRecommendations?.nutrition)

        return CarAnalysisResponse(
            carModelHe: modelHe, carModelEn: modelEn,
            carExplanationHe: explHe, carExplanationEn: explEn,
            carImageURL: "",
            carWikiName: carIdentity.wikiName,

            engineHe: engineHe, engineEn: engineEn,
            transmissionHe: transHe, transmissionEn: transEn,
            suspensionHe: suspHe, suspensionEn: suspEn,
            fuelEfficiencyHe: fuelHe, fuelEfficiencyEn: fuelEn,
            electronicsHe: elecHe, electronicsEn: elecEn,

            bottlenecksHe: bnHe, bottlenecksEn: bnEn,
            warningSignals: [],

            upgradesHe: upgHe, upgradesEn: upgEn,
            skippedMaintenanceHe: skipHe, skippedMaintenanceEn: skipEn,
            stopImmediatelyHe: stopHe, stopImmediatelyEn: stopEn,

            trainingAdjustmentsHe: trainHe, trainingAdjustmentsEn: trainEn,
            recoveryChangesHe: recHe, recoveryChangesEn: recEn,
            habitToAddHe: addHe, habitToAddEn: addEn,
            habitToRemoveHe: remHe, habitToRemoveEn: remEn,

            directiveStopHe: dStopHe, directiveStopEn: dStopEn,
            directiveStartHe: dStartHe, directiveStartEn: dStartEn,
            directiveWatchHe: dWatchHe, directiveWatchEn: dWatchEn,

            summaryHe: sumHe, summaryEn: sumEn,

            supplements: supplements,

            energyForecastTextHe: eTextHe, energyForecastTextEn: eTextEn,
            energyForecastTrend: json.energyForecast?.trend ?? "stable",

            scores: json.scores,

            homeRecommendationMedicalHe: homeRec.0, homeRecommendationMedicalEn: homeRec.1,
            homeRecommendationSportsHe: homeSports.0, homeRecommendationSportsEn: homeSports.1,
            homeRecommendationNutritionHe: homeNutrition.0, homeRecommendationNutritionEn: homeNutrition.1,

            weeklyGoals: json.weeklyGoals?.goals ?? [],
            weeklyGoalsShouldGenerate: json.weeklyGoals?.shouldGenerateNewGoals ?? true,
            weeklyGoalsProgressAssessmentHe: json.weeklyGoals?.progressAssessment_he ?? "",
            weeklyGoalsProgressAssessmentEn: json.weeklyGoals?.progressAssessment_en ?? "",

            rawResponse: rawResponse
        )
    }

    // MARK: - Main Parse Function

    static func parse(_ response: String) -> CarAnalysisResponse {
        // First attempt: structured JSON
        if let jsonResult = parseJSON(response) {
            return jsonResult
        }

        return parseLegacy(response)
    }

    // MARK: - Legacy Regex-Based Parsing (Fallback)

    private static func parseLegacy(_ response: String) -> CarAnalysisResponse {
        // Legacy parser - uses same value for both Hebrew and English
        // (since legacy format only has one language)

        let carModel = extractCarModel(from: response)
        let carExplanation = extractCarExplanation(from: response)
        let carWikiName = extractCarWikiName(from: response)

        let engine = extractPerformanceSection(from: response, sectionName: "מנוע", nextSections: ["תיבת הילוכים", "Transmission", "TRANSMISSION"])
        let transmission = extractPerformanceSection(from: response, sectionName: "תיבת הילוכים", nextSections: ["מתלים", "Suspension", "SUSPENSION"])
        let suspension = extractPerformanceSection(from: response, sectionName: "מתלים", nextSections: ["יעילות דלק", "Fuel Efficiency", "FUEL"])
        let fuelEfficiency = extractPerformanceSection(from: response, sectionName: "יעילות דלק", nextSections: ["אלקטרוניקה", "Electronics", "ELECTRONICS"])
        let electronics = extractPerformanceSection(from: response, sectionName: "אלקטרוניקה", nextSections: ["3.", "מה מגביל", "What limits", "BOTTLENECK"])

        let bottlenecks = extractBottlenecks(from: response)
        let warningSignals = extractWarningSignals(from: response)

        let upgrades = extractListItems(from: response, sectionMarkers: ["UPGRADES", "שדרוגים", "Upgrades", "upgrades"])
        let skippedMaintenance = extractListItems(from: response, sectionMarkers: ["MAINTENANCE", "טיפול אני מדלג", "Maintenance I'm skipping", "maintenance"])
        let stopImmediately = extractListItems(from: response, sectionMarkers: ["STOP IMMEDIATELY", "להפסיק לעשות מיד", "Stop doing immediately", "stop doing immediately"])

        let trainingAdjustments = extractSection(from: response, markers: ["TRAINING ADJUSTMENTS", "Training adjustments", "התאמות אימון", "**התאמות אימון**", "התאמות אימון:", "**Training adjustments**", "Training adjustments:"])
        let recoveryChanges = extractSection(from: response, markers: ["RECOVERY CHANGES", "Recovery changes", "שינויים בהתאוששות", "**שינויים בהתאוששות ושינה**", "שינויים בהתאוששות", "**Recovery and sleep changes**", "Recovery and sleep changes"])
        let habitToAdd = extractSection(from: response, markers: ["HABIT TO ADD", "Habit to add", "הרגל להוסיף", "**הרגל אחד בעל השפעה גבוהה להוסיף**", "הרגל אחד להוסיף:", "הרגל להוסיף:", "**One high-impact habit to add**", "One habit to add:", "Habit to add:"])
        let habitToRemove = extractSection(from: response, markers: ["HABIT TO REMOVE", "Habit to remove", "הרגל להסיר", "**הרגל אחד להסיר**", "הרגל אחד להסיר:", "הרגל להסיר:", "**One habit to remove**", "One habit to remove:", "Habit to remove:"])

        let directives = extractDirectives(from: response)
        let summary = extractSummary(from: response)
        let supplements = extractSupplements(from: response)

        return CarAnalysisResponse(
            // For legacy, use same value for both languages
            carModelHe: carModel,
            carModelEn: carModel,
            carExplanationHe: carExplanation,
            carExplanationEn: carExplanation,
            carImageURL: "",
            carWikiName: carWikiName,

            engineHe: engine,
            engineEn: engine,
            transmissionHe: transmission,
            transmissionEn: transmission,
            suspensionHe: suspension,
            suspensionEn: suspension,
            fuelEfficiencyHe: fuelEfficiency,
            fuelEfficiencyEn: fuelEfficiency,
            electronicsHe: electronics,
            electronicsEn: electronics,

            bottlenecksHe: bottlenecks,
            bottlenecksEn: bottlenecks,
            warningSignals: warningSignals,

            upgradesHe: upgrades,
            upgradesEn: upgrades,
            skippedMaintenanceHe: skippedMaintenance,
            skippedMaintenanceEn: skippedMaintenance,
            stopImmediatelyHe: stopImmediately,
            stopImmediatelyEn: stopImmediately,

            trainingAdjustmentsHe: trainingAdjustments,
            trainingAdjustmentsEn: trainingAdjustments,
            recoveryChangesHe: recoveryChanges,
            recoveryChangesEn: recoveryChanges,
            habitToAddHe: habitToAdd,
            habitToAddEn: habitToAdd,
            habitToRemoveHe: habitToRemove,
            habitToRemoveEn: habitToRemove,

            directiveStopHe: directives.stop,
            directiveStopEn: directives.stop,
            directiveStartHe: directives.start,
            directiveStartEn: directives.start,
            directiveWatchHe: directives.watch,
            directiveWatchEn: directives.watch,

            summaryHe: summary,
            summaryEn: summary,

            supplements: supplements,

            // Energy Forecast (not available in legacy format)
            energyForecastTextHe: "",
            energyForecastTextEn: "",
            energyForecastTrend: "stable",

            scores: nil,

            homeRecommendationMedicalHe: "", homeRecommendationMedicalEn: "",
            homeRecommendationSportsHe: "", homeRecommendationSportsEn: "",
            homeRecommendationNutritionHe: "", homeRecommendationNutritionEn: "",

            weeklyGoals: [],
            weeklyGoalsShouldGenerate: true,
            weeklyGoalsProgressAssessmentHe: "",
            weeklyGoalsProgressAssessmentEn: "",

            rawResponse: response
        )
    }

    // MARK: - Extraction Helpers

    private static func extractCarModel(from text: String) -> String {
        // Keywords that must not be the car name
        let blacklist = ["stop", "start", "watch", "מנוע", "engine", "תיבת", "transmission", "מתלים", "suspension", "יעילות", "fuel efficiency", "אלקטרוניקה", "electronics", "סיכום", "summary", "הנחיות", "directives", "סקירת", "review", "חשוב", "important", "כתוב", "write", "car_wiki", "generation", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth", "model", "version", "type", "series"]

        // First - search in section 1 only
        var section1 = ""
        let sectionMarkers = ["1. איזה רכב אני", "איזה רכב אני", "1. Which car am I", "Which car am I", "## 1", "WHICH CAR AM I", "הרכב שאני", "The car that I"]
        for marker in sectionMarkers {
            if let sectionStart = text.range(of: marker, options: .caseInsensitive) {
                let after = String(text[sectionStart.upperBound...])
                // Find the end of the section
                let endMarkers = ["2. סקירת", "2. Performance", "## 2", "סקירת ביצועים", "Performance review", "PERFORMANCE REVIEW"]
                for endMarker in endMarkers {
                    if let sectionEnd = after.range(of: endMarker, options: .caseInsensitive) {
                        section1 = String(after[..<sectionEnd.lowerBound])
                        break
                    }
                }
                if section1.isEmpty {
                    section1 = String(after.prefix(600))
                }
                break
            }
        }

        // First - search for English car name from the CAR_WIKI tag (most reliable!)
        // Search manually to avoid calling another function
        let wikiPatterns = [
            #"\[CAR_WIKI:\s*([^\]\n]+)\]"#,
            #"CAR_WIKI:\s*([^\]\n]+)"#,
        ]
        for pattern in wikiPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                var wikiCarName = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove parentheses with generation info etc.
                if let parenStart = wikiCarName.firstIndex(of: "(") {
                    wikiCarName = String(wikiCarName[..<parenStart]).trimmingCharacters(in: .whitespaces)
                }
                if !wikiCarName.isEmpty && wikiCarName.count > 3 && !wikiCarName.hasPrefix("http") {
                    return wikiCarName
                }
            }
        }

        // Patterns for identifying the car name
        let searchTexts = section1.isEmpty ? [text] : [section1, text]

        for searchText in searchTexts {
            let patterns = [
                // New format - car name on separate line after heading
                // e.g. "Porsche Taycan" or Hebrew equivalent
                #"עכשיו\??\s*\n+([^\n\[]+)\s*\("#,
                #"עכשיו\??\s*\n+([א-ת\s]+)\s*\(([A-Za-z\s]+)\)"#,
                #"now\??\s*\n+([^\n\[]+)\s*\("#,
                // English car name in parentheses
                #"\(([A-Z][a-z]+\s+[A-Za-z0-9\s\-]+)\)"#,
                // Format "You are currently like X:" (Hebrew)
                #"אתה כרגע כמו\s+([^:]+):"#,
                #"אתה כרגע\s+([A-Za-z][A-Za-z0-9\s\-]+[A-Za-z0-9])"#,
                #"אתה\s+([A-Za-z][A-Za-z0-9\s\-]+[A-Za-z0-9])"#,
                // Format "You are currently like X:" (English)
                #"You are currently like\s+([^:]+):"#,
                #"You are currently\s+([A-Za-z][A-Za-z0-9\s\-]+[A-Za-z0-9])"#,
                #"You are\s+a\s+([A-Za-z][A-Za-z0-9\s\-]+[A-Za-z0-9])"#,
                // Old format with markdown (Hebrew)
                #"אתה כרגע\s+\*\*([^*]+)\*\*"#,
                #"אתה כרגע כמו\s+\*\*([^*]+)\*\*"#,
                // Old format with markdown (English)
                #"You are currently\s+\*\*([^*]+)\*\*"#,
                #"You are currently like\s+\*\*([^*]+)\*\*"#,
                #"\*\*([^*\n]{4,50})\*\*"#,
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: searchText, options: [], range: NSRange(searchText.startIndex..., in: searchText)),
                   let range = Range(match.range(at: 1), in: searchText) {
                    var carName = String(searchText[range])
                        .replacingOccurrences(of: "**", with: "")
                        .replacingOccurrences(of: "[CAR_WIKI:", with: "")
                        .replacingOccurrences(of: "[CAR_WIKI]", with: "")
                        .replacingOccurrences(of: "CAR_WIKI:", with: "")
                        .replacingOccurrences(of: "CAR_WIKI", with: "")
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    // Remove trailing period, colon or parenthesis
                    while carName.hasSuffix(".") || carName.hasSuffix(":") {
                        carName = String(carName.dropLast()).trimmingCharacters(in: .whitespaces)
                    }

                    // Filter out blacklisted keywords
                    let lower = carName.lowercased()
                    let isBlacklisted = blacklist.contains { lower.hasPrefix($0) || lower == $0 }

                    if !isBlacklisted && !carName.isEmpty && carName.count > 2 && carName.count < 60 {
                        return carName
                    }
                }
            }
        }

        // Fallback: try to find car name from CAR_WIKI tag
        let wikiName = extractCarWikiName(from: text)
        if !wikiName.isEmpty {
            return wikiName
        }

        return "Unidentified vehicle"
    }

    private static func extractCarExplanation(from text: String) -> String {
        // Attempt 1: search for explicit section 1
        var section1 = ""
        let startMarkers = ["1. איזה רכב אני", "איזה רכב אני", "1. Which car am I", "Which car am I", "## 1"]
        for startMarker in startMarkers {
            if let sectionStart = text.range(of: startMarker, options: .caseInsensitive) {
                let after = String(text[sectionStart.upperBound...])
                let endMarkers = ["2. סקירת", "2. Performance", "## 2", "## 3", "סקירת ביצועים מלאה", "Full performance review", "מנוע\n", "Engine\n"]
                var endIdx = after.endIndex
                for endMarker in endMarkers {
                    if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx {
                        endIdx = r.lowerBound
                    }
                }
                section1 = String(after[..<endIdx])
                break
            }
        }

        // Attempt 2: new format - text starts with car name, then CAR_WIKI, then the explanation
        if section1.isEmpty {
            // Search for the text after the CAR_WIKI line until "Performance review"
            if let wikiEnd = text.range(of: "[CAR_WIKI:", options: .caseInsensitive) {
                // Find the end of the CAR_WIKI line
                let afterWiki = String(text[wikiEnd.upperBound...])
                if let closeBracket = afterWiki.firstIndex(of: "]") {
                    let afterTag = String(afterWiki[afterWiki.index(after: closeBracket)...])
                    // Find the end of the section
                    let endMarkers = ["סקירת ביצועים", "Performance review", "מנוע\n", "Engine\n", "2.", "## 2"]
                    var endIdx = afterTag.endIndex
                    for endMarker in endMarkers {
                        if let r = afterTag.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx {
                            endIdx = r.lowerBound
                        }
                    }
                    section1 = String(afterTag[..<endIdx])
                }
            }
        }

        // Attempt 3: take the first 2-3 lines after the name line
        if section1.isEmpty || section1.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
            let lines = text.components(separatedBy: "\n")
            var explanationLines: [String] = []
            var skipCount = 0
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                // Skip the name line and CAR_WIKI line
                if trimmed.contains("[CAR_WIKI") || trimmed.contains("CAR_WIKI:") {
                    skipCount += 1
                    continue
                }
                if skipCount == 0 && (trimmed.count < 50 || !trimmed.contains(" ")) {
                    // This is probably the car name line
                    skipCount += 1
                    continue
                }
                // Stop when reaching performance review
                if trimmed.contains("סקירת ביצועים") || trimmed.contains("Performance review") || trimmed.hasPrefix("מנוע") || trimmed.hasPrefix("Engine") {
                    break
                }
                if skipCount > 0 {
                    explanationLines.append(trimmed)
                    if explanationLines.count >= 3 { break }
                }
            }
            if !explanationLines.isEmpty {
                section1 = explanationLines.joined(separator: " ")
            }
        }

        var explanation = section1

        // Search for the sentence starting with "You are currently like" if present
        if let explStart = explanation.range(of: "אתה כרגע כמו", options: .caseInsensitive) {
            explanation = String(explanation[explStart.lowerBound...])
        } else if let explStart = explanation.range(of: "You are currently like", options: .caseInsensitive) {
            explanation = String(explanation[explStart.lowerBound...])
        } else if let explStart = explanation.range(of: "אתה כרגע", options: .caseInsensitive) {
            explanation = String(explanation[explStart.lowerBound...])
        } else if let explStart = explanation.range(of: "You are currently", options: .caseInsensitive) {
            explanation = String(explanation[explStart.lowerBound...])
        }

        // Cleanup
        explanation = explanation
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "[CAR_WIKI:", with: "")
            .replacingOccurrences(of: "[CAR_WIKI]", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove remnants from section header
        let headerRemnants = ["עכשיו?", "עכשיו", "now?", "now", "?"]
        for remnant in headerRemnants {
            if explanation.hasPrefix(remnant) {
                explanation = String(explanation.dropFirst(remnant.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Remove other tags (URL etc.)
        explanation = removeImageURL(from: explanation)

        return explanation
    }

    /// Removes image links and metadata tags from text
    private static func removeImageURL(from text: String) -> String {
        var result = text
        // Remove various URL and tag formats
        let patterns = [
            #"\[CAR_IMAGE_URL:\s*https?://[^\]\s]+\]"#,
            #"CAR_IMAGE_URL:\s*https?://[^\s\]\n]+"#,
            #"\[CAR_WIKI:\s*[^\]]+\]"#,
            #"CAR_WIKI:\s*[^\n]+"#,
            #"https://upload\.wikimedia\.org/wikipedia/commons/[^\s\]\n]+"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        // Clean up double spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractCarWikiName(from text: String) -> String {
        // Search for car name in English in [CAR_WIKI: ...] format
        let patterns = [
            #"\[CAR_WIKI:\s*([^\]\n]+)\]"#,
            #"CAR_WIKI:\s*([^\]\n]+)"#,
            #"\[CAR_IMAGE_URL:\s*([^\]\n]+)\]"#,  // backward compat
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                var name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)

                // Remove parentheses with generation/version info - e.g. "(eighth generation)"
                if let parenStart = name.firstIndex(of: "(") {
                    name = String(name[..<parenStart]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                if !name.isEmpty && !name.hasPrefix("http") {
                    return name
                }
            }
        }

        // Fallback: try to extract English name from car model
        let engPatterns = [
            #"\(([A-Za-z][A-Za-z0-9\s\-\.]+)\)"#,  // text in parentheses like (Subaru Forester)
            #"([A-Z][a-z]+(?:\s+[A-Za-z0-9\-]+)+)"#  // consecutive English words like Subaru Forester
        ]

        for pattern in engPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if name.count >= 5 && name.count < 50 {
                    return name
                }
            }
        }

        return ""
    }

    /// Extracts performance section content (Engine, Transmission, etc.)
    /// The section name appears on its own line, and content follows on the NEXT line(s)
    private static func extractPerformanceSection(from text: String, sectionName: String, nextSections: [String]) -> String {
        // Find the section header - it can be on its own line or with ** markers
        let patterns = [
            // Header on its own line (new format)
            "(?:^|\\n)\\s*\(sectionName)\\s*\\n",
            // Header with ** markers (old format)
            "\\*\\*\(sectionName)\\*\\*",
            // Header followed by colon
            "\(sectionName):",
            "\(sectionName) \\("
        ]

        var startIdx: String.Index? = nil
        var afterHeader = ""

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                startIdx = range.upperBound
                afterHeader = String(text[range.upperBound...])
                break
            }
        }

        // Fallback: simple string search
        if startIdx == nil {
            if let range = text.range(of: sectionName + "\n", options: .caseInsensitive) {
                afterHeader = String(text[range.upperBound...])
            } else if let range = text.range(of: sectionName, options: .caseInsensitive) {
                // Skip to the end of the line containing the section name
                let remaining = String(text[range.upperBound...])
                if let newlineIdx = remaining.firstIndex(of: "\n") {
                    afterHeader = String(remaining[remaining.index(after: newlineIdx)...])
                } else {
                    afterHeader = remaining
                }
            }
        }

        if afterHeader.isEmpty {
            return ""
        }

        // Find where the next section starts
        var endIdx = afterHeader.endIndex

        // Check for next sections
        for nextSection in nextSections {
            // Look for section header on its own line
            let nextPatterns = [
                "(?:^|\\n)\\s*\(nextSection)\\s*\\n",
                "\\*\\*\(nextSection)\\*\\*",
                "\(nextSection):"
            ]

            for pattern in nextPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: afterHeader, options: [], range: NSRange(afterHeader.startIndex..., in: afterHeader)),
                   let range = Range(match.range, in: afterHeader),
                   range.lowerBound < endIdx {
                    endIdx = range.lowerBound
                }
            }

            // Simple search fallback
            if let r = afterHeader.range(of: "\n" + nextSection, options: .caseInsensitive), r.lowerBound < endIdx {
                endIdx = r.lowerBound
            }
        }

        // Also check for section numbers and other markers
        let genericEndMarkers = ["\n3.", "\n4.", "\n5.", "\n6.", "\n7.", "## ", "---", "\n\n\n"]
        for endMarker in genericEndMarkers {
            if let r = afterHeader.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx && r.lowerBound != afterHeader.startIndex {
                endIdx = r.lowerBound
            }
        }

        var content = String(afterHeader[..<endIdx])

        // Clean up the content
        content = content
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading punctuation that might be left over from header
        while content.hasPrefix(")") || content.hasPrefix(":") || content.hasPrefix("(") {
            content = String(content.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        return content
    }

    private static func extractSection(from text: String, markers: [String]) -> String {
        for marker in markers {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                let after = String(text[range.upperBound...])
                // Find the end of the section (until next section or double empty line)
                // Supports both old markdown format and new ALL CAPS format
                let endMarkers = [
                    // New format - ALL CAPS / Hebrew on separate line
                    "\n\nמנוע\n", "\n\nתיבת הילוכים\n", "\n\nמתלים\n", "\n\nיעילות דלק\n", "\n\nאלקטרוניקה\n",
                    "\nמנוע\n", "\nתיבת הילוכים\n", "\nמתלים\n", "\nיעילות דלק\n", "\nאלקטרוניקה\n",
                    // English equivalents on separate line
                    "\n\nEngine\n", "\n\nTransmission\n", "\n\nSuspension\n", "\n\nFuel Efficiency\n", "\n\nElectronics\n",
                    "\nEngine\n", "\nTransmission\n", "\nSuspension\n", "\nFuel Efficiency\n", "\nElectronics\n",
                    "\nENGINE\n", "\nTRANSMISSION\n", "\nSUSPENSION\n", "\nFUEL", "\nELECTRONICS\n",
                    // Hebrew tune-up section markers
                    "\n\nהתאמות אימון\n", "\n\nשינויים בהתאוששות", "\n\nהרגל אחד", "\n\nהרגל להוסיף", "\n\nהרגל להסיר",
                    "\nהתאמות אימון\n", "\nשינויים בהתאוששות", "\nהרגל אחד", "\nהרגל להוסיף", "\nהרגל להסיר",
                    // English tune-up section markers
                    "\n\nTraining adjustments\n", "\n\nRecovery changes", "\n\nOne habit", "\n\nHabit to add", "\n\nHabit to remove",
                    "\nTraining adjustments\n", "\nRecovery changes", "\nOne habit", "\nHabit to add", "\nHabit to remove",
                    // Sections that come after habit to remove
                    "\n\nSTOP", "\n\nSTART", "\n\nWATCH", "\nSTOP\n", "\nSTART\n", "\nWATCH\n",
                    "\n\nסיכום", "\nסיכום\n", "\n\nSummary", "\nSummary\n", "\nSUMMARY\n", "\n\nSUMMARY",
                    "\n\nהנחיות פעולה", "\nהנחיות פעולה\n", "\n\nAction directives", "\nAction directives\n",
                    "\n\nתוספי תזונה", "\nתוספי תזונה\n", "\n\nSupplements", "\nSupplements\n", "\n\nSUPPLEMENTS", "\nSUPPLEMENTS\n",
                    // Section numbers
                    "\n3.", "\n4.", "\n5.", "\n6.", "\n7.", "\n8.", "תוספי תזונה", "Supplements",
                    // Old format - markdown (Hebrew)
                    "**מנוע**", "**תיבת הילוכים**", "**מתלים**", "**יעילות דלק**", "**אלקטרוניקה**",
                    "**התאמות אימון**", "**שינויים בהתאוששות**", "**הרגל אחד בעל השפעה**", "**הרגל אחד להסיר**",
                    "הרגל אחד להסיר:", "הרגל להסיר:", "הרגל אחד להוסיף:",
                    "**סיכום**", "**הנחיות פעולה**", "**תוספי תזונה**",
                    // Old format - markdown (English)
                    "**Engine**", "**Transmission**", "**Suspension**", "**Fuel Efficiency**", "**Electronics**",
                    "**Training adjustments**", "**Recovery changes**", "**One high-impact habit**", "**One habit to remove**",
                    "One habit to remove:", "Habit to remove:", "One habit to add:",
                    "**Summary**", "**Action directives**", "**Supplements**",
                    "## ", "---", "\n\n\n"
                ]
                var endIdx = after.endIndex
                for endMarker in endMarkers {
                    if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx && r.lowerBound != after.startIndex {
                        endIdx = r.lowerBound
                    }
                }
                var content = String(after[..<endIdx])

                // Remove first newline if present
                content = content.trimmingCharacters(in: .newlines)

                // Remove leading marker if present - only if it's near the start
                if content.hasPrefix(")") {
                    content = String(content.dropFirst())
                } else if content.hasPrefix(":") {
                    content = String(content.dropFirst())
                }

                return content
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private static func extractBottlenecks(from text: String) -> [String] {
        let markers = ["3. מה מגביל", "3. What limits", "מה מגביל את הביצועים", "What limits the performance", "צווארי בקבוק", "Bottlenecks", "bottlenecks", "צוואר בקבוק"]

        // First try to extract as list items
        let listItems = extractListItems(from: text, sectionMarkers: markers)
        if !listItems.isEmpty {
            return listItems
        }

        // If no list items found, extract as paragraph text
        for marker in markers {
            guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }

            var after = String(text[range.upperBound...])

            // Skip past the rest of the header line (e.g., "now?")
            // The actual content starts on the NEXT line
            if let firstNewline = after.firstIndex(of: "\n") {
                after = String(after[after.index(after: firstNewline)...])
            }

            // Find end of section
            let endMarkers = ["4. תוכנית", "4. Optimization", "## 4", "תוכנית אופטימיזציה", "Optimization plan", "אילו שדרוגים", "Which upgrades", "סימני אזהרה", "Warning signs", "---", "\n\n\n"]
            var endIdx = after.endIndex
            for endMarker in endMarkers {
                if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx && r.lowerBound != after.startIndex {
                    endIdx = r.lowerBound
                }
            }

            var content = String(after[..<endIdx])
            // Clean up the content
            content = content
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove any leftover header text like "What limits the performance now?"
            if content.hasPrefix("מה מגביל") || content.hasPrefix("What limits") {
                if let questionMark = content.firstIndex(of: "?") {
                    content = String(content[content.index(after: questionMark)...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Split by sentences if long enough
            if content.count > 20 {
                // Split by periods, keeping meaningful sentences
                let sentences = content.components(separatedBy: ".")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { sentence in
                        // Filter out short sentences and leftover header text
                        guard sentence.count > 15 else { return false }
                        // Filter out the repeated question "What limits the performance now"
                        if sentence.contains("מה מגביל את הביצועים") { return false }
                        if sentence.contains("What limits the performance") { return false }
                        return true
                    }

                if !sentences.isEmpty {
                    return sentences.map { $0 + "." }
                }

                // Fallback: return the whole content as single item if it doesn't contain the question
                if !content.contains("מה מגביל את הביצועים") && !content.contains("What limits the performance") {
                    return [content]
                }
            }
        }

        return []
    }

    private static func extractWarningSignals(from text: String) -> [String] {
        let markers = ["סימן אזהרה", "Warning sign", "סימני אזהרה", "Warning signs", "warning signs", "אזהרה מוקדם", "Early warning"]
        return extractListItems(from: text, sectionMarkers: markers)
    }

    private static func extractListItems(from text: String, sectionMarkers: [String]) -> [String] {
        var items: [String] = []

        for marker in sectionMarkers {
            guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }

            let after = String(text[range.upperBound...])
            // Find the end of the section
            let endMarkers = ["## ", "---", "\n\n\n", "**", "תוכנית", "Plan"]
            var endIdx = after.endIndex
            for endMarker in endMarkers {
                if let r = after.range(of: endMarker), r.lowerBound < endIdx && r.lowerBound != after.startIndex {
                    endIdx = r.lowerBound
                }
            }

            let section = String(after[..<endIdx])
            let lines = section.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Check if this is a list item
                if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") ||
                   trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil {
                    var item = trimmed
                    // Remove the marker
                    item = item.replacingOccurrences(of: #"^[-•*]\s*"#, with: "", options: .regularExpression)
                    item = item.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                    item = item.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                    if !item.isEmpty && item.count > 5 {
                        items.append(item)
                    }
                }
            }

            if !items.isEmpty { break }
        }

        return items
    }

    private static func extractDirectives(from text: String) -> (stop: String, start: String, watch: String) {
        var stop = ""
        var start = ""
        var watch = ""

        // STOP - supports new ALL CAPS format and old markdown format
        let stopPatterns = [
            #"STOP\s*\n+([^\n]+)"#,           // ALL CAPS on separate line
            #"STOP:\s*([^\n]+)"#,              // STOP: on one line
            #"\*\*STOP:\*\*\s*([^\n]+)"#,      // markdown
            #"עצור\s*\n+([^\n]+)"#,            // Hebrew "Stop"
            #"עצור:\s*([^\n]+)"#,              // Hebrew "Stop:"
            #"Stop\s*\n+([^\n]+)"#,            // English "Stop"
            #"Stop:\s*([^\n]+)"#,              // English "Stop:"
        ]
        for pattern in stopPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                stop = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !stop.isEmpty { break }
            }
        }

        // START - supports new ALL CAPS format and old markdown format
        let startPatterns = [
            #"START\s*\n+([^\n]+)"#,           // ALL CAPS on separate line
            #"START:\s*([^\n]+)"#,              // START: on one line
            #"\*\*START:\*\*\s*([^\n]+)"#,      // markdown
            #"התחל\s*\n+([^\n]+)"#,             // Hebrew "Start"
            #"התחל:\s*([^\n]+)"#,               // Hebrew "Start:"
            #"Start\s*\n+([^\n]+)"#,            // English "Start"
            #"Start:\s*([^\n]+)"#,              // English "Start:"
        ]
        for pattern in startPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                start = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !start.isEmpty { break }
            }
        }

        // WATCH - supports new ALL CAPS format and old markdown format
        let watchPatterns = [
            #"WATCH\s*\n+([^\n]+)"#,           // ALL CAPS on separate line
            #"WATCH:\s*([^\n]+)"#,              // WATCH: on one line
            #"\*\*WATCH:\*\*\s*([^\n]+)"#,      // markdown
            #"עקוב\s*\n+([^\n]+)"#,             // Hebrew "Watch/Follow"
            #"עקוב:\s*([^\n]+)"#,               // Hebrew "Watch/Follow:"
            #"Watch\s*\n+([^\n]+)"#,            // English "Watch"
            #"Watch:\s*([^\n]+)"#,              // English "Watch:"
        ]
        for pattern in watchPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                watch = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !watch.isEmpty { break }
            }
        }

        return (stop, start, watch)
    }

    private static func extractSummary(from text: String) -> String {
        // Supports new ALL CAPS format and old format
        let markers = [
            "SUMMARY", "Summary", "סיכום", "## 7. סיכום", "## 7. Summary", "**סיכום**", "**Summary**", "סיכום:", "Summary:",
            "אם הרכב הזה ימשיך", "If this car continues", "BOTTOM LINE", "Bottom line"
        ]

        for marker in markers {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                let after = String(text[range.upperBound...])
                // Take until end of text or until end marker
                let endMarkers = ["---", "###", "\n\n\n", "## 8", "תוספי תזונה", "Supplements"]
                var endIdx = after.endIndex
                for endMarker in endMarkers {
                    if let r = after.range(of: endMarker), r.lowerBound < endIdx {
                        endIdx = r.lowerBound
                    }
                }
                let summary = String(after[..<endIdx])
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !summary.isEmpty {
                    return summary
                }
            }
        }
        return ""
    }

    // MARK: - Supplements Extraction

    /// Extract supplement recommendations from Gemini response
    private static func extractSupplements(from text: String) -> [SupplementRecommendation] {
        var supplements: [SupplementRecommendation] = []

        // Search for "supplements" section
        let markers = ["תוספי תזונה מומלצים", "Recommended supplements", "המלצות תוספי תזונה", "Supplement recommendations", "## 8. תוספי תזונה", "## 8. Supplements", "SUPPLEMENTS", "Supplements", "תוספים מומלצים", "Recommended supplements"]

        for marker in markers {
            guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }

            let after = String(text[range.upperBound...])

            // Find the end of the section
            let endMarkers = ["---", "## 9", "###", "\n\n\n", "סיכום", "Summary", "SUMMARY"]
            var endIdx = after.endIndex
            for endMarker in endMarkers {
                if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx {
                    endIdx = r.lowerBound
                }
            }

            let section = String(after[..<endIdx])

            // Search for pattern: **name** (dosage) - reason [CATEGORY: xxx]
            let pattern = #"\*\*([^*]+)\*\*\s*\(([^)]+)\)\s*[-–]\s*([^\[]+)\[CATEGORY:\s*(\w+)\]"#

            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))

                for match in matches {
                    guard match.numberOfRanges >= 5,
                          let nameRange = Range(match.range(at: 1), in: section),
                          let dosageRange = Range(match.range(at: 2), in: section),
                          let reasonRange = Range(match.range(at: 3), in: section),
                          let categoryRange = Range(match.range(at: 4), in: section) else { continue }

                    let name = String(section[nameRange]).trimmingCharacters(in: .whitespaces)
                    let dosage = String(section[dosageRange]).trimmingCharacters(in: .whitespaces)
                    let reason = String(section[reasonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let categoryStr = String(section[categoryRange]).lowercased()

                    let category: SupplementCategory
                    switch categoryStr {
                    case "sleep": category = .sleep
                    case "performance": category = .performance
                    case "recovery": category = .recovery
                    default: category = .general
                    }

                    supplements.append(SupplementRecommendation(
                        name: name,
                        dosage: dosage,
                        reason: reason,
                        category: category
                    ))
                }
            }

            // If we didn't find with the exact format, try a simpler format
            if supplements.isEmpty {
                // Search for pattern: **name** (dosage) - reason
                let simplePattern = #"\*\*([^*]+)\*\*\s*\(([^)]+)\)\s*[-–]\s*([^\n]+)"#

                if let regex = try? NSRegularExpression(pattern: simplePattern, options: []) {
                    let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))

                    for match in matches {
                        guard match.numberOfRanges >= 4,
                              let nameRange = Range(match.range(at: 1), in: section),
                              let dosageRange = Range(match.range(at: 2), in: section),
                              let reasonRange = Range(match.range(at: 3), in: section) else { continue }

                        let name = String(section[nameRange]).trimmingCharacters(in: .whitespaces)
                        let dosage = String(section[dosageRange]).trimmingCharacters(in: .whitespaces)
                        var reason = String(section[reasonRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                        // Remove [CATEGORY:...] if present
                        if let catRange = reason.range(of: #"\[CATEGORY:[^\]]+\]"#, options: .regularExpression) {
                            reason = String(reason[..<catRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                        }

                        supplements.append(createSupplement(name: name, dosage: dosage, reason: reason))
                    }
                }
            }

            // Additional format: name (dosage) - reason (without **) or with bullets/numbers
            if supplements.isEmpty {
                // Search for: - name (dosage) - reason or 1. name (dosage) - reason
                let bulletPattern = #"(?:[-•]\s*|\d+\.\s*)([^(]+)\(([^)]+)\)\s*[-–:]\s*([^\n]+)"#

                if let regex = try? NSRegularExpression(pattern: bulletPattern, options: []) {
                    let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))

                    for match in matches {
                        guard match.numberOfRanges >= 4,
                              let nameRange = Range(match.range(at: 1), in: section),
                              let dosageRange = Range(match.range(at: 2), in: section),
                              let reasonRange = Range(match.range(at: 3), in: section) else { continue }

                        let name = String(section[nameRange])
                            .replacingOccurrences(of: "**", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        let dosage = String(section[dosageRange]).trimmingCharacters(in: .whitespaces)
                        let reason = String(section[reasonRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                        supplements.append(createSupplement(name: name, dosage: dosage, reason: reason))
                    }
                }
            }

            // Last format: name on separate line with dosage and reason
            if supplements.isEmpty {
                // Search for lines with structure: name\ndosage: xxx\nreason: xxx
                let lines = section.components(separatedBy: .newlines)
                var i = 0
                while i < lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    // If the line looks like a supplement name (short, no colons)
                    if line.count > 2 && line.count < 40 && !line.contains(":") && !line.hasPrefix("-") && !line.hasPrefix("•") {
                        let name = line.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                        var dosage = ""
                        var reason = ""

                        // Check following lines
                        for j in (i+1)..<min(i+4, lines.count) {
                            let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                            if nextLine.lowercased().hasPrefix("מינון") || nextLine.lowercased().hasPrefix("dosage") {
                                dosage = nextLine.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                            } else if nextLine.lowercased().hasPrefix("סיבה") || nextLine.lowercased().hasPrefix("reason") || nextLine.lowercased().hasPrefix("למה") || nextLine.lowercased().hasPrefix("why") {
                                reason = nextLine.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                            }
                        }

                        if !name.isEmpty && (!dosage.isEmpty || !reason.isEmpty) {
                            supplements.append(createSupplement(name: name, dosage: dosage.isEmpty ? "As directed" : dosage, reason: reason.isEmpty ? name : reason))
                            i += 3
                            continue
                        }
                    }
                    i += 1
                }
            }

            if !supplements.isEmpty { break }
        }

        return supplements
    }

    /// Helper function to create a supplement with automatic category detection
    private static func createSupplement(name: String, dosage: String, reason: String) -> SupplementRecommendation {
        let lowerReason = reason.lowercased()
        let lowerName = name.lowercased()

        let category: SupplementCategory
        // Match Hebrew and English keywords for category detection
        if lowerReason.contains("שינה") || lowerReason.contains("sleep") || lowerName.contains("מגנזיום") || lowerName.contains("magnesium") || lowerName.contains("melatonin") {
            category = .sleep
        } else if lowerReason.contains("אימון") || lowerReason.contains("training") || lowerReason.contains("ביצועים") || lowerReason.contains("performance") || lowerName.contains("קריאטין") || lowerName.contains("creatine") || lowerName.contains("beta-alanine") {
            category = .performance
        } else if lowerReason.contains("התאוששות") || lowerReason.contains("recovery") || lowerReason.contains("דלקת") || lowerReason.contains("inflammation") || lowerName.contains("אומגה") || lowerName.contains("omega") || lowerName.contains("turmeric") || lowerName.contains("כורכום") {
            category = .recovery
        } else {
            category = .general
        }

        return SupplementRecommendation(
            name: name,
            dosage: dosage,
            reason: reason,
            category: category
        )
    }
}
