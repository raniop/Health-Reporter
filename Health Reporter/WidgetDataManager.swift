//
//  WidgetDataManager.swift
//  Health Reporter
//
//  Manages data sharing between the main app and widgets via App Groups
//

import Foundation
import WidgetKit
import UIKit

/// Data structure shared with widgets (must match HealthWidgetData in widget extension)
struct SharedWidgetData: Codable {
    var healthScore: Int          // Gemini score (90-day average) - main display
    var dailyScore: Int?          // Daily health score - secondary display
    var healthStatus: String
    var steps: Int
    var stepsGoal: Int
    var calories: Int
    var caloriesGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int
    var heartRate: Int
    var hrv: Int
    var sleepHours: Double
    var lastUpdated: Date

    // Car tier info
    var carName: String
    var carEmoji: String
    var carImageName: String
    var carTierIndex: Int

    // User info
    var userName: String
}

/// Manages widget data updates
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let appGroupID = "group.com.rani.Health-Reporter"
    private let dataKey = "widgetData"

    private init() {}

    /// Updates widget data from current health metrics
    /// - Parameter syncToWatch: Whether to also send data to Apple Watch (default true)
    func updateWidgetData(
        healthScore: Int,
        dailyScore: Int? = nil,
        healthStatus: String,
        steps: Int,
        calories: Int,
        exerciseMinutes: Int,
        standHours: Int,
        heartRate: Int,
        hrv: Int,
        sleepHours: Double,
        carName: String,
        carEmoji: String,
        carImageName: String,
        carTierIndex: Int,
        userName: String = "",
        syncToWatch: Bool = true
    ) {
        let data = SharedWidgetData(
            healthScore: healthScore,
            dailyScore: dailyScore,
            healthStatus: healthStatus,
            steps: steps,
            stepsGoal: 10000,
            calories: calories,
            caloriesGoal: 500,
            exerciseMinutes: exerciseMinutes,
            exerciseGoal: 30,
            standHours: standHours,
            standGoal: 12,
            heartRate: heartRate,
            hrv: hrv,
            sleepHours: sleepHours,
            lastUpdated: Date(),
            carName: carName,
            carEmoji: carEmoji,
            carImageName: carImageName,
            carTierIndex: carTierIndex,
            userName: userName
        )

        saveData(data)
        refreshWidgets()

        // Send to Apple Watch only if requested (Home screen only)
        if syncToWatch {
            sendToWatch(data)
        }
    }

    /// Convenience method to update from HealthDashboard data
    /// Sends all data to Watch including score, status, steps, sleep, and car tier
    func updateFromDashboard(
        score: Int,
        status: String,
        steps: Int,
        activeCalories: Int,
        exerciseMinutes: Int,
        standHours: Int,
        restingHR: Int?,
        hrv: Int?,
        sleepHours: Double?,
        carTier: CarTier? = nil,
        userName: String = "",
        // Score breakdown for Watch
        recoveryScore: Int? = nil,
        sleepScore: Int? = nil,
        nervousSystemScore: Int? = nil,
        energyScore: Int? = nil,
        activityScore: Int? = nil,
        loadBalanceScore: Int? = nil
    ) {
        // Get car tier from score if not provided
        let tier = carTier ?? CarTierEngine.tierForScore(score)

        // Store score breakdown for Watch BEFORE sending
        scoreBreakdown = (recoveryScore, sleepScore, nervousSystemScore, energyScore, activityScore, loadBalanceScore)

        // ALWAYS use Gemini car name if available, NEVER use generic tier name
        let geminiCar = AnalysisCache.loadSelectedCar()
        let carName = geminiCar?.name ?? ""  // Empty if no Gemini data - don't show generic names
        let carEmoji = carName.isEmpty ? "" : tier.emoji

        // Save to widgets AND sync to Watch with all data
        updateWidgetData(
            healthScore: score,
            healthStatus: status,
            steps: steps,
            calories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            heartRate: restingHR ?? 0,
            hrv: hrv ?? 0,
            sleepHours: sleepHours ?? 0,
            carName: carName,
            carEmoji: carEmoji,
            carImageName: tier.imageName,
            carTierIndex: tier.tierIndex,
            userName: userName,
            syncToWatch: true  // Sync all data to Watch
        )
    }

    /// Score breakdown for Watch - stored separately
    private(set) var scoreBreakdown: (recovery: Int?, sleep: Int?, nervousSystem: Int?, energy: Int?, activity: Int?, loadBalance: Int?)?

    /// Update widget with Gemini car data (from Insights)
    /// Note: Does NOT sync to Watch - only Home screen syncs to Watch
    func updateFromInsights(
        score: Int,
        dailyScore: Int? = nil,
        status: String,
        carName: String,
        carEmoji: String,
        steps: Int = 0,
        activeCalories: Int = 0,
        exerciseMinutes: Int = 0,
        standHours: Int = 0,
        restingHR: Int? = nil,
        hrv: Int? = nil,
        sleepHours: Double? = nil,
        userName: String = ""
    ) {
        // Get tier index from score for the progress bar
        let tier = CarTierEngine.tierForScore(score)

        // Don't sync to Watch - Insights uses different score (car tier, 90-day average)
        // Only Home screen (InsightsDashboard) should sync to Watch with daily mainScore
        updateWidgetData(
            healthScore: score,
            dailyScore: dailyScore,
            healthStatus: status,
            steps: steps,
            calories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            heartRate: restingHR ?? 0,
            hrv: hrv ?? 0,
            sleepHours: sleepHours ?? 0,
            carName: carName,
            carEmoji: carEmoji,
            carImageName: "",  // Will use emoji instead
            carTierIndex: tier.tierIndex,
            userName: userName,
            syncToWatch: false  // Don't override Home screen data
        )
    }

    /// Saves data to App Group UserDefaults
    private func saveData(_ data: SharedWidgetData) {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("WidgetDataManager: ❌ Failed to access App Group")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            userDefaults.set(encoded, forKey: dataKey)
            userDefaults.synchronize()  // Force sync
            print("WidgetDataManager: ✅ Data saved - Score: \(data.healthScore), Car: \(data.carName), Status: \(data.healthStatus)")
        } catch {
            print("WidgetDataManager: ❌ Failed to encode data - \(error)")
        }
    }

    /// Triggers widget refresh
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("WidgetDataManager: Widgets refreshed")
    }

    /// Loads current widget data (for debugging)
    func loadCurrentData() -> SharedWidgetData? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: dataKey),
              let widgetData = try? JSONDecoder().decode(SharedWidgetData.self, from: data) else {
            return nil
        }
        return widgetData
    }
}

