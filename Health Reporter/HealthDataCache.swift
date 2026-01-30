import Foundation

/// Cache לשמירת נתוני בריאות שנטענו ב-Splash Screen
/// כך ה-Dashboard יכול להשתמש בהם מיידית בלי לטעון שוב
class HealthDataCache {
    static let shared = HealthDataCache()

    private init() {}

    /// נתוני הבריאות הכלליים
    var healthData: HealthDataModel?

    /// נתוני הגרפים והניתוחים
    var chartBundle: AIONChartDataBundle?

    /// האם הנתונים נטענו בהצלחה
    var isLoaded: Bool {
        healthData != nil && chartBundle != nil
    }

    /// ניקוי ה-cache (למשל בעת logout)
    func clear() {
        healthData = nil
        chartBundle = nil
    }
}
