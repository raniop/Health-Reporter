//
//  ProfileStore.swift
//  Health Reporter
//
//  UserDefaults-backed store for every Profile preference shown in the Livity
//  redesign. One observable singleton so every screen sees the same state.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Enums

enum LivityAppearance: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    var subtitle: String {
        switch self {
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        case .system: return "Match system settings"
        }
    }
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.righthalf.filled"
        }
    }
}

enum LivityDistanceUnit: String, CaseIterable, Identifiable {
    case kilometres, miles
    var id: String { rawValue }
    var label: String { self == .kilometres ? "Kilometres (km)" : "Miles (mi)" }
}

enum LivityTempUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }
    var label: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }
}

enum LivityEnergyUnit: String, CaseIterable, Identifiable {
    case kcal, kj
    var id: String { rawValue }
    var label: String { self == .kcal ? "Kilocalories (kcal)" : "Kilojoules (kJ)" }
}

enum LivityWeightUnit: String, CaseIterable, Identifiable {
    case kilograms, pounds, stones
    var id: String { rawValue }
    var label: String {
        switch self {
        case .kilograms: return "Kilograms"
        case .pounds: return "Pounds"
        case .stones: return "Stones"
        }
    }
}

enum LivityWaterUnit: String, CaseIterable, Identifiable {
    case litres, flOunces
    var id: String { rawValue }
    var label: String { self == .litres ? "Litres (L)" : "Fluid Ounces (fl oz)" }
}

enum LivityDefaultTab: String, CaseIterable, Identifiable {
    case overview, goals, insights, social, profile
    var id: String { rawValue }
    var label: String {
        switch self {
        case .overview: return "Overview"
        case .goals:    return "Goals"
        case .insights: return "Insights"
        case .social:   return "Social"
        case .profile:  return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "heart.fill"
        case .goals:    return "target"
        case .insights: return "sparkles"
        case .social:   return "person.2.fill"
        case .profile:  return "person.circle"
        }
    }
}

enum LivityAppIcon: String, CaseIterable, Identifiable {
    case primary, dark, graphite
    var id: String { rawValue }
    var label: String {
        switch self {
        case .primary:  return "Default"
        case .dark:     return "Midnight"
        case .graphite: return "Graphite"
        }
    }
    var alternateName: String? {
        switch self {
        case .primary:  return nil
        case .dark:     return "AppIcon-Midnight"
        case .graphite: return "AppIcon-Graphite"
        }
    }
}

enum LivityHRMaxSource: String, CaseIterable, Identifiable {
    case auto, manual
    var id: String { rawValue }
    var label: String { self == .auto ? "Auto" : "Manual" }
}

enum LivityHRZoneMethod: String, CaseIterable, Identifiable {
    case percentMax, hrrApple, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .percentMax: return "% of Max"
        case .hrrApple:   return "HRR (Apple)"
        case .custom:     return "Custom"
        }
    }
}

enum LivityHRVMethod: String, CaseIterable, Identifiable {
    case sdnn, rmssd
    var id: String { rawValue }
    var label: String { self == .sdnn ? "SDNN (Apple Watch)" : "RMSSD (Livity)" }
    var blurb: String {
        switch self {
        case .sdnn:
            return "SDNN is Apple Watch's standard measurement that shows overall heart rhythm variability over time. Great for tracking long-term heart health trends."
        case .rmssd:
            return "RMSSD specifically measures quick changes between heartbeats. This method can catch subtle changes in your recovery state more quickly than SDNN. While the numbers will be different from SDNN, they're equally valid for tracking your daily recovery."
        }
    }
}