// MARK: - Extension for Background Updates

extension WidgetDataManager {
    /// Call this from background fetch or after significant health data updates
    func scheduleWidgetUpdate() {
        refreshWidgets()
    }
}

// MARK: - Apple Watch Integration

extension WidgetDataManager {
    /// Sends only car tier data to Apple Watch (score/status calculated locally on Watch)
    /// ALWAYS uses Gemini car name - never generic tier names
    func sendCarDataToWatch(tier: CarTier) {
        // ALWAYS use Gemini car name if available
        let geminiCar = AnalysisCache.loadSelectedCar()
        let carName = geminiCar?.name ?? ""  // Empty if no Gemini data

        print("📱➡️⌚️ Sending car data to Watch: car=\(carName), tier=\(tier.tierIndex)")
        WatchConnectivityManager.shared.sendCarDataToWatch(
            carName: carName,
            carEmoji: carName.isEmpty ? "" : tier.emoji,
            carTierIndex: tier.tierIndex,
            carTierLabel: tier.tierLabel
        )
    }

    /// Sends full data to Apple Watch via WatchConnectivity
    private func sendToWatch(_ data: SharedWidgetData) {
        // Get Gemini car data from cache
        let geminiCar = AnalysisCache.loadSelectedCar()
        let geminiScore = AnalysisCache.loadHealthScore()

        print("📱➡️⌚️ Sending to Watch: score=\(data.healthScore), steps=\(data.steps)")
        WatchConnectivityManager.shared.sendWidgetDataToWatch(
            healthScore: data.healthScore,
            healthStatus: data.healthStatus,
            steps: data.steps,
            calories: data.calories,
            exerciseMinutes: data.exerciseMinutes,
            standHours: data.standHours,
            heartRate: data.heartRate,
            hrv: data.hrv,
            sleepHours: data.sleepHours,
            carName: data.carName,
            carEmoji: data.carEmoji,
            carTierIndex: data.carTierIndex,
            carTierLabel: CarTierEngine.tierForScore(data.healthScore).tierLabel,
            // Score breakdown
            recoveryScore: scoreBreakdown?.recovery,
            sleepScore: scoreBreakdown?.sleep,
            nervousSystemScore: scoreBreakdown?.nervousSystem,
            energyScore: scoreBreakdown?.energy,
            activityScore: scoreBreakdown?.activity,
            loadBalanceScore: scoreBreakdown?.loadBalance,
            // Gemini car data (for CarTierView on Watch)
            geminiCarName: geminiCar?.name,
            geminiCarScore: geminiScore
        )
    }
}

