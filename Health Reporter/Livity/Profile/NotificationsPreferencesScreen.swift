//
//  NotificationsPreferencesScreen.swift
//  Health Reporter
//
//  Notifications preferences screen: list of alert categories with toggles.
//

import SwiftUI

struct LivityNotificationsPreferencesScreen: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivityScreenChrome(title: "Notifications") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose when and how Livity should alert you about your health and activity metrics.")
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textSecondary)

                LivityGroupLabel(icon: "bell.fill", text: "Alert Types")

                LivityGroupedCard {
                    ForEach(Array(LivityAlertCategory.allCases.enumerated()), id: \.element.id) { idx, cat in
                        LivityListRow(
                            icon: cat.icon,
                            iconColor: cat.iconColor,
                            title: cat.title,
                            subtitle: cat.subtitle,
                            accessory: .toggle(Binding(
                                get: { store.alertEnabled[cat] ?? cat.defaultOn },
                                set: { store.setAlertEnabled(cat, $0) }
                            ))
                        )
                        if idx < LivityAlertCategory.allCases.count - 1 { LivityRowSeparator() }
                    }
                }
            }
        }
    }
}
