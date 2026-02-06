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
    // תאריך (אופציונלי - לשימוש בהיסטוריה)
    var date: Date?

    // נתונים פיזיים
    var steps: Double?
    var distance: Double?
    var activeEnergy: Double?
    var heartRate: Double?
    var restingHeartRate: Double?
    var walkingHeartRateAverage: Double?

    // MARK: - Activity Rings Data (Apple Activity App)
    /// דקות אימון (Exercise Ring - ירוק)
    var exerciseMinutes: Double?
    /// שעות עמידה (Stand Ring - כחול)
    var standHours: Double?
    /// דקות תנועה כללית
    var moveTimeMinutes: Double?
    /// קומות שנטפסו
    var flightsClimbed: Double?
    /// אנרגיה בסיסית (BMR)
    var basalEnergy: Double?
    /// סה"כ קלוריות (פעילות + בסיסית)
    var totalEnergy: Double?

    // MARK: - Workout Data
    /// מספר אימונים בטווח
    var workoutCount: Int?
    /// סה"כ דקות אימון
    var totalWorkoutMinutes: Double?
    /// סה"כ קלוריות באימונים
    var totalWorkoutCalories: Double?
    /// סוגי אימונים (ריצה, הליכה, וכו')
    var workoutTypes: [String]?
    /// אימון אחרון
    var lastWorkout: WorkoutData?
    /// כל האימונים בטווח (מפורט!)
    var recentWorkouts: [WorkoutData]?

    // MARK: - Walking Metrics (Apple)
    /// מהירות הליכה (קמ"ש)
    var walkingSpeed: Double?
    /// אורך צעד (מטר)
    var walkingStepLength: Double?
    /// אסימטריית הליכה (%)
    var walkingAsymmetry: Double?
    /// יציבות הליכה (%)
    var walkingSteadiness: Double?
    /// מרחק מבחן 6 דקות הליכה
    var sixMinuteWalkDistance: Double?
    /// Heart Rate Recovery (1 דקה אחרי אימון)
    var heartRateRecovery: Double?
    
    // נתונים קרדיווסקולריים
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var oxygenSaturation: Double?
    var heartRateVariability: Double? // HRV (ms)
    
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

    // MARK: - Data Source Tracking
    /// מקור הנתונים העיקרי (Apple Watch, Garmin, Oura)
    var primaryDataSource: HealthDataSource?
    /// כל המקורות שזוהו
    var detectedSources: Set<HealthDataSource>?

    // MARK: - Enhanced Sleep Data (Garmin/Oura)
    /// שעות שינה עמוקה
    var sleepDeepHours: Double?
    /// שעות שינה REM
    var sleepRemHours: Double?
    /// שעות שינה קלה
    var sleepLightHours: Double?
    /// דקות ערות בזמן שינה
    var sleepAwakeMinutes: Double?
    /// יעילות שינה (0-100%)
    var sleepEfficiency: Double?
    /// זמן במיטה (שעות)
    var timeInBedHours: Double?

    // MARK: - Calculated Metrics
    /// ציון מוכנות מחושב (0-100) - דומה ל-Oura/WHOOP
    var calculatedReadinessScore: Double?
    /// עומס אימון מחושב (0-10)
    var calculatedTrainingStrain: Double?
    /// האם ציון המוכנות מחושב (true) או מהמכשיר (false)
    var isReadinessCalculated: Bool?

    // MARK: - Oura-Specific Data
    /// סטיית טמפרטורת גוף מהבסיס (°C)
    var bodyTemperatureDeviation: Double?
    /// רמת חמצן בדם (%)
    var spO2: Double?
    /// קצב נשימה ממוצע (נשימות לדקה)
    var respiratoryRateAvg: Double?

    // MARK: - HRV Enhanced
    /// HRV ממוצע 7 ימים (baseline)
    var hrv7DayBaseline: Double?
    /// מגמת HRV (-1 עד +1)
    var hrvTrend: Double?

    /// האם יש נתוני בריאות אמיתיים (לפחות ערך אחד שאינו nil/0)
    var hasRealData: Bool {
        let all: [Double?] = [
            steps, distance, activeEnergy, heartRate, restingHeartRate,
            walkingHeartRateAverage, bloodPressureSystolic, oxygenSaturation,
            bodyMass, bodyMassIndex, bodyFatPercentage, respiratoryRate,
            dietaryEnergy, dietaryProtein, dietaryCarbohydrates, dietaryFat,
            sleepHours, bloodGlucose, vo2Max, bodyTemperature,
            exerciseMinutes, standHours, flightsClimbed, totalWorkoutMinutes
        ]
        return all.contains { $0 != nil && $0! > 0 }
    }
}

