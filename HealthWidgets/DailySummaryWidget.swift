//
//  DailySummaryWidget.swift
//  HealthWidgets
//
//  Comprehensive daily health dashboard widget.
//

import WidgetKit
import SwiftUI

// MARK: - Daily Summary Widget

struct DailySummaryWidget: Widget {
    let kind: String = "DailySummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                DailySummaryWidgetView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                DailySummaryWidgetView(entry: entry)
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Daily Summary")
        .description("Complete daily health overview")
        .supportedFamilies([.systemLarge, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Router View

struct DailySummaryWidgetView: View {
    var entry: HealthEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemLarge:
            LargeDailySummaryView(data: entry.data)
        case .systemMedium:
            MediumDailySummaryView(data: entry.data)
        default:
            LargeDailySummaryView(data: entry.data)
        }
    }
}

// MARK: - Large Daily Summary View

struct LargeDailySummaryView: View {
    let data: HealthWidgetData

    private var scoreColor: Color { .scoreColor(for: data.healthScore) }

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                // Header: Greeting + Score ring
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        Text(dateString)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Score ring
                    ZStack {
                        ArcRing(
                            progress: Double(data.healthScore) / 100.0,
                            gradient: [scoreColor.opacity(0.4), scoreColor, scoreColor],
                            lineWidth: 3.5
                        )

                        Text("\(data.healthScore)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: 46, height: 46)
                }
                .padding(.bottom, 12)

                // Activity Rings + Ring Stats
                HStack(spacing: 14) {
                    ActivityRings(data: data, outerSize: 70, lineWidth: 9)
                        .frame(width: 70, height: 70)

                    VStack(alignment: .leading, spacing: 5) {
                        RingStatRow(
                            color: .pink,
                            value: "\(data.calories)/\(data.caloriesGoal)",
                            unit: "kcal",
                            progress: Double(data.calories) / Double(max(data.caloriesGoal, 1))
                        )
                        RingStatRow(
                            color: .green,
                            value: "\(data.exerciseMinutes)/\(data.exerciseGoal)",
                            unit: "min",
                            progress: Double(data.exerciseMinutes) / Double(max(data.exerciseGoal, 1))
                        )
                        RingStatRow(
                            color: .cyan,
                            value: "\(data.standHours)/\(data.standGoal)",
                            unit: "hrs",
                            progress: Double(data.standHours) / Double(max(data.standGoal, 1))
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 12)

                // Metrics Grid (3x2 cards)
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        GlassMetricCard(icon: "figure.walk", value: formatSteps(data.steps), label: "Steps", color: .orange)
                        GlassMetricCard(icon: "heart.fill", value: "\(data.heartRate)", label: "Heart Rate", color: .red)
                        GlassMetricCard(icon: "waveform.path.ecg", value: data.hrv > 0 ? "\(data.hrv)" : "--", label: "HRV", color: .purple)
                    }

                    HStack(spacing: 6) {
                        GlassMetricCard(icon: "moon.fill", value: data.sleepHours > 0 ? formatSleep(data.sleepHours) : "--", label: "Sleep", color: .indigo)
                        GlassMetricCard(icon: "flame.fill", value: "\(data.calories)", label: "Calories", color: .pink)
                        GlassMetricCard(icon: "figure.run", value: "\(data.exerciseMinutes)m", label: "Exercise", color: .green)
                    }
                }

                Spacer(minLength: 0)

                // Footer
                HStack {
                    Text("AION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                    if data.isStale {
                        StaleDataBadge()
                    }
                    Spacer()
                    Text(timeAgoString(from: data.lastUpdated))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.2))
                }
                .padding(.top, 6)
            }
            .padding(14)
        }
    }

    // MARK: - Greeting (time-based)

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 5 { timeGreeting = "Good Night" }
        else if hour < 12 { timeGreeting = "Good Morning" }
        else if hour < 17 { timeGreeting = "Good Afternoon" }
        else if hour < 21 { timeGreeting = "Good Evening" }
        else { timeGreeting = "Good Night" }

        if !data.userName.isEmpty {
            let firstName = data.userName.components(separatedBy: " ").first ?? data.userName
            return "\(timeGreeting), \(firstName)"
        }
        return timeGreeting
    }

    // MARK: - Date string (uses device locale)

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Medium Daily Summary View

struct MediumDailySummaryView: View {
    let data: HealthWidgetData

    private var scoreColor: Color { .scoreColor(for: data.healthScore) }

    var body: some View {
        ZStack {
            Color.black

            HStack(spacing: 14) {
                // Left: Score ring
                VStack(spacing: 6) {
                    ZStack {
                        ArcRing(
                            progress: Double(data.healthScore) / 100.0,
                            gradient: [scoreColor.opacity(0.4), scoreColor, scoreColor],
                            lineWidth: 7
                        )

                        VStack(spacing: -2) {
                            Text("\(data.healthScore)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(data.healthStatus)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(scoreColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(width: 90, height: 90)

                    Text("AION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(width: 100)

                // Right: Metric grid (2x3)
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        CompactMetricPill(icon: "figure.walk", value: formatSteps(data.steps), color: .orange)
                        CompactMetricPill(icon: "heart.fill", value: "\(data.heartRate)", color: .red)
                        CompactMetricPill(icon: "waveform.path.ecg", value: data.hrv > 0 ? "\(data.hrv)" : "--", color: .purple)
                    }

                    HStack(spacing: 6) {
                        CompactMetricPill(icon: "moon.fill", value: data.sleepHours > 0 ? formatSleep(data.sleepHours) : "--", color: .indigo)
                        CompactMetricPill(icon: "flame.fill", value: "\(data.calories)", color: .pink)
                        CompactMetricPill(icon: "figure.run", value: "\(data.exerciseMinutes)m", color: .green)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Ring Stat Row (compact, for large widget)

private struct RingStatRow: View {
    let color: Color
    let value: String
    let unit: String
    let progress: Double

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(.gray)

            Spacer()

            Text("\(min(Int(progress * 100), 999))%")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(progress >= 1.0 ? color : .gray)
        }
    }
}

// MARK: - Glass Metric Card (large widget)

private struct GlassMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Compact Metric Pill (medium widget)

private struct CompactMetricPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
