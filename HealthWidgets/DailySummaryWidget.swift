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
        .configurationDisplayName("סיכום יומי")
        .description("כל נתוני הבריאות שלך במבט אחד")
        .supportedFamilies([.systemLarge, .systemMedium])
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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

                    // Score badge
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
                        MiniStatRow(label: "תנועה", value: "\(data.calories)/\(data.caloriesGoal) קק\"ל", color: .pink)
                        MiniStatRow(label: "אימון", value: "\(data.exerciseMinutes)/\(data.exerciseGoal) דק'", color: .green)
                        MiniStatRow(label: "עמידה", value: "\(data.standHours)/\(data.standGoal) שע'", color: .cyan)
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
                    StatCard(icon: "figure.walk", value: formatNumber(data.steps), label: "צעדים", color: .orange)
                    StatCard(icon: "heart.fill", value: "\(data.heartRate)", label: "דופק", color: .red)
                    StatCard(icon: "waveform.path.ecg", value: "\(data.hrv)", label: "HRV", color: .purple)
                    StatCard(icon: "bed.double.fill", value: String(format: "%.1f", data.sleepHours), label: "שינה", color: .indigo)
                    StatCard(icon: "flame.fill", value: "\(data.calories)", label: "קלוריות", color: .pink)
                    StatCard(icon: "figure.run", value: "\(data.exerciseMinutes)", label: "אימון", color: .green)
                }

                Spacer()

                // Footer
                HStack {
                    Text("AION Health")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("עודכן: \(timeString)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .padding(16)
        }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 5 { return "לילה טוב" }
        if hour < 12 { return "בוקר טוב" }
        if hour < 17 { return "צהריים טובים" }
        if hour < 21 { return "ערב טוב" }
        return "לילה טוב"
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.dateFormat = "EEEE, d MMMM"
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
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text(data.healthStatus)
                                .font(.system(size: 9))
                                .foregroundColor(scoreColor)
                        }
                    }
                    .frame(width: 70, height: 70)

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
    HealthEntry(date: .now, data: .placeholder)
}
