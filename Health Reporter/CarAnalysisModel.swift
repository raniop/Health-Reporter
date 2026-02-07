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

    // Bilingual bottlenecks
    let bottlenecks_he: [String]
    let bottlenecks_en: [String]
    let bottlenecks: [String]?  // Legacy

    let optimizationPlan: OptimizationPlanJSON
    let tuneUpPlan: TuneUpPlanJSON
    let directives: DirectivesJSON

    // Bilingual forecast/summary
    let forecast_he: String
    let forecast_en: String
    let forecast: String?  // Legacy

    // Energy Forecast (optional - new field)
    let energyForecast: EnergyForecastJSON?

    let supplements: [SupplementJSON]
}

struct EnergyForecastJSON: Codable {
    let text_he: String
    let text_en: String
    let trend: String  // "rising", "falling", "stable"
}

struct CarIdentityJSON: Codable {
    // Bilingual fields
    let model_he: String
    let model_en: String
    let wikiName: String
    let explanation_he: String
    let explanation_en: String

    // Backward compatibility - single language fields (legacy)
    let model: String?
    let explanation: String?
}

struct PerformanceReviewJSON: Codable {
    // Bilingual fields
    let engine_he: String
    let engine_en: String
    let transmission_he: String
    let transmission_en: String
    let suspension_he: String
    let suspension_en: String
    let fuelEfficiency_he: String
    let fuelEfficiency_en: String
    let electronics_he: String
    let electronics_en: String

    // Backward compatibility - single language fields (legacy)
    let engine: String?
    let transmission: String?
    let suspension: String?
    let fuelEfficiency: String?
    let electronics: String?
}

struct OptimizationPlanJSON: Codable {
    // Bilingual fields
    let upgrades_he: [String]
    let upgrades_en: [String]
    let skippedMaintenance_he: [String]
    let skippedMaintenance_en: [String]
    let stopImmediately_he: [String]
    let stopImmediately_en: [String]

    // Backward compatibility - single language fields (legacy)
    let upgrades: [String]?
    let skippedMaintenance: [String]?
    let stopImmediately: [String]?
}

struct TuneUpPlanJSON: Codable {
    // Bilingual fields
    let trainingAdjustments_he: String
    let trainingAdjustments_en: String
    let recoveryChanges_he: String
    let recoveryChanges_en: String
    let habitToAdd_he: String
    let habitToAdd_en: String
    let habitToRemove_he: String
    let habitToRemove_en: String

    // Backward compatibility - single language fields (legacy)
    let trainingAdjustments: String?
    let recoveryChanges: String?
    let habitToAdd: String?
    let habitToRemove: String?
}

struct DirectivesJSON: Codable {
    // Bilingual fields
    let stop_he: String
    let stop_en: String
    let start_he: String
    let start_en: String
    let watch_he: String
    let watch_en: String

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

                let nameHe = s["name_he"] as? String ?? s["name"] as? String ?? ""
                let nameEn = s["name_en"] as? String ?? s["englishName"] as? String ?? s["name"] as? String ?? ""
                let dosageHe = s["dosage_he"] as? String ?? s["dosage"] as? String ?? ""
                let dosageEn = s["dosage_en"] as? String ?? s["dosage"] as? String ?? dosageHe
                let reasonHe = s["reason_he"] as? String ?? s["reason"] as? String ?? ""
                let reasonEn = s["reason_en"] as? String ?? s["reason"] as? String ?? ""

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

