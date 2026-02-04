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
        VStack(alignment: .leading, spacing: 4) {
            // Header with score
            HStack {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundColor(.red)

                Text("Health")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.gray)

                Spacer()

                Text("\(data.healthScore)")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
            }

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            // Metrics Grid
            HStack(spacing: 12) {
                MetricItem(
                    icon: "heart.fill",
                    value: "\(data.heartRate)",
                    unit: "bpm",
                    color: .red
                )

                MetricItem(
                    icon: "bed.double.fill",
                    value: String(format: "%.1f", data.sleepHours),
                    unit: "hrs",
                    color: .purple
                )

                MetricItem(
                    icon: "figure.walk",
                    value: formatSteps(data.steps),
                    unit: "steps",
                    color: .green
                )

                MetricItem(
                    icon: "waveform.path.ecg",
                    value: "\(data.hrv)",
                    unit: "ms",
                    color: .cyan
                )
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var scoreColor: Color {
        switch data.healthScore {
        case 0..<25: return .red
        case 25..<45: return .orange
        case 45..<65: return .yellow
        case 65..<82: return .green
        default: return .mint
        }
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
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(height: 12)

            Text(value)
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(height: 14)

            Text(unit.isEmpty ? " " : unit)
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .frame(height: 10)
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    DailyMetricsComplication()
} timeline: {
    WatchHealthEntry(date: Date(), data: .placeholder)
}
