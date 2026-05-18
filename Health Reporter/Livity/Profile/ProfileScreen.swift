//
//  ProfileScreen.swift
//  Health Reporter
//
//  Livity Profile tab root: Subscription / App / More / Community sections,
//  each pushing into its detail screen.
//

import SwiftUI

struct LivityProfileScreen: View {
    @StateObject private var store = ProfileStore.shared
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LivityTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        subscriptionSection
                        appSection
                        moreSection
                        communitySection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, LivityTheme.horizontalPadding)
                    .padding(.top, 6)
                }
            }
            .navigationDestination(for: LivityProfileRoute.self) { route in
                destination(for: route)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Profile")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LivityTheme.textPrimary)
        }
        .frame(height: 44)
    }

    // MARK: - Sections

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LivityGroupLabel(icon: "creditcard", text: "Subscription")
            LivityGroupedCard {
                LivityListRow(
                    icon: "dollarsign.circle.fill",
                    iconColor: LivityTheme.good,
                    title: "Manage Subscriptions",
                    subtitle: "View and manage your subscriptions",
                    accessory: .chevron
                ) {
                    path.append(LivityProfileRoute.manageSubscriptions)
                }
            }
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LivityGroupLabel(icon: "gearshape", text: "App")
            LivityGroupedCard {
                LivityListRow(
                    icon: "slider.horizontal.3",
                    iconColor: LivityTheme.info,
                    title: "Preferences",
                    subtitle: "Appearance, health, notifications",
                    accessory: .chevron
                ) {
                    path.append(LivityProfileRoute.preferences)
                }
                LivityRowSeparator()
                LivityListRow(
                    icon: "link",
                    iconColor: LivityTheme.info,
                    title: "Integrations",
                    subtitle: "Garmin, Apple Watch",
                    accessory: .newBadge
                ) {
                    path.append(LivityProfileRoute.integrations)
                }
            }
        }
    }

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LivityGroupLabel(icon: "ellipsis.circle", text: "More")
            LivityGroupedCard {
                LivityListRow(
                    icon: "hand.raised.fill",
                    iconColor: LivityTheme.info,
                    title: "Privacy & Data",
                    subtitle: "Consent and legal",
                    accessory: .chevron
                ) {
                    path.append(LivityProfileRoute.privacy)
                }
                LivityRowSeparator()
                LivityListRow(
                    icon: "questionmark.circle.fill",
                    iconColor: LivityTheme.info,
                    title: "Help & Support",
                    subtitle: "Manual, feedback, contact us",
                    accessory: .chevron
                ) {
                    path.append(LivityProfileRoute.help)
                }
                LivityRowSeparator()
                LivityListRow(
                    icon: "person.circle.fill",
                    iconColor: LivityTheme.purple,
                    title: "Account",
                    subtitle: "Manage your account",
                    accessory: .chevron
                ) {
                    path.append(LivityProfileRoute.account)
                }
            }
        }
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LivityGroupLabel(icon: "hand.thumbsup", text: "Community")
            LivityGroupedCard {
                LivityListRow(
                    icon: "hand.thumbsup.fill",
                    iconColor: LivityTheme.info,
                    title: "Vote for Features",
                    subtitle: "Help shape the future of Livity",
                    accessory: .chevron
                ) {
                    path.append(LivityProfileRoute.vote)
                }
            }
        }
    }

    // MARK: - Routes

    @ViewBuilder
    private func destination(for route: LivityProfileRoute) -> some View {
        switch route {
        case .manageSubscriptions:   PaywallSheet()
        case .preferences:           LivityPreferencesHub(path: $path)
        case .integrations:          LivityIntegrationsScreen()
        case .privacy:               LivityPrivacyDataScreen()
        case .help:                  LivityHelpSupportScreen()
        case .account:               LivityAccountScreen()
        case .vote:                  LivityVoteForFeaturesScreen()
        case .uiCustomization:       LivityUICustomizationScreen(path: $path)
        case .healthPreferences:     LivityHealthPreferencesScreen(path: $path)
        case .notifications:         LivityNotificationsPreferencesScreen()
        case .language:              LivityLanguagePickerScreen()
        case .defaultTab:            LivityDefaultTabPickerScreen()
        case .appIcon:               LivityAppIconPickerScreen()
        }
    }
}

// MARK: - Routes

enum LivityProfileRoute: Hashable {
    // Tier 1: Profile root -> …
    case manageSubscriptions
    case preferences
    case integrations
    case privacy
    case help
    case account
    case vote
    // Tier 2: Preferences -> …
    case uiCustomization
    case healthPreferences
    case notifications
    // Tier 3: UI Customization -> …
    case language
    case defaultTab
    case appIcon
}