// MARK: - Car Image Management

extension WidgetDataManager {
    private var carImageFileName: String { "widget_car_image.jpg" }
    private var carImageCacheFileName: String { "cached_car_image.jpg" }
    private var carImageCacheKeyName: String { "cached_car_wiki_name" }

    /// Saves car image to App Group for widget access
    func saveCarImage(_ image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("WidgetDataManager: Failed to get App Group container")
            return
        }

        let imageURL = containerURL.appendingPathComponent(carImageFileName)

        // Compress and save as JPEG for smaller file size
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("WidgetDataManager: Failed to convert image to JPEG")
            return
        }

        do {
            try imageData.write(to: imageURL)
            print("WidgetDataManager: Car image saved to App Group")

            // Refresh widgets to show new image
            refreshWidgets()
        } catch {
            print("WidgetDataManager: Failed to save car image - \(error)")
        }
    }

    /// Returns the URL of the saved car image (for widget to load)
    func getCarImageURL() -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }

        let imageURL = containerURL.appendingPathComponent(carImageFileName)

        if FileManager.default.fileExists(atPath: imageURL.path) {
            return imageURL
        }
        return nil
    }

    // MARK: - Car Image Cache (for fast loading)

    /// Saves car image to local cache with wiki name key
    func cacheCarImage(_ image: UIImage, forWikiName wikiName: String) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("WidgetDataManager: Failed to get App Group container for cache")
            return
        }

        let imageURL = containerURL.appendingPathComponent(carImageCacheFileName)
        let keyURL = containerURL.appendingPathComponent(carImageCacheKeyName)

        // Compress and save as JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            print("WidgetDataManager: Failed to convert cached image to JPEG")
            return
        }

        do {
            try imageData.write(to: imageURL)
            try wikiName.write(to: keyURL, atomically: true, encoding: .utf8)
            print("🚗 [CarCache] ✅ Cached image for '\(wikiName)'")
        } catch {
            print("🚗 [CarCache] ❌ Failed to cache image: \(error)")
        }
    }

    /// Loads cached car image if the wiki name matches
    /// Returns nil if no cache exists or if the car changed
    func loadCachedCarImage(forWikiName wikiName: String) -> UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }

        let imageURL = containerURL.appendingPathComponent(carImageCacheFileName)
        let keyURL = containerURL.appendingPathComponent(carImageCacheKeyName)

        // Check if cache exists
        guard FileManager.default.fileExists(atPath: imageURL.path),
              FileManager.default.fileExists(atPath: keyURL.path) else {
            print("🚗 [CarCache] No cache found")
            return nil
        }

        // Check if wiki name matches
        do {
            let cachedWikiName = try String(contentsOf: keyURL, encoding: .utf8)
            if cachedWikiName == wikiName {
                if let imageData = try? Data(contentsOf: imageURL),
                   let image = UIImage(data: imageData) {
                    print("🚗 [CarCache] ✅ Loaded cached image for '\(wikiName)'")
                    return image
                }
            } else {
                print("🚗 [CarCache] Cache miss - different car (cached: '\(cachedWikiName)', requested: '\(wikiName)')")
            }
        } catch {
            print("🚗 [CarCache] Failed to read cache key: \(error)")
        }

        return nil
    }

    /// Clears the car image cache
    func clearCarImageCache() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }

        let imageURL = containerURL.appendingPathComponent(carImageCacheFileName)
        let keyURL = containerURL.appendingPathComponent(carImageCacheKeyName)

        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: keyURL)
        print("🚗 [CarCache] Cache cleared")
    }

    /// Prefetch car image from Wikipedia and cache it
    /// Call this during onboarding/splash to have the image ready when user opens Insights tab
    func prefetchCarImage(wikiName: String, completion: ((Bool) -> Void)? = nil) {
        guard !wikiName.isEmpty else {
            print("🚗 [Prefetch] wikiName is empty, skipping")
            completion?(false)
            return
        }

        // Check if already cached
        if loadCachedCarImage(forWikiName: wikiName) != nil {
            print("🚗 [Prefetch] Image already cached for '\(wikiName)'")
            completion?(true)
            return
        }

        print("🚗 [Prefetch] Starting prefetch for '\(wikiName)'")

        // Generate candidate names
        let words = wikiName.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
        var candidates: [String] = []
        for count in stride(from: words.count, through: max(2, words.count > 3 ? 2 : words.count), by: -1) {
            candidates.append(words.prefix(count).joined(separator: " "))
        }
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0).inserted }

        prefetchWithCandidates(candidates: candidates, index: 0, originalWikiName: wikiName, completion: completion)
    }

    private func prefetchWithCandidates(candidates: [String], index: Int, originalWikiName: String, completion: ((Bool) -> Void)?) {
        guard index < candidates.count else {
            print("🚗 [Prefetch] ❌ All candidates exhausted")
            completion?(false)
            return
        }

        let carName = candidates[index]
        let wikiTitle = carName.replacingOccurrences(of: " ", with: "_")
        let apiURL = "https://en.wikipedia.org/api/rest_v1/page/summary/\(wikiTitle)"

        guard let url = URL(string: apiURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiURL) else {
            prefetchWithCandidates(candidates: candidates, index: index + 1, originalWikiName: originalWikiName, completion: completion)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if error != nil {
                self.prefetchWithCandidates(candidates: candidates, index: index + 1, originalWikiName: originalWikiName, completion: completion)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let thumbnail = json["thumbnail"] as? [String: Any],
                  let source = thumbnail["source"] as? String else {
                self.prefetchWithCandidates(candidates: candidates, index: index + 1, originalWikiName: originalWikiName, completion: completion)
                return
            }

            // Get higher resolution
            let thumbURL = source.replacingOccurrences(of: "/320px-", with: "/640px-")
                .replacingOccurrences(of: "/330px-", with: "/640px-")

            guard let imageURL = URL(string: thumbURL) else {
                self.prefetchWithCandidates(candidates: candidates, index: index + 1, originalWikiName: originalWikiName, completion: completion)
                return
            }

            var imageRequest = URLRequest(url: imageURL)
            imageRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            imageRequest.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

            URLSession.shared.dataTask(with: imageRequest) { [weak self] imgData, _, _ in
                guard let self = self else { return }

                if let imgData = imgData, !imgData.isEmpty, let image = UIImage(data: imgData) {
                    print("🚗 [Prefetch] ✅ Image prefetched for '\(carName)'")
                    self.saveCarImage(image)
                    self.cacheCarImage(image, forWikiName: originalWikiName)
                    completion?(true)
                } else {
                    // Try original URL
                    if let originalURL = URL(string: source) {
                        var retryRequest = URLRequest(url: originalURL)
                        retryRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

                        URLSession.shared.dataTask(with: retryRequest) { [weak self] retryData, _, _ in
                            guard let self = self else { return }
                            if let retryData = retryData, !retryData.isEmpty, let image = UIImage(data: retryData) {
                                print("🚗 [Prefetch] ✅ Image prefetched with original URL for '\(carName)'")
                                self.saveCarImage(image)
                                self.cacheCarImage(image, forWikiName: originalWikiName)
                                completion?(true)
                            } else {
                                self.prefetchWithCandidates(candidates: candidates, index: index + 1, originalWikiName: originalWikiName, completion: completion)
                            }
                        }.resume()
                    } else {
                        self.prefetchWithCandidates(candidates: candidates, index: index + 1, originalWikiName: originalWikiName, completion: completion)
                    }
                }
            }.resume()
        }.resume()
    }
}
