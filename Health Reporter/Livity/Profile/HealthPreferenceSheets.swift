//
//  HealthPreferenceSheets.swift
//  Health Reporter
//
//  Every health-preference sheet presented from Health Preferences hub:
//  Sleep Goal, Heart Preferences, Recovery Preferences (HRV method),
//  Strain (Activity Goal), Nutrition Preferences, Recovery Mode, Medications.
//

import SwiftUI

// MARK: - Sleep Goal

struct LivitySleepGoalSheet: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivitySheetChrome(title: "Sleep Goal") {
            VStack(spacing: 18) {
                LivityHeroBlock(
                    icon: "moon.stars.fill",
                    tint: LivityTheme.info,
                    title: "Sleep Duration Goal",
                    subtitle: "Adjust your ideal sleep duration to help maintain healthy sleep patterns"
                )

                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(LivityTheme.info.opacity(0.55), lineWidth: 1.2)
                            .frame(width: 170, height: 64)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "%.1f", store.sleepGoalHours))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(LivityTheme.info)
                            Text("hours")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }

                    Slider(value: Binding(
                        get: { store.sleepGoalHours },
                        set: { store.sleepGoalHours = (round($0 * 2) / 2) }
                    ), in: 5.0...11.0, step: 0.5)
                        .tint(LivityTheme.info)

                    HStack {
                        Text("5h").foregroundStyle(LivityTheme.textSecondary)
                        Spacer()
                        Text("8h")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(LivityTheme.info))
                        Spacer()
                        Text("11h").foregroundStyle(LivityTheme.textSecondary)
                    }
                    .font(.system(size: 13))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                        .fill(LivityTheme.cardFill)
                )

                LivityInfoBanner(
                    icon: "lightbulb.fill",
                    iconColor: LivityTheme.info,
                    title: "Recommended Sleep Duration",
                    body: "Most adults need 7–9 hours of quality sleep per night for optimal health and wellbeing."
                )
            }
        }
    }
}

// MARK: - Heart Preferences

