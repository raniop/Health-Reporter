//
//  WatchConnectivityManager.swift
//  Health Reporter
//
//  Handles iPhone <-> Watch communication via WatchConnectivity.
//  Sends health data, car tier data, and score breakdowns to Watch.
//

import Foundation
import WatchConnectivity
import Combine

/// Manages WatchConnectivity session for iPhone side
class WatchConnectivityManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = WatchConnectivityManager()

    @Published var isWatchAppInstalled: Bool = false
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool = false

    private var session: WCSession?

    /// Stores the last full payload sent to Watch, used for car-only merges
    private var lastSentPayload: Data?

    private override init() {
        super.init()
        setupSession()
    }

    // MARK: - Session Setup

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("📱 [WC] WCSession is NOT supported on this device")
            return
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("📱 [WC] Session activating...")
    }

    // MARK: - Core Send Methods

    /// Sends encoded WatchHealthData JSON to Watch via application context (persistent)
    private func sendViaContext(_ encoded: Data) {
        guard let session = session, session.activationState == .activated,
              session.isWatchAppInstalled else {
            print("📱 [WC] sendViaContext: skipped — session not ready or watch not installed")
            return
        }
        do {
            try session.updateApplicationContext(["watchHealthData": encoded])
            print("📱 [WC] ✅ Sent \(encoded.count) bytes via application context")
        } catch {
            print("📱 [WC] ❌ Context send failed: \(error.localizedDescription)")
        }
    }

    /// Sends encoded WatchHealthData JSON to Watch immediately if reachable, else via context
    private func sendImmediately(_ encoded: Data) {
        guard let session = session else {
            print("📱 [WC] sendImmediately: no session")
            return
        }

        if session.isReachable {
            print("📱 [WC] Watch reachable — sending \(encoded.count) bytes via message")
            let message: [String: Any] = [
                "type": "healthDataUpdate",
                "watchHealthData": encoded
            ]
            session.sendMessage(message, replyHandler: { _ in
                print("📱 [WC] ✅ Message delivered to Watch")
            }, errorHandler: { [weak self] error in
                print("📱 [WC] ⚠️ Message failed (\(error.localizedDescription)), falling back to context")
                self?.sendViaContext(encoded)
            })
        } else {
            print("📱 [WC] Watch NOT reachable — sending via context")
            sendViaContext(encoded)
        }
    }

    // MARK: - Public Send Methods

    /// Main entry point: send scores/car/tier/breakdown to Watch after Gemini analysis.
    /// NOTE: HealthKit metrics (steps, HR, sleep, etc.) are NOT sent — Watch fetches those locally.
    func sendPostGeminiDataToWatch(result: GeminiDailyResult?) {
        print("📱 [WC] sendPostGeminiDataToWatch called (result=\(result != nil ? "present" : "nil"))")
        guard let widgetData = WidgetDataManager.shared.loadCurrentData() else {
            print("📱 [WC] ❌ No widget data available — cannot send to Watch")
            return
        }

        let scores = result?.scores
        let geminiCarName = result?.carModel.isEmpty == false ? result?.carModel : GeminiResultStore.loadCarName()
        let geminiScore = scores?.carScore ?? GeminiResultStore.loadCarScore()
        let geminiTierIndex = geminiScore.map { HealthTier.forScore($0).tierIndex }

        // Use healthScore (daily score) as primary — after SplashViewController fix,
        // widgetData.healthScore = daily health score, widgetData.dailyScore = 90-day car score
        let dailyScore = widgetData.healthScore > 0 ? widgetData.healthScore : (scores?.healthScore ?? GeminiResultStore.loadHealthScore() ?? 0)
        let tier = HealthTier.forScore(dailyScore)

        // Load score breakdown from result or store
        let breakdown: [String: Int]?
        if let scores = scores {
            var bd: [String: Int] = [:]
            if let v = scores.recoveryDebt { bd["recoveryDebt"] = v }
            if let v = scores.sleepScore { bd["sleep"] = v }
            if let v = scores.nervousSystemBalance { bd["nervousSystem"] = v }
            if let v = scores.energyScore { bd["energy"] = v }
            if let v = scores.activityScore { bd["activity"] = v }
            if let v = scores.loadBalance { bd["loadBalance"] = v }
            breakdown = bd.isEmpty ? nil : bd
        } else {
            breakdown = GeminiResultStore.loadScoreBreakdown()
        }

        // Only send scores, car, tier, breakdown — NO HealthKit metrics.
        // Watch fetches HealthKit data locally from its own HealthKit store.
        let encoded = buildWatchPayload(
            healthScore: dailyScore,
            healthStatus: widgetData.healthStatus,
            reliabilityScore: 85,
            carTierIndex: widgetData.carTierIndex,
            carName: widgetData.carName,
            carEmoji: widgetData.carEmoji,
            carTierLabel: tier.tierLabel,
            geminiCarName: geminiCarName,
            geminiCarScore: geminiScore,
            geminiCarTierIndex: geminiTierIndex,
            recoveryScore: breakdown?["recoveryDebt"],
            sleepScore: breakdown?["sleep"],
            nervousSystemScore: breakdown?["nervousSystem"],
            energyScore: breakdown?["energy"],
            activityScore: breakdown?["activity"],
            loadBalanceScore: breakdown?["loadBalance"]
        )

        guard let encoded = encoded else {
            print("📱 [WC] ❌ Failed to encode watch payload")
            return
        }
        print("📱 [WC] Payload built: \(encoded.count) bytes, score=\(dailyScore), car=\(widgetData.carName)")
        lastSentPayload = encoded
        sendImmediately(encoded)
    }

    /// Sends only car tier data to Watch
    func sendCarDataToWatch(
        carName: String,
        carEmoji: String,
        carTierIndex: Int,
        carTierLabel: String
    ) {
        print("📱 [WC] sendCarDataToWatch: \(carName) (\(carEmoji)) tier=\(carTierIndex)")
        guard let session = session, session.activationState == .activated,
              session.isWatchAppInstalled else {
            print("📱 [WC] sendCarDataToWatch: skipped — session not ready or watch not installed")
            return
        }

        let carData: [String: Any] = [
            "type": "carDataUpdate",
            "carName": carName,
            "carEmoji": carEmoji,
            "carTierIndex": carTierIndex,
            "carTierLabel": carTierLabel
        ]

        if session.isReachable {
            session.sendMessage(carData, replyHandler: { _ in
                print("📱 [WC] ✅ Car data message delivered to Watch")
            }, errorHandler: { [weak self] error in
                print("📱 [WC] ⚠️ Car data message failed (\(error.localizedDescription)), merging into full payload")
                self?.sendCarDataViaFullPayload(carName: carName, carEmoji: carEmoji, carTierIndex: carTierIndex, carTierLabel: carTierLabel)
            })
        } else {
            print("📱 [WC] Watch NOT reachable for car data — merging into full payload")
            sendCarDataViaFullPayload(carName: carName, carEmoji: carEmoji, carTierIndex: carTierIndex, carTierLabel: carTierLabel)
        }
    }

    /// Merges car fields into last sent payload and sends as full context
    private func sendCarDataViaFullPayload(carName: String, carEmoji: String, carTierIndex: Int, carTierLabel: String) {
        guard let lastData = lastSentPayload,
              var payload = try? JSONDecoder().decode(WatchPayload.self, from: lastData) else {
            print("📱 [WC] ⚠️ No last payload to merge car data into")
            return
        }

        payload.carName = carName
        payload.carEmoji = carEmoji
        payload.carTierIndex = carTierIndex
        payload.carTierLabel = carTierLabel
        payload.geminiCarName = carName
        payload.geminiCarTierIndex = carTierIndex
        payload.lastUpdated = Date()

        guard let merged = try? JSONEncoder().encode(payload) else { return }
        lastSentPayload = merged
        sendViaContext(merged)
    }

    // MARK: - Status

    var isWatchAvailable: Bool {
        guard let session = session else { return false }
        return session.activationState == .activated && session.isWatchAppInstalled
    }

    // MARK: - Payload Builder

    /// Builds a scores-only payload (no HealthKit metrics — Watch fetches those locally)
    private func buildWatchPayload(
        healthScore: Int,
        healthStatus: String,
        reliabilityScore: Int,
        carTierIndex: Int,
        carName: String,
        carEmoji: String,
        carTierLabel: String,
        geminiCarName: String?,
        geminiCarScore: Int?,
        geminiCarTierIndex: Int?,
        recoveryScore: Int?,
        sleepScore: Int?,
        nervousSystemScore: Int?,
        energyScore: Int?,
        activityScore: Int?,
        loadBalanceScore: Int?
    ) -> Data? {
        let payload = WatchPayload(
            healthScore: healthScore, healthStatus: healthStatus, reliabilityScore: reliabilityScore,
            carTierIndex: carTierIndex, carName: carName, carEmoji: carEmoji, carTierLabel: carTierLabel,
            geminiCarName: geminiCarName, geminiCarScore: geminiCarScore, geminiCarTierIndex: geminiCarTierIndex,
            recoveryScore: recoveryScore, sleepScore: sleepScore,
            nervousSystemScore: nervousSystemScore, energyScore: energyScore,
            activityScore: activityScore, loadBalanceScore: loadBalanceScore,
            lastUpdated: Date(), isFromPhone: true
        )
        return try? JSONEncoder().encode(payload)
    }
}

