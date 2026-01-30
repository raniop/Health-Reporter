//
//  HealthScoreWidget.swift
//  HealthWidgets
//
//  Small widget showing the health score with circular progress
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
                    .padding()
                    .background(Color.black)
            }
        }
        .configurationDisplayName("ציון בריאות")
        .description("הציון הכללי שלך ביום זה")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Health Score Widget View

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

// MARK: - Small Widget View

struct SmallHealthScoreView: View {
    let data: HealthWidgetData

    var scoreColor: Color {
        switch data.healthScore {
        case 80...100: return .green
        case 60..<80: return .cyan
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            // Pure black background
            Color.black

            VStack(spacing: 8) {
                // Score circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(data.healthScore) / 100)
                        .stroke(
                            AngularGradient(
                                colors: [scoreColor.opacity(0.6), scoreColor],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Score number
                    VStack(spacing: 0) {
                        Text("\(data.healthScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80, height: 80)

                // Status text
                Text(data.healthStatus)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(scoreColor)

                // App name
                Text("AION")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(12)
        }
    }
}

// MARK: - Circular Accessory View (Watch/Lock Screen)

struct CircularHealthScoreView: View {
    let data: HealthWidgetData

    var body: some View {
        Gauge(value: Double(data.healthScore), in: 0...100) {
            Text("AION")
        } currentValueLabel: {
            Text("\(data.healthScore)")
                .font(.system(size: 20, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Rectangular Accessory View

struct RectangularHealthScoreView: View {
    let data: HealthWidgetData

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ציון בריאות")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(data.healthScore)")
                    .font(.system(size: 28, weight: .bold))
                Text(data.healthStatus)
                    .font(.caption2)
                    .foregroundColor(.cyan)
            }
            Spacer()
            Gauge(value: Double(data.healthScore), in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryCircular)
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    HealthScoreWidget()
} timeline: {
    HealthEntry(date: .now, data: .placeholder, carImage: nil)
    HealthEntry(date: .now, data: HealthWidgetData(
        healthScore: 85,
        healthStatus: "מצוין",
        steps: 8500,
        stepsGoal: 10000,
        calories: 420,
        caloriesGoal: 500,
        exerciseMinutes: 35,
        exerciseGoal: 30,
        standHours: 10,
        standGoal: 12,
        heartRate: 62,
        hrv: 52,
        sleepHours: 8.0,
        lastUpdated: Date(),
        carName: "Porsche 911 Turbo",
        carEmoji: "🏁",
        carImageName: "CarPorsche911",
        carTierIndex: 3
    ), carImage: nil)
}
