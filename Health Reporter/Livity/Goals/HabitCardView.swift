//
//  HabitCardView.swift
//  Health Reporter
//
//  A single habit card for the Goals screen: icon, title, today's progress, streak heatmap.
//

import SwiftUI

struct HabitCardView: View {
    let habit: Habit
    let currentValue: Double
    let entries: [HabitDayProgress]
    let currentStreak: Int
    let bestStreak: Int
    var isLoadingHistory: Bool = false
    let onTap: () -> Void

    private var progress: Double {
        guard habit.goal > 0 else { return 0 }
        return min(1.0, currentValue / habit.goal)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                headerRow
                Divider().overlay(LivityTheme.separator)
                streakRow
                ZStack {
                    HabitHeatmap(habit: habit, entries: entries, todayTapped: false)
                        .frame(height: 120)
                        .opacity(isLoadingHistory && entries.isEmpty ? 0.3 : 1)
                    if isLoadingHistory && entries.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.85)
                            Text("livity.habit.loading".localized)
                                .font(.system(size: 13))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(habit.color.color.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(habit.color.color.opacity(0.25)).frame(width: 42, height: 42)
                Image(systemName: habit.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(habit.color.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.type.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(progressLabel)
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Spacer()
            LivityRingWithContent(progress: progress, color: habit.color.color, lineWidth: 6, size: 54) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
        }
    }

    private var streakRow: some View {
        HStack {
            HStack(spacing: 4) {
                Text(currentStreak > 0 ? "🔥" : "💤")
                Text(currentStreak > 0 ? String(format: "livity.habit.streak.single".localized, currentStreak) : "livity.habit.streak.none".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("🏆")
                Text(String(format: "livity.habit.best".localized, bestStreak))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
        }
    }

    private var progressLabel: String {
        let freqWord: String = {
            switch habit.frequency {
            case .daily: return "livity.habit.freq.today".localized
            case .weekly: return "livity.habit.freq.thisWeek".localized
            case .monthly: return "livity.habit.freq.thisMonth".localized
            }
        }()
        let unit = habit.type.unit.isEmpty ? "" : " \(habit.type.unit)"
        let goalStr = format(habit.goal)
        let valStr = format(currentValue)
        return "\(valStr) / \(goalStr)\(unit) \(freqWord)"
    }

    private func format(_ v: Double) -> String {
        let f = NumberFormatter()
        f.usesGroupingSeparator = true
        f.groupingSeparator = ","
        f.maximumFractionDigits = v.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }
}