// MARK: - Watch Payload (scores/car/tier only — no HealthKit metrics)

/// Codable struct that produces JSON decodable by Watch's WatchHealthData.
/// Only contains iPhone-owned fields: scores, car, tier, breakdown.
/// HealthKit metrics (steps, HR, sleep etc.) are fetched locally by the Watch.
private struct WatchPayload: Codable {
    var healthScore: Int
    var healthStatus: String
    var reliabilityScore: Int
    var carTierIndex: Int
    var carName: String
    var carEmoji: String
    var carTierLabel: String
    var geminiCarName: String?
    var geminiCarScore: Int?
    var geminiCarTierIndex: Int?
    var recoveryScore: Int?
    var sleepScore: Int?
    var nervousSystemScore: Int?
    var energyScore: Int?
    var activityScore: Int?
    var loadBalanceScore: Int?
    var lastUpdated: Date
    var isFromPhone: Bool
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let stateStr: String
        switch activationState {
        case .activated: stateStr = "ACTIVATED"
        case .inactive: stateStr = "INACTIVE"
        case .notActivated: stateStr = "NOT_ACTIVATED"
        @unknown default: stateStr = "UNKNOWN"
        }
        print("📱 [WC] Session activation complete: \(stateStr), error=\(error?.localizedDescription ?? "none")")

