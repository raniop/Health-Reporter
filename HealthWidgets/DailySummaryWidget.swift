//
//  DailySummaryWidget.swift
//  HealthWidgets
//
//  Large widget showing comprehensive daily health summary
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
                    .padding()
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Daily Summary")
        .description("All your health data at a glance")
        .supportedFamilies([.systemLarge, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Daily Summary Widget View

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

    var scoreColor: Color {
        switch data.healthScore {
        case 80...100: return .green
        case 60..<80: return .cyan
        case 40..<60: return .orange
        default: return .red
        }
    }

    var dailyScoreColor: Color {
        guard let daily = data.dailyScore else { return .gray }
        switch daily {
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

            VStack(spacing: 12) {
                // Header with score
                HStack {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(greeting)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text(dateString)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Score badges - Gemini score (main) + Daily score (secondary)
                    HStack(spacing: 8) {
                        // Daily score (smaller, secondary) - if available
                        if let dailyScore = data.dailyScore {
                            ZStack {
                                Circle()
                                    .fill(dailyScoreColor.opacity(0.15))
                                Circle()
                                    .trim(from: 0, to: CGFloat(dailyScore) / 100)
                                    .stroke(dailyScoreColor.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(dailyScore)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 36, height: 36)
                        }

                        // Main Gemini score (larger)
                        ZStack {
                            Circle()
                                .fill(scoreColor.opacity(0.2))
                            Circle()
                                .trim(from: 0, to: CGFloat(data.healthScore) / 100)
                                .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(data.healthScore)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(width: 50, height: 50)
                    }
                    .padding(.top, 4)  // Move the score down slightly
                }

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Activity Rings Section
                HStack(spacing: 20) {
                    // Mini rings
                    ZStack {
                        RingView(
                            progress: Double(data.calories) / Double(data.caloriesGoal),
                            color: .pink,
                            lineWidth: 8
                        )
                        .frame(width: 60, height: 60)

                        RingView(
                            progress: Double(data.exerciseMinutes) / Double(data.exerciseGoal),
                            color: .green,
                            lineWidth: 8
                        )
                        .frame(width: 44, height: 44)

                        RingView(
                            progress: Double(data.standHours) / Double(data.standGoal),
                            color: .cyan,
                            lineWidth: 8
                        )
                        .frame(width: 28, height: 28)
                    }

                    VStack(alignment: .trailing, spacing: 8) {
                        MiniStatRow(label: "Move", value: "\(data.calories)/\(data.caloriesGoal) kcal", color: .pink)
                        MiniStatRow(label: "Exercise", value: "\(data.exerciseMinutes)/\(data.exerciseGoal) min", color: .green)
                        MiniStatRow(label: "Stand", value: "\(data.standHours)/\(data.standGoal) hr", color: .cyan)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(icon: "figure.walk", value: formatNumber(data.steps), label: "Steps", color: .orange)
                    StatCard(icon: "heart.fill", value: "\(data.heartRate)", label: "Heart Rate", color: .red)
                    StatCard(icon: "waveform.path.ecg", value: "\(data.hrv)", label: "HRV", color: .purple)
                    StatCard(icon: "bed.double.fill", value: String(format: "%.1f", data.sleepHours), label: "Sleep", color: .indigo)
                    StatCard(icon: "flame.fill", value: "\(data.calories)", label: "Calories", color: .pink)
                    StatCard(icon: "figure.run", value: "\(data.exerciseMinutes)", label: "Exercise", color: .green)
                }

                Spacer()

                // Footer
                HStack {
                    Text("AION Health")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Updated: \(timeString)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding(16)
        }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 5 { timeGreeting = "Good Night" }
        else if hour < 12 { timeGreeting = "Good Morning" }
        else if hour < 17 { timeGreeting = "Good Afternoon" }
        else if hour < 21 { timeGreeting = "Good Evening" }
        else { timeGreeting = "Good Night" }

        // Add user's first name if available
        if !data.userName.isEmpty {
            let firstName = data.userName.components(separatedBy: " ").first ?? data.userName
            return "\(timeGreeting), \(firstName)"
        }
        return timeGreeting
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: data.lastUpdated)
    }

    func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }
}

// MARK: - Medium Daily Summary View

struct MediumDailySummaryView: View {
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

            HStack(spacing: 16) {
                // Left side - Score
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: CGFloat(data.healthScore) / 100)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(data.healthScore)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text(data.healthStatus)
                                .font(.system(size: 10))
                                .foregroundColor(scoreColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(width: 105, height: 105)

                    Text("AION")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }

                // Right side - Stats
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 16) {
                        MiniStatBox(icon: "figure.walk", value: formatNumber(data.steps), color: .orange)
                        MiniStatBox(icon: "heart.fill", value: "\(data.heartRate)", color: .red)
                        MiniStatBox(icon: "bed.double.fill", value: String(format: "%.1f", data.sleepHours), color: .indigo)
                    }

                    HStack(spacing: 16) {
                        MiniStatBox(icon: "flame.fill", value: "\(data.calories)", color: .pink)
                        MiniStatBox(icon: "figure.run", value: "\(data.exerciseMinutes)", color: .green)
                        MiniStatBox(icon: "waveform.path.ecg", value: "\(data.hrv)", color: .purple)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
        }
    }

    func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return "\(number)"
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemLarge) {
    DailySummaryWidget()
} timeline: {
    HealthEntry(date: .now, data: .placeholder, carImage: nil)
}
