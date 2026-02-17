//
//  AIONAnalysisOrchestrator.swift
//  Health Reporter
//
//  Centralized "once per day" Gemini analysis trigger.
//  Both the Home screen and Insights tab use this instead of calling GeminiService directly.
//

import Foundation

/// Describes why an analysis returned nil
enum AnalysisFailureReason {
    case noHealthData      // No HealthKit data to send to Gemini
    case geminiFailed      // Gemini API call failed (network, quota, etc.)
}

final class AIONAnalysisOrchestrator {

    static let shared = AIONAnalysisOrchestrator()

    /// Posted when a new analysis completes (UI should refresh)
    static let analysisDidCompleteNotification = Notification.Name("AIONAnalysisDidComplete")

    private var isRunning = false
    private var pendingCallbacks: [(GeminiDailyResult?, AnalysisFailureReason?) -> Void] = []
    private let queue = DispatchQueue(label: "AIONOrchestrator")

    private init() {}

    // MARK: - Public API

    /// Returns today's result if available, otherwise triggers a fresh Gemini call.
    func ensureTodayResult(forceRefresh: Bool = false, completion: @escaping (GeminiDailyResult?, AnalysisFailureReason?) -> Void) {
        if !forceRefresh, let existing = GeminiResultStore.load(), Calendar.current.isDateInToday(existing.date) {
            print("✅ [Orchestrator] Today's result already exists — returning cached")
            completion(existing, nil)
            return
        }

        // Need fresh analysis
        runAnalysis(completion: completion)
    }

    /// Forces a fresh Gemini call regardless of existing result.
    func refresh(completion: @escaping (GeminiDailyResult?, AnalysisFailureReason?) -> Void) {
        runAnalysis(completion: completion)
    }

    // MARK: - Internal

    private func runAnalysis(completion: @escaping (GeminiDailyResult?, AnalysisFailureReason?) -> Void) {
        queue.sync {
            pendingCallbacks.append(completion)
            guard !isRunning else {
                print("⏳ [Orchestrator] Analysis already in progress — queuing callback")
                return
            }
            isRunning = true
        }

        print("🚀 [Orchestrator] Starting fresh Gemini analysis...")

        // 1. Fetch health data
        HealthKitManager.shared.fetchAllHealthData(for: .month) { [weak self] data, error in
            guard let self = self, let data = data, data.hasRealData else {
                print("⚠️ [Orchestrator] No health data available")
                self?.completeAll(with: nil, reason: .noHealthData)
                return
            }

            // 2. Build weekly snapshots (same pattern as SplashViewController)
            let calendar = Calendar.current
            let now = Date()
            guard let curStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
                  let curEnd = calendar.date(byAdding: .day, value: 6, to: curStart),
                  let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: curStart),
                  let prevEnd = calendar.date(byAdding: .day, value: 6, to: prevStart) else {
                print("⚠️ [Orchestrator] Failed to compute week dates")
                self.completeAll(with: nil, reason: .noHealthData)
                return
            }

            let group = DispatchGroup()
            var currentWeek: WeeklyHealthSnapshot?
            var previousWeek: WeeklyHealthSnapshot?

            group.enter()
            HealthKitManager.shared.createWeeklySnapshot(weekStartDate: prevStart, weekEndDate: prevEnd) {
                previousWeek = $0
                group.leave()
            }

            group.enter()
            HealthKitManager.shared.createWeeklySnapshot(weekStartDate: curStart, weekEndDate: curEnd, previousWeekSnapshot: nil) {
                currentWeek = $0
                group.leave()
            }

            group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
                guard let self = self, let current = currentWeek, let previous = previousWeek else {
                    print("⚠️ [Orchestrator] Failed to create weekly snapshots")
                    self?.completeAll(with: nil, reason: .noHealthData)
                    return
                }

                // 3. Call Gemini
                GeminiService.shared.analyzeHealthDataWithWeeklyComparison(
                    data,
                    currentWeek: current,
                    previousWeek: previous,
                    chartBundle: nil
                ) { [weak self] insights, _, _, error in
                    if let error = error {
                        print("❌ [Orchestrator] Gemini failed: \(error.localizedDescription)")
                        self?.completeAll(with: nil, reason: .geminiFailed)
                        return
                    }

                    // 4. Load the result that GeminiService already saved to GeminiResultStore
                    let result = GeminiResultStore.load()

                    // 5. Also save to legacy AnalysisCache for backwards compatibility during migration
                    if let insights = insights {
                        AnalysisCache.save(insights: insights, healthDataHash: "gemini-orchestrator")
                    }

                    print("✅ [Orchestrator] Analysis complete — healthScore: \(result?.scores.healthScore ?? -1)")
                    self?.completeAll(with: result, reason: nil)
                }
            }
        }
    }

    private func completeAll(with result: GeminiDailyResult?, reason: AnalysisFailureReason?) {
        var callbacks: [(GeminiDailyResult?, AnalysisFailureReason?) -> Void] = []
        queue.sync {
            callbacks = pendingCallbacks
            pendingCallbacks.removeAll()
            isRunning = false
        }

        DispatchQueue.main.async {
            for cb in callbacks {
                cb(result, reason)
            }
            NotificationCenter.default.post(name: Self.analysisDidCompleteNotification, object: result)
        }
    }
}