        return CarAnalysisResponse(
            carModelHe: str(carIdentity, "model_he").isEmpty ? str(carIdentity, "model") : str(carIdentity, "model_he"),
            carModelEn: str(carIdentity, "model_en").isEmpty ? str(carIdentity, "model") : str(carIdentity, "model_en"),
            carExplanationHe: str(carIdentity, "explanation_he").isEmpty ? str(carIdentity, "explanation") : str(carIdentity, "explanation_he"),
            carExplanationEn: str(carIdentity, "explanation_en").isEmpty ? str(carIdentity, "explanation") : str(carIdentity, "explanation_en"),
            carImageURL: "",
            carWikiName: str(carIdentity, "wikiName"),

            engineHe: str(performanceReview, "engine_he").isEmpty ? str(performanceReview, "engine") : str(performanceReview, "engine_he"),
            engineEn: str(performanceReview, "engine_en").isEmpty ? str(performanceReview, "engine") : str(performanceReview, "engine_en"),
            transmissionHe: str(performanceReview, "transmission_he").isEmpty ? str(performanceReview, "transmission") : str(performanceReview, "transmission_he"),
            transmissionEn: str(performanceReview, "transmission_en").isEmpty ? str(performanceReview, "transmission") : str(performanceReview, "transmission_en"),
            suspensionHe: str(performanceReview, "suspension_he").isEmpty ? str(performanceReview, "suspension") : str(performanceReview, "suspension_he"),
            suspensionEn: str(performanceReview, "suspension_en").isEmpty ? str(performanceReview, "suspension") : str(performanceReview, "suspension_en"),
            fuelEfficiencyHe: str(performanceReview, "fuelEfficiency_he").isEmpty ? str(performanceReview, "fuelEfficiency") : str(performanceReview, "fuelEfficiency_he"),
            fuelEfficiencyEn: str(performanceReview, "fuelEfficiency_en").isEmpty ? str(performanceReview, "fuelEfficiency") : str(performanceReview, "fuelEfficiency_en"),
            electronicsHe: str(performanceReview, "electronics_he").isEmpty ? str(performanceReview, "electronics") : str(performanceReview, "electronics_he"),
            electronicsEn: str(performanceReview, "electronics_en").isEmpty ? str(performanceReview, "electronics") : str(performanceReview, "electronics_en"),

            bottlenecksHe: strArr(json as [String: Any], "bottlenecks_he").isEmpty ? strArr(json as [String: Any], "bottlenecks") : strArr(json as [String: Any], "bottlenecks_he"),
            bottlenecksEn: strArr(json as [String: Any], "bottlenecks_en").isEmpty ? strArr(json as [String: Any], "bottlenecks") : strArr(json as [String: Any], "bottlenecks_en"),
            warningSignals: [],

            upgradesHe: strArr(optimizationPlan, "upgrades_he").isEmpty ? strArr(optimizationPlan, "upgrades") : strArr(optimizationPlan, "upgrades_he"),
            upgradesEn: strArr(optimizationPlan, "upgrades_en").isEmpty ? strArr(optimizationPlan, "upgrades") : strArr(optimizationPlan, "upgrades_en"),
            skippedMaintenanceHe: strArr(optimizationPlan, "skippedMaintenance_he").isEmpty ? strArr(optimizationPlan, "skippedMaintenance") : strArr(optimizationPlan, "skippedMaintenance_he"),
            skippedMaintenanceEn: strArr(optimizationPlan, "skippedMaintenance_en").isEmpty ? strArr(optimizationPlan, "skippedMaintenance") : strArr(optimizationPlan, "skippedMaintenance_en"),
            stopImmediatelyHe: strArr(optimizationPlan, "stopImmediately_he").isEmpty ? strArr(optimizationPlan, "stopImmediately") : strArr(optimizationPlan, "stopImmediately_he"),
            stopImmediatelyEn: strArr(optimizationPlan, "stopImmediately_en").isEmpty ? strArr(optimizationPlan, "stopImmediately") : strArr(optimizationPlan, "stopImmediately_en"),

            trainingAdjustmentsHe: str(tuneUpPlan, "trainingAdjustments_he").isEmpty ? str(tuneUpPlan, "trainingAdjustments") : str(tuneUpPlan, "trainingAdjustments_he"),
            trainingAdjustmentsEn: str(tuneUpPlan, "trainingAdjustments_en").isEmpty ? str(tuneUpPlan, "trainingAdjustments") : str(tuneUpPlan, "trainingAdjustments_en"),
            recoveryChangesHe: str(tuneUpPlan, "recoveryChanges_he").isEmpty ? str(tuneUpPlan, "recoveryChanges") : str(tuneUpPlan, "recoveryChanges_he"),
            recoveryChangesEn: str(tuneUpPlan, "recoveryChanges_en").isEmpty ? str(tuneUpPlan, "recoveryChanges") : str(tuneUpPlan, "recoveryChanges_en"),
            habitToAddHe: str(tuneUpPlan, "habitToAdd_he").isEmpty ? str(tuneUpPlan, "habitToAdd") : str(tuneUpPlan, "habitToAdd_he"),
            habitToAddEn: str(tuneUpPlan, "habitToAdd_en").isEmpty ? str(tuneUpPlan, "habitToAdd") : str(tuneUpPlan, "habitToAdd_en"),
            habitToRemoveHe: str(tuneUpPlan, "habitToRemove_he").isEmpty ? str(tuneUpPlan, "habitToRemove") : str(tuneUpPlan, "habitToRemove_he"),
            habitToRemoveEn: str(tuneUpPlan, "habitToRemove_en").isEmpty ? str(tuneUpPlan, "habitToRemove") : str(tuneUpPlan, "habitToRemove_en"),

            directiveStopHe: str(directives, "stop_he").isEmpty ? str(directives, "stop") : str(directives, "stop_he"),
            directiveStopEn: str(directives, "stop_en").isEmpty ? str(directives, "stop") : str(directives, "stop_en"),
            directiveStartHe: str(directives, "start_he").isEmpty ? str(directives, "start") : str(directives, "start_he"),
            directiveStartEn: str(directives, "start_en").isEmpty ? str(directives, "start") : str(directives, "start_en"),
            directiveWatchHe: str(directives, "watch_he").isEmpty ? str(directives, "watch") : str(directives, "watch_he"),
            directiveWatchEn: str(directives, "watch_en").isEmpty ? str(directives, "watch") : str(directives, "watch_en"),

            summaryHe: str(json as [String: Any], "forecast_he").isEmpty ? str(json as [String: Any], "forecast") : str(json as [String: Any], "forecast_he"),
            summaryEn: str(json as [String: Any], "forecast_en").isEmpty ? str(json as [String: Any], "forecast") : str(json as [String: Any], "forecast_en"),

            supplements: supplements,

            // Energy Forecast
            energyForecastTextHe: {
                if let ef = json["energyForecast"] as? [String: Any] {
                    return str(ef, "text_he")
                }
                return ""
            }(),
            energyForecastTextEn: {
                if let ef = json["energyForecast"] as? [String: Any] {
                    return str(ef, "text_en")
                }
                return ""
            }(),
            energyForecastTrend: {
                if let ef = json["energyForecast"] as? [String: Any] {
                    return str(ef, "trend")
                }
                return "stable"
            }(),

            rawResponse: rawResponse
        )
    }

    /// Converts the parsed JSON to a CarAnalysisResponse model
    /// Supports both the new bilingual format (_he/_en) and the legacy format (single field)
    private static func convertJSONToResponse(_ json: CarAnalysisJSONResponse, rawResponse: String) -> CarAnalysisResponse {
        // Convert supplements - handle nil values gracefully
        let supplements = json.supplements.map { s in
            let category: SupplementCategory
            switch (s.category ?? "general").lowercased() {
            case "sleep": category = .sleep
            case "performance": category = .performance
            case "recovery": category = .recovery
            default: category = .general
            }
            // Use bilingual fields, fallback to legacy if nil or empty
            let nameHe = (s.name_he?.isEmpty ?? true) ? (s.name ?? s.name_he ?? "") : (s.name_he ?? "")
            let nameEn = (s.name_en?.isEmpty ?? true) ? (s.englishName ?? s.name ?? s.name_en ?? "") : (s.name_en ?? "")
            let dosageHe = (s.dosage_he?.isEmpty ?? true) ? (s.dosage ?? s.dosage_he ?? "") : (s.dosage_he ?? "")
            let dosageEn = (s.dosage_en?.isEmpty ?? true) ? (s.dosage ?? s.dosage_en ?? dosageHe) : (s.dosage_en ?? "")
            let reasonHe = (s.reason_he?.isEmpty ?? true) ? (s.reason ?? s.reason_he ?? "") : (s.reason_he ?? "")
            let reasonEn = (s.reason_en?.isEmpty ?? true) ? (s.reason ?? s.reason_en ?? "") : (s.reason_en ?? "")

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

        // Helper to get bilingual value with legacy fallback
        let carIdentity = json.carIdentity
        let perf = json.performanceReview
        let opt = json.optimizationPlan
        let tune = json.tuneUpPlan
        let dir = json.directives

        return CarAnalysisResponse(
            // Car Identity
            carModelHe: carIdentity.model_he.isEmpty ? (carIdentity.model ?? carIdentity.model_he) : carIdentity.model_he,
            carModelEn: carIdentity.model_en.isEmpty ? (carIdentity.model ?? carIdentity.model_en) : carIdentity.model_en,
            carExplanationHe: carIdentity.explanation_he.isEmpty ? (carIdentity.explanation ?? carIdentity.explanation_he) : carIdentity.explanation_he,
            carExplanationEn: carIdentity.explanation_en.isEmpty ? (carIdentity.explanation ?? carIdentity.explanation_en) : carIdentity.explanation_en,
            carImageURL: "",
            carWikiName: carIdentity.wikiName,

            // Performance Review
            engineHe: perf.engine_he.isEmpty ? (perf.engine ?? perf.engine_he) : perf.engine_he,
            engineEn: perf.engine_en.isEmpty ? (perf.engine ?? perf.engine_en) : perf.engine_en,
            transmissionHe: perf.transmission_he.isEmpty ? (perf.transmission ?? perf.transmission_he) : perf.transmission_he,
            transmissionEn: perf.transmission_en.isEmpty ? (perf.transmission ?? perf.transmission_en) : perf.transmission_en,
            suspensionHe: perf.suspension_he.isEmpty ? (perf.suspension ?? perf.suspension_he) : perf.suspension_he,
            suspensionEn: perf.suspension_en.isEmpty ? (perf.suspension ?? perf.suspension_en) : perf.suspension_en,
            fuelEfficiencyHe: perf.fuelEfficiency_he.isEmpty ? (perf.fuelEfficiency ?? perf.fuelEfficiency_he) : perf.fuelEfficiency_he,
            fuelEfficiencyEn: perf.fuelEfficiency_en.isEmpty ? (perf.fuelEfficiency ?? perf.fuelEfficiency_en) : perf.fuelEfficiency_en,
            electronicsHe: perf.electronics_he.isEmpty ? (perf.electronics ?? perf.electronics_he) : perf.electronics_he,
            electronicsEn: perf.electronics_en.isEmpty ? (perf.electronics ?? perf.electronics_en) : perf.electronics_en,

            // Bottlenecks
            bottlenecksHe: json.bottlenecks_he.isEmpty ? (json.bottlenecks ?? json.bottlenecks_he) : json.bottlenecks_he,
            bottlenecksEn: json.bottlenecks_en.isEmpty ? (json.bottlenecks ?? json.bottlenecks_en) : json.bottlenecks_en,
            warningSignals: [],

            // Optimization Plan
            upgradesHe: opt.upgrades_he.isEmpty ? (opt.upgrades ?? opt.upgrades_he) : opt.upgrades_he,
            upgradesEn: opt.upgrades_en.isEmpty ? (opt.upgrades ?? opt.upgrades_en) : opt.upgrades_en,
            skippedMaintenanceHe: opt.skippedMaintenance_he.isEmpty ? (opt.skippedMaintenance ?? opt.skippedMaintenance_he) : opt.skippedMaintenance_he,
            skippedMaintenanceEn: opt.skippedMaintenance_en.isEmpty ? (opt.skippedMaintenance ?? opt.skippedMaintenance_en) : opt.skippedMaintenance_en,
            stopImmediatelyHe: opt.stopImmediately_he.isEmpty ? (opt.stopImmediately ?? opt.stopImmediately_he) : opt.stopImmediately_he,
            stopImmediatelyEn: opt.stopImmediately_en.isEmpty ? (opt.stopImmediately ?? opt.stopImmediately_en) : opt.stopImmediately_en,

            // Tune Up Plan
            trainingAdjustmentsHe: tune.trainingAdjustments_he.isEmpty ? (tune.trainingAdjustments ?? tune.trainingAdjustments_he) : tune.trainingAdjustments_he,
            trainingAdjustmentsEn: tune.trainingAdjustments_en.isEmpty ? (tune.trainingAdjustments ?? tune.trainingAdjustments_en) : tune.trainingAdjustments_en,
            recoveryChangesHe: tune.recoveryChanges_he.isEmpty ? (tune.recoveryChanges ?? tune.recoveryChanges_he) : tune.recoveryChanges_he,
            recoveryChangesEn: tune.recoveryChanges_en.isEmpty ? (tune.recoveryChanges ?? tune.recoveryChanges_en) : tune.recoveryChanges_en,
            habitToAddHe: tune.habitToAdd_he.isEmpty ? (tune.habitToAdd ?? tune.habitToAdd_he) : tune.habitToAdd_he,
            habitToAddEn: tune.habitToAdd_en.isEmpty ? (tune.habitToAdd ?? tune.habitToAdd_en) : tune.habitToAdd_en,
            habitToRemoveHe: tune.habitToRemove_he.isEmpty ? (tune.habitToRemove ?? tune.habitToRemove_he) : tune.habitToRemove_he,
            habitToRemoveEn: tune.habitToRemove_en.isEmpty ? (tune.habitToRemove ?? tune.habitToRemove_en) : tune.habitToRemove_en,

            // Directives
            directiveStopHe: dir.stop_he.isEmpty ? (dir.stop ?? dir.stop_he) : dir.stop_he,
            directiveStopEn: dir.stop_en.isEmpty ? (dir.stop ?? dir.stop_en) : dir.stop_en,
            directiveStartHe: dir.start_he.isEmpty ? (dir.start ?? dir.start_he) : dir.start_he,
            directiveStartEn: dir.start_en.isEmpty ? (dir.start ?? dir.start_en) : dir.start_en,
            directiveWatchHe: dir.watch_he.isEmpty ? (dir.watch ?? dir.watch_he) : dir.watch_he,
            directiveWatchEn: dir.watch_en.isEmpty ? (dir.watch ?? dir.watch_en) : dir.watch_en,

            // Summary
            summaryHe: json.forecast_he.isEmpty ? (json.forecast ?? json.forecast_he) : json.forecast_he,
            summaryEn: json.forecast_en.isEmpty ? (json.forecast ?? json.forecast_en) : json.forecast_en,

            supplements: supplements,

            // Energy Forecast
            energyForecastTextHe: json.energyForecast?.text_he ?? "",
            energyForecastTextEn: json.energyForecast?.text_en ?? "",
            energyForecastTrend: json.energyForecast?.trend ?? "stable",

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
