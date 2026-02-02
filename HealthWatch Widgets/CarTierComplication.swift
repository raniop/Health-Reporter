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
}

// MARK: - Circular Car View

struct CircularCarView: View {
    let data: WatchComplicationData

    private var tierColor: Color {
        switch data.carTierIndex {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return .mint
        }
    }

    var body: some View {
        ZStack {
            // Background circle with tier color
            Circle()
                .fill(tierColor.opacity(0.2))

            // Car emoji
            Text(data.carEmoji)
                .font(.system(size: 28))

            // Tier indicator dots at bottom
            VStack {
                Spacer()

                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index <= data.carTierIndex ? tierColor : Color.gray.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Rectangular Car View

struct RectangularCarView: View {
    let data: WatchComplicationData

    private var tierColor: Color {
        switch data.carTierIndex {
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
            Text(data.carEmoji)
                .font(.system(size: 32))
                .shadow(color: tierColor.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                // Car name
                Text(data.carName)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Tier progress
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= data.carTierIndex ? tierColor : Color.gray.opacity(0.3))
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
        Text("\(data.carEmoji) \(data.carName)")
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    CarTierComplication()
} timeline: {
    WatchHealthEntry(date: Date(), data: .placeholder)
}
