//
//  AddHabitSheet.swift
//  Health Reporter
//
//  Full "Add Habit" bottom sheet: type, frequency, goal, color, reminders, historical data.
//

import SwiftUI

struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// When non-nil we're EDITING an existing habit (pre-fills fields, swaps the
    /// "+" header button for "Save", and shows a delete action). When nil the
    /// sheet behaves as the original Add Habit flow.
    let editingHabit: Habit?

    @State private var selectedType: HabitType = .steps
    @State private var frequency: HabitFrequency = .daily
    @State private var goalText: String = "10000"
    @State private var color: HabitColor = .green
    @State private var dailyReminders: Bool = true
    @State private var goalCompleted: Bool = true
    @State private var progressReminder: Bool = true
    @State private var reminderTime: Date = {
        var comps = DateComponents(); comps.hour = 19; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()
    @State private var syncHistorical: Bool = true
    @State private var showDeleteConfirm = false

    let onSave: (Habit) -> Void
    var onDelete: ((Habit) -> Void)? = nil

    private var isEditing: Bool { editingHabit != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                section(title: "livity.addHabit.whatToTrack".localized) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(HabitType.allCases) { type in
                            typeChip(type)
                        }
                    }
                }

                section(title: "livity.addHabit.howOften".localized) {
                    HStack(spacing: 10) {
                        ForEach(HabitFrequency.allCases) { f in
                            Button { frequency = f } label: {
                                Text(f.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(frequency == f ? LivityTheme.textPrimary : LivityTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule().fill(frequency == f ? LivityTheme.goodTint : Color.white)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(frequency.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(LivityTheme.textSecondary)
                }

                section(title: "\(frequency.label) \("livity.addHabit.goal".localized)") {
                    goalEditor
                }

                section(title: "livity.addHabit.color".localized) {
                    HStack(spacing: 10) {
                        ForEach(HabitColor.allCases) { c in
                            Button { color = c } label: {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Group {
                                            if color == c {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    )
                                    .overlay(
                                        Circle().strokeBorder(color == c ? LivityTheme.textPrimary : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Capsule().fill(Color.white))
                }

                section(title: "livity.addHabit.reminders".localized) {
                    remindersBlock
                }

                section(title: "livity.addHabit.data".localized) {
                    settingRow(
                        icon: "arrow.counterclockwise",
                        iconColor: LivityTheme.info,
                        title: "livity.addHabit.historical".localized,
                        subtitle: "livity.addHabit.historicalSubtitle".localized,
                        value: $syncHistorical
                    )
                }

                if isEditing, let habit = editingHabit, onDelete != nil {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Habit")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(LivityTheme.bad)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.badTint.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Delete \(habit.type.displayName) habit?",
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            onDelete?(habit)
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will remove the habit and all its tracked progress.")
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(LivityTheme.background.ignoresSafeArea())
        .onChange(of: selectedType) { _, new in
            // Only reset the goal when the user actively switches type — don't
            // stomp the saved value while we're pre-filling for edit mode.
            if !isEditing || editingHabit?.type != new {
                goalText = String(Int(new.defaultGoal))
            }
        }
        .onAppear { applyEditingHabitIfNeeded() }
    }

    private func applyEditingHabitIfNeeded() {
        guard let habit = editingHabit else { return }
        selectedType = habit.type
        frequency = habit.frequency
        goalText = String(Int(habit.goal))
        color = habit.color
        dailyReminders = habit.dailyReminders
        goalCompleted = habit.goalCompletedNotif
        progressReminder = habit.progressReminder
        var comps = DateComponents()
        comps.hour = habit.reminderHour
        comps.minute = habit.reminderMinute
        reminderTime = Calendar.current.date(from: comps) ?? reminderTime
        syncHistorical = habit.syncHistoricalData
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(isEditing ? "Edit Habit" : "livity.addHabit.title".localized)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(LivityTheme.textPrimary)
            Spacer()
            Button {
                saveHabit()
            } label: {
                Image(systemName: isEditing ? "checkmark" : "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(LivityTheme.goodTint))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Sections

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        // Don't uppercase — Hebrew has no case, and uppercasing mangles RTL text rendering.
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LivityTheme.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func typeChip(_ type: HabitType) -> some View {
        let selected = selectedType == type
        return Button {
            selectedType = type
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(selected ? LivityTheme.goodTint : LivityTheme.chipFill).frame(width: 32, height: 32)
                    Image(systemName: type.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? LivityTheme.good : LivityTheme.textPrimary)
                }
                Text(type.displayName)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if selected {
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LivityTheme.good)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule().fill(selected ? LivityTheme.goodTint.opacity(0.6) : Color.white)
            )
        }
        .buttonStyle(.plain)
    }

    private var goalEditor: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("", text: $goalText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .multilineTextAlignment(.trailing)
                Text(selectedType.unit)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            HStack(spacing: 12) {
                ForEach(selectedType.suggestedGoals, id: \.self) { g in
                    Button {
                        goalText = String(Int(g))
                    } label: {
                        Text(formatSuggested(g))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LivityTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelectedGoal(g) ? LivityTheme.goodTint : LivityTheme.chipFill)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(LivityTheme.cardFill))
    }

    private func isSelectedGoal(_ g: Double) -> Bool {
        Double(goalText) == g
    }

    private func formatSuggested(_ g: Double) -> String {
        if g >= 1000 { return "\(Int(g / 1000))k" }
        return "\(Int(g))"
    }

    private var remindersBlock: some View {
        VStack(spacing: 0) {
            settingRow(icon: "bell.fill", iconColor: LivityTheme.good, title: "livity.addHabit.dailyReminders".localized, subtitle: "livity.addHabit.dailyRemindersSubtitle".localized, value: $dailyReminders)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill))

            VStack(spacing: 0) {
                settingRow(icon: "checkmark.seal.fill", iconColor: LivityTheme.good, title: "livity.addHabit.goalCompleted".localized, subtitle: "livity.addHabit.goalCompletedSubtitle".localized, value: $goalCompleted)
                Divider().overlay(LivityTheme.separator)
                settingRow(icon: "clock.badge.exclamationmark", iconColor: LivityTheme.warning, title: "livity.addHabit.progressReminder".localized, subtitle: "livity.addHabit.progressReminderSubtitle".localized, value: $progressReminder)
                Divider().overlay(LivityTheme.separator)
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(LivityTheme.goodTint).frame(width: 32, height: 32)
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LivityTheme.good)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("livity.addHabit.reminderTime".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Text("livity.addHabit.reminderTimeSubtitle".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(LivityTheme.textSecondary)
                    }
                    Spacer()
                    DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill))
            .padding(.top, 10)
        }
    }

    private func settingRow(icon: String, iconColor: Color, title: String, subtitle: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconColor.opacity(0.18)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: value)
                .labelsHidden()
                .tint(LivityTheme.good)
        }
    }

    // MARK: - Save

    private func saveHabit() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let goal = Double(goalText) ?? selectedType.defaultGoal
        let habit = Habit(
            // Preserve the original id + createdAt when editing, otherwise a
            // new UUID is assigned and HabitStore.update() won't find a match.
            id: editingHabit?.id ?? UUID(),
            type: selectedType,
            frequency: frequency,
            goal: goal,
            color: color,
            dailyReminders: dailyReminders,
            goalCompletedNotif: goalCompleted,
            progressReminder: progressReminder,
            reminderHour: comps.hour ?? 19,
            reminderMinute: comps.minute ?? 0,
            syncHistoricalData: syncHistorical,
            createdAt: editingHabit?.createdAt ?? Date()
        )
        onSave(habit)
        dismiss()
    }
}
