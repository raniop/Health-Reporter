//
//  CarTierWidget.swift
//  HealthWidgets
//
//  Widget showing your health status as a car tier - from Fiat Panda to Ferrari!
//

import WidgetKit
import SwiftUI

// MARK: - Car Tier Widget

struct CarTierWidget: Widget {
    let kind: String = "CarTierWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                CarTierWidgetView(entry: entry)
                    .containerBackground(.black, for: .widget)
            } else {
                CarTierWidgetView(entry: entry)
                    .padding()
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Your Car Meter")
        .description("Your health as a car - from Fiat Panda to Ferrari!")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Car Tier Widget View

struct CarTierWidgetView: View {
    var entry: HealthEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCarTierView(data: entry.data, carImage: entry.carImage)
        case .systemMedium:
            MediumCarTierView(data: entry.data, carImage: entry.carImage)
        default:
            SmallCarTierView(data: entry.data, carImage: entry.carImage)
        }
    }
}

// MARK: - Small Car Tier View

struct SmallCarTierView: View {
    let data: HealthWidgetData
    let carImage: UIImage?

    var tierColor: Color {
        switch data.carTierIndex {
        case 0: return .red
        case 1: return .orange
        case 2: return .cyan
        case 3: return .blue
        case 4: return .green
        default: return .cyan
        }
    }

    var body: some View {
        ZStack {
            // Pure black background
            Color.black

            VStack(spacing: 6) {
                // Car image or emoji fallback
                if let uiImage = carImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 40)
                        .cornerRadius(6)
                        .shadow(color: tierColor.opacity(0.5), radius: 10)
                } else {
                    Text(data.carEmoji)
                        .font(.system(size: 50))
                        .shadow(color: tierColor.opacity(0.5), radius: 10)
                }

                // Score
                Text("\(data.healthScore)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Status
                Text(data.healthStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(tierColor)

                // Car name
                Text(data.carName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(8)
        }
    }
}

// MARK: - Medium Car Tier View

struct MediumCarTierView: View {
    let data: HealthWidgetData
    let carImage: UIImage?

    var tierColor: Color {
        switch data.carTierIndex {
        case 0: return .red
        case 1: return .orange
        case 2: return .cyan
        case 3: return .blue
        case 4: return .green
        default: return .cyan
        }
    }

    var body: some View {
        ZStack {
            // Pure black background
            Color.black

            HStack(spacing: 16) {
                // Left side - Car visual
                VStack(spacing: 8) {
                    // Car image with glow or emoji fallback
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(tierColor.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .blur(radius: 10)

                        if let uiImage = carImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 55)
                                .cornerRadius(8)
                        } else {
                            Text(data.carEmoji)
                                .font(.system(size: 55))
                        }
                    }

                    // Car name
                    Text(data.carName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 110)

                // Right side - Stats
                VStack(alignment: .trailing, spacing: 10) {
                    // Score with gauge
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(data.healthScore)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(data.healthStatus)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(tierColor)
                        }

                        // Mini gauge
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: CGFloat(data.healthScore) / 100)
                                .stroke(tierColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 40, height: 40)
                    }

                    // Tier progress bar
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { index in
                                Rectangle()
                                    .fill(index <= data.carTierIndex ? tierColorForIndex(index) : Color.gray.opacity(0.3))
                                    .frame(height: 6)
                                    .cornerRadius(3)
                            }
                        }
                        Text("Level \(data.carTierIndex + 1) of 5")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }

                    // Key stats
                    HStack(spacing: 12) {
                        MiniStat(icon: "heart.fill", value: "\(data.heartRate)", color: .red)
                        MiniStat(icon: "bed.double.fill", value: String(format: "%.1f", data.sleepHours), color: .indigo)
                        MiniStat(icon: "waveform.path.ecg", value: "\(data.hrv)", color: .purple)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
        }
    }

    func tierColorForIndex(_ index: Int) -> Color {
        switch index {
        case 0: return .red
        case 1: return .orange
        case 2: return .cyan
        case 3: return .blue
        case 4: return .green
        default: return .gray
        }
    }
}

// MARK: - Mini Stat Component

struct MiniStat: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview(as: .systemMedium) {
    CarTierWidget()
} timeline: {
    HealthEntry(date: .now, data: .placeholder, carImage: nil)
    HealthEntry(date: .now, data: HealthWidgetData(
        healthScore: 88,
        healthStatus: "Peak Performance",
        steps: 12000,
        stepsGoal: 10000,
        calories: 550,
        caloriesGoal: 500,
        exerciseMinutes: 45,
        exerciseGoal: 30,
        standHours: 11,
        standGoal: 12,
        heartRate: 58,
        hrv: 65,
        sleepHours: 8.2,
        lastUpdated: Date(),
        carName: "Ferrari SF90 Stradale",
        carEmoji: "🏆",
        carImageName: "CarFerrariSF90",
        carTierIndex: 4,
        userName: ""
    ), carImage: nil)
}
