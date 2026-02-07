//
//  HealthDataModel.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import Foundation
import HealthKit

/// Health data model
struct HealthDataModel {
    // Date (optional - for use in history)
    var date: Date?

    // Physical data
    var steps: Double?
    var distance: Double?
    var activeEnergy: Double?
    var heartRate: Double?
    var restingHeartRate: Double?
    var walkingHeartRateAverage: Double?

    // MARK: - Activity Rings Data (Apple Activity App)
    /// Exercise minutes (Exercise Ring - green)
    var exerciseMinutes: Double?
    /// Stand hours (Stand Ring - blue)
    var standHours: Double?
    /// General movement minutes
    var moveTimeMinutes: Double?
    /// Flights climbed
    var flightsClimbed: Double?
    /// Basal energy (BMR)
    var basalEnergy: Double?
    /// Total calories (active + basal)
    var totalEnergy: Double?

    // MARK: - Workout Data
    /// Number of workouts in range
    var workoutCount: Int?
    /// Total workout minutes
    var totalWorkoutMinutes: Double?
    /// Total workout calories
    var totalWorkoutCalories: Double?
    /// Workout types (running, walking, etc.)
    var workoutTypes: [String]?
    /// Last workout
    var lastWorkout: WorkoutData?
    /// All workouts in range (detailed!)
    var recentWorkouts: [WorkoutData]?

    // MARK: - Walking Metrics (Apple)
    /// Walking speed (km/h)
    var walkingSpeed: Double?
    /// Step length (meters)
    var walkingStepLength: Double?
    /// Walking asymmetry (%)
    var walkingAsymmetry: Double?
    /// Walking steadiness (%)
    var walkingSteadiness: Double?
    /// Six-minute walk test distance
    var sixMinuteWalkDistance: Double?
    /// Heart Rate Recovery (1 minute after workout)
    var heartRateRecovery: Double?
    
    // Cardiovascular data
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var oxygenSaturation: Double?
    var heartRateVariability: Double? // HRV (ms)
    
    // Metabolic data
    var bodyMass: Double?
    var bodyMassIndex: Double?
    var bodyFatPercentage: Double?
    var leanBodyMass: Double?
    
    // Respiratory data
    var respiratoryRate: Double?
    var forcedVitalCapacity: Double?
    
    // Nutritional data
    var dietaryEnergy: Double?
    var dietaryProtein: Double?
    var dietaryCarbohydrates: Double?
    var dietaryFat: Double?
    
    // Sleep data
    var sleepHours: Double?
    var sleepAnalysis: [SleepData]?
    
    // Additional data
    var bloodGlucose: Double?
    var bodyTemperature: Double?
    var vo2Max: Double?

    // Insights from Gemini
    var insights: String?
    var recommendations: [String]?
    var riskFactors: [String]?

    var lastUpdated: Date?

    // MARK: - Data Source Tracking
    /// Primary data source (Apple Watch, Garmin, Oura)
    var primaryDataSource: HealthDataSource?
    /// All detected sources
    var detectedSources: Set<HealthDataSource>?

    // MARK: - Enhanced Sleep Data (Garmin/Oura)
    /// Deep sleep hours
    var sleepDeepHours: Double?
    /// REM sleep hours
    var sleepRemHours: Double?
    /// Light sleep hours
    var sleepLightHours: Double?
    /// Awake minutes during sleep
    var sleepAwakeMinutes: Double?
    /// Sleep efficiency (0-100%)
    var sleepEfficiency: Double?
    /// Time in bed (hours)
    var timeInBedHours: Double?

    // MARK: - Calculated Metrics
    /// Calculated readiness score (0-100) - similar to Oura/WHOOP
    var calculatedReadinessScore: Double?
    /// Calculated training strain (0-10)
    var calculatedTrainingStrain: Double?
    /// Whether readiness score is calculated (true) or from device (false)
    var isReadinessCalculated: Bool?

    // MARK: - Oura-Specific Data
    /// Body temperature deviation from baseline (°C)
    var bodyTemperatureDeviation: Double?
    /// Blood oxygen level (%)
    var spO2: Double?
    /// Average respiratory rate (breaths per minute)
    var respiratoryRateAvg: Double?

    // MARK: - HRV Enhanced
    /// HRV 7-day average (baseline)
    var hrv7DayBaseline: Double?
    /// HRV trend (-1 to +1)
    var hrvTrend: Double?

    /// Whether there is real health data (at least one non-nil/0 value)
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

/// Workout data model
struct WorkoutData: Codable {
    var type: String // Workout type (Running, Walking, Cycling, etc.)
    var startDate: Date
    var endDate: Date
    var durationMinutes: Double
    var totalCalories: Double?
    var totalDistance: Double? // meters
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var elevationGain: Double? // meters

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

/// Weekly health data (Weekly Snapshot)
struct WeeklyHealthSnapshot: Codable {
    var weekStartDate: Date
    var weekEndDate: Date
    var restingHeartRate: Double?
    var heartRateVariability: Double? // HRV - if available
    var hrv7DayAverage: Double? // 7-day HRV average
    var sleepDurationHours: Double?
    var sleepEfficiency: Double? // Sleep efficiency
    var remSleepHours: Double? // REM hours
    var deepSleepHours: Double? // Deep sleep hours
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
    var basalBodyTemperature: Double? // Basal body temperature
    var trainingStrain: Double? // Training strain (1-10)
    var recoveryScore: Double? // Recovery score (0-100%)
    var efficiencyFactor: Double? // Efficiency factor (Pace/HR)

    // MARK: - Activity Rings
    var exerciseMinutes: Double? // Exercise minutes (green)
    var standHours: Double? // Stand hours (blue)
    var flightsClimbed: Double? // Flights

    // MARK: - Workouts
    var workoutCount: Int? // Number of workouts
    var totalWorkoutMinutes: Double? // Total workout minutes
    var workoutTypes: [String]? // Workout types

    // MARK: - Walking Metrics
    var walkingSpeed: Double? // Walking speed (km/h)
    var heartRateRecovery: Double? // Heart Rate Recovery

    // MARK: - Data Source Info
    var primaryDataSource: String? // "Garmin", "Oura", "Apple Watch"

    // MARK: - Enhanced Sleep (Garmin/Oura)
    var lightSleepHours: Double? // Light sleep
    var awakeMinutes: Double? // Awake minutes

    // MARK: - Calculated Scores
    var calculatedReadinessScore: Double? // Calculated readiness score (0-100)
    var isReadinessCalculated: Bool? // Whether calculated or from device

    // MARK: - Oura-Specific
    var bodyTemperatureDeviation: Double? // Temperature deviation from baseline
    var spO2Average: Double? // Average oxygen

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

        // Calculate Recovery-to-Strain Ratio
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
