//
//  HabitStore.swift
//  Health Reporter
//
//  UserDefaults-backed persistence for habits + daily progress.
//

import Foundation
import Combine

final class HabitStore: ObservableObject {
    static let shared = HabitStore()

    @Published private(set) var habits: [Habit] = []
    @Published private(set) var progress: [UUID: [HabitDayProgress]] = [:]

    private let habitsKey = "livity.habits.v1"
    private let progressKey = "livity.habitProgress.v1"
    private let defaults = UserDefaults.standard

    private init() {
        loadHabits()
        loadProgress()
    }

    // MARK: - Habits CRUD

    func add(_ habit: Habit) {
        habits.append(habit)
        save()
        // Ask for notification permission the first time a user saves a habit
        // that wants a reminder — then install the recurring local notification.
        if habit.dailyReminders {
            HabitNotificationManager.requestAuthorizationIfNeeded { _ in
                HabitNotificationManager.schedule(for: habit)
            }
        }
    }

    func update(_ habit: Habit) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[idx] = habit
        save()
        // Re-schedule (or cancel) to reflect the user's edit — this replaces
        // any pending notification with the same identifier atomically.
        if habit.dailyReminders {
            HabitNotificationManager.requestAuthorizationIfNeeded { _ in
                HabitNotificationManager.schedule(for: habit)
            }
        } else {
            HabitNotificationManager.cancel(for: habit)
        }
    }

    func delete(_ habit: Habit) {
        HabitNotificationManager.cancel(for: habit)
        habits.removeAll { $0.id == habit.id }
        progress.removeValue(forKey: habit.id)
        save()
    }

    // MARK: - Progress

    /// Record the value for a habit on a given date. Marks `met` if value ≥ goal.
    func recordProgress(habit: Habit, date: Date, value: Double) {
        let day = Calendar.current.startOfDay(for: date)
        let met = value >= habit.goal
        var entries = progress[habit.id] ?? []
        entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: day) }
        entries.append(HabitDayProgress(date: day, value: value, met: met))
        progress[habit.id] = entries
        save()
    }

    /// Bulk version for historical backfill: merges a batch of daily values in one save.
    /// Existing entries for the same days are overwritten.
    func recordProgress(habit: Habit, entries: [(date: Date, value: Double)]) {
        guard !entries.isEmpty else { return }
        let cal = Calendar.current
        var current = progress[habit.id] ?? []
        let incomingDays = Set(entries.map { cal.startOfDay(for: $0.date) })
        current.removeAll { incomingDays.contains(cal.startOfDay(for: $0.date)) }
        for entry in entries {
            let day = cal.startOfDay(for: entry.date)
            current.append(HabitDayProgress(date: day, value: entry.value, met: entry.value >= habit.goal))
        }
        progress[habit.id] = current
        save()
    }

    func progress(for habit: Habit) -> [HabitDayProgress] {
        progress[habit.id] ?? []
    }

    func todayProgress(for habit: Habit) -> HabitDayProgress? {
        let today = Calendar.current.startOfDay(for: Date())
        return progress(for: habit).first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    /// Current streak: count of consecutive days (including today or yesterday) with `met == true`.
    func currentStreak(for habit: Habit) -> Int {
        let cal = Calendar.current
        let entries = progress(for: habit).sorted { $0.date > $1.date }
        let today = cal.startOfDay(for: Date())
        var streak = 0
        var cursor = today

        // Allow today to be unset (streak can "continue" — starts counting from yesterday if today has no entry yet)
        if let todayEntry = entries.first(where: { cal.isDate($0.date, inSameDayAs: today) }) {
            if todayEntry.met { streak = 1; cursor = cal.date(byAdding: .day, value: -1, to: today)! }
            else { return 0 }
        } else {
            cursor = cal.date(byAdding: .day, value: -1, to: today)!
        }

        while true {
            if let entry = entries.first(where: { cal.isDate($0.date, inSameDayAs: cursor) }), entry.met {
                streak += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
            } else {
                break
            }
        }
        return streak
    }

    /// Best (longest) streak across entire history.
    func bestStreak(for habit: Habit) -> Int {
        let cal = Calendar.current
        let metDates = progress(for: habit).filter { $0.met }.map { cal.startOfDay(for: $0.date) }.sorted()
        guard !metDates.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for i in 1..<metDates.count {
            let prev = metDates[i - 1]
            let curr = metDates[i]
            if let gap = cal.dateComponents([.day], from: prev, to: curr).day, gap == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    // MARK: - Persistence

    private func save() {
        saveHabits()
        saveProgress()
    }

    private func saveHabits() {
        if let data = try? JSONEncoder().encode(habits) {
            defaults.set(data, forKey: habitsKey)
        }
    }

    private func loadHabits() {
        guard let data = defaults.data(forKey: habitsKey),
              let decoded = try? JSONDecoder().decode([Habit].self, from: data) else {
            habits = []
            return
        }
        habits = decoded
    }

    private func saveProgress() {
        let wrapper = progress.mapValues { $0 }
        if let data = try? JSONEncoder().encode(wrapper.map { ProgressRecord(id: $0.key, entries: $0.value) }) {
            defaults.set(data, forKey: progressKey)
        }
    }

    private func loadProgress() {
        guard let data = defaults.data(forKey: progressKey),
              let decoded = try? JSONDecoder().decode([ProgressRecord].self, from: data) else {
            progress = [:]
            return
        }
        var map: [UUID: [HabitDayProgress]] = [:]
        for record in decoded { map[record.id] = record.entries }
        progress = map
    }

    private struct ProgressRecord: Codable {
        let id: UUID
        let entries: [HabitDayProgress]
    }
}
