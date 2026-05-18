//
//  LivityPreferences.swift
//  Health Reporter
//
//  User-configurable goals and personalisation knobs used across the Livity UI.
//  Defaults follow widely-cited health guidelines (AASM, ISSN, ACSM) so that
//  the first-run experience is reasonable without inventing personalised numbers.
//

import Foundation

enum LivityActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary, light, moderate, active, veryActive
    var id: String { rawValue }

    var label: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }

    /// Multiplier applied to BMR to estimate TDEE (industry-standard PAL values).
    var palMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    /// Protein target in g/kg body weight per ISSN/ACSM consensus.
    var proteinGramsPerKg: Double {
        switch self {
        case .sedentary: return 0.8
        case .light: return 1.0
        case .moderate: return 1.4
        case .active: return 1.6
        case .veryActive: return 1.8
        }
    }

    /// Carbohydrate target in g/kg body weight (rough endurance-aware default).
    var carbsGramsPerKg: Double {
        switch self {
        case .sedentary: return 2.0
        case .light: return 2.5
        case .moderate: return 3.0
        case .active: return 4.0
        case .veryActive: return 5.0
        }
    }

    var fatGramsPerKg: Double { 1.0 }
}

final class LivityPreferences {
    static let shared = LivityPreferences()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let sleepGoalMinutes = "livity.pref.sleepGoalMinutes"
        static let wakeHour = "livity.pref.wakeHour"
        static let wakeMinute = "livity.pref.wakeMinute"
        static let daylightGoalMinutes = "livity.pref.daylightGoalMinutes"
        static let activityLevel = "livity.pref.activityLevel"
    }

    private init() {}

    /// Default 7h aligns with the AASM minimum recommendation for adults.
    var sleepGoalMinutes: Double {
        get {
            let stored = defaults.double(forKey: Key.sleepGoalMinutes)
            return stored > 0 ? stored : 7 * 60
        }
        set { defaults.set(newValue, forKey: Key.sleepGoalMinutes) }
    }

    /// Default wake target 07:00. Stored as 24h hour/minute pair.
    var wakeHour: Int {
        get { (defaults.object(forKey: Key.wakeHour) as? Int) ?? 7 }
        set { defaults.set(newValue, forKey: Key.wakeHour) }
    }
    var wakeMinute: Int {
        get { (defaults.object(forKey: Key.wakeMinute) as? Int) ?? 0 }
        set { defaults.set(newValue, forKey: Key.wakeMinute) }
    }

    /// Apple's Time-in-Daylight goal default (60 min/day, mid-range of 30–120
    /// commonly cited in chronobiology research).
    var daylightGoalMinutes: Int {
        get {
            let stored = defaults.integer(forKey: Key.daylightGoalMinutes)
            return stored > 0 ? stored : 60
        }
        set { defaults.set(newValue, forKey: Key.daylightGoalMinutes) }
    }

    var activityLevel: LivityActivityLevel {
        get {
            guard let raw = defaults.string(forKey: Key.activityLevel),
                  let level = LivityActivityLevel(rawValue: raw) else { return .moderate }
            return level
        }
        set { defaults.set(newValue.rawValue, forKey: Key.activityLevel) }
    }

    /// Whether the user has explicitly configured ANY preference, so the UI can
    /// distinguish "default" from "user-chosen" labels if it wants to.
    var hasAnyUserConfigured: Bool {
        defaults.object(forKey: Key.sleepGoalMinutes) != nil
        || defaults.object(forKey: Key.wakeHour) != nil
        || defaults.object(forKey: Key.daylightGoalMinutes) != nil
        || defaults.object(forKey: Key.activityLevel) != nil
    }

    func wakeTargetDate(for date: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = wakeHour
        comps.minute = wakeMinute
        return Calendar.current.date(from: comps) ?? date
    }
}
