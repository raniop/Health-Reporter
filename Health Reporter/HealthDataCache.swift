import Foundation

/// Cache for storing health data loaded in Splash Screen
/// So the Dashboard can use them immediately without loading again
class HealthDataCache {
    static let shared = HealthDataCache()

    private init() {}

    /// General health data
    var healthData: HealthDataModel?

    /// Charts and analysis data
    var chartBundle: AIONChartDataBundle?

    /// Whether data was loaded successfully
    var isLoaded: Bool {
        healthData != nil && chartBundle != nil
    }

    /// Clear the cache (e.g. on logout)
    func clear() {
        healthData = nil
        chartBundle = nil
    }
}
