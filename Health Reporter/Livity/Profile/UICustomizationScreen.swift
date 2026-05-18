//
//  UICustomizationScreen.swift
//  Health Reporter
//
//  UI Customization screen: Appearance (Light/Dark/System cards) + Units,
//  Default Tab, App Icon, Language rows.
//

import SwiftUI

struct LivityUICustomizationScreen: View {
    @Binding var path: NavigationPath
    @StateObject private var store = ProfileStore.shared
    @State private var showUnits = false

    var body: some View {
        LivityScreenChrome(title: "UI Customization") {
            VStack(alignment: .leading, spacing: 16) {
                // Appearance
                VStack(alignment: .leading, spacing: 0) {
                    LivityGroupLabel(icon: "paintbrush.fill", text: "Appearance")
                    LivityGroupedCard {
                        LivityListRow(
                            icon: "sun.max.fill",
                            iconColor: LivityTheme.caution,
                            title: "Light",
                            subtitle: "Always use light mode",
                            accessory: .checkmark(store.appearance == .light)
                        ) { store.appearance = .light }
                        LivityRowSeparator()
                        LivityListRow(
                            icon: "moon.fill",
                            iconColor: LivityTheme.info,
                            title: "Dark",
                            subtitle: "Always use dark mode",
                            accessory: .checkmark(store.appearance == .dark)
                        ) { store.appearance = .dark }
                        LivityRowSeparator()
                        LivityListRow(
                            icon: "circle.righthalf.filled",
                            iconColor: LivityTheme.good,
                            title: "System",
                            subtitle: "Match system settings",
                            accessory: .checkmark(store.appearance == .system)
                        ) { store.appearance = .system }
                    }
                }

                // Preferences group
                VStack(alignment: .leading, spacing: 0) {
                    LivityGroupLabel(icon: "slider.horizontal.3", text: "Preferences")
                    LivityGroupedCard {
                        LivityListRow(
                            icon: "ruler.fill",
                            iconColor: LivityTheme.caution,
                            title: "Units",
                            subtitle: "Choose your preferred measurement units",
                            accessory: .chevron
                        ) { showUnits = true }

                        LivityRowSeparator()

                        LivityListRow(
                            icon: "square.grid.2x2.fill",
                            iconColor: LivityTheme.info,
                            title: "Default Tab",
                            subtitle: "Choose which tab to show when opening the app",
                            accessory: .chevron
                        ) { path.append(LivityProfileRoute.defaultTab) }

                        LivityRowSeparator()

                        LivityListRow(
                            icon: "app.fill",
                            iconColor: LivityTheme.caution,
                            title: "App Icon",
                            subtitle: "Customize your app's home screen icon",
                            accessory: .chevron
                        ) { path.append(LivityProfileRoute.appIcon) }

                        LivityRowSeparator()

                        LivityListRow(
                            icon: "globe",
                            iconColor: LivityTheme.info,
                            title: "Language",
                            subtitle: "Change app language",
                            accessory: .chevron
                        ) { path.append(LivityProfileRoute.language) }
                    }
                }
            }
        }
        .sheet(isPresented: $showUnits) {
            LivityUnitPreferencesSheet()
        }
    }
}

// MARK: - Unit Preferences sheet

struct LivityUnitPreferencesSheet: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivitySheetChrome(title: "Unit Preferences") {
            VStack(alignment: .leading, spacing: 14) {
                row("Distance",
                    options: LivityDistanceUnit.allCases,
                    selection: Binding(get: { store.distance }, set: { store.distance = $0 }),
                    label: { $0.label })

                divider

                row("Temperature",
                    options: LivityTempUnit.allCases,
                    selection: Binding(get: { store.temperature }, set: { store.temperature = $0 }),
                    label: { $0.label })

                divider

                row("Energy",
                    options: LivityEnergyUnit.allCases,
                    selection: Binding(get: { store.energy }, set: { store.energy = $0 }),
                    label: { $0.label })

                divider

                row("Weight",
                    options: LivityWeightUnit.allCases,
                    selection: Binding(get: { store.weight }, set: { store.weight = $0 }),
                    label: { $0.label })

                divider

                row("Water",
                    options: LivityWaterUnit.allCases,
                    selection: Binding(get: { store.water }, set: { store.water = $0 }),
                    label: { $0.label })
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                    .fill(LivityTheme.cardFill)
            )
        }
    }

    private var divider: some View {
        Rectangle().fill(LivityTheme.separator.opacity(0.5)).frame(height: 0.5).padding(.vertical, 4)
    }

    @ViewBuilder
    private func row<T: Hashable>(
        _ title: String,
        options: [T],
        selection: Binding<T>,
        label: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LivityTheme.textPrimary)

            HStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button { selection.wrappedValue = option } label: {
                        Text(label(option))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                selection.wrappedValue == option ? .white : LivityTheme.textPrimary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    selection.wrappedValue == option
                                    ? LivityTheme.info
                                    : LivityTheme.chipFill
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Default tab picker

struct LivityDefaultTabPickerScreen: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivityScreenChrome(title: "Default Tab") {
            LivityGroupedCard {
                ForEach(Array(LivityDefaultTab.allCases.enumerated()), id: \.element.id) { index, tab in
                    LivityListRow(
                        icon: tab.icon,
                        iconColor: LivityTheme.info,
                        title: tab.label,
                        accessory: .checkmark(store.defaultTab == tab)
                    ) { store.defaultTab = tab }
                    if index < LivityDefaultTab.allCases.count - 1 {
                        LivityRowSeparator()
                    }
                }
            }
        }
    }
}

