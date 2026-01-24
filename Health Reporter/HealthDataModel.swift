//
//  HealthDataModel.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import Foundation
import HealthKit

/// מודל נתונים לנתוני בריאות
struct HealthDataModel {
    // נתונים פיזיים
    var steps: Double?
    var distance: Double?
    var activeEnergy: Double?
    var heartRate: Double?
    var restingHeartRate: Double?
    var walkingHeartRateAverage: Double?
    
    // נתונים קרדיווסקולריים
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var oxygenSaturation: Double?
    
    // נתונים מטבוליים
    var bodyMass: Double?
    var bodyMassIndex: Double?
    var bodyFatPercentage: Double?
    var leanBodyMass: Double?
    
    // נתונים נשימתיים
    var respiratoryRate: Double?
    var forcedVitalCapacity: Double?
    
    // נתונים תזונתיים
    var dietaryEnergy: Double?
    var dietaryProtein: Double?
    var dietaryCarbohydrates: Double?
    var dietaryFat: Double?
    
    // נתונים שינה
    var sleepHours: Double?
    var sleepAnalysis: [SleepData]?
    
    // נתונים נוספים
    var bloodGlucose: Double?
    var bodyTemperature: Double?
    var vo2Max: Double?
    
    // תובנות מ-Gemini
    var insights: String?
    var recommendations: [String]?
    var riskFactors: [String]?
    
    var lastUpdated: Date?
}

struct SleepData {
    var startDate: Date
    var endDate: Date
    var value: HKCategoryValueSleepAnalysis
}

/// נתוני בריאות שבועיים (Weekly Snapshot)
struct WeeklyHealthSnapshot: Codable {
    var weekStartDate: Date
    var weekEndDate: Date
    var restingHeartRate: Double?
    var heartRateVariability: Double? // HRV - אם זמין
    var hrv7DayAverage: Double? // ממוצע HRV של 7 ימים
    var sleepDurationHours: Double?
    var sleepEfficiency: Double? // יעילות שינה
    var remSleepHours: Double? // שעות REM
    var deepSleepHours: Double? // שעות שינה עמוקה
    var activeCalories: Double?
    var vo2Max: Double?
    var steps: Double?
    var distanceKm: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var bodyMass: Double?
    var bodyMassIndex: Double?
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var oxygenSaturation: Double?
    var dietaryEnergy: Double?
    var basalBodyTemperature: Double? // טמפרטורת גוף בסיסית
    var trainingStrain: Double? // עומס אימון (1-10)
    var recoveryScore: Double? // ציון התאוששות (0-100%)
    var efficiencyFactor: Double? // גורם יעילות (Pace/HR)
    
    func toJSON() -> [String: Any] {
        var json: [String: Any] = [:]
        json["week_start"] = ISO8601DateFormatter().string(from: weekStartDate)
        json["week_end"] = ISO8601DateFormatter().string(from: weekEndDate)
        
        if let rhr = restingHeartRate { json["resting_heart_rate_bpm"] = rhr }
        if let hrv = heartRateVariability { json["heart_rate_variability_ms"] = hrv }
        if let hrv7d = hrv7DayAverage { json["hrv_7day_average_ms"] = hrv7d }
        if let sleep = sleepDurationHours { json["sleep_duration_hours"] = sleep }
        if let sleepEff = sleepEfficiency { json["sleep_efficiency_percent"] = sleepEff }
        if let rem = remSleepHours { json["rem_sleep_hours"] = rem }
        if let deep = deepSleepHours { json["deep_sleep_hours"] = deep }
        if let calories = activeCalories { json["active_calories_kcal"] = calories }
        if let vo2 = vo2Max { json["vo2_max"] = vo2 }
        if let steps = steps { json["steps"] = steps }
        if let distance = distanceKm { json["distance_km"] = distance }
        if let hr = averageHeartRate { json["average_heart_rate_bpm"] = hr }
        if let maxHR = maxHeartRate { json["max_heart_rate_bpm"] = maxHR }
        if let weight = bodyMass { json["body_mass_kg"] = weight }
        if let bmi = bodyMassIndex { json["bmi"] = bmi }
        if let systolic = bloodPressureSystolic, let diastolic = bloodPressureDiastolic {
            json["blood_pressure"] = ["systolic": systolic, "diastolic": diastolic]
        }
        if let oxygen = oxygenSaturation { json["oxygen_saturation_percent"] = oxygen }
        if let dietary = dietaryEnergy { json["dietary_energy_kcal"] = dietary }
        if let bbt = basalBodyTemperature { json["basal_body_temperature_c"] = bbt }
        if let strain = trainingStrain { json["training_strain_1_10"] = strain }
        if let recovery = recoveryScore { json["recovery_score_percent"] = recovery }
        if let ef = efficiencyFactor { json["efficiency_factor"] = ef }
        
        // חישוב Recovery-to-Strain Ratio
        if let strain = trainingStrain, let recovery = recoveryScore, strain > 0 {
            json["recovery_to_strain_ratio"] = recovery / (strain * 10)
        }
        
        return json
    }
}

/// סיכום נתוני בריאות לניתוח
struct HealthSummary {
    var dataModel: HealthDataModel
    var dateRange: DateInterval
    var keyMetrics: [String: Any]
    var currentWeek: WeeklyHealthSnapshot?
    var previousWeek: WeeklyHealthSnapshot?
    
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        var json: [String: Any] = [:]
        
        // נתונים פיזיים
        if let steps = dataModel.steps {
            json["steps"] = steps
        }
        if let distance = dataModel.distance {
            json["distance_km"] = distance
        }
        if let activeEnergy = dataModel.activeEnergy {
            json["active_energy_kcal"] = activeEnergy
        }
        if let heartRate = dataModel.heartRate {
            json["heart_rate_bpm"] = heartRate
        }
        if let restingHeartRate = dataModel.restingHeartRate {
            json["resting_heart_rate_bpm"] = restingHeartRate
        }
        
        // נתונים קרדיווסקולריים
        if let systolic = dataModel.bloodPressureSystolic,
           let diastolic = dataModel.bloodPressureDiastolic {
            json["blood_pressure"] = ["systolic": systolic, "diastolic": diastolic]
        }
        if let oxygen = dataModel.oxygenSaturation {
            json["oxygen_saturation_percent"] = oxygen
        }
        
        // נתונים מטבוליים
        if let bmi = dataModel.bodyMassIndex {
            json["bmi"] = bmi
        }
        if let weight = dataModel.bodyMass {
            json["weight_kg"] = weight
        }
        if let bodyFat = dataModel.bodyFatPercentage {
            json["body_fat_percent"] = bodyFat
        }
        
        // נתונים שינה
        if let sleepHours = dataModel.sleepHours {
            json["sleep_hours"] = sleepHours
        }
        
        // נתונים תזונתיים
        if let calories = dataModel.dietaryEnergy {
            json["dietary_calories"] = calories
        }
        
        // נתונים נוספים
        if let glucose = dataModel.bloodGlucose {
            json["blood_glucose_mmol"] = glucose
        }
        if let vo2Max = dataModel.vo2Max {
            json["vo2_max"] = vo2Max
        }
        
        json["date_range"] = [
            "start": ISO8601DateFormatter().string(from: dateRange.start),
            "end": ISO8601DateFormatter().string(from: dateRange.end)
        ]
        
        // הוסף נתונים שבועיים אם זמינים
        if let currentWeek = currentWeek {
            json["current_week"] = currentWeek.toJSON()
        }
        if let previousWeek = previousWeek {
            json["previous_week"] = previousWeek.toJSON()
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error converting to JSON: \(error)")
            return nil
        }
    }
}
