//
//  AIONAnalysisOrchestrator.swift
//  Health Reporter
//
//  Centralized "once per day" Gemini analysis trigger.
//  Both the Home screen and Insights tab use this instead of calling GeminiService directly.
//
//  Layered reliability model:
//    Layer 1: Local GeminiResultStore (BGProcessingTask cached result) → 0s
//    Layer 2: Firestore server result (Cloud Function at 5:30 AM)     → ~2s
//    Layer 3: On-device Gemini analysis (full HealthKit + API call)    → 60s+
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
    /// Checks three layers: local cache → Firestore server result → on-device analysis.
    func ensureTodayResult(forceRefresh: Bool = false, completion: @escaping (GeminiDailyResult?, AnalysisFailureReason?) -> Void) {

        // ── Layer 1: Local cache (instant) ──
        if !forceRefresh, let existing = GeminiResultStore.load(), Calendar.current.isDateInToday(existing.date) {
            print("✅ [Orchestrator] Layer 1 — Today's result already cached locally")
            completion(existing, nil)
            // Still notify so Watch sync fires on every app launch
            NotificationCenter.default.post(name: Self.analysisDidCompleteNotification, object: existing)
            return
        }

        // ── Consent check: skip Gemini if user declined AI consent ──
        if !ConsentManager.hasAIConsent {
            print("⚠️ [Orchestrator] AI consent not granted — skipping analysis")
            completion(nil, .geminiFailed)
            return
        }

        // ── Layer 2: Firestore server result (2.5s timeout) ──
        if !forceRefresh {
            print("📥 [Orchestrator] Layer 2 — Checking Firestore for server result...")
            GeminiResultFirestoreSync.fetchTodayResult { [weak self] serverResult in
                guard let self = self else { return }

                if let serverResult = serverResult,
                   let dailyResult = self.parseServerResult(serverResult) {
                    // Save locally so Layer 1 catches it next time
                    GeminiResultStore.save(dailyResult)

                    // Save score breakdown for profile display
                    let s = dailyResult.scores
                    AnalysisCache.saveScoreBreakdown(
                        recovery: s.readinessScore,
                        sleep: s.sleepScore,
                        nervousSystem: s.nervousSystemBalance,
                        energy: s.energyScore,
                        activity: s.activityScore,
                        loadBalance: s.loadBalance
                    )

                    // Process side effects (weekly goals, AION memory, legacy cache)
                    self.processServerResultSideEffects(rawResponse: serverResult.rawResponse, dailyResult: dailyResult)

                    print("✅ [Orchestrator] Layer 2 — Server result loaded! Score: \(dailyResult.scores.healthScore ?? -1)")
                    completion(dailyResult, nil)
                    NotificationCenter.default.post(name: Self.analysisDidCompleteNotification, object: dailyResult)
                    return
                }

                // ── Layer 3: Fall through to on-device analysis ──
                print("🚀 [Orchestrator] Layer 3 — No server result, running on-device analysis")
                self.runAnalysis(completion: completion)
            }
            return
        }

        // Force refresh — skip server check, go straight to on-device
        runAnalysis(completion: completion)
    }

    /// Forces a fresh Gemini call regardless of existing result.
    func refresh(completion: @escaping (GeminiDailyResult?, AnalysisFailureReason?) -> Void) {
        runAnalysis(completion: completion)
    }

    // MARK: - Parse Server Result

    /// Parses a server Gemini response into a GeminiDailyResult.
    /// Uses the same CarAnalysisParser.parseJSON() as the on-device path.
    private func parseServerResult(_ serverResult: ServerGeminiResult) -> GeminiDailyResult? {
        guard let parsed = CarAnalysisParser.parseJSON(serverResult.rawResponse) else {
            print("⚠️ [Orchestrator] Failed to parse server Gemini response")
            return nil
        }

        let lang = LocalizationManager.shared.currentLanguage
        let geminiScores = GeminiScores.from(parsed.scores, language: lang)

        return GeminiDailyResult(
            date: serverResult.generatedAt,
            scores: geminiScores,
            carModelHe: parsed.carModelHe, carModelEn: parsed.carModelEn,
            carWikiName: parsed.carWikiName,
            carExplanationHe: parsed.carExplanationHe, carExplanationEn: parsed.carExplanationEn,
            homeRecommendationMedicalHe: parsed.homeRecommendationMedicalHe,
            homeRecommendationMedicalEn: parsed.homeRecommendationMedicalEn,
            homeRecommendationSportsHe: parsed.homeRecommendationSportsHe,
            homeRecommendationSportsEn: parsed.homeRecommendationSportsEn,
            homeRecommendationNutritionHe: parsed.homeRecommendationNutritionHe,
            homeRecommendationNutritionEn: parsed.homeRecommendationNutritionEn,
            rawAnalysisJSON: serverResult.rawResponse
        )
    }

    /// Processes side effects that normally happen after an on-device Gemini call:
    /// weekly goals saving, goal verification, AION memory update, and legacy cache.
    private func processServerResultSideEffects(rawResponse: String, dailyResult: GeminiDailyResult) {
        guard let parsed = CarAnalysisParser.parseJSON(rawResponse) else { return }

        let lang = LocalizationManager.shared.currentLanguage
        let geminiScores = GeminiScores.from(parsed.scores, language: lang)

        // 1. Save weekly goals if generated
        if !parsed.weeklyGoals.isEmpty {
            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()

            let goals: [WeeklyGoal] = parsed.weeklyGoals.compactMap { json in
                let he = json.text_he ?? json.text_en ?? ""
                let en = json.text_en ?? json.text_he ?? ""
                guard !he.isEmpty || !en.isEmpty else { return nil }
                let catStr = (json.category ?? "exercise").lowercased()
                let category = GoalCategory(rawValue: catStr) ?? .exercise
                let diffStr = (json.difficulty ?? "moderate").lowercased()
                let difficulty = GoalDifficulty(rawValue: diffStr) ?? .moderate
                let metricIds = json.linkedMetrics ?? []
                let baselines = WeeklyGoalEngine.captureBaselines(for: metricIds, from: geminiScores)
                return WeeklyGoal(
                    id: UUID().uuidString,
                    textHe: he, textEn: en,
                    category: category, difficulty: difficulty,
                    weekStartDate: weekStart,
                    linkedMetricIds: metricIds,
                    status: .pending,
                    baselineMetrics: baselines
                )
            }

            if !goals.isEmpty {
                var seenCategories: Set<String> = []
                let uniqueGoals = goals.filter { goal in
                    if seenCategories.contains(goal.category.rawValue) { return false }
                    seenCategories.insert(goal.category.rawValue)
                    return true
                }

                let goalSet = WeeklyGoalSet(
                    weekStartDate: weekStart,
                    goals: uniqueGoals,
                    generatedDate: Date(),
                    progressAssessmentHe: parsed.weeklyGoalsProgressAssessmentHe,
                    progressAssessmentEn: parsed.weeklyGoalsProgressAssessmentEn
                )
                WeeklyGoalStore.saveNewGoalSet(goalSet)
                GoalReminderManager.shared.scheduleReminders()
                print("🎯 [Orchestrator] Server result: saved \(uniqueGoals.count) weekly goals")
            }
        }

        // 2. Auto-verify existing pending goals against latest scores
        if let currentGoalSet = WeeklyGoalStore.currentWeek() {
            let verifiedGoals = WeeklyGoalEngine.autoVerifyGoals(
                goals: currentGoalSet.goals,
                currentScores: geminiScores
            )
            if verifiedGoals != currentGoalSet.goals {
                var allSets = WeeklyGoalStore.loadAll()
                if let idx = allSets.lastIndex(where: {
                    Calendar.current.isDate($0.weekStartDate, equalTo: currentGoalSet.weekStartDate, toGranularity: .weekOfYear)
                }) {
                    allSets[idx].goals = verifiedGoals
                    WeeklyGoalStore.save(allSets)
                    print("✅ [Orchestrator] Server result: auto-verified weekly goals")
                }
                GoalReminderManager.shared.refreshAfterGoalUpdate()
            }
        }

        // 3. Update AION Memory in the background
        let score = geminiScores.healthScore ?? 0
        DispatchQueue.global(qos: .utility).async {
            let memory = AIONMemoryManager.loadFromCache()
            let updated = AIONMemoryExtractor.updateMemory(
                existingMemory: memory,
                parsedAnalysis: parsed,
                healthPayload: nil,  // Not available from server path — acceptable
                healthScore: score
            )
            AIONMemoryManager.save(updated)
            print("🧠 [AION Memory] Updated from server result (interactions: \(updated.interactionCount))")
        }

        // 4. Legacy cache
        let (insights, _, _) = GeminiService.shared.parseResponse(rawResponse)
        if !insights.isEmpty {
            AnalysisCache.save(insights: insights, healthDataHash: "server-result")
        }
    }

    // MARK: - On-Device Analysis (Layer 3)

    private func runAnalysis(completion: @escaping (GeminiDailyResult?, AnalysisFailureReason?) -> Void) {
        queue.sync {
            pendingCallbacks.append(completion)
            guard !isRunning else {
                print("⏳ [Orchestrator] Analysis already in progress — queuing callback")
                return
            }
            isRunning = true
        }

        print("🚀 [Orchestrator] Starting fresh Gemini analysis (parallel fetch)...")

        // Compute week dates upfront (no async needed)
        let calendar = Calendar.current
        let now = Date()
        guard let curStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let curEnd = calendar.date(byAdding: .day, value: 6, to: curStart),
              let prevStart = calendar.date(byAdding: .weekOfYear, value: -1, to: curStart),
              let prevEnd = calendar.date(byAdding: .day, value: 6, to: prevStart) else {
            print("⚠️ [Orchestrator] Failed to compute week dates")
            completeAll(with: nil, reason: .noHealthData)
            return
        }

        // ── Launch ALL fetches in parallel ──
        let group = DispatchGroup()
        var healthData: HealthDataModel?
        var currentWeek: WeeklyHealthSnapshot?
        var previousWeek: WeeklyHealthSnapshot?

        // 1. AION Memory from Firestore
        group.enter()
        AIONMemoryManager.load { memory in
            if let memory = memory {
                AIONMemoryManager.saveToCache(memory)
                print("🧠 [Orchestrator] AION Memory loaded (interaction #\(memory.interactionCount))")
            } else {
                print("🧠 [Orchestrator] No AION Memory found")
            }
            group.leave()
        }

        // 2. Health data (month)
        group.enter()
        HealthKitManager.shared.fetchAllHealthData(for: .month) { data, _ in
            healthData = data
            group.leave()
        }

        // 3. Current week snapshot
        group.enter()
        HealthKitManager.shared.createWeeklySnapshot(weekStartDate: curStart, weekEndDate: curEnd, previousWeekSnapshot: nil) {
            currentWeek = $0
            group.leave()
        }

        // 4. Previous week snapshot
        group.enter()
        HealthKitManager.shared.createWeeklySnapshot(weekStartDate: prevStart, weekEndDate: prevEnd) {
            previousWeek = $0
            group.leave()
        }

        // ── All parallel fetches complete → call Gemini ──
        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }

            guard let data = healthData, data.hasRealData else {
                print("⚠️ [Orchestrator] No health data available")
                self.completeAll(with: nil, reason: .noHealthData)
                return
            }

            guard let current = currentWeek, let previous = previousWeek else {
                print("⚠️ [Orchestrator] Failed to create weekly snapshots")
                self.completeAll(with: nil, reason: .noHealthData)
                return
            }

            // 5. Call Gemini (this also fetches 90-day daily data internally)
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

                // 6. Load the result that GeminiService already saved to GeminiResultStore
                let result = GeminiResultStore.load()

                // 7. Also save to legacy AnalysisCache for backwards compatibility
                if let insights = insights {
                    AnalysisCache.save(insights: insights, healthDataHash: "gemini-orchestrator")
                }

                print("✅ [Orchestrator] Analysis complete — healthScore: \(result?.scores.healthScore ?? -1)")
                self?.completeAll(with: result, reason: nil)
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
