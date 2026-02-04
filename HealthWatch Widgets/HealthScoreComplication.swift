//
//  HealthScoreComplication.swift
//  HealthWatch Widgets
//
//  Watch complication showing health score
//

import WidgetKit
import SwiftUI

struct HealthScoreComplication: Widget {
    let kind: String = "HealthScoreWatch"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchHealthTimelineProvider()
        ) { entry in
            HealthScoreComplicationView(entry: entry)
        }
        .configurationDisplayName("Health Score")
        .description("Your overall health score")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Complication Views

struct HealthScoreComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchHealthEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularScoreView(data: entry.data)
            case .accessoryRectangular:
                RectangularScoreView(data: entry.data)
            case .accessoryInline:
                InlineScoreView(data: entry.data)
            case .accessoryCorner:
                CornerScoreView(data: entry.data)
            default:
                CircularScoreView(data: entry.data)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Circular View

struct CircularScoreView: View {
    let data: WatchComplicationData

    private var scoreGradient: Gradient {
        Gradient(colors: [.red, .orange, .yellow, .green, .mint])
    }

    var body: some View {
        Gauge(value: Double(data.healthScore), in: 0...100) {
            Text("AION")
        } currentValueLabel: {
            Text("\(data.healthScore)")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(scoreGradient)
    }
}

// MARK: - Rectangular View

struct RectangularScoreView: View {
    let data: WatchComplicationData

    private var scoreColor: Color {
        switch data.healthScore {
        case 0..<25: return .red
        case 25..<45: return .orange
        case 45..<65: return .yellow
        case 65..<82: return .green
        default: return .mint
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Score Gauge
            Gauge(value: Double(data.healthScore), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text("\(data.healthScore)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(scoreColor)
            .frame(width: 40, height: 40)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(data.healthStatus)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    Label("\(data.heartRate)", systemImage: "heart.fill")
                        .font(.system(.caption2))
                        .foregroundColor(.red)

                    Label(data.formattedSleepHours, systemImage: "bed.double.fill")
                        .font(.system(.caption2))
                        .foregroundColor(.purple)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Inline View

struct InlineScoreView: View {
    let data: WatchComplicationData

    var body: some View {
        Text("\(data.healthScore) \(data.healthStatus)")
    }
}

// MARK: - Corner View

struct CornerScoreView: View {
    let data: WatchComplicationData

    private var scoreColor: Color {
        switch data.healthScore {
        case 0..<25: return .red
        case 25..<45: return .orange
        case 45..<65: return .yellow
        case 65..<82: return .green
        default: return .mint
        }
    }

    var body: some View {
        Text("\(data.healthScore)")
            .font(.system(.title3, design: .rounded))
            .fontWeight(.bold)
            .foregroundColor(scoreColor)
            .widgetLabel {
                Gauge(value: Double(data.healthScore), in: 0...100) {
                    Text("Score")
                }
                .tint(scoreColor)
            }
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    HealthScoreComplication()
} timeline: {
    WatchHealthEntry(date: Date(), data: .placeholder)
}
