//
//  ScoreBreakdownView.swift
//  Health Reporter Watch App
//
//  Shows breakdown of health score components

import SwiftUI

struct ScoreBreakdownView: View {
    @EnvironmentObject var dataManager: WatchDataManager

    private var data: WatchHealthData {
        dataManager.healthData
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with score
                VStack(spacing: 4) {
                    Text("\(data.healthScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("watch.scoreBreakdown.title".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.gray)
                }
                .padding(.bottom, 8)

                // Score components
                VStack(spacing: 8) {
                    ScoreRow(
                        icon: "heart.fill",
                        name: "watch.scoreBreakdown.recovery".localized,
                        value: data.recoveryScore,
                        weight: 25,
                        color: .red
                    )

                    ScoreRow(
                        icon: "bed.double.fill",
                        name: "watch.scoreBreakdown.sleepQuality".localized,
                        value: data.sleepScore,
                        weight: 20,
                        color: .purple
                    )

                    ScoreRow(
                        icon: "waveform.path.ecg",
                        name: "watch.scoreBreakdown.nervousSystem".localized,
                        value: data.nervousSystemScore,
                        weight: 20,
                        color: .cyan
                    )

                    ScoreRow(
                        icon: "bolt.fill",
                        name: "watch.scoreBreakdown.energyForecast".localized,
                        value: data.energyScore,
                        weight: 15,
                        color: .yellow
                    )

                    ScoreRow(
                        icon: "figure.walk",
                        name: "watch.scoreBreakdown.activity".localized,
                        value: data.activityScore,
                        weight: 10,
                        color: .green
                    )

                    ScoreRow(
                        icon: "chart.bar.fill",
                        name: "watch.scoreBreakdown.loadBalance".localized,
                        value: data.loadBalanceScore,
                        weight: 10,
                        color: .orange
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Score Row

struct ScoreRow: View {
    let icon: String
    let name: String
    let value: Int?
    let weight: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                if let v = value {
                    Text("\(v)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("--")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.gray)
                }

                Text("(\(weight)%)")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    ScoreBreakdownView()
        .environmentObject(WatchDataManager.shared)
}
