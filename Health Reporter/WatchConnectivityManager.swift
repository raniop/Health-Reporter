//
//  WatchConnectivityManager.swift
//  Health Reporter
//
//  Handles iPhone <-> Watch communication via WatchConnectivity
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

    private override init() {
        super.init()
        setupSession()
    }

    // MARK: - Session Setup

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity: Not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("WatchConnectivity: Session activation requested")
    }

    // MARK: - Data Sending

    /// Sends health data to Watch via application context (persistent)
    func sendDataToWatch(_ watchData: WatchHealthDataTransfer) {
        guard let session = session, session.activationState == .activated else {
            print("WatchConnectivity: Session not activated")
            return
        }

        guard session.isWatchAppInstalled else {
            print("WatchConnectivity: Watch app not installed")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(watchData)
            let context: [String: Any] = ["watchHealthData": encoded]
            try session.updateApplicationContext(context)
            print("WatchConnectivity: Application context updated with health data")
        } catch {
            print("WatchConnectivity: Failed to send data - \(error.localizedDescription)")
        }
    }

    /// Sends health data immediately if Watch is reachable
    func sendDataImmediately(_ watchData: WatchHealthDataTransfer) {
        guard let session = session, session.isReachable else {
            // Fall back to application context
            sendDataToWatch(watchData)
            return
        }

        do {
            let encoded = try JSONEncoder().encode(watchData)
            let message: [String: Any] = [
                "type": "healthDataUpdate",
                "watchHealthData": encoded
            ]

            session.sendMessage(message, replyHandler: { reply in
                print("WatchConnectivity: Watch received data - \(reply)")
            }, errorHandler: { error in
                print("WatchConnectivity: Immediate send failed - \(error.localizedDescription)")
                // Fall back to application context
                self.sendDataToWatch(watchData)
            })
        } catch {
            print("WatchConnectivity: Failed to encode data - \(error.localizedDescription)")
        }
    }

    /// Convenience method to send data from widget data
    func sendWidgetDataToWatch(
        healthScore: Int,
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
        carTierIndex: Int,
        carTierLabel: String,
        // Score breakdown (optional)
        recoveryScore: Int? = nil,
        sleepScore: Int? = nil,
        nervousSystemScore: Int? = nil,
        energyScore: Int? = nil,
        activityScore: Int? = nil,
        loadBalanceScore: Int? = nil,
        // Gemini car data (optional)
        geminiCarName: String? = nil,
        geminiCarScore: Int? = nil
    ) {
        // Calculate gemini car tier index if we have the score
        let geminiTierIndex = geminiCarScore.map { CarTierEngine.tierForScore($0).tierIndex }

        let watchData = WatchHealthDataTransfer(
            healthScore: healthScore,
            healthStatus: healthStatus,
            reliabilityScore: 85,
            carTierIndex: carTierIndex,
            carName: carName,
            carEmoji: carEmoji,
            carTierLabel: carTierLabel,
            geminiCarName: geminiCarName,
            geminiCarScore: geminiCarScore,
            geminiCarTierIndex: geminiTierIndex,
            moveCalories: calories,
            moveGoal: 500,
            exerciseMinutes: exerciseMinutes,
            exerciseGoal: 30,
            standHours: standHours,
            standGoal: 12,
            steps: steps,
            heartRate: heartRate,
            restingHeartRate: heartRate,
            hrv: hrv,
            sleepHours: sleepHours,
            recoveryScore: recoveryScore,
            sleepScore: sleepScore,
            nervousSystemScore: nervousSystemScore,
            energyScore: energyScore,
            activityScore: activityScore,
            loadBalanceScore: loadBalanceScore,
            lastUpdated: Date(),
            isFromPhone: true
        )

        sendDataImmediately(watchData)
    }

    /// Sends only car tier data to Watch (score/status calculated locally on Watch)
    func sendCarDataToWatch(
        carName: String,
        carEmoji: String,
        carTierIndex: Int,
        carTierLabel: String
    ) {
        guard let session = session, session.activationState == .activated else {
            print("WatchConnectivity: Session not activated for car data")
            return
        }

        guard session.isWatchAppInstalled else {
            print("WatchConnectivity: Watch app not installed")
            return
        }

        // Send only car data - Watch will merge with local health data
        let carData: [String: Any] = [
            "type": "carDataUpdate",
            "carName": carName,
            "carEmoji": carEmoji,
            "carTierIndex": carTierIndex,
            "carTierLabel": carTierLabel
        ]

        if session.isReachable {
            session.sendMessage(carData, replyHandler: { reply in
                print("WatchConnectivity: Watch received car data - \(reply)")
            }, errorHandler: { error in
                print("WatchConnectivity: Car data send failed - \(error.localizedDescription)")
                // Fall back to application context
                self.sendCarDataViaContext(carName: carName, carEmoji: carEmoji, carTierIndex: carTierIndex, carTierLabel: carTierLabel)
            })
        } else {
            sendCarDataViaContext(carName: carName, carEmoji: carEmoji, carTierIndex: carTierIndex, carTierLabel: carTierLabel)
        }
    }

    /// Sends car data via application context (when not reachable)
    private func sendCarDataViaContext(carName: String, carEmoji: String, carTierIndex: Int, carTierLabel: String) {
        guard let session = session else { return }

        let context: [String: Any] = [
            "carDataOnly": true,
            "carName": carName,
            "carEmoji": carEmoji,
            "carTierIndex": carTierIndex,
            "carTierLabel": carTierLabel
        ]

        do {
            try session.updateApplicationContext(context)
            print("WatchConnectivity: Car data sent via application context")
        } catch {
            print("WatchConnectivity: Failed to send car data context - \(error.localizedDescription)")
        }
    }

    /// Transfers user info to Watch (queued, guaranteed delivery)
    func transferUserInfo(_ watchData: WatchHealthDataTransfer) {
        guard let session = session, session.activationState == .activated else {
            print("WatchConnectivity: Session not activated")
            return
        }

        guard session.isWatchAppInstalled else {
            print("WatchConnectivity: Watch app not installed")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(watchData)
            let userInfo: [String: Any] = ["watchHealthData": encoded]
            session.transferUserInfo(userInfo)
            print("WatchConnectivity: User info transfer queued")
        } catch {
            print("WatchConnectivity: Failed to encode user info - \(error.localizedDescription)")
        }
    }

    // MARK: - Status

    /// Checks if Watch communication is available
    var isWatchAvailable: Bool {
        guard let session = session else { return false }
        return session.activationState == .activated && session.isWatchAppInstalled
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WatchConnectivity: Activation failed - \(error.localizedDescription)")
            } else {
                print("WatchConnectivity: Activated with state \(activationState.rawValue)")
                self.updateSessionState(session)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchConnectivity: Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WatchConnectivity: Session deactivated")
        // Reactivate session on deactivation
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("WatchConnectivity: Reachability changed to \(session.isReachable)")
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.updateSessionState(session)
        }
    }

    private func updateSessionState(_ session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable

        print("WatchConnectivity: State updated - Paired: \(isPaired), Installed: \(isWatchAppInstalled), Reachable: \(isReachable)")
    }

    /// Receives messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("WatchConnectivity: Received message from Watch")

        if message["request"] as? String == "healthData" {
            // Watch is requesting data refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .watchRequestedDataRefresh, object: nil)
            }
        }
    }

    /// Receives messages from Watch with reply handler
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("WatchConnectivity: Received message with reply handler")

        if message["request"] as? String == "healthData" {
            // Send ALL data back to Watch
            DispatchQueue.main.async {
                if let widgetData = WidgetDataManager.shared.loadCurrentData() {
                    let tier = CarTierEngine.tierForScore(widgetData.healthScore)

                    // Get Gemini car data from cache
                    let geminiCar = AnalysisCache.loadSelectedCar()
                    let geminiScore = AnalysisCache.loadHealthScore()
                    let geminiTierIndex = geminiScore.map { CarTierEngine.tierForScore($0).tierIndex }

                    let watchData = WatchHealthDataTransfer(
                        healthScore: widgetData.healthScore,
                        healthStatus: widgetData.healthStatus,
                        reliabilityScore: 85,
                        carTierIndex: widgetData.carTierIndex,
                        carName: widgetData.carName,
                        carEmoji: widgetData.carEmoji,
                        carTierLabel: tier.tierLabel,
                        geminiCarName: geminiCar?.name,
                        geminiCarScore: geminiScore,
                        geminiCarTierIndex: geminiTierIndex,
                        moveCalories: widgetData.calories,
                        moveGoal: widgetData.caloriesGoal,
                        exerciseMinutes: widgetData.exerciseMinutes,
                        exerciseGoal: widgetData.exerciseGoal,
                        standHours: widgetData.standHours,
                        standGoal: widgetData.standGoal,
                        steps: widgetData.steps,
                        heartRate: widgetData.heartRate,
                        restingHeartRate: widgetData.heartRate,
                        hrv: widgetData.hrv,
                        sleepHours: widgetData.sleepHours,
                        recoveryScore: nil,
                        sleepScore: nil,
                        nervousSystemScore: nil,
                        energyScore: nil,
                        activityScore: nil,
                        loadBalanceScore: nil,
                        lastUpdated: Date(),
                        isFromPhone: true
                    )

                    if let encoded = try? JSONEncoder().encode(watchData) {
                        replyHandler(["watchHealthData": encoded])
                        print("WatchConnectivity: Sent ALL data to Watch - score=\(widgetData.healthScore), geminiCar=\(geminiCar?.name ?? "nil"), geminiScore=\(geminiScore ?? 0)")
                    } else {
                        replyHandler(["error": "Failed to encode data"])
                    }
                } else {
                    replyHandler(["error": "No data available"])
                }
            }
        } else {
            replyHandler(["status": "received"])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchRequestedDataRefresh = Notification.Name("watchRequestedDataRefresh")
}

