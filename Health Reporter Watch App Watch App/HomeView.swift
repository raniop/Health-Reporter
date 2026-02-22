//
//  HomeView.swift
//  Health Reporter Watch App
//
//  Main dashboard showing health score and quick stats

import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var dataManager: WatchDataManager
    @State private var showScoreBreakdown = false
    @State private var animatedProgress: Double = 0

    private var data: WatchHealthData {
        dataManager.healthData
    }

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
                .frame(height: 10)

            // Health Score Ring - tap to show breakdown
            HealthScoreRing(
                score: data.healthScore,
                animatedProgress: animatedProgress
            )
            .frame(width: 125, height: 125)
            .onTapGesture {
                showScoreBreakdown = true
            }
            .sheet(isPresented: $showScoreBreakdown) {
                ScoreBreakdownView()
                    .environmentObject(dataManager)
            }

            // Health Status Label
            Text(data.healthStatus)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            // Quick Stats Row
            HStack(spacing: 20) {
                QuickStat(
                    icon: "heart.fill",
                    value: "\(data.heartRate)",
                    color: .red
                )

                QuickStat(
                    icon: "bed.double.fill",
                    value: formatSleep(data.sleepHours),
                    color: .purple
                )

                QuickStat(
                    icon: "figure.walk",
                    value: formatSteps(data.steps),
                    color: .green
                )
            }
            .padding(.top, 2)

            // Sync Status
            if data.isStale {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("watch.home.dataStale".localized)
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .onChange(of: data.healthScore) { _, newScore in
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = Double(newScore) / 100.0
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProgress = Double(data.healthScore) / 100.0
            }
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            return String(format: "%.1fK", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }

    private func formatSleep(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if m > 0 {
            return "\(h)h \(m)m"
        }
        return "\(h)h"
    }
}

// MARK: - Health Score Ring

struct HealthScoreRing: View {
    let score: Int
    let animatedProgress: Double

    private var scoreColor: Color {
        WatchHealthData.scoreColor(for: score)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 10)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.red, .orange, .yellow, .green, .mint]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Score in center
            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(4)
    }
}

// MARK: - Quick Stat

struct QuickStat: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(height: 16, alignment: .center)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(height: 14, alignment: .center)
        }
        .frame(width: 55)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(WatchDataManager.shared)
}