struct LivityHeartPreferencesSheet: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivitySheetChrome(title: "Heart Preferences") {
            VStack(alignment: .leading, spacing: 18) {
                // Max HR card
                maxHRCard
                // Resting HR
                restingHRCard
                // HR Zones
                zonesCard

                Button {
                    // Info action placeholder
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(LivityTheme.info)
                        Text("How to choose the best option?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LivityTheme.info)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LivityTheme.info)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                            .fill(LivityTheme.info.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var maxHRCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LivityTheme.info)
                Text("Maximum Heart Rate")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
            Text("Choose how your maximum heart rate is determined")
                .font(.system(size: 13))
                .foregroundStyle(LivityTheme.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Source")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                    LivitySegmented(
                        selection: Binding(
                            get: { store.hrMaxSource },
                            set: { store.hrMaxSource = $0 }
                        ),
                        titleFor: { $0.label }
                    )
                    .frame(maxWidth: 170)
                }

                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Circle().fill(LivityTheme.good).frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Age Formula")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(LivityTheme.textPrimary)
                            Text("Tanaka: 208 − (0.7 × age)")
                                .font(.system(size: 12))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                    Spacer()
                    LivityNumberUnit(number: "\(store.hrMaxManual)", unit: "BPM")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                    .fill(LivityTheme.chipFill.opacity(0.6))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }

    private var restingHRCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LivityTheme.info)
                Text("Resting Heart Rate")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
            Text("Used for Heart Rate Reserve calculation")
                .font(.system(size: 13))
                .foregroundStyle(LivityTheme.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Source")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                    LivitySegmented(
                        selection: Binding(
                            get: { store.restingHRSource },
                            set: { store.restingHRSource = $0 }
                        ),
                        titleFor: { $0.label }
                    )
                    .frame(maxWidth: 170)
                }

                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(LivityTheme.good).frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("From Apple Health")
                                .font(.system(size: 14))
                                .foregroundStyle(LivityTheme.textPrimary)
                            Text("Apple Watch resting heart rate")
                                .font(.system(size: 12))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                    Spacer()
                    LivityNumberUnit(number: "\(store.restingHRManual)", unit: "BPM")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                    .fill(LivityTheme.chipFill.opacity(0.6))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }

    private var zonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LivityTheme.info)
                Text("Heart Rate Zones")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
            Text("Choose how your training zones are calculated")
                .font(.system(size: 13))
                .foregroundStyle(LivityTheme.textSecondary)

            LivitySegmented(
                selection: Binding(
                    get: { store.hrZoneMethod },
                    set: { store.hrZoneMethod = $0 }
                ),
                titleFor: { $0.label }
            )

            // Zone spectrum bars
            HStack(spacing: 4) {
                ForEach(Array(zoneColors.enumerated()), id: \.offset) { _, c in
                    Capsule().fill(c).frame(height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(zonesData.enumerated()), id: \.offset) { index, zone in
                    zoneRow(index: index + 1, color: zoneColors[index], data: zone)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }

    private let zoneColors: [Color] = [
        LivityTheme.good, LivityTheme.caution,
        LivityTheme.warning, LivityTheme.bad, LivityTheme.purple
    ]

    private var zonesData: [(label: String, range: String, percent: String?, bpm: String)] {
        [
            ("Zone 1", "<128 bpm",     nil,       "—"),
            ("Zone 2", "129-140 bpm",  "71%",     "129"),
            ("Zone 3", "141-153 bpm",  "78%",     "141"),
            ("Zone 4", "154-166 bpm",  "85%",     "154"),
            ("Zone 5", "≥167 bpm",     "92%",     "167")
        ]
    }

    @ViewBuilder
    private func zoneRow(index: Int, color: Color, data: (label: String, range: String, percent: String?, bpm: String)) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(color).frame(width: 3, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text(data.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(data.range)
                    .font(.system(size: 12))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Spacer()
            if let p = data.percent {
                Text(p)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(color.opacity(0.18)))
            }
            if data.bpm != "—" {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(data.bpm)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("BPM")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Recovery Preferences (HRV method)

struct LivityRecoveryPreferencesSheet: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivitySheetChrome(title: "Recovery Preferences") {
            VStack(alignment: .leading, spacing: 14) {
                Text("HRV Measurement Method")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text("Choose how your Heart Rate Variability is calculated")
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)

                ForEach(LivityHRVMethod.allCases) { method in
                    methodCard(method)
                }
            }
        }
    }

    @ViewBuilder
    private func methodCard(_ method: LivityHRVMethod) -> some View {
        let selected = store.hrvMethod == method
        Button { store.hrvMethod = method } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(method.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                    Image(systemName: selected ? "circle.inset.filled" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? LivityTheme.info : LivityTheme.textTertiary)
                }
                Text(method.blurb)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                    .fill(selected ? LivityTheme.info.opacity(0.1) : LivityTheme.cardFill)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Strain Preferences (Activity Goal)

struct LivityStrainPreferencesSheet: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivitySheetChrome(title: "Activity Goal") {
            VStack(alignment: .leading, spacing: 14) {
                LivityHeroBlock(
                    icon: "figure.run",
                    tint: LivityTheme.info,
                    title: "Set Your Activity Goal",
                    subtitle: "Your selection helps us personalize your daily strain target based on your recovery state"
                )

                HStack(spacing: 8) {
                    Image(systemName: "circle.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                    Text("Select Your Goal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                }
                .padding(.top, 4)

                ForEach(LivityActivityGoal.allCases) { goal in
                    LivityRadioCard(
                        icon: goal.icon,
                        iconColor: LivityTheme.info,
                        title: goal.title,
                        subtitle: goal.subtitle,
                        isSelected: store.activityGoal == goal
                    ) { store.activityGoal = goal }
                }
            }
        }
    }
}

// MARK: - Nutrition Preferences

struct LivityNutritionPreferencesSheet: View {
    @StateObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LivitySheetChrome(
            title: "Nutrition Preferences",
            trailingActionLabel: "Save",
            trailingAction: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                LivityHeroBlock(
                    icon: "fork.knife",
                    tint: LivityTheme.good,
                    title: "Set Your Nutrition Goal",
                    subtitle: "Your goal shapes calorie and protein targets to match your lifestyle and body composition preferences"
                )

                HStack(spacing: 8) {
                    Image(systemName: "circle.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.good)
                    Text("Nutrition Goal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                }

                VStack(spacing: 10) {
                    ForEach(LivityNutritionGoal.allCases) { goal in
                        LivityRadioCard(
                            icon: goal.icon,
                            iconColor: LivityTheme.good,
                            title: goal.title,
                            subtitle: goal.subtitle,
                            isSelected: store.nutritionGoal == goal
                        ) { store.nutritionGoal = goal }
                    }
                }

                calorieCard
                proteinCard
            }
        }
    }

    private var calorieCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.warning)
                Text("Daily Calorie Goal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }

            LivitySegmented(
                selection: Binding(
                    get: { store.calorieAuto ? AutoManual.auto : .manual },
                    set: { store.calorieAuto = ($0 == .auto) }
                ),
                titleFor: { $0.label }
            )

            if store.calorieAuto {
                VStack(alignment: .center, spacing: 3) {
                    Text("Uses your TDEE calculation")
                        .font(.system(size: 13))
                        .foregroundStyle(LivityTheme.textSecondary)
                    Text("Recommended: \(store.calorieRecommended) kcal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.good)
                    Text("Based on lightly active estimate")
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Spacer()
                    Text("\(store.calorieManual)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(LivityTheme.good)
                    Text("kcal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LivityTheme.textSecondary)
                    Spacer()
                }
                Slider(value: Binding(
                    get: { Double(store.calorieManual) },
                    set: { store.calorieManual = Int($0) }
                ), in: 1200...4500, step: 25)
                    .tint(LivityTheme.good)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }

    private var proteinCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.good)
                Text("Daily Protein Goal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }

            LivitySegmented(
                selection: Binding(
                    get: { store.proteinAuto ? AutoManual.auto : .manual },
                    set: { store.proteinAuto = ($0 == .auto) }
                ),
                titleFor: { $0.label }
            )

            if store.proteinAuto {
                Text("Calculated from your weight and activity level")
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Spacer()
                    Text("\(store.proteinManualG)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(LivityTheme.good)
                    Text("g")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LivityTheme.textSecondary)
                    Spacer()
                }
                Slider(value: Binding(
                    get: { Double(store.proteinManualG) },
                    set: { store.proteinManualG = Int($0) }
                ), in: 40...280, step: 5)
                    .tint(LivityTheme.good)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }
}

private enum AutoManual: String, CaseIterable, Identifiable {
    case auto, manual
    var id: String { rawValue }
    var label: String { self == .auto ? "Auto" : "Manual" }
}

// MARK: - Recovery Mode

struct LivityRecoveryModeSheet: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivitySheetChrome(title: "Recovery Mode") {
            VStack(alignment: .leading, spacing: 16) {
                LivityHeroBlock(
                    icon: "bandage.fill",
                    tint: LivityTheme.info,
                    title: "Recovery Mode",
                    subtitle: "Temporarily soften strain and activity targets while you heal from an injury or illness."
                )

                LivityGroupedCard {
                    LivityListRow(
                        icon: "power",
                        iconColor: LivityTheme.info,
                        title: "Recovery Mode",
                        subtitle: store.recoveryModeOn ? "Active — metrics are softened" : "Off",
                        accessory: .toggle(Binding(
                            get: { store.recoveryModeOn },
                            set: { store.recoveryModeOn = $0 }
                        ))
                    )
                }

                LivityInfoBanner(
                    icon: "info.circle.fill",
                    iconColor: LivityTheme.info,
                    title: "How it works",
                    body: "With Recovery Mode on, Livity lowers your daily strain target, scales HR-zone weighting, and surfaces gentler suggestions until you toggle it off."
                )
            }
        }
    }
}

// MARK: - Medications

struct LivityMedicationsSheet: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivitySheetChrome(title: "Medications") {
            VStack(alignment: .leading, spacing: 16) {
                LivityHeroBlock(
                    icon: "pills.fill",
                    tint: LivityTheme.warning,
                    title: "Medication & Heart Rate",
                    subtitle: "Some medications affect your resting heart rate. Livity can adjust your metrics to reflect your true cardiovascular fitness."
                )

                LivityGroupedCard {
                    LivityListRow(
                        icon: "pills.fill",
                        iconColor: LivityTheme.warning,
                        title: "Adjust for Medication",
                        subtitle: "Correct heart rate metrics for medication effects",
                        accessory: .toggle(Binding(
                            get: { store.medAdjustOn },
                            set: { store.medAdjustOn = $0 }
                        ))
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivityTheme.textSecondary)
                    Text("Medication Type")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Spacer()
                }

                LivityGroupedCard {
                    ForEach(Array(LivityMedicationType.allCases.enumerated()), id: \.element.id) { idx, type in
                        LivityListRow(
                            icon: type.icon,
                            iconColor: LivityTheme.warning,
                            title: type.title,
                            subtitle: type.subtitle,
                            accessory: .radio(store.medType == type)
                        ) { store.medType = type }
                        if idx < LivityMedicationType.allCases.count - 1 { LivityRowSeparator() }
                    }
                }

                effectCard
                affectedMetricsCard

                LivityInfoBanner(
                    icon: "exclamationmark.circle.fill",
                    iconColor: LivityTheme.warning,
                    title: "This does not modify your stored heart rate data.",
                    body: "It only adjusts how Livity interprets your resting heart rate for scoring."
                )
            }
        }
    }

    private var effectCard: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LivityTheme.warning.opacity(0.55), lineWidth: 1.2)
                    .frame(width: 170, height: 56)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatOffset(store.medBPMOffset))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(LivityTheme.warning)
                    Text("BPM")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }

            Text(effectDescription)
                .font(.system(size: 13))
                .foregroundStyle(LivityTheme.textSecondary)

            Slider(value: Binding(
                get: { Double(store.medBPMOffset) },
                set: { store.medBPMOffset = Int($0.rounded()) }
            ), in: -20...20, step: 1)
                .tint(LivityTheme.warning)

            HStack {
                Text("1").foregroundStyle(LivityTheme.textSecondary)
                Spacer()
                Text("Typical: 3–10")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivityTheme.warning)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(LivityTheme.warning.opacity(0.18)))
                Spacer()
                Text("20").foregroundStyle(LivityTheme.textSecondary)
            }
            .font(.system(size: 13))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }

    private var affectedMetricsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivityTheme.textSecondary)
                Text("Affected Metrics")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }
            metricRow(icon: "heart.fill",               color: LivityTheme.bad,     label: "Recovery",        value: "Baseline adjusted")
            LivityRowSeparator()
            metricRow(icon: "flame.fill",               color: LivityTheme.warning, label: "Strain",          value: "HR zones shift up")
            LivityRowSeparator()
            metricRow(icon: "figure.run",               color: LivityTheme.good,    label: "Fitness Age",     value: "-0.5 years")
            LivityRowSeparator()
            metricRow(icon: "battery.100.bolt",         color: LivityTheme.info,    label: "Body Battery",    value: "Drain rate adjusted")
            LivityRowSeparator()
            metricRow(icon: "chart.bar.doc.horizontal", color: LivityTheme.info,    label: "Heart Rate Zones", value: "+5 BPM shift")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }

    @ViewBuilder
    private func metricRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label).font(.system(size: 15)).foregroundStyle(LivityTheme.textPrimary)
            Spacer()
            Text(value).font(.system(size: 13)).foregroundStyle(LivityTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var effectDescription: String {
        let v = store.medBPMOffset
        if v > 0 { return "Raises heart rate" }
        if v < 0 { return "Lowers heart rate" }
        return "No adjustment"
    }

    private func formatOffset(_ v: Int) -> String {
        if v > 0 { return "+\(v)" }
        return "\(v)"
    }
}
