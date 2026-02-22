//
//  WidgetDataManager.swift
//  Health Reporter
//
//  Manages data sharing between the main app and widgets via App Groups
//

import Foundation
import WidgetKit
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

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
    var restingHeartRate: Int     // Separate from heartRate
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

    /// Updates widget data from current health metrics.
    /// Goal parameters have sensible defaults so existing callers don't break.
    func updateWidgetData(
        healthScore: Int,
        dailyScore: Int? = nil,
        healthStatus: String,
        steps: Int,
        stepsGoal: Int = 10000,
        calories: Int,
        caloriesGoal: Int = 500,
        exerciseMinutes: Int,
        exerciseGoal: Int = 30,
        standHours: Int,
        standGoal: Int = 12,
        heartRate: Int,
        restingHeartRate: Int = 0,
        hrv: Int,
        sleepHours: Double,
        carName: String,
        carEmoji: String,
        carImageName: String,
        carTierIndex: Int,
        userName: String = ""
    ) {
        print("📱 [WidgetData] 🔄 Updating: score=\(healthScore), steps=\(steps), cal=\(calories)/\(caloriesGoal), ex=\(exerciseMinutes)/\(exerciseGoal), stand=\(standHours)/\(standGoal), hr=\(heartRate), sleep=\(sleepHours)h, car=\(carName)")

        let data = SharedWidgetData(
            healthScore: healthScore,
            dailyScore: dailyScore,
            healthStatus: healthStatus,
            steps: steps,
            stepsGoal: stepsGoal,
            calories: calories,
            caloriesGoal: caloriesGoal,
            exerciseMinutes: exerciseMinutes,
            exerciseGoal: exerciseGoal,
            standHours: standHours,
            standGoal: standGoal,
            heartRate: heartRate,
            restingHeartRate: restingHeartRate,
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
    }

    /// Convenience method to update from HealthDashboard data
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
        carTier: HealthTier? = nil,
        userName: String = "",
        // Score breakdown (kept for compatibility, stored for callers that read it)
        recoveryScore: Int? = nil,
        sleepScore: Int? = nil,
        nervousSystemScore: Int? = nil,
        energyScore: Int? = nil,
        activityScore: Int? = nil,
        loadBalanceScore: Int? = nil
    ) {
        let tier = carTier ?? HealthTier.forScore(score)

        let carName = GeminiResultStore.loadCarName() ?? AnalysisCache.loadSelectedCar()?.name ?? ""
        let carEmoji = carName.isEmpty ? "" : tier.emoji

        updateWidgetData(
            healthScore: score,
            dailyScore: score,
            healthStatus: status,
            steps: steps,
            calories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            heartRate: restingHR ?? 0,
            restingHeartRate: restingHR ?? 0,
            hrv: hrv ?? 0,
            sleepHours: sleepHours ?? 0,
            carName: carName,
            carEmoji: carEmoji,
            carImageName: tier.imageName,
            carTierIndex: tier.tierIndex,
            userName: userName
        )
    }

    /// Update widget with Gemini car data (from Insights)
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
        let tier = HealthTier.forScore(score)

        updateWidgetData(
            healthScore: score,
            dailyScore: dailyScore,
            healthStatus: status,
            steps: steps,
            calories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            heartRate: restingHR ?? 0,
            restingHeartRate: restingHR ?? 0,
            hrv: hrv ?? 0,
            sleepHours: sleepHours ?? 0,
            carName: carName,
            carEmoji: carEmoji,
            carImageName: "",
            carTierIndex: tier.tierIndex,
            userName: userName
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

    /// Loads current widget data (used by Watch communication + debugging)
    func loadCurrentData() -> SharedWidgetData? {
        guard let userDefaults = UserDefaults(suiteName: appGroupID),
              let data = userDefaults.data(forKey: dataKey),
              let widgetData = try? JSONDecoder().decode(SharedWidgetData.self, from: data) else {
            print("📱 [WidgetData] ⚠️ loadCurrentData() returned nil")
            return nil
        }
        print("📱 [WidgetData] Loaded: score=\(widgetData.healthScore), steps=\(widgetData.steps), car=\(widgetData.carName)")
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
    /// Sends only car tier data to Apple Watch
    func sendCarDataToWatch(tier: HealthTier) {
        let carName = GeminiResultStore.loadCarName() ?? AnalysisCache.loadSelectedCar()?.name ?? ""
        WatchConnectivityManager.shared.sendCarDataToWatch(
            carName: carName,
            carEmoji: carName.isEmpty ? "" : tier.emoji,
            carTierIndex: tier.tierIndex,
            carTierLabel: tier.tierLabel
        )
    }
}

// MARK: - Car Image Background Removal

extension WidgetDataManager {

    /// Removes the background from a car image using Vision framework (iOS 17+).
    /// Returns the isolated subject with transparent background via completion handler.
    /// Falls back to the original image if background removal fails.
    func removeBackground(from image: UIImage, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let inputCIImage = CIImage(image: image) else {
                print("🚗 [BgRemoval] ❌ Failed to create CIImage")
                completion(image)
                return
            }

            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(ciImage: inputCIImage)

            do {
                try handler.perform([request])

                guard let result = request.results?.first else {
                    print("🚗 [BgRemoval] ❌ No mask results")
                    completion(image)
                    return
                }

                let mask = try result.generateScaledMaskForImage(
                    forInstances: result.allInstances,
                    from: handler
                )

                let maskCIImage = CIImage(cvPixelBuffer: mask)

                let filter = CIFilter.blendWithMask()
                filter.inputImage = inputCIImage
                filter.maskImage = maskCIImage
                filter.backgroundImage = CIImage.empty()

                guard let outputCIImage = filter.outputImage else {
                    print("🚗 [BgRemoval] ❌ Filter produced no output")
                    completion(image)
                    return
                }

                let context = CIContext(options: nil)
                guard let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
                    print("🚗 [BgRemoval] ❌ Failed to create CGImage")
                    completion(image)
                    return
                }

                let resultImage = UIImage(cgImage: cgImage)
                print("🚗 [BgRemoval] ✅ Background removed successfully")
                completion(resultImage)

            } catch {
                print("🚗 [BgRemoval] ❌ Vision error: \(error.localizedDescription)")
                completion(image)
            }
        }
    }
}