enum LivityActivityGoal: String, CaseIterable, Identifiable {
    case pushMax, maintain, activeRecovery
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pushMax:        return "Push to maximum"
        case .maintain:       return "Maintain current shape"
        case .activeRecovery: return "Active recovery"
        }
    }
    var subtitle: String {
        switch self {
        case .pushMax:        return "Challenge yourself to reach new fitness levels"
        case .maintain:       return "Stay consistent with your current fitness"
        case .activeRecovery: return "Focus on restoration and gentle movement"
        }
    }
    var icon: String {
        switch self {
        case .pushMax:        return "flame.fill"
        case .maintain:       return "figure.walk"
        case .activeRecovery: return "heart.fill"
        }
    }
}

enum LivityNutritionGoal: String, CaseIterable, Identifiable {
    case weightLoss, maintenance, weightGain, performance
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weightLoss:  return "Weight Loss"
        case .maintenance: return "Maintenance"
        case .weightGain:  return "Weight Gain"
        case .performance: return "Performance"
        }
    }
    var subtitle: String {
        switch self {
        case .weightLoss:  return "Calorie deficit to lose weight steadily"
        case .maintenance: return "Eat at maintenance to keep your current weight"
        case .weightGain:  return "Calorie surplus to build muscle and gain weight"
        case .performance: return "Fuel intense training and optimize performance"
        }
    }
    var icon: String {
        switch self {
        case .weightLoss:  return "arrow.down.circle.fill"
        case .maintenance: return "equal.circle.fill"
        case .weightGain:  return "arrow.up.circle.fill"
        case .performance: return "bolt.fill"
        }
    }
}

enum LivityMedicationType: String, CaseIterable, Identifiable {
    case stimulant, betaBlocker, snri, thyroid, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .stimulant:    return "Stimulant"
        case .betaBlocker:  return "Beta Blocker"
        case .snri:         return "SNRI Antidepressant"
        case .thyroid:      return "Thyroid Medication"
        case .other:        return "Other"
        }
    }
    var subtitle: String {
        switch self {
        case .stimulant:    return "Adderall, Vyvanse, Ritalin"
        case .betaBlocker:  return "Propranolol, Metoprolol, Atenolol"
        case .snri:         return "Venlafaxine, Duloxetine"
        case .thyroid:      return "Levothyroxine"
        case .other:        return "Other medications affecting heart rate"
        }
    }
    var icon: String {
        switch self {
        case .stimulant:    return "heart.circle.fill"
        case .betaBlocker:  return "pills.fill"
        case .snri:         return "brain.head.profile"
        case .thyroid:      return "pill.fill"
        case .other:        return "cross.case.fill"
        }
    }
    /// Suggested BPM offset mid-point for the "typical" range.
    var typicalOffset: Int {
        switch self {
        case .stimulant:    return 5
        case .betaBlocker:  return -15
        case .snri:         return 3
        case .thyroid:      return 2
        case .other:        return 0
        }
    }
}

// MARK: - Sleep source entry

struct LivitySleepSource: Identifiable, Codable, Equatable {
    var id: String          // stable id (device name)
    var title: String
    var subtitle: String
    var lastSync: String    // human-readable timestamp shown in the row
    var isValid: Bool
}

// MARK: - Health data source metric

