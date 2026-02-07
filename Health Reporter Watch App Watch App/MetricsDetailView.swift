//
//  MetricsDetailView.swift
//  Health Reporter Watch App
//
//  Scrollable list of detailed health metrics
//

import SwiftUI

struct MetricsDetailView: View {
    @EnvironmentObject var dataManager: WatchDataManager

    private var data: WatchHealthData {
        dataManager.healthData
    }

    var body: some View {
        let _ = print("⌚️ MetricsDetailView: exercise=\(data.exerciseMinutes), stand=\(data.standHours), isFromPhone=\(data.isFromPhone)")
        List {
            // Heart Section
            Section {
                MetricRow(
                    icon: "heart.fill",
                    iconColor: .red,
                    label: "watch.metrics.heartRate".localized,
                    value: "\(data.heartRate)",
                    unit: "bpm"
                )

                MetricRow(
                    icon: "heart.text.square.fill",
                    iconColor: .pink,
                    label: "watch.metrics.restingHeartRate".localized,
                    value: "\(data.restingHeartRate)",
                    unit: "bpm"
                )

                MetricRow(
                    icon: "waveform.path.ecg",
                    iconColor: .purple,
                    label: "HRV",
                    value: "\(data.hrv)",
                    unit: "ms"
                )
            } header: {
                Label("watch.metrics.sectionHeart".localized, systemImage: "heart.fill")
                    .foregroundColor(.red)
            }

            // Sleep Section
            Section {
                MetricRow(
                    icon: "bed.double.fill",
                    iconColor: .purple,
                    label: "watch.metrics.sleep".localized,
                    value: data.formattedSleepHours,
                    unit: ""
                )
            } header: {
                Label("watch.metrics.sectionSleep".localized, systemImage: "moon.fill")
                    .foregroundColor(.purple)
            }

            // Activity Section
            Section {
                MetricRow(
                    icon: "figure.walk",
                    iconColor: .green,
                    label: "watch.metrics.steps".localized,
                    value: formatNumber(data.steps),
                    unit: ""
                )

                MetricRow(
                    icon: "flame.fill",
                    iconColor: .orange,
                    label: "watch.metrics.calories".localized,
                    value: "\(data.moveCalories)",
                    unit: "kcal"
                )

                MetricRow(
                    icon: "figure.run",
                    iconColor: .green,
                    label: "watch.metrics.exercise".localized,
                    value: "\(data.exerciseMinutes)",
                    unit: "watch.metrics.exerciseUnit".localized
                )

                MetricRow(
                    icon: "figure.stand",
                    iconColor: .cyan,
                    label: "watch.metrics.standing".localized,
                    value: "\(data.standHours)",
                    unit: "watch.metrics.standingUnit".localized
                )
            } header: {
                Label("watch.metrics.sectionActivity".localized, systemImage: "figure.walk")
                    .foregroundColor(.green)
            }

            // Score Section
            Section {
                MetricRow(
                    icon: "chart.bar.fill",
                    iconColor: .blue,
                    label: "watch.metrics.healthScore".localized,
                    value: "\(data.healthScore)",
                    unit: "/100"
                )

                MetricRow(
                    icon: "checkmark.shield.fill",
                    iconColor: .teal,
                    label: "watch.metrics.reliability".localized,
                    value: "\(data.reliabilityScore)",
                    unit: "%"
                )
            } header: {
                Label("watch.metrics.sectionScore".localized, systemImage: "chart.bar.fill")
                    .foregroundColor(.blue)
            }
        }
        .listStyle(.carousel)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.gray)

            Spacer()

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MetricsDetailView()
        .environmentObject(WatchDataManager.shared)
}
