//
//  DailyMetricsComplication.swift
//  HealthWatch Widgets
//
//  Watch complication showing daily metrics summary
//

import WidgetKit
import SwiftUI

struct DailyMetricsComplication: Widget {
    let kind: String = "DailyMetricsWatch"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WatchHealthTimelineProvider()
        ) { entry in
            DailyMetricsComplicationView(entry: entry)
        }
        .configurationDisplayName("Daily Metrics")
        .description("Key health metrics at a glance")
        .supportedFamilies([
            .accessoryRectangular
        ])
    }
}

// MARK: - Complication View

struct DailyMetricsComplicationView: View {
    let entry: WatchHealthEntry

    private var data: WatchComplicationData {
        entry.data
    }

    var body: some View {
        HStack(spacing: 0) {
            MetricItem(icon: "heart.fill", value: "\(data.heartRate)", unit: "bpm", color: .red)
                .frame(maxWidth: .infinity)
            MetricItem(icon: "bed.double.fill", value: String(format: "%.1f", data.sleepHours), unit: "hrs", color: .purple)
                .frame(maxWidth: .infinity)
            MetricItem(icon: "figure.walk", value: formatSteps(data.steps), unit: "steps", color: .green)
                .frame(maxWidth: .infinity)
            MetricItem(icon: "waveform.path.ecg", value: "\(data.hrv)", unit: "ms", color: .cyan)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fK", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

// MARK: - Metric Item

struct MetricItem: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(maxHeight: .infinity, alignment: .bottom)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxHeight: .infinity, alignment: .center)

            Text(unit.isEmpty ? " " : unit)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    DailyMetricsComplication()
} timeline: {
    WatchHealthEntry(date: Date(), data: .placeholder)
}
