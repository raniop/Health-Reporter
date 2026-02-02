//
//  ContentView.swift
//  Health Reporter Watch App
//
//  Main navigation view with tabbed pages
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
        .onAppear {
            // Always request fresh data when app appears
            print("⌚️ ContentView appeared - requesting refresh from iPhone")
            dataManager.requestRefresh()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(WatchDataManager.shared)
        .environmentObject(WatchConnectivityManager.shared)
}
