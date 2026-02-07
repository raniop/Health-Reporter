//
//  LocalizationManager.swift
//  Health Reporter
//
//  Manages app localization with support for Hebrew and English.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

enum AppLanguage: String, CaseIterable {
    case hebrew = "he"
    case english = "en"

    var displayName: String {
        switch self {
        case .hebrew: return "Hebrew"
        case .english: return "English"
        }
    }

    var isRTL: Bool {
        return self == .hebrew
    }
}

final class LocalizationManager {
    static let shared = LocalizationManager()

    private let languageKey = "AppLanguage"
    private let manualOverrideKey = "AppLanguageManualOverride"
    private var bundle: Bundle?

    /// Returns true if user manually selected a language (not using device default)
    var isManualOverride: Bool {
        return UserDefaults.standard.bool(forKey: manualOverrideKey)
    }

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            loadBundle()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    /// Sets language manually (user override)
    func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(true, forKey: manualOverrideKey)
        currentLanguage = language
        syncLanguageToFirestore()
    }

    /// Resets to automatic (device language)
    func resetToAutomatic() {
        UserDefaults.standard.set(false, forKey: manualOverrideKey)
        UserDefaults.standard.removeObject(forKey: languageKey)
        currentLanguage = Self.detectDeviceLanguage()
        syncLanguageToFirestore()
    }

    /// Syncs the current language to Firestore for localized push notifications
    private func syncLanguageToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        Firestore.firestore().collection("users").document(uid).setData([
            "language": currentLanguage.rawValue
        ], merge: true)
    }

    /// Detects the device's preferred language
    private static func detectDeviceLanguage() -> AppLanguage {
        // Check device's preferred languages
        let preferredLanguages = Locale.preferredLanguages
        for language in preferredLanguages {
            if language.hasPrefix("he") {
                return .hebrew
            } else if language.hasPrefix("en") {
                return .english
            }
        }
        // Default to English if neither Hebrew nor English is found
        return .english
    }

    private init() {
        // Check if user has manually overridden the language
        if UserDefaults.standard.bool(forKey: manualOverrideKey),
           let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            // User manually selected a language - use their choice
            currentLanguage = language
        } else {
            // No manual override - detect from device
            currentLanguage = Self.detectDeviceLanguage()
        }
        loadBundle()
    }

    private func loadBundle() {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            self.bundle = Bundle.main
            return
        }
        self.bundle = bundle
    }

    func localized(_ key: String) -> String {
        return bundle?.localizedString(forKey: key, value: key, table: nil) ?? key
    }

    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, arguments: arguments)
    }

    var semanticContentAttribute: UISemanticContentAttribute {
        return currentLanguage.isRTL ? .forceRightToLeft : .forceLeftToRight
    }

    var textAlignment: NSTextAlignment {
        return currentLanguage.isRTL ? .right : .left
    }

    var naturalTextAlignment: NSTextAlignment {
        return .natural
    }

    var currentLocale: Locale {
        switch currentLanguage {
        case .hebrew: return Locale(identifier: "he_IL")
        case .english: return Locale(identifier: "en_US")
        }
    }
}

// MARK: - String Extension

extension String {
    var localized: String {
        return LocalizationManager.shared.localized(self)
    }

    func localized(_ arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localized(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}
