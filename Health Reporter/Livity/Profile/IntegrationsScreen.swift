//
//  IntegrationsScreen.swift
//  Health Reporter
//
//  Integrations screen: connect Garmin, Sync to Apple Watch.
//

import SwiftUI

struct LivityIntegrationsScreen: View {
    @StateObject private var store = ProfileStore.shared
    @State private var syncingWatch = false

    var body: some View {
        LivityScreenChrome(title: "Integrations") {
            VStack(alignment: .leading, spacing: 0) {
                LivityGroupLabel(icon: "link", text: "Integrations")
                LivityGroupedCard {
                    LivityListRow(
                        icon: "figure.outdoor.cycle",
                        iconColor: LivityTheme.info,
                        title: "Garmin Connect™",
                        subtitle: store.garminConnected
                            ? "Connected"
                            : "Connect your Garmin account",
                        accessory: .chevron
                    ) {
                        store.garminConnected.toggle()
                    }
                    LivityRowSeparator()
                    LivityListRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: LivityTheme.good,
                        title: "Sync to Apple Watch",
                        subtitle: syncingWatch ? "Syncing…" : "Send latest data to your watch",
                        accessory: .chevron
                    ) {
                        syncingWatch = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            syncingWatch = false
                        }
                    }
                }
            }
        }
    }
}
