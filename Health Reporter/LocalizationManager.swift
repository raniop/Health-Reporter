//
//  LocalizationManager.swift
//  Health Reporter
//
//  Manages app localization with support for Hebrew and English.
//

import Foundation
import UIKit

enum AppLanguage: String, CaseIterable {
    case hebrew = "he"
    case english = "en"

    var displayName: String {
        switch self {
        case .hebrew: return "עברית"
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
    private var bundle: Bundle?

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            loadBundle()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            currentLanguage = .hebrew
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
