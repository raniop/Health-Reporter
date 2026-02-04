//
//  OnboardingCoordinator.swift
//  Health Reporter
//
//  מנהל את הניתוח ברקע במהלך ה-Onboarding
//

import Foundation
import FirebaseAuth
import HealthKit

final class OnboardingCoordinator {

    // MARK: - Notifications

    static let analysisDidCompleteNotification = Notification.Name("OnboardingAnalysisComplete")
    static let analysisProgressNotification = Notification.Name("OnboardingAnalysisProgress")

    // MARK: - State

    enum AnalysisState: Equatable {
        case idle
        case requestingHealthKit
        case fetchingData
        case analyzingWithGemini
        case completed
        case failed(String)

        static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.requestingHealthKit, .requestingHealthKit),
                 (.fetchingData, .fetchingData),
                 (.analyzingWithGemini, .analyzingWithGemini),
                 (.completed, .completed):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private(set) var analysisState: AnalysisState = .idle
    private var analysisTask: Task<Void, Never>?
    private var healthKitGranted = false

    // MARK: - Singleton

    static let shared = OnboardingCoordinator()
    private init() {}

    // MARK: - Public API

    /// מתחיל ניתוח ברקע אחרי שהמשתמש אישר HealthKit
    func startBackgroundAnalysis() {
        guard analysisState == .idle else {
            print("⚠️ [Onboarding] Analysis already running, state: \(analysisState)")
            return
        }

        print("🚀 [Onboarding] Starting background analysis")
        analysisTask = Task { [weak self] in
            await self?.runAnalysis()
        }
    }

    /// בודק אם הניתוח כבר הסתיים
    var isAnalysisComplete: Bool {
        return analysisState == .completed
    }

    /// מסמן ש-HealthKit אושר (גם אם דילגו - יקרא עם false)
    func setHealthKitGranted(_ granted: Bool) {
        healthKitGranted = granted
    }

    /// מאפס את ה-coordinator למצב התחלתי
    func reset() {
        analysisTask?.cancel()
        analysisTask = nil
        analysisState = .idle
        healthKitGranted = false
    }

    // MARK: - Analysis Flow

