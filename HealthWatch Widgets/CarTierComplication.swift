//
//  CarTierComplication.swift
//  HealthWatch Widgets
//
//  Watch complication showing car tier
//

import WidgetKit
import SwiftUI

struct CarTierComplication: Widget {
    let kind: String = "CarTierWatch"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchHealthTimelineProvider()
        ) { entry in
            CarTierComplicationView(entry: entry)
        }
        .configurationDisplayName("Car Tier")
        .description("Your health tier represented as a car")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Complication Views

struct CarTierComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchHealthEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularCarView(data: entry.data)
            case .accessoryRectangular:
                RectangularCarView(data: entry.data)
            case .accessoryInline:
                InlineCarView(data: entry.data)
            default:
                CircularCarView(data: entry.data)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Circular Car View

struct CircularCarView: View {
    let data: WatchComplicationData

    /// Car score - uses gemini score if available, otherwise health score
    private var carScore: Int {
        return data.geminiCarScore ?? data.healthScore
    }

    private var tierColor: Color {
        switch data.displayTierIndex {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return .mint
        }
    }

    private var scoreGradient: Gradient {
        Gradient(colors: [.red, .orange, .yellow, .green, .mint])
    }

    var body: some View {
        Gauge(value: Double(carScore), in: 0...100) {
            Text(data.displayCarEmoji)
                .font(.system(size: 14))
        } currentValueLabel: {
            Text("\(carScore)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(scoreGradient)
    }
}

// MARK: - Rectangular Car View

struct RectangularCarView: View {
    let data: WatchComplicationData

    private var tierColor: Color {
        switch data.displayTierIndex {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return .mint
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Car emoji with glow
            Text(data.displayCarEmoji)
                .font(.system(size: 32))
                .shadow(color: tierColor.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                // Car name
                Text(data.displayCarName)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Tier progress
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= data.displayTierIndex ? tierColor : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 4)
                    }
                }

                // Score
                Text("Score: \(data.healthScore)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

// MARK: - Inline Car View

struct InlineCarView: View {
    let data: WatchComplicationData

    var body: some View {
        Text("\(data.displayCarEmoji) \(data.displayCarName)")
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    CarTierComplication()
} timeline: {
    WatchHealthEntry(date: Date(), data: .placeholder)
}
