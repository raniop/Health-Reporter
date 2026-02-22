//
//  HomeMetricSelection.swift
//  Health Reporter
//
//  Persists which metrics the user chose for the home screen
//  (1 hero + 4–6 secondary).
//

import Foundation

struct HomeMetricSelection: Codable, Equatable {
    var heroMetricId: String
    var secondaryMetricIds: [String]   // 4–6 items

    // MARK: - Limits

    static let minSecondaryCount = 4
    static let maxSecondaryCount = 6

    var isValid: Bool {
        (Self.minSecondaryCount...Self.maxSecondaryCount).contains(secondaryMetricIds.count)
    }

    // MARK: - Defaults

    static let defaultSelection = HomeMetricSelection(
        heroMetricId: "main_score",
        secondaryMetricIds: [
            "sleep_quality",
            "recovery_readiness",
            "energy_forecast",
            "training_strain"
        ]
    )

    // MARK: - All available metric IDs (for the picker)

    static let allAvailableMetrics: [(id: String, nameKey: String, iconName: String, category: String)] = [
        ("main_score",              "dashboard.healthScore",            "battery.100.bolt",                      "hero"),
        ("nervous_system_balance",  "metric.nervous_system_balance",    "waveform.path.ecg",                     "recovery"),
        ("recovery_readiness",      "metric.recovery_readiness",        "heart.circle",                          "recovery"),
        ("recovery_debt",           "metric.recovery_debt",             "arrow.up.arrow.down.circle",            "recovery"),
        ("stress_load_index",       "metric.stress_load_index",         "brain.head.profile",                    "stress"),
        ("morning_freshness",       "metric.morning_freshness",         "sun.horizon.fill",                      "recovery"),
        ("sleep_quality",           "metric.sleep_quality",             "moon.zzz.fill",                         "sleep"),
        ("sleep_consistency",       "metric.sleep_consistency",         "clock.badge.checkmark",                 "sleep"),
        ("sleep_debt",              "metric.sleep_debt",                "bed.double.fill",                       "sleep"),
        ("training_strain",         "metric.training_strain",           "flame.fill",                            "load"),
        ("load_balance",            "metric.load_balance",              "scale.3d",                              "load"),
        ("energy_forecast",         "metric.energy_forecast",           "bolt.fill",                             "performance"),
        ("workout_readiness",       "metric.workout_readiness",         "figure.strengthtraining.traditional",   "performance"),
        ("activity_score",          "metric.activity_score",            "figure.walk",                           "activity"),
        ("daily_goals",             "metric.daily_goals",               "target",                                "activity"),
        ("cardio_fitness_trend",    "metric.cardio_fitness_trend",      "heart.text.square",                     "performance"),
    ]

    // MARK: - Persistence

    private static let key = "HomeMetricSelection_v1"

    static func load() -> HomeMetricSelection {
        guard let data = UserDefaults.standard.data(forKey: key),
              let selection = try? JSONDecoder().decode(HomeMetricSelection.self, from: data)
        else {
            return .defaultSelection
        }
        return selection
    }

    static func save(_ selection: HomeMetricSelection) {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func reset() {
        save(.defaultSelection)
    }

    // MARK: - Helpers

    /// Returns the icon name for a given metric ID
    static func iconName(for metricId: String) -> String {
        allAvailableMetrics.first(where: { $0.id == metricId })?.iconName ?? "star.fill"
    }

    /// Returns the localized name key for a given metric ID
    static func nameKey(for metricId: String) -> String {
        allAvailableMetrics.first(where: { $0.id == metricId })?.nameKey ?? metricId
    }
}
