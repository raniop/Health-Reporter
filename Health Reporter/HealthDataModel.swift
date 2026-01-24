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

/// סיכום נתוני בריאות לניתוח
struct HealthSummary {
    var dataModel: HealthDataModel
    var dateRange: DateInterval
    var keyMetrics: [String: Any]
    
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
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error converting to JSON: \(error)")
            return nil
        }
    }
}
