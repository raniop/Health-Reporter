//
//  HealthWidgets.swift
//  HealthWidgets
//
//  Widget Extension for Health Reporter — shared data model, loader, and components.
//  Rebuilt from scratch.
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Shared Data Model

struct HealthWidgetData: Codable {
    // Core scores
    var healthScore: Int
    var dailyScore: Int?
    var healthStatus: String

    // Activity rings
    var steps: Int
    var stepsGoal: Int
    var calories: Int
    var caloriesGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int

    // Health metrics
    var heartRate: Int
    var restingHeartRate: Int
    var hrv: Int
    var sleepHours: Double

    // Metadata
    var lastUpdated: Date

    // Car tier
    var carName: String
    var carEmoji: String
    var carImageName: String
    var carTierIndex: Int

    // User
    var userName: String

    // MARK: - Backward-Compatible Decoding

    enum CodingKeys: String, CodingKey {
        case healthScore, dailyScore, healthStatus
        case steps, stepsGoal, calories, caloriesGoal
        case exerciseMinutes, exerciseGoal, standHours, standGoal
        case heartRate, restingHeartRate, hrv, sleepHours
        case lastUpdated
        case carName, carEmoji, carImageName, carTierIndex
        case userName
    }

    init(healthScore: Int, dailyScore: Int?, healthStatus: String,
         steps: Int, stepsGoal: Int, calories: Int, caloriesGoal: Int,
         exerciseMinutes: Int, exerciseGoal: Int, standHours: Int, standGoal: Int,
         heartRate: Int, restingHeartRate: Int, hrv: Int, sleepHours: Double,
         lastUpdated: Date,
         carName: String, carEmoji: String, carImageName: String, carTierIndex: Int,
         userName: String) {
        self.healthScore = healthScore; self.dailyScore = dailyScore; self.healthStatus = healthStatus
        self.steps = steps; self.stepsGoal = stepsGoal
        self.calories = calories; self.caloriesGoal = caloriesGoal
        self.exerciseMinutes = exerciseMinutes; self.exerciseGoal = exerciseGoal
        self.standHours = standHours; self.standGoal = standGoal
        self.heartRate = heartRate; self.restingHeartRate = restingHeartRate
        self.hrv = hrv; self.sleepHours = sleepHours
        self.lastUpdated = lastUpdated
        self.carName = carName; self.carEmoji = carEmoji
        self.carImageName = carImageName; self.carTierIndex = carTierIndex
        self.userName = userName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        healthScore = (try? c.decode(Int.self, forKey: .healthScore)) ?? 0
        dailyScore = try? c.decode(Int.self, forKey: .dailyScore)
        healthStatus = (try? c.decode(String.self, forKey: .healthStatus)) ?? ""
        steps = (try? c.decode(Int.self, forKey: .steps)) ?? 0
        stepsGoal = (try? c.decode(Int.self, forKey: .stepsGoal)) ?? 10000
        calories = (try? c.decode(Int.self, forKey: .calories)) ?? 0
        caloriesGoal = (try? c.decode(Int.self, forKey: .caloriesGoal)) ?? 500
        exerciseMinutes = (try? c.decode(Int.self, forKey: .exerciseMinutes)) ?? 0
        exerciseGoal = (try? c.decode(Int.self, forKey: .exerciseGoal)) ?? 30
        standHours = (try? c.decode(Int.self, forKey: .standHours)) ?? 0
        standGoal = (try? c.decode(Int.self, forKey: .standGoal)) ?? 12
        heartRate = (try? c.decode(Int.self, forKey: .heartRate)) ?? 0
        restingHeartRate = (try? c.decode(Int.self, forKey: .restingHeartRate)) ?? 0
        hrv = (try? c.decode(Int.self, forKey: .hrv)) ?? 0
        sleepHours = (try? c.decode(Double.self, forKey: .sleepHours)) ?? 0
        lastUpdated = (try? c.decode(Date.self, forKey: .lastUpdated)) ?? Date.distantPast
        carName = (try? c.decode(String.self, forKey: .carName)) ?? "--"
        carEmoji = (try? c.decode(String.self, forKey: .carEmoji)) ?? "🚗"
        carImageName = (try? c.decode(String.self, forKey: .carImageName)) ?? ""
        carTierIndex = (try? c.decode(Int.self, forKey: .carTierIndex)) ?? 0
        userName = (try? c.decode(String.self, forKey: .userName)) ?? ""
    }

