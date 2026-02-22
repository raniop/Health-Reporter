//
//  HealthScoreWidget.swift
//  HealthWidgets
//
//  Circular health score widget with gradient ring and lock screen support.
//  Rebuilt from scratch.
//

import WidgetKit
import SwiftUI

// MARK: - Health Score Widget

struct HealthScoreWidget: Widget {
    let kind: String = "HealthScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                HealthScoreWidgetView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                HealthScoreWidgetView(entry: entry)
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Health Score")
        .description("Your overall AION health score")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Router View

struct HealthScoreWidgetView: View {
    var entry: HealthEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallHealthScoreView(data: entry.data)
        case .accessoryCircular:
            CircularHealthScoreView(data: entry.data)
        case .accessoryRectangular:
            RectangularHealthScoreView(data: entry.data)
        default:
            SmallHealthScoreView(data: entry.data)
        }
    }
}

// MARK: - Small Widget (Home Screen)

struct SmallHealthScoreView: View {
    let data: HealthWidgetData

    private var scoreColor: Color { .scoreColor(for: data.healthScore) }
    private var progress: Double { Double(data.healthScore) / 100.0 }

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 6) {
                // Score ring
                ZStack {
                    ArcRing(
                        progress: progress,
                        gradient: [scoreColor.opacity(0.4), scoreColor, scoreColor],
                        lineWidth: 9
                    )

                    VStack(spacing: -2) {
                        Text("\(data.healthScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ 100")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 90, height: 90)

                // Status
                Text(data.healthStatus)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(scoreColor)
                    .lineLimit(1)

                // Key metrics or stale badge
                if data.isStale {
                    StaleDataBadge()
                } else {
                    HStack(spacing: 14) {
                        Label(data.heartRate > 0 ? "\(data.heartRate)" : "--", systemImage: "heart.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                        Label(data.sleepHours > 0 ? formatSleep(data.sleepHours) : "--", systemImage: "moon.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.indigo.opacity(0.8))
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Circular Accessory (Lock Screen)

struct CircularHealthScoreView: View {
    let data: HealthWidgetData

    var body: some View {
        Gauge(value: Double(data.healthScore), in: 0...100) {
            Text("AION")
                .font(.system(size: 7))
        } currentValueLabel: {
            Text("\(data.healthScore)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Rectangular Accessory (Lock Screen)

struct RectangularHealthScoreView: View {
    let data: HealthWidgetData

    var body: some View {
        HStack(spacing: 8) {
            Gauge(value: Double(data.healthScore), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text("\(data.healthScore)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("AION Score")
                    .font(.system(size: 11, weight: .semibold))
                Text(data.healthStatus)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    Label("\(data.heartRate)", systemImage: "heart.fill")
                    Label(formatSleep(data.sleepHours), systemImage: "moon.fill")
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            }
        }
    }
}
