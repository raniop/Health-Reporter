//
//  PreferencesHub.swift
//  Health Reporter
//
//  Preferences hub (3 rows: UI Customization / Health Preferences / Notifications).
//

import SwiftUI

struct LivityPreferencesHub: View {
    @Binding var path: NavigationPath

    var body: some View {
        LivityScreenChrome(title: "Preferences") {
            VStack(alignment: .leading, spacing: 0) {
                LivityGroupLabel(icon: "slider.horizontal.3", text: "Preferences")
                LivityGroupedCard {
                    LivityListRow(
                        icon: "paintpalette.fill",
                        iconColor: LivityTheme.textSecondary,
                        title: "UI Customization",
                        subtitle: "Appearance, units, app icon",
                        accessory: .chevron
                    ) { path.append(LivityProfileRoute.uiCustomization) }

                    LivityRowSeparator()

                    LivityListRow(
                        icon: "heart.fill",
                        iconColor: LivityTheme.bad,
                        title: "Health Preferences",
                        subtitle: "Sleep, heart, recovery, strain settings",
                        accessory: .chevron
                    ) { path.append(LivityProfileRoute.healthPreferences) }

                    LivityRowSeparator()

                    LivityListRow(
                        icon: "bell.fill",
                        iconColor: LivityTheme.caution,
                        title: "Notifications",
                        subtitle: "Customize your notification preferences",
                        accessory: .chevron
                    ) { path.append(LivityProfileRoute.notifications) }
                }
            }
        }
    }
}
