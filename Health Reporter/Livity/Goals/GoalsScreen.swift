//
//  GoalsScreen.swift
//  Health Reporter
//
//  Livity-style Goals tab: list of habits, each showing progress + streak heatmap.
//  Plus button opens the Add Habit sheet.
//

import SwiftUI
import Combine

final class LivityGoalsViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var values: [UUID: Double] = [:]
    @Published var loadingHabits: Set<UUID> = []

    func refresh() {
        habits = HabitStore.shared.habits
        loadValues()
    }

    private func loadValues() {
        for habit in habits {
            // Show today's cached value (if any) immediately so the card isn't blank while we fetch.
            if let cached = HabitStore.shared.todayProgress(for: habit)?.value {
                values[habit.id] = cached
            }
            // Fire the fast "today" query first so the ring updates quickly.
            loadingHabits.insert(habit.id)
            LivityMetricsService.shared.fetchHabitValue(type: habit.type, on: Date()) { [weak self] value in
                guard let self else { return }
                self.values[habit.id] = value
                HabitStore.shared.recordProgress(habit: habit, date: Date(), value: value)
            }
            // Then backfill history for streaks & heatmap.
            LivityMetricsService.shared.fetchHabitHistory(type: habit.type, endingOn: Date()) { [weak self] entries in
                guard let self else { return }
                if !entries.isEmpty {
                    HabitStore.shared.recordProgress(habit: habit, entries: entries)
                }
                self.loadingHabits.remove(habit.id)
            }
        }
    }
}

struct LivityGoalsScreen: View {
    @StateObject private var vm = LivityGoalsViewModel()
    @ObservedObject private var store = HabitStore.shared
    @State private var showAddSheet = false
    @State private var editingHabit: Habit?

    var body: some View {
        ZStack(alignment: .top) {
            LivityTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    headerBar
                        .padding(.horizontal, LivityTheme.horizontalPadding)
                        .padding(.top, 12)

                    if store.habits.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        ForEach(store.habits) { habit in
                            HabitCardView(
                                habit: habit,
                                currentValue: vm.values[habit.id] ?? 0,
                                entries: store.progress(for: habit),
                                currentStreak: store.currentStreak(for: habit),
                                bestStreak: store.bestStreak(for: habit),
                                isLoadingHistory: vm.loadingHabits.contains(habit.id)
                            ) {
                                editingHabit = habit
                            }
                                .contextMenu {
                                    Button {
                                        editingHabit = habit
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        HabitStore.shared.delete(habit)
                                        vm.refresh()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .padding(.horizontal, LivityTheme.horizontalPadding)
                        }
                    }

                    Color.clear.frame(height: 90)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddHabitSheet(editingHabit: nil) { newHabit in
                HabitStore.shared.add(newHabit)
                vm.refresh()
            }
        }
        .sheet(item: $editingHabit) { habit in
            AddHabitSheet(
                editingHabit: habit,
                onSave: { updated in
                    HabitStore.shared.update(updated)
                    vm.refresh()
                },
                onDelete: { toDelete in
                    HabitStore.shared.delete(toDelete)
                    vm.refresh()
                }
            )
        }
        .onAppear { vm.refresh() }
    }

    private var headerBar: some View {
        HStack {
            Text("livity.goals.title".localized)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(LivityTheme.textPrimary)
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LivityTheme.cardFill).shadow(color: .black.opacity(0.08), radius: 6, y: 2))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(LivityTheme.goodTint).frame(width: 80, height: 80)
                Image(systemName: "target")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(LivityTheme.good)
            }
            Text("livity.goals.emptyTitle".localized)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LivityTheme.textPrimary)
            Text("livity.goals.emptySubtitle".localized)
                .font(.system(size: 15))
                .foregroundStyle(LivityTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