struct SleepData {
    var startDate: Date
    var endDate: Date
    var value: HKCategoryValueSleepAnalysis
}

/// מודל נתוני אימון
struct WorkoutData: Codable {
    var type: String // סוג האימון (Running, Walking, Cycling, etc.)
    var startDate: Date
    var endDate: Date
    var durationMinutes: Double
    var totalCalories: Double?
    var totalDistance: Double? // מטרים
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var elevationGain: Double? // מטרים

    func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "type": type,
            "start_date": ISO8601DateFormatter().string(from: startDate),
            "end_date": ISO8601DateFormatter().string(from: endDate),
            "duration_minutes": durationMinutes
        ]
        if let cal = totalCalories { json["calories_kcal"] = cal }
        if let dist = totalDistance { json["distance_meters"] = dist }
        if let avgHR = averageHeartRate { json["average_heart_rate_bpm"] = avgHR }
        if let maxHR = maxHeartRate { json["max_heart_rate_bpm"] = maxHR }
        if let elev = elevationGain { json["elevation_gain_meters"] = elev }
        return json
    }
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

    // MARK: - Activity Rings
    var exerciseMinutes: Double? // דקות אימון (ירוק)
    var standHours: Double? // שעות עמידה (כחול)
    var flightsClimbed: Double? // קומות

    // MARK: - Workouts
    var workoutCount: Int? // מספר אימונים
    var totalWorkoutMinutes: Double? // סה"כ דקות אימון
    var workoutTypes: [String]? // סוגי אימונים

    // MARK: - Walking Metrics
    var walkingSpeed: Double? // מהירות הליכה (קמ"ש)
    var heartRateRecovery: Double? // Heart Rate Recovery

    // MARK: - Data Source Info
    var primaryDataSource: String? // "Garmin", "Oura", "Apple Watch"

    // MARK: - Enhanced Sleep (Garmin/Oura)
    var lightSleepHours: Double? // שינה קלה
    var awakeMinutes: Double? // דקות ערות

    // MARK: - Calculated Scores
    var calculatedReadinessScore: Double? // ציון מוכנות מחושב (0-100)
    var isReadinessCalculated: Bool? // האם מחושב או מהמכשיר

    // MARK: - Oura-Specific
    var bodyTemperatureDeviation: Double? // סטיית טמפ' מבסיס
    var spO2Average: Double? // חמצן ממוצע

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

        // Data Source
        if let source = primaryDataSource { json["data_source"] = source }

        // Enhanced Sleep
        if let light = lightSleepHours { json["light_sleep_hours"] = light }
        if let awake = awakeMinutes { json["awake_minutes"] = awake }

        // Calculated Scores
        if let readiness = calculatedReadinessScore {
            json["readiness_score"] = readiness
            json["readiness_is_calculated"] = isReadinessCalculated ?? true
        }

        // Oura-Specific
        if let tempDev = bodyTemperatureDeviation { json["body_temp_deviation_c"] = tempDev }
        if let spo2 = spO2Average { json["spo2_average_percent"] = spo2 }

        // חישוב Recovery-to-Strain Ratio
        if let strain = trainingStrain, let recovery = recoveryScore, strain > 0 {
            json["recovery_to_strain_ratio"] = recovery / (strain * 10)
        }

        // Activity Rings
        if let exercise = exerciseMinutes { json["exercise_minutes"] = exercise }
        if let stand = standHours { json["stand_hours"] = stand }
        if let flights = flightsClimbed { json["flights_climbed"] = flights }

        // Workouts
        if let count = workoutCount, count > 0 { json["workout_count"] = count }
        if let totalMins = totalWorkoutMinutes, totalMins > 0 { json["total_workout_minutes"] = totalMins }
        if let types = workoutTypes, !types.isEmpty { json["workout_types"] = types }

        // Walking Metrics
        if let speed = walkingSpeed { json["walking_speed_kmh"] = speed }
        if let hrr = heartRateRecovery { json["heart_rate_recovery_bpm"] = hrr }

        return json
    }
}
