//
//  ActivityRingsComplication.swift
//  HealthWatch Widgets
//
//  Watch complication showing activity rings
//

import WidgetKit
import SwiftUI

struct ActivityRingsComplication: Widget {
    let kind: String = "ActivityRingsWatch"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchHealthTimelineProvider()
        ) { entry in
            ActivityRingsComplicationView(entry: entry)
        }
        .configurationDisplayName("Activity Rings")
        .description("Your Move, Exercise, and Stand progress")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Complication Views

struct ActivityRingsComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchHealthEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularRingsView(data: entry.data)
            case .accessoryRectangular:
                RectangularRingsView(data: entry.data)
            default:
                CircularRingsView(data: entry.data)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Circular Rings View

struct CircularRingsView: View {
    let data: WatchComplicationData

    var body: some View {
        ZStack {
            // Move Ring (outermost)
            ComplicationRing(
                progress: data.moveProgress,
                color: .red,
                lineWidth: 5
            )
            .frame(width: 50, height: 50)

            // Exercise Ring (middle)
            ComplicationRing(
                progress: data.exerciseProgress,
                color: .green,
                lineWidth: 5
            )
            .frame(width: 38, height: 38)

            // Stand Ring (innermost)
            ComplicationRing(
                progress: data.standProgress,
                color: .cyan,
                lineWidth: 5
            )
            .frame(width: 26, height: 26)
        }
    }
}

// MARK: - Rectangular Rings View

struct RectangularRingsView: View {
    let data: WatchComplicationData

    var body: some View {
        HStack(spacing: 8) {
            // Mini Rings
            ZStack {
                ComplicationRing(progress: data.moveProgress, color: .red, lineWidth: 4)
                    .frame(width: 36, height: 36)
                ComplicationRing(progress: data.exerciseProgress, color: .green, lineWidth: 4)
                    .frame(width: 26, height: 26)
                ComplicationRing(progress: data.standProgress, color: .cyan, lineWidth: 4)
                    .frame(width: 16, height: 16)
            }

            // Progress Text
            VStack(alignment: .leading, spacing: 2) {
                RingProgressText(
                    value: data.moveCalories,
                    goal: data.moveGoal,
                    unit: "cal",
                    color: .red
                )

                RingProgressText(
                    value: data.exerciseMinutes,
                    goal: data.exerciseGoal,
                    unit: "min",
                    color: .green
                )

                RingProgressText(
                    value: data.standHours,
                    goal: data.standGoal,
                    unit: "hrs",
                    color: .cyan
                )
            }

            Spacer()
        }
    }
}

// MARK: - Complication Ring

struct ComplicationRing: View {
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
        }
    }
}

// MARK: - Ring Progress Text

struct RingProgressText: View {
    let value: Int
    let goal: Int
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)

            Text("\(value)/\(goal) \(unit)")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    ActivityRingsComplication()
} timeline: {
    WatchHealthEntry(date: Date(), data: .placeholder)
}
