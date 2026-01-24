//
//  GraphDataModels.swift
//  Health Reporter
//
//  מודלים ל־6 הגרפים המקצועיים של AION.
//

import Foundation

// MARK: - 1. Readiness Matrix (Recovery vs Strain)
struct ReadinessDataPoint {
    var date: Date
    var recovery: Double  // 0–100
    var strain: Double    // 0–10, normalized
}

struct ReadinessGraphData {
    var points: [ReadinessDataPoint]
    var periodLabel: String
}

// MARK: - 2. Cardiovascular Efficiency (HR vs Pace/Distance)
struct EfficiencyDataPoint {
    var date: Date
    var avgHeartRate: Double?
    var distanceKm: Double?
    var activeCalories: Double?
}

struct EfficiencyGraphData {
    var points: [EfficiencyDataPoint]
    var periodLabel: String
}

// MARK: - 3. Sleep Architecture & Thermal
struct SleepDayPoint {
    var date: Date
    var totalHours: Double?
    var deepHours: Double?
    var remHours: Double?
    var bbt: Double?  // Basal body temp °C
}

struct SleepArchitectureGraphData {
    var points: [SleepDayPoint]
    var periodLabel: String
}

// MARK: - 4. Glucose & Energy
struct GlucoseEnergyPoint {
    var date: Date
    var glucose: Double?
    var activeEnergy: Double?
}

struct GlucoseEnergyGraphData {
    var points: [GlucoseEnergyPoint]
    var periodLabel: String
}

// MARK: - 5. Autonomic Balance (Radar)
struct AutonomicRadarData {
    var rhr: Double?      // 0–100 normalized
    var hrv: Double?      // 0–100 normalized
    var respiratory: Double?
    var stressIndicator: Double?  // inferred
    var periodLabel: String
}

// MARK: - 6. Nutrition Adherence
struct NutritionDayPoint {
    var date: Date
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var proteinGoal: Double?
    var carbsGoal: Double?
    var fatGoal: Double?
}

struct NutritionGraphData {
    var points: [NutritionDayPoint]
    var periodLabel: String
}

/// צרור כל נתוני הגרפים לשליחה ל-AION
struct AIONChartDataBundle {
    var range: DataRange
    var rangeLabel: String
    var readiness: ReadinessGraphData
    var efficiency: EfficiencyGraphData
    var sleep: SleepArchitectureGraphData
    var glucoseEnergy: GlucoseEnergyGraphData
    var autonomic: AutonomicRadarData
    var nutrition: NutritionGraphData
}

// MARK: - JSON Schema for Gemini (6 graphs in one Review request)

/// סכמת JSON לאריזת כל 6 הגרפים לשליחה ל-AION ב-Gemini
struct AIONReviewPayload {
    var period: String
    var graph1_Readiness: [[String: Any]]
    var graph2_CVEfficiency: [[String: Any]]
    var graph3_Sleep: [[String: Any]]
    var graph4_GlucoseEnergy: [[String: Any]]
    var graph5_Autonomic: [String: Any]
    var graph6_Nutrition: [[String: Any]]

    func toJSONString() -> String? {
        var json: [String: Any] = [
            "period": period,
            "graph_1_readiness_recovery_vs_strain": graph1_Readiness,
            "graph_2_cv_efficiency_hr_vs_pace": graph2_CVEfficiency,
            "graph_3_sleep_architecture_thermal": graph3_Sleep,
            "graph_4_glucose_energy_stability": graph4_GlucoseEnergy,
            "graph_5_autonomic_balance_radar": graph5_Autonomic,
            "graph_6_nutrition_adherence": graph6_Nutrition,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension AIONChartDataBundle {
    func toAIONReviewPayload() -> AIONReviewPayload {
        let g1 = readiness.points.map { p in
            ["date": ISO8601DateFormatter().string(from: p.date), "recovery": p.recovery, "strain": p.strain] as [String: Any]
        }
        let g2 = efficiency.points.map { p -> [String: Any] in
            var r: [String: Any] = ["date": ISO8601DateFormatter().string(from: p.date)]
            if let hr = p.avgHeartRate { r["avg_hr_bpm"] = hr }
            if let km = p.distanceKm { r["distance_km"] = km }
            if let c = p.activeCalories { r["active_kcal"] = c }
            return r
        }
        let g3 = sleep.points.map { p -> [String: Any] in
            var r: [String: Any] = ["date": ISO8601DateFormatter().string(from: p.date)]
            if let h = p.totalHours { r["sleep_hours"] = h }
            if let d = p.deepHours { r["deep_hours"] = d }
            if let rem = p.remHours { r["rem_hours"] = rem }
            if let b = p.bbt { r["bbt_c"] = b }
            return r
        }
        let g4 = glucoseEnergy.points.map { p -> [String: Any] in
            var r: [String: Any] = ["date": ISO8601DateFormatter().string(from: p.date)]
            if let g = p.glucose { r["glucose"] = g }
            if let e = p.activeEnergy { r["active_energy"] = e }
            return r
        }
        var g5: [String: Any] = [:]
        if let r = autonomic.rhr { g5["rhr_normalized"] = r }
        if let h = autonomic.hrv { g5["hrv_normalized"] = h }
        if let r = autonomic.respiratory { g5["respiratory"] = r }
        g5["period"] = autonomic.periodLabel
        let g6 = nutrition.points.map { p -> [String: Any] in
            var r: [String: Any] = ["date": ISO8601DateFormatter().string(from: p.date)]
            if let pr = p.protein { r["protein_g"] = pr }
            if let c = p.carbs { r["carbs_g"] = c }
            if let f = p.fat { r["fat_g"] = f }
            return r
        }
        return AIONReviewPayload(
            period: rangeLabel,
            graph1_Readiness: g1,
            graph2_CVEfficiency: g2,
            graph3_Sleep: g3,
            graph4_GlucoseEnergy: g4,
            graph5_Autonomic: g5,
            graph6_Nutrition: g6
        )
    }
}