    // MARK: - Computed Properties

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 14400 // 4 hours
    }

    var displayCarEmoji: String {
        carEmoji.isEmpty ? "🚗" : carEmoji
    }

    var displayCarName: String {
        carName.isEmpty ? "--" : carName
    }

    // MARK: - Placeholder

    static var placeholder: HealthWidgetData {
        HealthWidgetData(
            healthScore: 72,
            dailyScore: nil,
            healthStatus: "Good",
            steps: 6543,
            stepsGoal: 10000,
            calories: 320,
            caloriesGoal: 500,
            exerciseMinutes: 25,
            exerciseGoal: 30,
            standHours: 8,
            standGoal: 12,
            heartRate: 68,
            restingHeartRate: 62,
            hrv: 45,
            sleepHours: 7.5,
            lastUpdated: Date(),
            carName: "BMW M3",
            carEmoji: "🏎️",
            carImageName: "CarBMWM3",
            carTierIndex: 2,
            userName: ""
        )
    }
}

// MARK: - App Group Data Loading

struct WidgetDataLoader {
    static let appGroupID = "group.com.rani.Health-Reporter"
    static let carImageFileName = "widget_car_image.png"

    static func loadData() -> HealthWidgetData {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: "widgetData") else {
            return .placeholder
        }
        do {
            return try JSONDecoder().decode(HealthWidgetData.self, from: data)
        } catch {
            return .placeholder
        }
    }

    static func loadCarImage() -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let imageURL = containerURL.appendingPathComponent(carImageFileName)
        guard FileManager.default.fileExists(atPath: imageURL.path),
              let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image
    }
}

// MARK: - Timeline Provider

struct HealthTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(date: Date(), data: .placeholder, carImage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> Void) {
        let data = WidgetDataLoader.loadData()
        let carImage = WidgetDataLoader.loadCarImage()
        completion(HealthEntry(date: Date(), data: data, carImage: carImage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthEntry>) -> Void) {
        let data = WidgetDataLoader.loadData()
        let carImage = WidgetDataLoader.loadCarImage()
        let entry = HealthEntry(date: Date(), data: data, carImage: carImage)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct HealthEntry: TimelineEntry {
    let date: Date
    let data: HealthWidgetData
    let carImage: UIImage?
}

// MARK: - Color Helpers (matched to Watch + HealthTier)

extension Color {
    /// Score color — identical to WatchHealthData.scoreColor(for:)
    static func scoreColor(for score: Int) -> Color {
        switch score {
        case ..<25:  return .red
        case 25..<45: return .orange
        case 45..<65: return .yellow
        case 65..<82: return .green
        default:      return .mint
        }
    }

    /// Tier color — identical to WatchHealthData.tierColor(for:) and HealthTier
    static func tierColor(for index: Int) -> Color {
        switch index {
        case 0:  return .red
        case 1:  return .orange
        case 2:  return .yellow
        case 3:  return .green
        default: return .mint
        }
    }
}

// MARK: - Shared UI Components

/// Arc progress ring with gradient
struct ArcRing: View {
    let progress: Double
    let gradient: [Color]
    let lineWidth: CGFloat
    let lineCap: CGLineCap

    init(progress: Double, gradient: [Color], lineWidth: CGFloat = 8, lineCap: CGLineCap = .round) {
        self.progress = progress
        self.gradient = gradient
        self.lineWidth = lineWidth
        self.lineCap = lineCap
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        colors: gradient,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * min(progress, 1.0))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: lineCap)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Simple solid color ring
struct RingView: View {
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

/// Concentric activity rings (Move / Exercise / Stand)
struct ActivityRings: View {
    let data: HealthWidgetData
    let outerSize: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            RingView(
                progress: Double(data.calories) / Double(max(data.caloriesGoal, 1)),
                color: .pink,
                lineWidth: lineWidth
            )
            .frame(width: outerSize, height: outerSize)

            RingView(
                progress: Double(data.exerciseMinutes) / Double(max(data.exerciseGoal, 1)),
                color: .green,
                lineWidth: lineWidth
            )
            .frame(width: outerSize - lineWidth * 2.5, height: outerSize - lineWidth * 2.5)

            RingView(
                progress: Double(data.standHours) / Double(max(data.standGoal, 1)),
                color: .cyan,
                lineWidth: lineWidth
            )
            .frame(width: outerSize - lineWidth * 5, height: outerSize - lineWidth * 5)
        }
    }
}

// MARK: - Number Formatting

func formatSteps(_ number: Int) -> String {
    if number >= 10000 {
        return String(format: "%.1fK", Double(number) / 1000)
    } else if number >= 1000 {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    return "\(number)"
}

func formatSleep(_ hours: Double) -> String {
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    if m > 0 { return "\(h)h\(m)m" }
    return "\(h)h"
}

func timeAgoString(from date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "just now" }
    if interval < 3600 { return "\(Int(interval / 60))m ago" }
    if interval < 86400 { return "\(Int(interval / 3600))h ago" }
    return "1d+ ago"
}

// MARK: - Stale Data Badge

struct StaleDataBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 7))
            Text("Stale")
                .font(.system(size: 7, weight: .medium))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
    }
}
