//
//  ContentView.swift
//  Health Reporter Watch App
//
//  Main navigation view with tabbed pages.
//  NOTE: Refresh is handled by the App struct's scenePhase handler — not here.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataManager: WatchDataManager
    @EnvironmentObject var connectivityManager: WatchConnectivityManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(0)

            CarTierView()
                .tag(1)

            ActivityRingsView()
                .tag(2)

            MetricsDetailView()
                .tag(3)
        }
        .tabViewStyle(.verticalPage)
        // NOTE: No onAppear or onChange(scenePhase) here.
        // The App struct handles all refresh triggers to avoid duplicate requests.
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(WatchDataManager.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
