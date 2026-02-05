//
//  WatchLocalization.swift
//  Health Reporter Watch App
//
//  Simple localization support for Watch App
//

import Foundation

// MARK: - String Extension for Watch Localization

extension String {
    /// Returns localized string using device language
    var localized: String {
        // Get the preferred language from device
        let preferredLanguages = Locale.preferredLanguages
        var languageCode = "en" // default

        for language in preferredLanguages {
            if language.hasPrefix("he") {
                languageCode = "he"
                break
            } else if language.hasPrefix("en") {
                languageCode = "en"
                break
            }
        }

        // Try to load from the correct language bundle
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: self, value: self, table: nil)
        }

        // Fallback to main bundle
        return Bundle.main.localizedString(forKey: self, value: self, table: nil)
    }

    /// Alias for localized (for WatchHealthData static values)
    var localizedWatch: String {
        return self.localized
    }
}
