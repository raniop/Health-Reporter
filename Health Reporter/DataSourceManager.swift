//
//  DataSourceManager.swift
//  Health Reporter
//
//  מנהל זיהוי מקור נתונים (Apple Watch / Garmin / Oura) והעדפות משתמש.
//

import Foundation
import HealthKit

// MARK: - Health Data Source Enum

/// מקורות נתונים נתמכים
enum HealthDataSource: String, CaseIterable, Codable {
    case appleWatch = "Apple Watch"
    case garmin = "Garmin"
    case oura = "Oura"
    case whoop = "WHOOP"
    case fitbit = "Fitbit"
    case samsung = "Samsung"
    case other = "Other"
    case autoDetect = "Auto"

    /// שם תצוגה בעברית
    var displayNameHebrew: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .garmin: return "Garmin"
        case .oura: return "Oura Ring"
        case .whoop: return "WHOOP"
        case .fitbit: return "Fitbit"
        case .samsung: return "Samsung Health"
        case .other: return "אחר"
        case .autoDetect: return "זיהוי אוטומטי"
        }
    }

    /// Localized display name
    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .garmin: return "Garmin"
        case .oura: return "Oura Ring"
        case .whoop: return "WHOOP"
        case .fitbit: return "Fitbit"
        case .samsung: return "Samsung Health"
        case .other: return "dataSources.other".localized
        case .autoDetect: return "dataSources.autoDetect".localized
        }
    }

    /// שם קצר לאינדיקטור
    var shortName: String {
        switch self {
        case .appleWatch: return "Watch"
        case .garmin: return "Garmin"
        case .oura: return "Oura"
        case .whoop: return "WHOOP"
        case .fitbit: return "Fitbit"
        case .samsung: return "Samsung"
        case .other: return "Other"
        case .autoDetect: return "Auto"
        }
    }

    /// אייקון SF Symbol
    var icon: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .garmin: return "figure.run"
        case .oura: return "circle.circle"
        case .whoop: return "waveform.path.ecg"
        case .fitbit: return "heart.fill"
        case .samsung: return "smartphone"
        case .other: return "questionmark.circle"
        case .autoDetect: return "antenna.radiowaves.left.and.right"
        }
    }

    /// צבע מזהה
    var color: String {
        switch self {
        case .appleWatch: return "#007AFF"  // Apple Blue
        case .garmin: return "#007DC3"      // Garmin Blue
        case .oura: return "#B4A7D6"        // Oura Purple
        case .whoop: return "#00D1FF"       // WHOOP Cyan
        case .fitbit: return "#00B0B9"      // Fitbit Teal
        case .samsung: return "#1428A0"     // Samsung Blue
        case .other: return "#8E8E93"       // Gray
        case .autoDetect: return "#34C759"  // Green
        }
    }

    /// חוזקות הידועות של כל מכשיר
    var strengths: [String] {
        switch self {
        case .appleWatch:
            return ["ECG מדויק", "זיהוי נפילות", "אינטגרציה מלאה עם iOS"]
        case .garmin:
            return ["Body Battery", "Training Load", "GPS מדויק", "חיי סוללה ארוכים"]
        case .oura:
            return ["HRV בשינה (מדויק מאוד)", "מעקב טמפרטורת גוף", "Readiness Score"]
        case .whoop:
            return ["מעקב Strain", "ניתוח התאוששות", "מעקב 24/7"]
        case .fitbit:
            return ["מעקב שינה", "מעקב פעילות", "קהילה"]
        case .samsung:
            return ["מעקב לחץ דם", "ECG", "הרכב גוף"]
        case .other, .autoDetect:
            return []
        }
    }
}

// MARK: - Source Detection Result

/// תוצאת זיהוי מקורות נתונים
struct SourceDetectionResult {
    let primarySource: HealthDataSource
    let detectedSources: Set<HealthDataSource>
    let sourceCounts: [HealthDataSource: Int]
    let lastSyncDates: [HealthDataSource: Date]

    /// מקור עיקרי לפי מספר דגימות
    var dominantSource: HealthDataSource {
        sourceCounts.max(by: { $0.value < $1.value })?.key ?? primarySource
    }
}

// MARK: - Data Source Manager

/// Singleton לניהול מקורות נתונים
final class DataSourceManager {
    static let shared = DataSourceManager()

    private let userDefaultsKey = "preferredHealthDataSource"
    private let lastDetectionKey = "lastSourceDetection"

    // MARK: - Known Source Identifiers

    /// מזהי Garmin ידועים
    private let garminIdentifiers: Set<String> = [
        "garmin", "garmin connect", "connect iq", "garmin health",
        "com.garmin", "garmin.com"
    ]

    /// מזהי Oura ידועים
    private let ouraIdentifiers: Set<String> = [
        "oura", "oura ring", "ouraring", "com.ouraring"
    ]

    /// מזהי Apple ידועים
    private let appleIdentifiers: Set<String> = [
        "apple watch", "watch", "com.apple.health", "com.apple"
    ]

    /// מזהי WHOOP ידועים
    private let whoopIdentifiers: Set<String> = [
        "whoop", "com.whoop"
    ]

    /// מזהי Fitbit ידועים
    private let fitbitIdentifiers: Set<String> = [
        "fitbit", "com.fitbit"
    ]

    /// מזהי Samsung ידועים
    private let samsungIdentifiers: Set<String> = [
        "samsung", "samsung health", "com.samsung"
    ]

    // MARK: - User Preferences

