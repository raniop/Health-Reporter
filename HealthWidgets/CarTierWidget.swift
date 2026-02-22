//
//  CarTierWidget.swift
//  HealthWidgets
//
//  Your health as a car — from Fiat Panda to Ferrari!
//  Rebuilt from scratch.
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
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Car Meter")
        .description("Your health as a car - from Fiat Panda to Ferrari!")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Router View

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

    private var tierColor: Color { .tierColor(for: data.carTierIndex) }

    var body: some View {
        ZStack {
            Color.black

            // Subtle tier-colored glow at top
            VStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [tierColor.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 60)
                    .offset(y: -10)
                Spacer()
            }

            VStack(spacing: 4) {
                // Car visual
                if let uiImage = carImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 46)
                } else {
                    Text(data.displayCarEmoji)
                        .font(.system(size: 46))
                }

                // Score
                Text("\(data.healthScore)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Car name
                Text(data.displayCarName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tierColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Stale indicator
                if data.isStale {
                    StaleDataBadge()
                }

                // Tier dots
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i <= data.carTierIndex ? Color.tierColor(for: i) : Color.white.opacity(0.1))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 2)
            }
            .padding(10)
        }
    }
}

// MARK: - Medium Car Tier View

struct MediumCarTierView: View {
    let data: HealthWidgetData
    let carImage: UIImage?

    private var tierColor: Color { .tierColor(for: data.carTierIndex) }

    var body: some View {
        ZStack {
            Color.black

            HStack(spacing: 14) {
                // Left: Car visual with glow
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tierColor.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 55
                            )
                        )
                        .frame(width: 100, height: 100)

                    if let uiImage = carImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 60)
                    } else {
                        Text(data.displayCarEmoji)
                            .font(.system(size: 54))
                    }
                }
                .frame(width: 110)

                // Right: Info
                VStack(alignment: .leading, spacing: 6) {
                    // Car name + stale badge
                    HStack(spacing: 6) {
                        Text(data.displayCarName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if data.isStale {
                            StaleDataBadge()
                        }
                    }

                    // Score row
                    HStack(spacing: 10) {
                        Text("\(data.healthScore)")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.healthStatus)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(tierColor)
                                .lineLimit(1)
                            Text("Level \(data.carTierIndex + 1) / 5")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }

                    // Tier progress bar
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i <= data.carTierIndex ? Color.tierColor(for: i) : Color.white.opacity(0.08))
                                .frame(height: 5)
                        }
                    }

                    // Quick stats
                    HStack(spacing: 12) {
                        CarStatPill(icon: "heart.fill", value: "\(data.heartRate)", color: .red)
                        CarStatPill(icon: "moon.fill", value: formatSleep(data.sleepHours), color: .indigo)
                        CarStatPill(icon: "waveform.path.ecg", value: "\(data.hrv)", color: .purple)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Car Stat Pill

private struct CarStatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
