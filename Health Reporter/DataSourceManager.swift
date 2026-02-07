//
//  DataSourceManager.swift
//  Health Reporter
//
//  Manages data source detection (Apple Watch / Garmin / Oura) and user preferences.
//

import Foundation
import HealthKit

// MARK: - Health Data Source Enum

/// Supported data sources
enum HealthDataSource: String, CaseIterable, Codable {
    case appleWatch = "Apple Watch"
    case garmin = "Garmin"
    case oura = "Oura"
    case whoop = "WHOOP"
    case fitbit = "Fitbit"
    case samsung = "Samsung"
    case other = "Other"
    case autoDetect = "Auto"

    /// Display name (non-localized)
    var displayNameHebrew: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .garmin: return "Garmin"
        case .oura: return "Oura Ring"
        case .whoop: return "WHOOP"
        case .fitbit: return "Fitbit"
        case .samsung: return "Samsung Health"
        case .other: return "Other"
        case .autoDetect: return "Auto Detect"
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

    /// Short name for indicator
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

    /// SF Symbol icon
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

    /// Identifying color
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

    /// Known strengths of each device
    var strengths: [String] {
        switch self {
        case .appleWatch:
            return [
                "dataSources.strength.appleWatch.ecg".localized,
                "dataSources.strength.appleWatch.fallDetection".localized,
                "dataSources.strength.appleWatch.iosIntegration".localized
            ]
        case .garmin:
            return [
                "dataSources.strength.garmin.bodyBattery".localized,
                "dataSources.strength.garmin.trainingLoad".localized,
                "dataSources.strength.garmin.gps".localized,
                "dataSources.strength.garmin.battery".localized
            ]
        case .oura:
            return [
                "dataSources.strength.oura.sleepHrv".localized,
                "dataSources.strength.oura.bodyTemp".localized,
                "dataSources.strength.oura.readiness".localized
            ]
        case .whoop:
            return [
                "dataSources.strength.whoop.strain".localized,
                "dataSources.strength.whoop.recovery".localized,
                "dataSources.strength.whoop.tracking".localized
            ]
        case .fitbit:
            return [
                "dataSources.strength.fitbit.sleep".localized,
                "dataSources.strength.fitbit.activity".localized,
                "dataSources.strength.fitbit.community".localized
            ]
        case .samsung:
            return [
                "dataSources.strength.samsung.bloodPressure".localized,
                "dataSources.strength.samsung.ecg".localized,
                "dataSources.strength.samsung.bodyComposition".localized
            ]
        case .other, .autoDetect:
            return []
        }
    }
}

// MARK: - Source Detection Result

/// Data source detection result
struct SourceDetectionResult {
    let primarySource: HealthDataSource
    let detectedSources: Set<HealthDataSource>
    let sourceCounts: [HealthDataSource: Int]
    let lastSyncDates: [HealthDataSource: Date]

    /// Primary source by number of samples
    var dominantSource: HealthDataSource {
        sourceCounts.max(by: { $0.value < $1.value })?.key ?? primarySource
    }
}

// MARK: - Data Source Manager

/// Singleton for managing data sources
final class DataSourceManager {
    static let shared = DataSourceManager()

    private let userDefaultsKey = "preferredHealthDataSource"
    private let lastDetectionKey = "lastSourceDetection"

    // MARK: - Known Source Identifiers

    /// Known Garmin identifiers
    private let garminIdentifiers: Set<String> = [
        "garmin", "garmin connect", "connect iq", "garmin health",
        "com.garmin", "garmin.com"
    ]

    /// Known Oura identifiers
    private let ouraIdentifiers: Set<String> = [
        "oura", "oura ring", "ouraring", "com.ouraring"
    ]

    /// Known Apple identifiers
    private let appleIdentifiers: Set<String> = [
        "apple watch", "watch", "com.apple.health", "com.apple"
    ]

    /// Known WHOOP identifiers
    private let whoopIdentifiers: Set<String> = [
        "whoop", "com.whoop"
    ]

    /// Known Fitbit identifiers
    private let fitbitIdentifiers: Set<String> = [
        "fitbit", "com.fitbit"
    ]

    /// Known Samsung identifiers
    private let samsungIdentifiers: Set<String> = [
        "samsung", "samsung health", "com.samsung"
    ]

    // MARK: - User Preferences

    /// User preference for data source
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

    /// Last detection result (cached)
    private(set) var lastDetectionResult: SourceDetectionResult?

    // MARK: - Init

    private init() {}

    // MARK: - Source Detection

    /// Detect source from a single HealthKit sample
    func detectSource(from sample: HKSample) -> HealthDataSource {
        let sourceName = sample.sourceRevision.source.name.lowercased()
        let bundleId = (sample.sourceRevision.source.bundleIdentifier ?? "").lowercased()

        // Check by source name and bundle identifier
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

    /// Analyze an array of samples to detect the primary source
    func analyzeDataSources(samples: [HKSample]) -> SourceDetectionResult {
        var sourceCounts: [HealthDataSource: Int] = [:]
        var detectedSources: Set<HealthDataSource> = []
        var lastSyncDates: [HealthDataSource: Date] = [:]

        for sample in samples {
            let source = detectSource(from: sample)
            sourceCounts[source, default: 0] += 1
            detectedSources.insert(source)

            // Update last sync date
            if let existing = lastSyncDates[source] {
                if sample.endDate > existing {
                    lastSyncDates[source] = sample.endDate
                }
            } else {
                lastSyncDates[source] = sample.endDate
            }
        }

        // Determine the primary source
        let primarySource: HealthDataSource
        if preferredSource != .autoDetect {
            primarySource = preferredSource
        } else {
            // Auto detect - by number of samples
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

    /// Detect sources from a set of HealthKit sources
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

    /// Returns the effective source (preference or detected)
    func effectiveSource() -> HealthDataSource {
        if preferredSource != .autoDetect {
            return preferredSource
        }
        return lastDetectionResult?.dominantSource ?? .appleWatch
    }

    // MARK: - Source Info

    /// Returns information about the selected source's strengths for display
    func sourceInfoText() -> String {
        let source = effectiveSource()
        let strengths = source.strengths

        if strengths.isEmpty {
            return ""
        }

        return "Strengths of \(source.displayName): " + strengths.joined(separator: ", ")
    }

    /// Whether the current source provides accurate sleep HRV
    func hasAccurateSleepHRV() -> Bool {
        let source = effectiveSource()
        return source == .oura || source == .whoop
    }

    /// Whether the source provides detailed sleep stages
    func hasDetailedSleepStages() -> Bool {
        let source = effectiveSource()
        return source == .oura || source == .garmin || source == .whoop
    }

    /// Whether the source provides native Body Battery / Readiness score
    func hasNativeReadinessScore() -> Bool {
        // No source syncs Readiness/Body Battery to Apple Health
        // Therefore we always need to calculate it ourselves
        return false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dataSourceChanged = Notification.Name("dataSourceChanged")
    static let backgroundColorChanged = Notification.Name("backgroundColorChanged")
}