        DispatchQueue.main.async {
            if error == nil {
                self.updateSessionState(session)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 [WC] Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("📱 [WC] Session deactivated — reactivating")
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("📱 [WC] Reachability changed: \(session.isReachable ? "REACHABLE" : "NOT reachable")")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("📱 [WC] Watch state changed: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled), reachable=\(session.isReachable)")
        DispatchQueue.main.async {
            self.updateSessionState(session)
        }
    }

    private func updateSessionState(_ session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
        print("📱 [WC] State updated: paired=\(isPaired), installed=\(isWatchAppInstalled), reachable=\(isReachable)")
    }

    /// Receives messages from Watch (no reply handler)
    /// FIX: Previously posted a dead notification nobody observed.
    /// Now directly sends data back to Watch via sendPostGeminiDataToWatch.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let keys = message.keys.sorted().joined(separator: ", ")
        print("📱 [WC] 📩 Received message (no-reply) from Watch: [\(keys)]")

        if message["request"] as? String == "healthData" {
            print("📱 [WC] Watch requested health data (no-reply path) — sending via sendPostGeminiDataToWatch")
            DispatchQueue.main.async { [weak self] in
                self?.sendPostGeminiDataToWatch(result: nil)
            }
        }
    }

    /// Receives messages from Watch with reply handler
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let keys = message.keys.sorted().joined(separator: ", ")
        print("📱 [WC] 📩 Received message (with reply) from Watch: [\(keys)]")

        if message["request"] as? String == "healthData" {
            print("📱 [WC] Watch requested scores/car data (reply path) — building response")
            DispatchQueue.main.async { [weak self] in
                guard let widgetData = WidgetDataManager.shared.loadCurrentData() else {
                    print("📱 [WC] ❌ No widget data for reply")
                    replyHandler(["error": "No data available"])
                    return
                }

                let geminiScore = GeminiResultStore.loadCarScore()
                // Use healthScore (daily score) as primary — after SplashViewController fix,
                // widgetData.healthScore = daily health score, widgetData.dailyScore = 90-day car score
                let dailyScore = widgetData.healthScore > 0 ? widgetData.healthScore : (widgetData.dailyScore ?? 0)
                let tier = HealthTier.forScore(dailyScore)
                let geminiCarName = GeminiResultStore.loadCarName()
                let geminiTierIndex = geminiScore.map { HealthTier.forScore($0).tierIndex }

                // Load score breakdown from GeminiResultStore
                let breakdown = GeminiResultStore.loadScoreBreakdown()

                // Only send scores/car/tier/breakdown — no HealthKit metrics
                let encoded = self?.buildWatchPayload(
                    healthScore: dailyScore,
                    healthStatus: widgetData.healthStatus,
                    reliabilityScore: 85,
                    carTierIndex: widgetData.carTierIndex,
                    carName: widgetData.carName,
                    carEmoji: widgetData.carEmoji,
                    carTierLabel: tier.tierLabel,
                    geminiCarName: geminiCarName,
                    geminiCarScore: geminiScore,
                    geminiCarTierIndex: geminiTierIndex,
                    recoveryScore: breakdown?["recoveryDebt"],
                    sleepScore: breakdown?["sleep"],
                    nervousSystemScore: breakdown?["nervousSystem"],
                    energyScore: breakdown?["energy"],
                    activityScore: breakdown?["activity"],
                    loadBalanceScore: breakdown?["loadBalance"]
                )

                if let encoded = encoded {
                    self?.lastSentPayload = encoded
                    print("📱 [WC] ✅ Replying to Watch with \(encoded.count) bytes, score=\(dailyScore), car=\(widgetData.carName)")
                    replyHandler(["watchHealthData": encoded])
                } else {
                    print("📱 [WC] ❌ Failed to encode reply payload")
                    replyHandler(["error": "Failed to encode data"])
                }
            }
        } else {
            print("📱 [WC] Unknown message type — replying with status:received")
            replyHandler(["status": "received"])
        }
    }
}
