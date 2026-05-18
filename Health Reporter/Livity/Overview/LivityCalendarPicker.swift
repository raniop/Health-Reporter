//
//  LivityCalendarPicker.swift
//  Health Reporter
//
//  Expanding month calendar shown when tapping the date pill.
//

import SwiftUI

struct LivityCalendarPicker: View {
    @Binding var selectedDate: Date
    @Binding var displayMonth: Date
    let onPick: (Date) -> Void

    private let calendar = Calendar.current
    private let weekdaySymbols = [
        "livity.weekday.sun".localized,
        "livity.weekday.mon".localized,
        "livity.weekday.tue".localized,
        "livity.weekday.wed".localized,
        "livity.weekday.thu".localized,
        "livity.weekday.fri".localized,
        "livity.weekday.sat".localized
    ]

    var body: some View {
        VStack(spacing: 14) {
            monthNav

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 10) {
                ForEach(daysGrid, id: \.self) { entry in
                    cell(for: entry)
                }
            }
        }
        .padding(.horizontal, LivityTheme.horizontalPadding)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LivityTheme.cardFill)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        )
        .padding(.horizontal, LivityTheme.horizontalPadding)
    }

    private var monthNav: some View {
        HStack {
            Button {
                if let prev = calendar.date(byAdding: .month, value: -1, to: displayMonth) {
                    displayMonth = prev
                }
            } label: {
                HStack(spacing: 6) {
                    Text(Self.monthFormatter.string(from: displayMonth))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 18) {
                Button {
                    if let prev = calendar.date(byAdding: .month, value: -1, to: displayMonth) { displayMonth = prev }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                }.buttonStyle(.plain)
                Button {
                    if let next = calendar.date(byAdding: .month, value: 1, to: displayMonth),
                       !calendar.isDateInFuture(next, relativeTo: Date()) {
                        displayMonth = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(canGoNextMonth ? LivityTheme.textPrimary : LivityTheme.textTertiary)
                }.buttonStyle(.plain)
                .disabled(!canGoNextMonth)
            }
        }
    }

    private var canGoNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayMonth) else { return false }
        return next <= Date()
    }

    private struct DayEntry: Hashable {
        let date: Date?
        let dayNumber: Int?
    }

    private var daysGrid: [DayEntry] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayMonth),
            let range = calendar.range(of: .day, in: .month, for: displayMonth)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start) // 1=Sun
        var entries: [DayEntry] = []
        for _ in 1..<firstWeekday { entries.append(DayEntry(date: nil, dayNumber: nil)) }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                entries.append(DayEntry(date: date, dayNumber: day))
            }
        }
        return entries
    }

    @ViewBuilder
    private func cell(for entry: DayEntry) -> some View {
        if let date = entry.date, let day = entry.dayNumber {
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let isFuture = date > Date()
            Button {
                guard !isFuture else { return }
                selectedDate = date
                onPick(date)
            } label: {
                Text("\(day)")
                    .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(color(isSelected: isSelected, isFuture: isFuture))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        Circle().fill(isSelected ? LivityTheme.info : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
        } else {
            Color.clear.frame(height: 40)
        }
    }

    private func color(isSelected: Bool, isFuture: Bool) -> Color {
        if isSelected { return .white }
        if isFuture { return LivityTheme.textTertiary }
        return LivityTheme.textPrimary
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

private extension Calendar {
    func isDateInFuture(_ date: Date, relativeTo ref: Date) -> Bool {
        date > ref
    }
}
