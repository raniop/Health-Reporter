//
//  HealthWidgets.swift
//  HealthWidgets
//
//  Widget Extension for Health Reporter - displays health data on home screen
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data Model

struct HealthWidgetData: Codable {
    var healthScore: Int
    var healthStatus: String
    var steps: Int
    var stepsGoal: Int
    var calories: Int
    var caloriesGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int
    var heartRate: Int
    var hrv: Int
    var sleepHours: Double
    var lastUpdated: Date

    // Car tier info
    var carName: String
    var carEmoji: String
    var carImageName: String
    var carTierIndex: Int

    static var placeholder: HealthWidgetData {
        HealthWidgetData(
            healthScore: 72,
            healthStatus: "מצב טוב",
            steps: 6543,
            stepsGoal: 10000,
            calories: 320,
            caloriesGoal: 500,
            exerciseMinutes: 25,
            exerciseGoal: 30,
            standHours: 8,
            standGoal: 12,
            heartRate: 68,
            hrv: 45,
            sleepHours: 7.5,
            lastUpdated: Date(),
            carName: "BMW M3",
            carEmoji: "🏎️",
            carImageName: "CarBMWM3",
            carTierIndex: 2
        )
    }
}

// MARK: - App Group Data Loading

struct WidgetDataLoader {
    static let appGroupID = "group.com.rani.Health-Reporter"

    static func loadData() -> HealthWidgetData {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("Widget: ❌ Failed to access App Group")
            return .placeholder
        }

        guard let data = userDefaults.data(forKey: "widgetData") else {
            print("Widget: ⚠️ No data found in App Group, using placeholder")
            return .placeholder
        }

        do {
            let widgetData = try JSONDecoder().decode(HealthWidgetData.self, from: data)
            print("Widget: ✅ Loaded data - Score: \(widgetData.healthScore), Car: \(widgetData.carName)")
            return widgetData
        } catch {
            print("Widget: ❌ Decode error: \(error)")
            return .placeholder
        }
    }
}

// MARK: - Timeline Provider

struct HealthTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> Void) {
        let data = WidgetDataLoader.loadData()
        let entry = HealthEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthEntry>) -> Void) {
        let data = WidgetDataLoader.loadData()
        let entry = HealthEntry(date: Date(), data: data)

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct HealthEntry: TimelineEntry {
    let date: Date
    let data: HealthWidgetData
}

// MARK: - Shared UI Components

/// Ring progress view for activity rings
struct RingView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: lineWidth)

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

/// Small stat label for compact displays
struct StatLabel: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(color)
        }
    }
}

/// Activity stat row for medium widget
struct ActivityStatRow: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text("\(value) \(unit)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)

            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
        }
    }
}

/// Mini stat row for daily summary
struct MiniStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
    }
}

/// Stat card for grid display
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Mini stat box for medium summary widget
struct MiniStatBox: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 36)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}
