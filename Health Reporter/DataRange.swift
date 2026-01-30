//
//  DataRange.swift
//  Health Reporter
//
//  טווח נתונים: יום / שבוע / חודש.
//  מספק תיאור ברור למשתמש: "נתוני יום | 24 בינואר 2026".
//

import Foundation

enum DataRange: String, CaseIterable {
    case day
    case week
    case month

    var title: String {
        switch self {
        case .day: return "יום"
        case .week: return "שבוע"
        case .month: return "חודש"
        }
    }

    var shortTitle: String { title }

    /// תאריך התחלה וסיום לטווח הנוכחי (יחסית ליום הזה)
    func interval(relativeTo date: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let endOfToday = date
        let startOfToday = cal.startOfDay(for: date)
        let start: Date
        let end: Date
        switch self {
        case .day:
            start = startOfToday
            end = endOfToday
        case .week:
            start = cal.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
            end = endOfToday
        case .month:
            start = cal.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday
            end = endOfToday
        }
        return (start, end)
    }

    /// מספר ימים בטווח (כולל)
    var dayCount: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        }
    }

    /// טקסט להצגה: "נתוני [יום|שבוע|חודש] | [תאריכים]"
    func displayLabel(relativeTo date: Date = Date()) -> String {
        let (start, end) = interval(relativeTo: date)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "he_IL")
        fmt.dateFormat = "d בMMMM yyyy"

        switch self {
        case .day:
            return "נתוני יום · \(fmt.string(from: end))"
        case .week:
            fmt.dateFormat = "d"
            let a = fmt.string(from: start)
            fmt.dateFormat = "d בMMMM yyyy"
            let b = fmt.string(from: end)
            return "נתוני שבוע · \(a)–\(b)"
        case .month:
            fmt.dateFormat = "MMMM yyyy"
            return "נתוני חודש · \(fmt.string(from: end))"
        }
    }

    /// Short text for segment: "Today" / "7 Days" / "30 Days"
    func segmentTitle() -> String {
        switch self {
        case .day: return "time.today".localized
        case .week: return "time.7days".localized
        case .month: return "time.30days".localized
        }
    }
}