    private func runAnalysis() async {
        // Step 1: Request HealthKit (if not already done)
        updateState(.requestingHealthKit)
        postProgress(step: "onboarding.progress.connecting".localized, progress: 0.1)

        guard HealthKitManager.shared.isHealthDataAvailable() else {
            print("⚠️ [Onboarding] HealthKit not available")
            updateState(.completed)
            return
        }

        // אם ההרשאה כבר ניתנה - ממשיכים
        // אחרת מבקשים שוב (למקרה שדילגו על המסך אבל עכשיו רוצים)
        let authSuccess: Bool
        if healthKitGranted {
            authSuccess = true
        } else {
            authSuccess = await withCheckedContinuation { continuation in
                HealthKitManager.shared.requestAuthorization { success, error in
                    if let error = error {
                        print("⚠️ [Onboarding] HealthKit auth error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: success)
                }
            }
        }

        guard authSuccess else {
            print("⚠️ [Onboarding] HealthKit auth denied, completing without analysis")
            updateState(.completed)
            return
        }

        // Step 2: Fetch health data
        updateState(.fetchingData)
        postProgress(step: "onboarding.progress.syncing".localized, progress: 0.3)

        let healthData = await withCheckedContinuation { (continuation: CheckedContinuation<HealthDataModel?, Never>) in
            HealthKitManager.shared.fetchAllHealthData(for: .week) { data, error in
                if let error = error {
                    print("⚠️ [Onboarding] Health data fetch error: \(error.localizedDescription)")
                }
                continuation.resume(returning: data)
            }
        }

        guard let data = healthData, data.hasRealData else {
            print("⚠️ [Onboarding] No health data available")
            updateState(.completed)
            return
        }

        // Cache health data
        HealthDataCache.shared.healthData = data

        // Step 3: Fetch chart data
        postProgress(step: "onboarding.progress.processing".localized, progress: 0.5)

        let chartBundle = await withCheckedContinuation { (continuation: CheckedContinuation<AIONChartDataBundle?, Never>) in
            HealthKitManager.shared.fetchChartData(for: .week) { bundle in
                continuation.resume(returning: bundle)
            }
        }
        HealthDataCache.shared.chartBundle = chartBundle

        // Step 4: Fetch 90 days for HealthScore
        let dailyEntries = await withCheckedContinuation { (continuation: CheckedContinuation<[RawDailyHealthEntry], Never>) in
            HealthKitManager.shared.fetchDailyHealthData(days: 90) { entries in
                continuation.resume(returning: entries)
            }
        }

        // Calculate health score
        let healthResult = HealthScoreEngine.shared.calculate(from: dailyEntries)
        AnalysisCache.saveHealthScoreResult(healthResult)

        // Step 5: Run Gemini analysis
        updateState(.analyzingWithGemini)
        postProgress(step: "onboarding.progress.analyzing".localized, progress: 0.7)

        await runGeminiAnalysis(healthData: data, chartBundle: chartBundle, dailyEntries: dailyEntries)

        postProgress(step: "onboarding.progress.ready".localized, progress: 1.0)
        updateState(.completed)

        print("✅ [Onboarding] Background analysis completed")
    }

    private func runGeminiAnalysis(healthData: HealthDataModel, chartBundle: AIONChartDataBundle?, dailyEntries: [RawDailyHealthEntry]) async {
        let calendar = Calendar.current
        let now = Date()

        guard let curStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let curEnd = calendar.date(byAdding: .day, value: 6, to: curStart),
              let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: curStart),
              let prevEnd = calendar.date(byAdding: .day, value: 6, to: prevStart) else {
            return
        }

        // Fetch weekly snapshots
        let (previousWeek, currentWeek) = await withCheckedContinuation { (continuation: CheckedContinuation<(WeeklyHealthSnapshot?, WeeklyHealthSnapshot?), Never>) in
            var prev: WeeklyHealthSnapshot?
            var curr: WeeklyHealthSnapshot?
            let group = DispatchGroup()

            group.enter()
            HealthKitManager.shared.createWeeklySnapshot(weekStartDate: prevStart, weekEndDate: prevEnd) {
                prev = $0
                group.leave()
            }

            group.enter()
            HealthKitManager.shared.createWeeklySnapshot(weekStartDate: curStart, weekEndDate: curEnd, previousWeekSnapshot: nil) {
                curr = $0
                group.leave()
            }

            group.notify(queue: .main) {
                continuation.resume(returning: (prev, curr))
            }
        }

        guard let current = currentWeek, let previous = previousWeek else {
            print("⚠️ [Onboarding] Failed to create weekly snapshots")
            return
        }

        // Generate hash for cache
        let healthDataHash: String
        if let bundle = chartBundle {
            healthDataHash = AnalysisCache.generateHealthDataHash(from: bundle)
        } else {
            healthDataHash = AnalysisCache.generateHealthDataHash(from: healthData)
        }

        postProgress(step: "onboarding.progress.findingCar".localized, progress: 0.85)

        // Call Gemini
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            GeminiService.shared.analyzeHealthDataWithWeeklyComparison(
                healthData,
                currentWeek: current,
                previousWeek: previous,
                chartBundle: chartBundle
            ) { insights, _, _, error in
                if let error = error {
                    print("⚠️ [Onboarding] Gemini analysis error: \(error.localizedDescription)")
                }

                if let insights = insights {
                    AnalysisCache.save(insights: insights, healthDataHash: healthDataHash)
                    AnalysisFirestoreSync.saveIfLoggedIn(insights: insights, recommendations: "")
                    print("✅ [Onboarding] Gemini analysis saved to cache")

                    // שמירת הרכב ב-cache כדי למנוע reveal כפול ב-Insights
                    let parsed = CarAnalysisParser.parse(insights)
                    let geminiCar = parsed.carModel.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !geminiCar.isEmpty && geminiCar.count > 3 && geminiCar.count < 40 {
                        AnalysisCache.saveSelectedCar(
                            name: geminiCar,
                            wikiName: parsed.carWikiName,
                            explanation: parsed.carExplanation
                        )
                        print("🚗 [Onboarding] Car saved to cache: \(geminiCar)")
                    }
                }

                continuation.resume()
            }
        }

        // Sync to leaderboard
        let score = AnalysisCache.loadHealthScore() ?? 0
        let tier = CarTierEngine.tierForScore(score)
        let carName = AnalysisCache.loadSelectedCar()?.name
        LeaderboardFirestoreSync.syncScore(score: score, tier: tier, geminiCarName: carName)
    }

    // MARK: - Helpers

    private func updateState(_ state: AnalysisState) {
        DispatchQueue.main.async { [weak self] in
            self?.analysisState = state

            if state == .completed {
                NotificationCenter.default.post(name: Self.analysisDidCompleteNotification, object: nil)
            }
        }
    }

    private func postProgress(step: String, progress: Double) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.analysisProgressNotification,
                object: nil,
                userInfo: ["step": step, "progress": progress]
            )
        }
    }
}
