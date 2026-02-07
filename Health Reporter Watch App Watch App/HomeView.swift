//
//  HomeView.swift
//  Health Reporter Watch App
//
//  Main dashboard showing health score and quick stats (like iPhone main screen)
//

import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var dataManager: WatchDataManager
    @State private var showPeriodPicker = false
    @State private var showScoreBreakdown = false
    @State private var selectedPeriod: TimePeriod = .today

    private var data: WatchHealthData {
        dataManager.healthData
    }

    // Computed values based on period
    private var displaySteps: Int {
        switch selectedPeriod {
        case .today: return data.steps
        case .week: return data.steps * 7
        case .month: return data.steps * 30
        }
    }

    private var displaySleepHours: Double {
        switch selectedPeriod {
        case .today: return data.sleepHours
        case .week: return data.sleepHours * 7
        case .month: return data.sleepHours * 30
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Spacer()
                .frame(height: 10)

            // Health Score Ring (like iPhone)
            // Tap to show breakdown, long-press kept for period picker
            HealthScoreRing(
                score: data.healthScore,
                status: data.healthStatus
            )
            .frame(width: 125, height: 125)
            .onTapGesture {
                showScoreBreakdown = true
            }
            .onLongPressGesture {
                showPeriodPicker = true
            }
            .sheet(isPresented: $showScoreBreakdown) {
                ScoreBreakdownView()
                    .environmentObject(dataManager)
            }

            // Health Status Label (like iPhone main screen)
            Text(data.healthStatus)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.gray)
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
                    value: formatSleep(displaySleepHours),
                    color: .purple
                )

                QuickStat(
                    icon: "figure.walk",
                    value: formatSteps(displaySteps),
                    color: .green
                )
            }
            .padding(.top, 2)

            // Period indicator - always visible, tappable to change
            Button(action: { showPeriodPicker = true }) {
                Text(selectedPeriod.localizedName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
            }
            .buttonStyle(.plain)

            // Sync Status
            if data.isStale {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("watch.home.dataStale".localized)
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .sheet(isPresented: $showPeriodPicker) {
            PeriodPickerView(selectedPeriod: $selectedPeriod)
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

// MARK: - Period Picker View

struct PeriodPickerView: View {
    @Binding var selectedPeriod: TimePeriod
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                    dismiss()
                }) {
                    HStack {
                        Text(period.localizedName)
                            .foregroundColor(.white)
                        Spacer()
                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("watch.period.title".localized)
    }
}

// MARK: - Period Enum

enum TimePeriod: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"

    var localizedName: String {
        switch self {
        case .today: return "period.day".localized
        case .week: return "period.week".localized
        case .month: return "period.month".localized
        }
    }
}

// MARK: - Health Score Ring (like iPhone)

struct HealthScoreRing: View {
    let score: Int
    let status: String

    private var progress: Double {
        Double(score) / 100.0
    }

    private var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [.red, .orange, .yellow, .green, .mint]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 10)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Score only in center (larger)
            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.white)
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
                .foregroundColor(color)
                .frame(height: 16, alignment: .center)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
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
