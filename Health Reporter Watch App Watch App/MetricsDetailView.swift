//
//  MetricsDetailView.swift
//  Health Reporter Watch App
//
//  Scrollable list of detailed health metrics

import SwiftUI

struct MetricsDetailView: View {
    @EnvironmentObject var dataManager: WatchDataManager

    private var data: WatchHealthData {
        dataManager.healthData
    }

    private var isEmpty: Bool {
        !data.isFromPhone &&
        data.heartRate == 0 && data.steps == 0 &&
        data.moveCalories == 0 && data.sleepHours == 0
    }

    var body: some View {
        Group {
            if dataManager.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("watch.status.waiting".localized)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            } else if isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.title2)
                        .foregroundStyle(.gray)
                    Text("watch.status.waitingForData".localized)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
            } else {
                metricsList
            }
        }
    }

    private var metricsList: some View {
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
                    .foregroundStyle(.red)
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
                    .foregroundStyle(.purple)
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
                    .foregroundStyle(.green)
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
                    .foregroundStyle(.blue)
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
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.gray)

            Spacer()

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.gray)
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