// MARK: - Car Image Management

extension WidgetDataManager {
    private var carImageFileName: String { "widget_car_image.png" }
    private var carImageCacheFileName: String { "cached_car_image.png" }
    private var carImageCacheKeyName: String { "cached_car_wiki_name" }

    /// Saves car image to App Group for widget access
    func saveCarImage(_ image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("WidgetDataManager: Failed to get App Group container")
            return
        }

        let imageURL = containerURL.appendingPathComponent(carImageFileName)

        // Save as PNG to preserve transparency (background-removed images)
        guard let imageData = image.pngData() else {
            print("WidgetDataManager: Failed to convert image to PNG")
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

        // Save as PNG to preserve transparency (background-removed images)
        guard let imageData = image.pngData() else {
            print("WidgetDataManager: Failed to convert cached image to PNG")
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

    /// Migrates old JPEG car image cache to PNG (one-time on upgrade)
    private func migrateJpegCacheToPngIfNeeded() {
        let migrationKey = "CarImageCache.MigratedToPNG"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(true, forKey: migrationKey)

        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return }

        // Remove old JPEG files
        let oldFiles = ["cached_car_image.jpg", "widget_car_image.jpg"]
        for file in oldFiles {
            let url = containerURL.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
                print("🚗 [CarCache] Migrated: removed old \(file)")
            }
        }
        // Also clear the wiki key so cache is rebuilt
        let keyURL = containerURL.appendingPathComponent(carImageCacheKeyName)
        try? FileManager.default.removeItem(at: keyURL)
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

        // One-time migration from old JPEG cache to PNG
        migrateJpegCacheToPngIfNeeded()

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
                    print("🚗 [Prefetch] ✅ Image prefetched for '\(carName)', removing background...")
                    self.removeBackground(from: image) { processedImage in
                        self.saveCarImage(processedImage)
                        self.cacheCarImage(processedImage, forWikiName: originalWikiName)
                        completion?(true)
                    }
                } else {
                    // Try original URL
                    if let originalURL = URL(string: source) {
                        var retryRequest = URLRequest(url: originalURL)
                        retryRequest.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

                        URLSession.shared.dataTask(with: retryRequest) { [weak self] retryData, _, _ in
                            guard let self = self else { return }
                            if let retryData = retryData, !retryData.isEmpty, let image = UIImage(data: retryData) {
                                print("🚗 [Prefetch] ✅ Image prefetched with original URL for '\(carName)', removing background...")
                                self.removeBackground(from: image) { processedImage in
                                    self.saveCarImage(processedImage)
                                    self.cacheCarImage(processedImage, forWikiName: originalWikiName)
                                    completion?(true)
                                }
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
