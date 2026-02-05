//
//  CarTierView.swift
//  Health Reporter Watch App
//
//  Displays the Gemini car tier with visual representation (90-day average score)
//

import SwiftUI

struct CarTierView: View {
    @EnvironmentObject var dataManager: WatchDataManager

    private var data: WatchHealthData {
        dataManager.healthData
    }

    // Use Gemini data if available, otherwise fall back to daily data
    private var displayCarName: String {
        data.geminiCarName ?? data.carName
    }

    private var displayScore: Int {
        data.geminiCarScore ?? data.healthScore
    }

    private var displayTierIndex: Int {
        data.geminiCarTierIndex ?? data.carTierIndex
    }

    private var tierColor: Color {
        switch displayTierIndex {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return .mint
        }
    }

    private var tierEmoji: String {
        switch displayTierIndex {
        case 0: return "🚙"
        case 1: return "🚗"
        case 2: return "🏎️"
        case 3: return "🏁"
        default: return "🏆"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Large Car Emoji with glow (based on tier)
                Text(tierEmoji)
                    .font(.system(size: 60))
                    .shadow(color: tierColor.opacity(0.6), radius: 20)
                    .padding(.top, 8)

                // Car Name from Gemini
                Text(displayCarName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .onAppear {
                        print("⌚️ CarTierView: geminiCarName=\(data.geminiCarName ?? "nil"), geminiScore=\(data.geminiCarScore ?? 0), displayCarName=\(displayCarName), displayScore=\(displayScore)")
                    }

                // Tier Progress Bar
                TierProgressBar(currentTier: displayTierIndex)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Health Score (90-day average)
                HStack(spacing: 4) {
                    Text("watch.carTier.90DayScore".localized)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.gray)

                    Text("\(displayScore)")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
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
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index <= currentTier ? tierColor(for: index) : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }

            // Tier level text
            Text("Level \(currentTier + 1)/5")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.gray)
        }
    }

    private func tierColor(for index: Int) -> Color {
        switch index {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        default: return .mint
        }
    }
}

// MARK: - Preview

#Preview {
    CarTierView()
        .environmentObject(WatchDataManager.shared)
}
