//
//  ActivityRingsView.swift
//  Health Reporter Watch App
//
//  Displays Activity Rings (Move, Exercise, Stand)

import SwiftUI

struct ActivityRingsView: View {
    @EnvironmentObject var dataManager: WatchDataManager

    private var data: WatchHealthData {
        dataManager.healthData
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Activity Rings
                ZStack {
                    // Move Ring (outermost)
                    RingProgressView(
                        progress: data.moveProgress,
                        color: .red,
                        lineWidth: 12
                    )
                    .frame(width: 100, height: 100)

                    // Exercise Ring (middle)
                    RingProgressView(
                        progress: data.exerciseProgress,
                        color: .green,
                        lineWidth: 12
                    )
                    .frame(width: 74, height: 74)

                    // Stand Ring (innermost)
                    RingProgressView(
                        progress: data.standProgress,
                        color: .cyan,
                        lineWidth: 12
                    )
                    .frame(width: 48, height: 48)
                }
                .padding(.top, 8)

                // Ring Stats
                VStack(spacing: 8) {
                    RingStatRow(
                        color: .red,
                        label: "watch.activity.move".localized,
                        value: "\(data.moveCalories)",
                        goal: "\(data.moveGoal)",
                        unit: "cal"
                    )

                    RingStatRow(
                        color: .green,
                        label: "watch.activity.exercise".localized,
                        value: "\(data.exerciseMinutes)",
                        goal: "\(data.exerciseGoal)",
                        unit: "min"
                    )

                    RingStatRow(
                        color: .cyan,
                        label: "watch.activity.stand".localized,
                        value: "\(data.standHours)",
                        goal: "\(data.standGoal)",
                        unit: "hrs"
                    )
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

// MARK: - Ring Progress View

struct RingProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if progress > 1.0 {
                Circle()
                    .trim(from: 0, to: min(progress - 1.0, 1.0))
                    .stroke(
                        color.opacity(0.5),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

// MARK: - Ring Stat Row

struct RingStatRow: View {
    let color: Color
    let label: String
    let value: String
    let goal: String
    let unit: String

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.gray)

            Spacer()

            Text("\(value)/\(goal)")
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.white)

            Text(unit)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityRingsView()
        .environmentObject(WatchDataManager.shared)
}
