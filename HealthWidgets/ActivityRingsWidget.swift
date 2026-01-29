//
//  ActivityRingsWidget.swift
//  HealthWidgets
//
//  Medium widget showing activity rings similar to Apple Watch
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
                    .padding()
                    .background(Color.black)
            }
        }
        .configurationDisplayName("טבעות פעילות")
        .description("תנועה, אימון ועמידה")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Activity Rings Widget View

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
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                // Activity Rings
                ZStack {
                    // Move ring (red/pink)
                    RingView(
                        progress: Double(data.calories) / Double(data.caloriesGoal),
                        color: .pink,
                        lineWidth: 10
                    )
                    .frame(width: 70, height: 70)

                    // Exercise ring (green)
                    RingView(
                        progress: Double(data.exerciseMinutes) / Double(data.exerciseGoal),
                        color: .green,
                        lineWidth: 10
                    )
                    .frame(width: 50, height: 50)

                    // Stand ring (cyan)
                    RingView(
                        progress: Double(data.standHours) / Double(data.standGoal),
                        color: .cyan,
                        lineWidth: 10
                    )
                    .frame(width: 30, height: 30)
                }

                // Stats
                HStack(spacing: 12) {
                    StatLabel(value: "\(data.calories)", unit: "קק\"ל", color: .pink)
                    StatLabel(value: "\(data.exerciseMinutes)", unit: "דק'", color: .green)
                    StatLabel(value: "\(data.standHours)", unit: "שע'", color: .cyan)
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Medium Activity Rings View

struct MediumActivityRingsView: View {
    let data: HealthWidgetData

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Activity Rings
                ZStack {
                    RingView(
                        progress: Double(data.calories) / Double(data.caloriesGoal),
                        color: .pink,
                        lineWidth: 12
                    )
                    .frame(width: 100, height: 100)

                    RingView(
                        progress: Double(data.exerciseMinutes) / Double(data.exerciseGoal),
                        color: .green,
                        lineWidth: 12
                    )
                    .frame(width: 74, height: 74)

                    RingView(
                        progress: Double(data.standHours) / Double(data.standGoal),
                        color: .cyan,
                        lineWidth: 12
                    )
                    .frame(width: 48, height: 48)
                }

                // Stats Column
                VStack(alignment: .trailing, spacing: 10) {
                    ActivityStatRow(
                        icon: "flame.fill",
                        title: "תנועה",
                        value: "\(data.calories)/\(data.caloriesGoal)",
                        unit: "קק\"ל",
                        color: .pink
                    )

                    ActivityStatRow(
                        icon: "figure.run",
                        title: "אימון",
                        value: "\(data.exerciseMinutes)/\(data.exerciseGoal)",
                        unit: "דק'",
                        color: .green
                    )

                    ActivityStatRow(
                        icon: "figure.stand",
                        title: "עמידה",
                        value: "\(data.standHours)/\(data.standGoal)",
                        unit: "שע'",
                        color: .cyan
                    )
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    ActivityRingsWidget()
} timeline: {
    HealthEntry(date: .now, data: .placeholder)
}
