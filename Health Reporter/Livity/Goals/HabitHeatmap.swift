//
//  HabitHeatmap.swift
//  Health Reporter
//
//  GitHub-style streak heatmap showing ~6 months of habit progress.
//  Rows = weekdays (Mon-Sun). Columns = weeks. Green square = goal met.
//

import SwiftUI

struct HabitHeatmap: View {
    let habit: Habit
    let entries: [HabitDayProgress]
    let todayTapped: Bool

    private let calendar = Calendar.current
    private let rows: Int = 7   // Mon..Sun
    private let weeksShown: Int = 26

    private var gridStartDate: Date {
        // Start ~26 weeks ago at Monday
        let today = calendar.startOfDay(for: Date())
        let weeksAgo = calendar.date(byAdding: .weekOfYear, value: -(weeksShown - 1), to: today) ?? today
        return startOfWeek(for: weeksAgo)
    }

    private var todayIndex: (col: Int, row: Int) {
        let today = calendar.startOfDay(for: Date())
        let start = gridStartDate
        let daysBetween = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let col = daysBetween / 7
        let row = daysBetween % 7
        return (col, row)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            monthLabels
            gridBody
            HStack {
                HStack(spacing: 6) {
                    Rectangle().fill(Color.clear).frame(width: 12, height: 12).overlay(Rectangle().strokeBorder(LivityTheme.textTertiary, lineWidth: 1.5))
                    Text("livity.habit.legend.today".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("livity.habit.legend.notMet".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                    RoundedRectangle(cornerRadius: 2).fill(habit.color.color)
                        .frame(width: 12, height: 12)
                    Text("livity.habit.legend.met".localized)
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }
        }
    }

    private var monthLabels: some View {
        // Align with the grid: 16pt weekday column + 4pt HStack spacing.
        let leading: CGFloat = 20
        let minLabelSpacing: CGFloat = 28   // approx width of "MMM" at 11pt, prevents collisions
        return GeometryReader { geo in
            let totalWidth = max(0, geo.size.width - leading)
            let colWidth = totalWidth / CGFloat(weeksShown)
            let filtered = spacedLabels(colWidth: colWidth, minSpacing: minLabelSpacing)
            ZStack(alignment: .topLeading) {
                ForEach(filtered, id: \.self) { pos in
                    Text(pos.label)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(LivityTheme.textTertiary)
                        .offset(x: leading + CGFloat(pos.col) * colWidth, y: 0)
                }
            }
        }
        .frame(height: 16)
    }

    private func spacedLabels(colWidth: CGFloat, minSpacing: CGFloat) -> [MonthPosition] {
        var kept: [MonthPosition] = []
        var lastX: CGFloat = -.infinity
        for pos in monthPositions {
            let x = CGFloat(pos.col) * colWidth
            if x - lastX >= minSpacing {
                kept.append(pos)
                lastX = x
            }
        }
        return kept
    }

    private var gridBody: some View {
        HStack(alignment: .top, spacing: 4) {
            // Weekday labels
            VStack(alignment: .leading, spacing: 2) {
                Text("livity.habit.weekday.m".localized).font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary).frame(height: 12)
                Text("").frame(height: 12)
                Text("livity.habit.weekday.w".localized).font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary).frame(height: 12)
                Text("").frame(height: 12)
                Text("livity.habit.weekday.f".localized).font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary).frame(height: 12)
                Text("").frame(height: 12)
                Text("").frame(height: 12)
            }
            .frame(width: 16)

            GeometryReader { geo in
                let gap: CGFloat = 2
                let colCount = CGFloat(weeksShown)
                let colWidth = (geo.size.width - gap * (colCount - 1)) / colCount
                let cellSize = min(colWidth, 12)
                HStack(alignment: .top, spacing: gap) {
                    ForEach(0..<weeksShown, id: \.self) { col in
                        VStack(spacing: gap) {
                            ForEach(0..<rows, id: \.self) { row in
                                cell(col: col, row: row, size: cellSize)
                            }
                        }
                    }
                }
            }
            .frame(height: 12 * 7 + 2 * 6)
        }
    }

    private func cell(col: Int, row: Int, size: CGFloat) -> some View {
        let date = dateForCell(col: col, row: row)
        let isToday = calendar.isDateInToday(date)
        let entry = entries.first { calendar.isDate($0.date, inSameDayAs: date) }
        let isMet = entry?.met ?? false
        let isPast = date <= Date()

        return Group {
            if isToday {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isMet ? habit.color.color : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(LivityTheme.textTertiary, lineWidth: 1.25)
                    )
            } else if isMet {
                RoundedRectangle(cornerRadius: 2).fill(habit.color.color)
            } else if isPast {
                RoundedRectangle(cornerRadius: 2).fill(Color.clear)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(Color.clear)
            }
        }
        .frame(width: size, height: size)
    }

    private func dateForCell(col: Int, row: Int) -> Date {
        let offset = col * 7 + row
        return calendar.date(byAdding: .day, value: offset, to: gridStartDate) ?? gridStartDate
    }

    private func startOfWeek(for date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        // Make Monday the first day (Sunday = 1 in Apple's calendar)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: date)) ?? date
    }

    private struct MonthPosition: Hashable {
        let col: Int
        let label: String
    }

    private var monthPositions: [MonthPosition] {
        var positions: [MonthPosition] = []
        var lastMonth = -1
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateFormat = "MMM"
        for col in 0..<weeksShown {
            let date = calendar.date(byAdding: .day, value: col * 7, to: gridStartDate) ?? gridStartDate
            let month = calendar.component(.month, from: date)
            if month != lastMonth {
                lastMonth = month
                let label = formatter.string(from: date)
                positions.append(MonthPosition(col: col, label: label))
            }
        }
        return positions
    }
}

private extension DateFormatter {
    func with(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        configure(self)
        return self
    }
}