enum LivityHealthMetric: String, CaseIterable, Identifiable {
    case steps, activeEnergy, restingEnergy, exerciseTime, heartRate, hrv,
         respiratoryRate, bloodOxygen, flightsClimbed, vo2Max
    var id: String { rawValue }
    var title: String {
        switch self {
        case .steps:           return "Steps"
        case .activeEnergy:    return "Active Energy"
        case .restingEnergy:   return "Resting Energy"
        case .exerciseTime:    return "Exercise Time"
        case .heartRate:       return "Heart Rate"
        case .hrv:             return "Heart Rate Variability"
        case .respiratoryRate: return "Respiratory Rate"
        case .bloodOxygen:     return "Blood Oxygen"
        case .flightsClimbed:  return "Flights Climbed"
        case .vo2Max:          return "VO2 Max"
        }
    }
    var icon: String {
        switch self {
        case .steps:           return "figure.walk"
        case .activeEnergy:    return "flame.fill"
        case .restingEnergy:   return "bolt.fill"
        case .exerciseTime:    return "clock.fill"
        case .heartRate:       return "heart.fill"
        case .hrv:             return "waveform.path.ecg"
        case .respiratoryRate: return "lungs.fill"
        case .bloodOxygen:     return "drop.fill"
        case .flightsClimbed:  return "figure.stairs"
        case .vo2Max:          return "wind"
        }
    }
    var color: Color {
        switch self {
        case .steps:           return LivityTheme.good
        case .activeEnergy:    return LivityTheme.warning
        case .restingEnergy:   return LivityTheme.caution
        case .exerciseTime:    return LivityTheme.good
        case .heartRate:       return LivityTheme.bad
        case .hrv:             return LivityTheme.info
        case .respiratoryRate: return LivityTheme.info
        case .bloodOxygen:     return LivityTheme.info
        case .flightsClimbed:  return LivityTheme.good
        case .vo2Max:          return LivityTheme.purple
        }
    }
    /// Default # of active sources (what the UI shows as "X of Y sources active").
    var defaultActiveOfTotal: (Int, Int) {
        switch self {
        case .steps, .activeEnergy, .flightsClimbed: return (2, 2)
        default: return (1, 1)
        }
    }
}

// MARK: - Notification alert category

enum LivityAlertCategory: String, CaseIterable, Identifiable {
    case sleep, sleepCoach, circadianPhases, workout, stress, caffeineWindow, strainTarget
    var id: String { rawValue }
    var title: String {
        switch self {
        case .sleep:           return "Sleep"
        case .sleepCoach:      return "Sleep Coach"
        case .circadianPhases: return "Circadian Phases"
        case .workout:         return "Workout"
        case .stress:          return "Stress"
        case .caffeineWindow:  return "Caffeine Window"
        case .strainTarget:    return "Strain Target"
        }
    }
    var subtitle: String {
        switch self {
        case .sleep:           return "Get updates about your sleep cycles and patterns"
        case .sleepCoach:      return "Get bedtime reminders based on your daily stress and activity"
        case .circadianPhases: return "Get notified about optimal times for activity and rest"
        case .workout:         return "Receive alerts about workout status and activity"
        case .stress:          return "Be alerted when your stress levels change significantly"
        case .caffeineWindow:  return "Receive alerts for optimal caffeine consumption timing"
        case .strainTarget:    return "Track your daily strain and know when to push or rest"
        }
    }
    var icon: String {
        switch self {
        case .sleep:           return "bed.double.fill"
        case .sleepCoach:      return "moon.stars.fill"
        case .circadianPhases: return "sun.horizon.fill"
        case .workout:         return "figure.run"
        case .stress:          return "heart.fill"
        case .caffeineWindow:  return "cup.and.saucer.fill"
        case .strainTarget:    return "flame.fill"
        }
    }
    var iconColor: Color {
        switch self {
        case .sleep:           return LivityTheme.info
        case .sleepCoach:      return LivityTheme.info
        case .circadianPhases: return LivityTheme.caution
        case .workout:         return LivityTheme.good
        case .stress:          return LivityTheme.bad
        case .caffeineWindow:  return LivityTheme.warning
        case .strainTarget:    return LivityTheme.warning
        }
    }
    var defaultOn: Bool { self == .sleepCoach }
}

// MARK: - Store

