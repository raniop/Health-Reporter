//
//  WatchConnectivityManager.swift
//  Health Reporter Watch App
//
//  Handles Watch <-> iPhone communication via WatchConnectivity.
//  Includes retry logic for data requests and comprehensive logging.
//

import Foundation
import WatchConnectivity
import Combine

/// Manages WatchConnectivity session for Watch side
class WatchConnectivityManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = WatchConnectivityManager()

    @Published var isReachable: Bool = false
    @Published var isConnected: Bool = false
    @Published var lastSyncDate: Date?

    private var session: WCSession?

    /// Retry state for data requests
    private var retryCount = 0
    private let maxRetries = 3

    private override init() {
        super.init()
    }

    // MARK: - Session Setup

    /// Activates the WatchConnectivity session
    func activateSession() {
        guard WCSession.isSupported() else {
            print("⌚ [WC] WCSession NOT supported on this device")
            return
        }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("⌚ [WC] Session activation requested")
    }

    // MARK: - Data Request with Retry

    /// Requests scores/car/tier data from iPhone with retry logic.
    /// NOTE: HealthKit metrics are NOT requested — Watch fetches those locally.
    /// On failure, retries up to 3 times with exponential backoff (2s, 4s, 6s).
    func requestDataFromPhone() {
        guard let session = session, session.isReachable else {
            print("⌚ [WC] Cannot request data — phone not reachable")
            return
        }

        print("⌚ [WC] 📡 Requesting scores/car from iPhone (attempt \(retryCount + 1)/\(maxRetries + 1))")

        session.sendMessage(["request": "healthData"], replyHandler: { [weak self] reply in
            guard let self = self else { return }
            self.retryCount = 0  // Reset on success

            if let data = reply["watchHealthData"] as? Data {
                print("⌚ [WC] ✅ Received scores/car from iPhone (\(data.count) bytes)")
                WatchDataManager.shared.updateFromContext(reply)
                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                }
            } else if let error = reply["error"] as? String {
                print("⌚ [WC] ❌ iPhone replied with error: \(error)")
            } else {
                print("⌚ [WC] ⚠️ iPhone reply had no recognizable data (keys: \(reply.keys.joined(separator: ", ")))")
            }
        }, errorHandler: { [weak self] error in
            guard let self = self else { return }
            print("⌚ [WC] ❌ Request failed: \(error.localizedDescription)")

            if self.retryCount < self.maxRetries {
                self.retryCount += 1
                let delay = Double(self.retryCount) * 2.0
                print("⌚ [WC] 🔄 Retrying in \(delay)s (attempt \(self.retryCount + 1)/\(self.maxRetries + 1))")
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.requestDataFromPhone()
                }
            } else {
                print("⌚ [WC] ❌ All \(self.maxRetries) retries exhausted")
                self.retryCount = 0
            }
        })
    }

    /// Sends a message to iPhone (fire and forget)
    func sendToPhone(_ message: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("⌚ [WC] Cannot send — phone not reachable")
            return
        }
        print("⌚ [WC] 📤 Sending message to iPhone (keys: \(message.keys.joined(separator: ", ")))")
        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("⌚ [WC] ❌ Send failed: \(error.localizedDescription)")
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let stateStr: String
        switch activationState {
        case .activated: stateStr = "activated"
        case .inactive: stateStr = "inactive"
        case .notActivated: stateStr = "notActivated"
        @unknown default: stateStr = "unknown(\(activationState.rawValue))"
        }
        print("⌚ [WC] Activation complete: \(stateStr), error=\(error?.localizedDescription ?? "none")")

        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("⌚ [WC] 📶 Reachability changed: \(session.isReachable)")
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable {
                print("⌚ [WC] Phone became reachable — auto-requesting data")
                self.requestDataFromPhone()
            }
        }
    }

    /// Receives application context updates from iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let hasHealthData = applicationContext["watchHealthData"] != nil
        print("⌚ [WC] 📥 Received application context (hasHealthData: \(hasHealthData), keys: \(applicationContext.keys.joined(separator: ", ")))")
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
        }
        WatchDataManager.shared.updateFromContext(applicationContext)
    }

    /// Receives direct messages from iPhone (no reply)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let type = message["type"] as? String ?? "unknown"
        print("⌚ [WC] 📥 Received message (type: \(type))")

        // Handle full health data update
        if type == "healthDataUpdate" {
            WatchDataManager.shared.updateFromContext(message)
            DispatchQueue.main.async { self.lastSyncDate = Date() }
            return
        }

        // Handle car-only update
        if type == "carDataUpdate",
           let carName = message["carName"] as? String,
           let carEmoji = message["carEmoji"] as? String,
           let carTierIndex = message["carTierIndex"] as? Int,
           let carTierLabel = message["carTierLabel"] as? String {
            print("⌚ [WC] 🚗 Car update: \(carName) (tier \(carTierIndex))")
            WatchDataManager.shared.updateCarDataOnly(
                carName: carName,
                carEmoji: carEmoji,
                carTierIndex: carTierIndex,
                carTierLabel: carTierLabel
            )
            DispatchQueue.main.async { self.lastSyncDate = Date() }
            return
        }

        print("⌚ [WC] ⚠️ Unhandled message type: \(type)")
    }

    /// Receives messages with reply handler
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let type = message["type"] as? String ?? "unknown"
        print("⌚ [WC] 📥 Received message with reply (type: \(type))")

        if type == "ping" {
            replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
            return
        }

        if type == "healthDataUpdate" {
            WatchDataManager.shared.updateFromContext(message)
            DispatchQueue.main.async { self.lastSyncDate = Date() }
            replyHandler(["status": "received"])
            return
        }

        replyHandler(["status": "received"])
    }

    /// Receives user info transfers
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("⌚ [WC] 📥 Received user info (keys: \(userInfo.keys.joined(separator: ", ")))")
        WatchDataManager.shared.updateFromContext(userInfo)
        DispatchQueue.main.async { self.lastSyncDate = Date() }
    }
}
