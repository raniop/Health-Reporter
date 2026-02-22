//
//  Health_Reporter_Watch_AppApp.swift
//  Health Reporter Watch App
//
//  Main entry point for the Apple Watch app.
//  scenePhase handler is the SINGLE refresh trigger — no duplicate refreshes.
//

import SwiftUI
import WatchConnectivity
import WatchKit

@main
struct Health_Reporter_Watch_App_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataManager: WatchDataManager
    @StateObject private var connectivityManager: WatchConnectivityManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // One-time migration: wipe stale cache BEFORE any manager loads data
        WatchDataStorage.migrateIfNeeded()

        // Init managers after migration
        _dataManager = StateObject(wrappedValue: WatchDataManager.shared)
        _connectivityManager = StateObject(wrappedValue: WatchConnectivityManager.shared)

        // Activate WatchConnectivity session
        WatchConnectivityManager.shared.activateSession()

        print("⌚ [App] Watch app initialized, WC session activated")
        // NOTE: Do NOT call ensureHealthKitAuthorization() or requestRefresh() here.
        // The scenePhase handler below will trigger requestRefresh() when app becomes .active,
        // which handles both auth and fetch. This avoids duplicate refresh races.
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(connectivityManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                print("⌚ [App] Scene became active — requesting refresh + starting periodic timer")
                WatchDataManager.shared.requestRefresh()
                WatchDataManager.shared.startPeriodicRefresh()
            case .background, .inactive:
                print("⌚ [App] Scene became \(newPhase) — stopping periodic timer, scheduling background refresh")
                WatchDataManager.shared.stopPeriodicRefresh()
                WatchDataManager.shared.scheduleNextBackgroundRefresh()
            @unknown default:
                break
            }
        }
    }
}

// MARK: - WKApplicationDelegate for background task handling

class AppDelegate: NSObject, WKApplicationDelegate {

    /// Called by the system when a background task is scheduled to run
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                print("⌚ [AppDelegate] 🔄 WKApplicationRefreshBackgroundTask received")
                Task {
                    await WatchDataManager.shared.handleBackgroundRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                print("⌚ [AppDelegate] 📸 WKSnapshotRefreshBackgroundTask received")
                Task {
                    await WatchDataManager.shared.handleBackgroundRefresh()
                    snapshotTask.setTaskCompletedWithSnapshot(true)
                }

            default:
                print("⌚ [AppDelegate] ❓ Unknown background task: \(type(of: task))")
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