final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    private let d = UserDefaults.standard

    // Keys
    private enum K {
        static let appearance         = "livity.profile.appearance"
        static let distance           = "livity.profile.unit.distance"
        static let temperature        = "livity.profile.unit.temperature"
        static let energy             = "livity.profile.unit.energy"
        static let weight             = "livity.profile.unit.weight"
        static let water              = "livity.profile.unit.water"
        static let language           = "livity.profile.language"
        static let defaultTab         = "livity.profile.defaultTab"
        static let appIcon            = "livity.profile.appIcon"
        static let sleepGoalHours     = "livity.profile.sleepGoalHours"
        static let hrMaxSource        = "livity.profile.hrMaxSource"
        static let hrMaxManual        = "livity.profile.hrMaxManual"
        static let restingHRSource    = "livity.profile.restingHRSource"
        static let restingHRManual    = "livity.profile.restingHRManual"
        static let hrZoneMethod       = "livity.profile.hrZoneMethod"
        static let hrvMethod          = "livity.profile.hrvMethod"
        static let activityGoal       = "livity.profile.activityGoal"
        static let nutritionGoal      = "livity.profile.nutritionGoal"
        static let calorieAuto        = "livity.profile.calorieAuto"
        static let calorieManual      = "livity.profile.calorieManual"
        static let proteinAuto        = "livity.profile.proteinAuto"
        static let proteinManualG     = "livity.profile.proteinManualG"
        static let recoveryModeOn     = "livity.profile.recoveryModeOn"
        static let medAdjustOn        = "livity.profile.medAdjustOn"
        static let medType            = "livity.profile.medType"
        static let medBPMOffset       = "livity.profile.medBPMOffset"
        static let allowDataCompare   = "livity.profile.allowDataCompare"
        static let aiInsights         = "livity.profile.aiInsights"
        static let garminConnected    = "livity.profile.garminConnected"
        static let sleepSources       = "livity.profile.sleepSources"
        static let metricEnabledPrefix = "livity.profile.metric."
        static let alertEnabledPrefix  = "livity.profile.alert."
    }

    // Appearance
    @Published var appearance: LivityAppearance {
        didSet {
            d.set(appearance.rawValue, forKey: K.appearance)
            NotificationCenter.default.post(name: NSNotification.Name("LivityAppearanceChanged"), object: nil)
        }
    }

    // Units
    @Published var distance: LivityDistanceUnit  { didSet { d.set(distance.rawValue, forKey: K.distance) } }
    @Published var temperature: LivityTempUnit   { didSet { d.set(temperature.rawValue, forKey: K.temperature) } }
    @Published var energy: LivityEnergyUnit      { didSet { d.set(energy.rawValue, forKey: K.energy) } }
    @Published var weight: LivityWeightUnit      { didSet { d.set(weight.rawValue, forKey: K.weight) } }
    @Published var water: LivityWaterUnit        { didSet { d.set(water.rawValue, forKey: K.water) } }

    // Language / Default tab / App icon
    @Published var languageCode: String?         { didSet { d.set(languageCode, forKey: K.language) } }
    @Published var defaultTab: LivityDefaultTab  { didSet { d.set(defaultTab.rawValue, forKey: K.defaultTab) } }
    @Published var appIcon: LivityAppIcon        { didSet { d.set(appIcon.rawValue, forKey: K.appIcon) } }

    // Sleep
    @Published var sleepGoalHours: Double        { didSet { d.set(sleepGoalHours, forKey: K.sleepGoalHours) } }

    // Heart
    @Published var hrMaxSource: LivityHRMaxSource   { didSet { d.set(hrMaxSource.rawValue, forKey: K.hrMaxSource) } }
    @Published var hrMaxManual: Int                 { didSet { d.set(hrMaxManual, forKey: K.hrMaxManual) } }
    @Published var restingHRSource: LivityHRMaxSource { didSet { d.set(restingHRSource.rawValue, forKey: K.restingHRSource) } }
    @Published var restingHRManual: Int             { didSet { d.set(restingHRManual, forKey: K.restingHRManual) } }
    @Published var hrZoneMethod: LivityHRZoneMethod  { didSet { d.set(hrZoneMethod.rawValue, forKey: K.hrZoneMethod) } }

    // Recovery / Strain
    @Published var hrvMethod: LivityHRVMethod         { didSet { d.set(hrvMethod.rawValue, forKey: K.hrvMethod) } }
    @Published var activityGoal: LivityActivityGoal   { didSet { d.set(activityGoal.rawValue, forKey: K.activityGoal) } }

    // Nutrition
    @Published var nutritionGoal: LivityNutritionGoal { didSet { d.set(nutritionGoal.rawValue, forKey: K.nutritionGoal) } }
    @Published var calorieAuto: Bool                  { didSet { d.set(calorieAuto, forKey: K.calorieAuto) } }
    @Published var calorieManual: Int                 { didSet { d.set(calorieManual, forKey: K.calorieManual) } }
    @Published var proteinAuto: Bool                  { didSet { d.set(proteinAuto, forKey: K.proteinAuto) } }
    @Published var proteinManualG: Int                { didSet { d.set(proteinManualG, forKey: K.proteinManualG) } }

    // Recovery mode / medications
    @Published var recoveryModeOn: Bool               { didSet { d.set(recoveryModeOn, forKey: K.recoveryModeOn) } }
    @Published var medAdjustOn: Bool                  { didSet { d.set(medAdjustOn, forKey: K.medAdjustOn) } }
    @Published var medType: LivityMedicationType      { didSet { d.set(medType.rawValue, forKey: K.medType) } }
    @Published var medBPMOffset: Int                  { didSet { d.set(medBPMOffset, forKey: K.medBPMOffset) } }

    // Privacy & data
    @Published var allowDataCompare: Bool             { didSet { d.set(allowDataCompare, forKey: K.allowDataCompare) } }
    @Published var aiInsights: Bool                   { didSet { d.set(aiInsights, forKey: K.aiInsights) } }

    // Integrations
    @Published var garminConnected: Bool              { didSet { d.set(garminConnected, forKey: K.garminConnected) } }

    // Sleep sources (user-reorderable priority list)
    @Published var sleepSources: [LivitySleepSource]

    // Per-metric enabled/disabled map
    @Published var metricEnabled: [LivityHealthMetric: Bool]

    // Per-alert enabled map
    @Published var alertEnabled: [LivityAlertCategory: Bool]

    // MARK: - Init

    private init() {
        // Appearance / units
        appearance  = LivityAppearance(rawValue: UserDefaults.standard.string(forKey: K.appearance) ?? "") ?? .system
        distance    = LivityDistanceUnit(rawValue: UserDefaults.standard.string(forKey: K.distance) ?? "") ?? .kilometres
        temperature = LivityTempUnit(rawValue: UserDefaults.standard.string(forKey: K.temperature) ?? "") ?? .fahrenheit
        energy      = LivityEnergyUnit(rawValue: UserDefaults.standard.string(forKey: K.energy) ?? "") ?? .kcal
        weight      = LivityWeightUnit(rawValue: UserDefaults.standard.string(forKey: K.weight) ?? "") ?? .kilograms
        water       = LivityWaterUnit(rawValue: UserDefaults.standard.string(forKey: K.water) ?? "") ?? .litres

        languageCode = UserDefaults.standard.string(forKey: K.language)
        defaultTab   = LivityDefaultTab(rawValue: UserDefaults.standard.string(forKey: K.defaultTab) ?? "") ?? .overview
        appIcon      = LivityAppIcon(rawValue: UserDefaults.standard.string(forKey: K.appIcon) ?? "") ?? .primary

        let savedSleep = UserDefaults.standard.double(forKey: K.sleepGoalHours)
        sleepGoalHours = savedSleep > 0 ? savedSleep : 7.0

        hrMaxSource      = LivityHRMaxSource(rawValue: UserDefaults.standard.string(forKey: K.hrMaxSource) ?? "") ?? .auto
        hrMaxManual      = (UserDefaults.standard.object(forKey: K.hrMaxManual)      as? Int) ?? 180
        restingHRSource  = LivityHRMaxSource(rawValue: UserDefaults.standard.string(forKey: K.restingHRSource) ?? "") ?? .auto
        restingHRManual  = (UserDefaults.standard.object(forKey: K.restingHRManual)  as? Int) ?? 60
        hrZoneMethod     = LivityHRZoneMethod(rawValue: UserDefaults.standard.string(forKey: K.hrZoneMethod) ?? "") ?? .hrrApple

        hrvMethod    = LivityHRVMethod(rawValue: UserDefaults.standard.string(forKey: K.hrvMethod) ?? "") ?? .sdnn
        activityGoal = LivityActivityGoal(rawValue: UserDefaults.standard.string(forKey: K.activityGoal) ?? "") ?? .maintain

        nutritionGoal   = LivityNutritionGoal(rawValue: UserDefaults.standard.string(forKey: K.nutritionGoal) ?? "") ?? .maintenance
        calorieAuto     = (UserDefaults.standard.object(forKey: K.calorieAuto)  as? Bool) ?? true
        calorieManual   = (UserDefaults.standard.object(forKey: K.calorieManual) as? Int) ?? 2300
        proteinAuto     = (UserDefaults.standard.object(forKey: K.proteinAuto)   as? Bool) ?? true
        proteinManualG  = (UserDefaults.standard.object(forKey: K.proteinManualG) as? Int) ?? 140

        recoveryModeOn  = UserDefaults.standard.bool(forKey: K.recoveryModeOn)
        medAdjustOn     = UserDefaults.standard.bool(forKey: K.medAdjustOn)
        medType         = LivityMedicationType(rawValue: UserDefaults.standard.string(forKey: K.medType) ?? "") ?? .stimulant
        medBPMOffset    = (UserDefaults.standard.object(forKey: K.medBPMOffset) as? Int) ?? 5

        allowDataCompare = (UserDefaults.standard.object(forKey: K.allowDataCompare) as? Bool) ?? true
        aiInsights       = UserDefaults.standard.bool(forKey: K.aiInsights)

        garminConnected  = UserDefaults.standard.bool(forKey: K.garminConnected)

        // Sleep sources: decode JSON or fall back to a single Apple Watch entry.
        if let data = UserDefaults.standard.data(forKey: K.sleepSources),
           let decoded = try? JSONDecoder().decode([LivitySleepSource].self, from: data),
           !decoded.isEmpty {
            sleepSources = decoded
        } else {
            sleepSources = [
                LivitySleepSource(
                    id: "apple-watch",
                    title: "Apple Watch",
                    subtitle: "Apple Watch",
                    lastSync: "Last data: \(ProfileStore.shortDateString(Date()))",
                    isValid: true
                )
            ]
        }

        // Per-metric toggles
        var metrics: [LivityHealthMetric: Bool] = [:]
        for m in LivityHealthMetric.allCases {
            let key = K.metricEnabledPrefix + m.rawValue
            metrics[m] = (UserDefaults.standard.object(forKey: key) as? Bool) ?? true
        }
        metricEnabled = metrics

        // Per-alert toggles
        var alerts: [LivityAlertCategory: Bool] = [:]
        for a in LivityAlertCategory.allCases {
            let key = K.alertEnabledPrefix + a.rawValue
            alerts[a] = (UserDefaults.standard.object(forKey: key) as? Bool) ?? a.defaultOn
        }
        alertEnabled = alerts
    }

    // MARK: - Derived

    var calorieRecommended: Int { 2351 }          // shown in video; TDEE-derived placeholder
    var proteinRecommended: Int { 140 }

    // MARK: - Helpers

    func saveSleepSources() {
        if let data = try? JSONEncoder().encode(sleepSources) {
            d.set(data, forKey: K.sleepSources)
        }
    }

    func setMetricEnabled(_ metric: LivityHealthMetric, _ on: Bool) {
        metricEnabled[metric] = on
        d.set(on, forKey: K.metricEnabledPrefix + metric.rawValue)
    }

    func setAlertEnabled(_ alert: LivityAlertCategory, _ on: Bool) {
        alertEnabled[alert] = on
        d.set(on, forKey: K.alertEnabledPrefix + alert.rawValue)
    }

    static func shortDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy 'at' HH:mm"
        return f.string(from: date)
    }
}
