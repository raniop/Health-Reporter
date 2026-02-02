//
//  WatchConnectivityManager.swift
//  Health Reporter Watch App
//
//  Handles Watch <-> iPhone communication via WatchConnectivity
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

    private override init() {
        super.init()
    }

    /// Activates the WatchConnectivity session
    func activateSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity: Not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("WatchConnectivity: Session activation requested")
    }

    /// Requests ALL health data from iPhone
    func requestDataFromPhone() {
        guard let session = session, session.isReachable else {
            print("WatchConnectivity: iPhone not reachable")
            return
        }

        let message: [String: Any] = ["request": "healthData"]
        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                // Handle full data response
                if let _ = reply["watchHealthData"] as? Data {
                    Task { @MainActor in
                        WatchDataManager.shared.updateFromContext(reply)
                    }
                }
            }
        }, errorHandler: { error in
            print("WatchConnectivity: Failed to request data: \(error.localizedDescription)")
        })
    }

    /// Sends a message to iPhone (fire and forget)
    func sendToPhone(_ message: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("WatchConnectivity: iPhone not reachable for message")
            return
        }

        session.sendMessage(message, replyHandler: nil) { error in
            print("WatchConnectivity: Send message failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated

            if let error = error {
                print("WatchConnectivity: Activation failed - \(error.localizedDescription)")
            } else {
                print("WatchConnectivity: Activated with state \(activationState.rawValue)")
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("WatchConnectivity: Reachability changed to \(session.isReachable)")

            if session.isReachable {
                // Request fresh data when iPhone becomes reachable
                self.requestDataFromPhone()
            }
        }
    }

    /// Receives application context updates from iPhone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("WatchConnectivity: Received application context")
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
            Task { @MainActor in
                WatchDataManager.shared.updateFromContext(applicationContext)
            }
        }
    }

    /// Receives direct messages from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("WatchConnectivity: Received message")
        DispatchQueue.main.async {
            if message["type"] as? String == "healthDataUpdate" {
                Task { @MainActor in
                    WatchDataManager.shared.updateFromContext(message)
                }
            }
        }
    }

    /// Receives messages with reply handler
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("WatchConnectivity: Received message with reply handler")

        // Handle ping requests
        if message["type"] as? String == "ping" {
            replyHandler(["status": "alive", "timestamp": Date().timeIntervalSince1970])
            return
        }

        // Handle full data updates
        if message["type"] as? String == "healthDataUpdate" {
            DispatchQueue.main.async {
                Task { @MainActor in
                    WatchDataManager.shared.updateFromContext(message)
                }
            }
            replyHandler(["status": "received"])
        }
    }

    /// Receives user info transfers
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("WatchConnectivity: Received user info")
        DispatchQueue.main.async {
            Task { @MainActor in
                WatchDataManager.shared.updateFromContext(userInfo)
            }
        }
    }
}
