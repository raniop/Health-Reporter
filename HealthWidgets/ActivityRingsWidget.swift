//
//  ActivityRingsWidget.swift
//  HealthWidgets
//
//  Activity rings widget showing Move, Exercise, and Stand progress.
//  Rebuilt from scratch.
//

import WidgetKit
import SwiftUI

// MARK: - Activity Rings Widget

struct ActivityRingsWidget: Widget {
    let kind: String = "ActivityRingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                ActivityRingsWidgetView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                ActivityRingsWidgetView(entry: entry)
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Activity Rings")
        .description("Move, Exercise and Stand progress")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Router View

struct ActivityRingsWidgetView: View {
    var entry: HealthEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallActivityRingsView(data: entry.data)
        case .systemMedium:
            MediumActivityRingsView(data: entry.data)
        default:
            SmallActivityRingsView(data: entry.data)
        }
    }
}

// MARK: - Small Activity Rings View

struct SmallActivityRingsView: View {
    let data: HealthWidgetData

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 8) {
                ActivityRings(data: data, outerSize: 80, lineWidth: 10)

                // Compact stats
                HStack(spacing: 10) {
                    VStack(spacing: 1) {
                        Text("\(data.calories)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.pink)
                        Text("kcal")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.pink.opacity(0.6))
                    }

                    VStack(spacing: 1) {
                        Text("\(data.exerciseMinutes)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("min")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.green.opacity(0.6))
                    }

                    VStack(spacing: 1) {
                        Text("\(data.standHours)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                        Text("hrs")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.6))
                    }
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Medium Activity Rings View

struct MediumActivityRingsView: View {
    let data: HealthWidgetData

    private func progressPercent(_ current: Int, _ goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        return min(Int(Double(current) / Double(goal) * 100), 999)
    }

    var body: some View {
        ZStack {
            Color.black

            HStack(spacing: 20) {
                // Rings
                ActivityRings(data: data, outerSize: 110, lineWidth: 12)
                    .frame(width: 110, height: 110)

                // Stats column
                VStack(alignment: .leading, spacing: 12) {
                    ActivityRow(
                        icon: "flame.fill",
                        label: "Move",
                        value: "\(data.calories)",
                        goal: "\(data.caloriesGoal)",
                        unit: "kcal",
                        percent: progressPercent(data.calories, data.caloriesGoal),
                        color: .pink
                    )

                    ActivityRow(
                        icon: "figure.run",
                        label: "Exercise",
                        value: "\(data.exerciseMinutes)",
                        goal: "\(data.exerciseGoal)",
                        unit: "min",
                        percent: progressPercent(data.exerciseMinutes, data.exerciseGoal),
                        color: .green
                    )

                    ActivityRow(
                        icon: "figure.stand",
                        label: "Stand",
                        value: "\(data.standHours)",
                        goal: "\(data.standGoal)",
                        unit: "hrs",
                        percent: progressPercent(data.standHours, data.standGoal),
                        color: .cyan
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let icon: String
    let label: String
    let value: String
    let goal: String
    let unit: String
    let percent: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/ \(goal) \(unit)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }

                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(color.opacity(0.15))
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * min(Double(percent) / 100.0, 1.0))
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(percent >= 100 ? color : .gray)
        }
    }
}
