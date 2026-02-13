//
//  Health_Reporter_Watch_AppApp.swift
//  Health Reporter Watch App
//
//  Main entry point for the Apple Watch app
//

import SwiftUI
import WatchConnectivity

@main
struct Health_Reporter_Watch_App_Watch_AppApp: App {
    @StateObject private var dataManager = WatchDataManager.shared
    @StateObject private var connectivityManager = WatchConnectivityManager.shared

    init() {
        // Activate WatchConnectivity session
        WatchConnectivityManager.shared.activateSession()

        // Request HealthKit authorization early so local data is available
        WatchDataManager.shared.ensureHealthKitAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(connectivityManager)
        }
    }
}