// MARK: - App icon picker

struct LivityAppIconPickerScreen: View {
    @StateObject private var store = ProfileStore.shared

    var body: some View {
        LivityScreenChrome(title: "App Icon") {
            VStack(alignment: .leading, spacing: 16) {
                LivityInfoBanner(
                    icon: "info.circle.fill",
                    iconColor: LivityTheme.info,
                    title: "Home-screen icon",
                    body: "Pick an alternate icon to personalize your home screen."
                )

                LivityGroupedCard {
                    ForEach(Array(LivityAppIcon.allCases.enumerated()), id: \.element.id) { index, icon in
                        LivityListRow(
                            icon: "app.fill",
                            iconColor: LivityTheme.caution,
                            title: icon.label,
                            accessory: .checkmark(store.appIcon == icon)
                        ) {
                            store.appIcon = icon
                            applyIcon(icon)
                        }
                        if index < LivityAppIcon.allCases.count - 1 {
                            LivityRowSeparator()
                        }
                    }
                }
            }
        }
    }

    private func applyIcon(_ icon: LivityAppIcon) {
        UIApplication.shared.setAlternateIconName(icon.alternateName)
    }
}

// MARK: - Language picker

struct LivityLanguagePickerScreen: View {
    @StateObject private var store = ProfileStore.shared

    private let suggested: [(code: String, title: String, subtitle: String)] = [
        ("en", "English", "Default")
    ]

    private let others: [(code: String, title: String, subtitle: String)] = [
        ("ar",       "العربية",           "Arabic"),
        ("zh-Hans",  "简体中文",           "Chinese, Simplified"),
        ("zh-Hant",  "繁體中文",           "Chinese, Traditional"),
        ("cs",       "Čeština",            "Czech"),
        ("da",       "Dansk",              "Danish"),
        ("nl",       "Nederlands",         "Dutch"),
        ("fi",       "Suomi",              "Finnish"),
        ("fr",       "Français",           "French"),
        ("fr-CA",    "Français (Canada)",  "French (Canada)"),
        ("de",       "Deutsch",            "German"),
        ("he",       "עברית",              "Hebrew"),
        ("hi",       "हिन्दी",               "Hindi"),
        ("hu",       "Magyar",             "Hungarian"),
        ("id",       "Bahasa Indonesia",   "Indonesian"),
        ("it",       "Italiano",           "Italian"),
        ("ja",       "日本語",              "Japanese"),
        ("ko",       "한국어",              "Korean"),
        ("no",       "Norsk",              "Norwegian"),
        ("pl",       "Polski",             "Polish"),
        ("pt-BR",    "Português (Brasil)", "Portuguese (Brazil)"),
        ("pt-PT",    "Português",          "Portuguese (Portugal)"),
        ("ro",       "Română",             "Romanian"),
        ("ru",       "Русский",            "Russian"),
        ("es",       "Español",            "Spanish"),
        ("sv",       "Svenska",            "Swedish"),
        ("th",       "ไทย",                "Thai"),
        ("tr",       "Türkçe",             "Turkish"),
        ("uk",       "Українська",         "Ukrainian"),
        ("vi",       "Tiếng Việt",         "Vietnamese")
    ]

    var body: some View {
        LivityScreenChrome(title: "Language") {
            VStack(alignment: .leading, spacing: 12) {
                LivityGroupLabel(text: "Suggested Languages")
                LivityGroupedCard {
                    ForEach(Array(suggested.enumerated()), id: \.offset) { idx, item in
                        LivityListRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            accessory: .checkmark(
                                (store.languageCode ?? "en") == item.code
                            )
                        ) {
                            store.languageCode = item.code
                        }
                        if idx < suggested.count - 1 { LivityRowSeparator() }
                    }
                }

                Text("Livity will use the first language that it supports from Language & Region settings. You can select a different language for Livity to use if you prefer.")
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 6)

                LivityGroupLabel(text: "Other Languages")
                LivityGroupedCard {
                    ForEach(Array(others.enumerated()), id: \.offset) { idx, item in
                        LivityListRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            accessory: .checkmark(store.languageCode == item.code)
                        ) {
                            store.languageCode = item.code
                        }
                        if idx < others.count - 1 { LivityRowSeparator() }
                    }
                }
            }
        }
    }
}