// MARK: - Watch Data Transfer Model

/// Data model for transferring to Watch (matches Watch's WatchHealthData)
struct WatchHealthDataTransfer: Codable {
    var healthScore: Int      // Daily score (for HomeView)
    var healthStatus: String
    var reliabilityScore: Int

    // Car tier based on daily score (for progress bar)
    var carTierIndex: Int
    var carName: String
    var carEmoji: String
    var carTierLabel: String

    // Gemini car data (for CarTierView - 90-day average)
    var geminiCarName: String?       // Car name from Gemini
    var geminiCarScore: Int?         // 90-day score
    var geminiCarTierIndex: Int?     // Tier based on 90-day score

    var moveCalories: Int
    var moveGoal: Int
    var exerciseMinutes: Int
    var exerciseGoal: Int
    var standHours: Int
    var standGoal: Int

    var steps: Int
    var heartRate: Int
    var restingHeartRate: Int
    var hrv: Int
    var sleepHours: Double

    // Score breakdown (for "Why" screen on Watch)
    var recoveryScore: Int?
    var sleepScore: Int?
    var nervousSystemScore: Int?
    var energyScore: Int?
    var activityScore: Int?
    var loadBalanceScore: Int?

    var lastUpdated: Date
    var isFromPhone: Bool
}
