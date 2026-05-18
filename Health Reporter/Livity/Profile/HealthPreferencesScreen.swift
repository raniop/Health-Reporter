//
//  HealthPreferencesScreen.swift
//  Health Reporter
//
//  Health "Customization" hub: list of preference sheets (Sleep, Heart,
//  Recovery, Strain, Nutrition, Recovery Mode, Medications) + Data sources.
//

import SwiftUI

struct LivityHealthPreferencesScreen: View {
    @Binding var path: NavigationPath
    @StateObject private var store = ProfileStore.shared

    enum Sheet: Identifiable {
        case sleep, heart, recovery, strain, nutrition, recoveryMode, medications
        case sleepSources, healthSources
        var id: Int { hashValue }
    }
    @State private var sheet: Sheet?

    var body: some View {
        LivityScreenChrome(title: "Customization") {
            VStack(alignment: .leading, spacing: 16) {
                preferencesGroup
                dataGroup
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .sleep:          LivitySleepGoalSheet()
            case .heart:          LivityHeartPreferencesSheet()
            case .recovery:       LivityRecoveryPreferencesSheet()
            case .strain:         LivityStrainPreferencesSheet()
            case .nutrition:      LivityNutritionPreferencesSheet()
            case .recoveryMode:   LivityRecoveryModeSheet()
            case .medications:    LivityMedicationsSheet()
            case .sleepSources:   LivitySleepDataSourcesSheet()
            case .healthSources:  LivityHealthDataSourcesSheet()
            }
        }
    }

    private var preferencesGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            LivityGroupLabel(icon: "slider.horizontal.3", text: "Preferences")
            LivityGroupedCard {
                LivityListRow(
                    icon: "bed.double.fill",
                    iconColor: LivityTheme.info,
                    title: "Sleep Thresholds",
                    subtitle: "Customize your sleep tracking preferences",
                    accessory: .chevron
                ) { sheet = .sleep }
                LivityRowSeparator()
                LivityListRow(
                    icon: "heart.fill",
                    iconColor: LivityTheme.bad,
                    title: "Heart Preferences",
                    subtitle: "Configure heart rate monitoring",
                    accessory: .chevron
                ) { sheet = .heart }
                LivityRowSeparator()
                LivityListRow(
                    icon: "leaf.fill",
                    iconColor: LivityTheme.good,
                    title: "Recovery Preferences",
                    subtitle: "Adjust recovery tracking settings",
                    accessory: .chevron
                ) { sheet = .recovery }
                LivityRowSeparator()
                LivityListRow(
                    icon: "flame.fill",
                    iconColor: LivityTheme.warning,
                    title: "Strain Preferences",
                    subtitle: "Adjust strain calculation settings",
                    accessory: .chevron
                ) { sheet = .strain }
                LivityRowSeparator()
                LivityListRow(
                    icon: "fork.knife.circle.fill",
                    iconColor: LivityTheme.good,
                    title: "Nutrition Preferences",
                    subtitle: "Set calorie goal, nutrition goal type and targets",
                    accessory: .chevron
                ) { sheet = .nutrition }
                LivityRowSeparator()
                LivityListRow(
                    icon: "bandage.fill",
                    iconColor: LivityTheme.info,
                    title: "Recovery Mode",
                    subtitle: "For injury or sickness recovery",
                    accessory: .chevron
                ) { sheet = .recoveryMode }
                LivityRowSeparator()
                medicationsRow
            }
        }
    }

    private var medicationsRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LivityTheme.warning.opacity(0.18)).frame(width: 30, height: 30)
                Image(systemName: "pills.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.warning)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Medications")
                        .font(.system(size: 16))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("NEW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(LivityTheme.info))
                }
                Text(store.medAdjustOn
                     ? "\(store.medType.title) \(formatOffset(store.medBPMOffset)) BPM"
                     : "Adjust metrics for medication effects")
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LivityTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
        .onTapGesture { sheet = .medications }
    }

    private func formatOffset(_ v: Int) -> String {
        v >= 0 ? "+\(v)" : "\(v)"
    }

    private var dataGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            LivityGroupLabel(icon: "arrow.triangle.2.circlepath", text: "Data")
            LivityGroupedCard {
                LivityListRow(
                    icon: "square.stack.3d.up.fill",
                    iconColor: LivityTheme.info,
                    title: "Sleep Data Source",
                    subtitle: "Select prefered sleep data source",
                    accessory: .chevron
                ) { sheet = .sleepSources }
                LivityRowSeparator()
                LivityListRow(
                    icon: "square.grid.2x2.fill",
                    iconColor: LivityTheme.info,
                    title: "Health Data Source",
                    subtitle: "Select source for steps, heart rate, energy",
                    accessory: .chevron
                ) { sheet = .healthSources }
                LivityRowSeparator()
                LivityListRow(
                    icon: "arrow.clockwise",
                    iconColor: LivityTheme.good,
                    title: "Reload Data",
                    subtitle: "Force refresh all your health data",
                    accessory: .chevron
                ) {
                    HealthKitManager.shared.requestAuthorization { _, _ in }
                }
            }
        }
    }
}