    /// העדפת המשתמש למקור נתונים
    var preferredSource: HealthDataSource {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey),
               let source = HealthDataSource(rawValue: rawValue) {
                return source
            }
            return .autoDetect
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
            NotificationCenter.default.post(name: .dataSourceChanged, object: newValue)
        }
    }

    /// תוצאת הזיהוי האחרונה (cached)
    private(set) var lastDetectionResult: SourceDetectionResult?

    // MARK: - Init

    private init() {}

    // MARK: - Source Detection

    /// זיהוי מקור מדגימת HealthKit בודדת
    func detectSource(from sample: HKSample) -> HealthDataSource {
        let sourceName = sample.sourceRevision.source.name.lowercased()
        let bundleId = (sample.sourceRevision.source.bundleIdentifier ?? "").lowercased()

        // בדיקה לפי שם מקור ו-bundle identifier
        if garminIdentifiers.contains(where: { sourceName.contains($0) || bundleId.contains($0) }) {
            return .garmin
        }
        if ouraIdentifiers.contains(where: { sourceName.contains($0) || bundleId.contains($0) }) {
            return .oura
        }
        if whoopIdentifiers.contains(where: { sourceName.contains($0) || bundleId.contains($0) }) {
            return .whoop
        }
        if fitbitIdentifiers.contains(where: { sourceName.contains($0) || bundleId.contains($0) }) {
            return .fitbit
        }
        if samsungIdentifiers.contains(where: { sourceName.contains($0) || bundleId.contains($0) }) {
            return .samsung
        }
        if appleIdentifiers.contains(where: { sourceName.contains($0) || bundleId.contains($0) }) {
            return .appleWatch
        }

        return .other
    }

    /// ניתוח מערך דגימות לזיהוי מקור עיקרי
    func analyzeDataSources(samples: [HKSample]) -> SourceDetectionResult {
        var sourceCounts: [HealthDataSource: Int] = [:]
        var detectedSources: Set<HealthDataSource> = []
        var lastSyncDates: [HealthDataSource: Date] = [:]

        for sample in samples {
            let source = detectSource(from: sample)
            sourceCounts[source, default: 0] += 1
            detectedSources.insert(source)

            // עדכון תאריך סנכרון אחרון
            if let existing = lastSyncDates[source] {
                if sample.endDate > existing {
                    lastSyncDates[source] = sample.endDate
                }
            } else {
                lastSyncDates[source] = sample.endDate
            }
        }

        // קביעת מקור עיקרי
        let primarySource: HealthDataSource
        if preferredSource != .autoDetect {
            primarySource = preferredSource
        } else {
            // זיהוי אוטומטי - לפי כמות הדגימות
            primarySource = sourceCounts.max(by: { $0.value < $1.value })?.key ?? .appleWatch
        }

        let result = SourceDetectionResult(
            primarySource: primarySource,
            detectedSources: detectedSources,
            sourceCounts: sourceCounts,
            lastSyncDates: lastSyncDates
        )

        lastDetectionResult = result
        return result
    }

    /// זיהוי מקור מרשימת מקורות HealthKit
    func detectSources(from sources: Set<HKSource>) -> Set<HealthDataSource> {
        var detected: Set<HealthDataSource> = []

        for source in sources {
            let name = source.name.lowercased()
            let bundleId = (source.bundleIdentifier ?? "").lowercased()

            if garminIdentifiers.contains(where: { name.contains($0) || bundleId.contains($0) }) {
                detected.insert(.garmin)
            } else if ouraIdentifiers.contains(where: { name.contains($0) || bundleId.contains($0) }) {
                detected.insert(.oura)
            } else if whoopIdentifiers.contains(where: { name.contains($0) || bundleId.contains($0) }) {
                detected.insert(.whoop)
            } else if fitbitIdentifiers.contains(where: { name.contains($0) || bundleId.contains($0) }) {
                detected.insert(.fitbit)
            } else if samsungIdentifiers.contains(where: { name.contains($0) || bundleId.contains($0) }) {
                detected.insert(.samsung)
            } else if appleIdentifiers.contains(where: { name.contains($0) || bundleId.contains($0) }) {
                detected.insert(.appleWatch)
            }
        }

        return detected
    }

    // MARK: - Effective Source

    /// מחזיר את המקור האפקטיבי (העדפה או זיהוי)
    func effectiveSource() -> HealthDataSource {
        if preferredSource != .autoDetect {
            return preferredSource
        }
        return lastDetectionResult?.dominantSource ?? .appleWatch
    }

    // MARK: - Source Info

    /// מחזיר מידע על חוזקות המקור הנבחר לתצוגה
    func sourceInfoText() -> String {
        let source = effectiveSource()
        let strengths = source.strengths

        if strengths.isEmpty {
            return ""
        }

        return "חוזקות \(source.displayNameHebrew): " + strengths.joined(separator: ", ")
    }

    /// האם המקור הנוכחי מספק HRV מדויק בשינה
    func hasAccurateSleepHRV() -> Bool {
        let source = effectiveSource()
        return source == .oura || source == .whoop
    }

    /// האם המקור מספק שלבי שינה מפורטים
    func hasDetailedSleepStages() -> Bool {
        let source = effectiveSource()
        return source == .oura || source == .garmin || source == .whoop
    }

    /// האם המקור מספק Body Battery / Readiness נייטיבי
    func hasNativeReadinessScore() -> Bool {
        // אף מקור לא מסנכרן את ה-Readiness/Body Battery לאפל הלט'
        // לכן תמיד נצטרך לחשב
        return false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dataSourceChanged = Notification.Name("dataSourceChanged")
    static let backgroundColorChanged = Notification.Name("backgroundColorChanged")
}
