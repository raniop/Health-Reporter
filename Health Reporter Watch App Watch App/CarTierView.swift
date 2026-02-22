//
//  CarTierView.swift
//  Health Reporter Watch App
//
//  Displays the Gemini car tier with visual representation (90-day average score)

import SwiftUI

struct CarTierView: View {
    @EnvironmentObject var dataManager: WatchDataManager

    private var data: WatchHealthData {
        dataManager.healthData
    }

    private var displayCarName: String {
        data.geminiCarName ?? data.carName
    }

    private var displayScore: Int {
        data.geminiCarScore ?? data.healthScore
    }

    private var displayTierIndex: Int {
        data.geminiCarTierIndex ?? data.carTierIndex
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Car Emoji with glow
                Text(data.carEmoji.isEmpty ? "🚗" : data.carEmoji)
                    .font(.system(size: 60))
                    .shadow(color: WatchHealthData.tierColor(for: displayTierIndex).opacity(0.6), radius: 20)
                    .padding(.top, 8)

                // Car Name
                Text(displayCarName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Tier Progress Bar
                TierProgressBar(currentTier: displayTierIndex)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Health Score (90-day average)
                HStack(spacing: 4) {
                    Text("watch.carTier.90DayScore".localized)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.gray)

                    Text("\(displayScore)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding()
        }
    }
}

// MARK: - Tier Progress Bar

struct TierProgressBar: View {
    let currentTier: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index <= currentTier ? WatchHealthData.tierColor(for: index) : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }

            Text("Level \(currentTier + 1)/5")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Preview

#Preview {
    CarTierView()
        .environmentObject(WatchDataManager.shared)
}
