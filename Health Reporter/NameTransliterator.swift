//
//  NameTransliterator.swift
//  Health Reporter
//
//  Transliterates common Israeli names between Hebrew and English.
//  Used to display the user's first name in the app's current language.
//

import Foundation

struct NameTransliterator {

    // MARK: - English → Hebrew Dictionary

    private static let enToHe: [String: String] = [
        // Common male names
        "rani": "רני",
        "amit": "עמית",
        "yoav": "יואב",
        "omer": "עומר",
        "tomer": "תומר",
        "gal": "גל",
        "itay": "איתי",
        "dan": "דן",
        "tal": "טל",
        "roi": "רועי",
        "lior": "ליאור",
        "adi": "עדי",
        "ori": "אורי",
        "shai": "שי",
        "roni": "רוני",
        "eyal": "אייל",
        "chen": "חן",
        "bar": "בר",
        "nir": "ניר",
        "guy": "גיא",
        "ofir": "אופיר",
        "ophir": "אופיר",
        "alon": "אלון",
        "dor": "דור",
        "rotem": "רותם",
        "yonatan": "יונתן",
        "jonathan": "יונתן",
        "david": "דוד",
        "daniel": "דניאל",
        "michael": "מיכאל",
        "matan": "מתן",
        "elad": "אלעד",
        "assaf": "אסף",
        "ido": "עידו",
        "yuval": "יובל",
        "noam": "נועם",
        "ariel": "אריאל",
        "shachar": "שחר",
        "gilad": "גלעד",
        "liron": "לירון",
        "moshe": "משה",
        "oren": "אורן",
        "nadav": "נדב",
        "ran": "רן",
        "eran": "ערן",
        "amir": "אמיר",
        "ilan": "אילן",
        "yaniv": "יניב",
        "avi": "אבי",
        "ben": "בן",
        "tom": "תום",
        "adam": "אדם",
        "yoni": "יוני",

        // Common female names
        "noa": "נועה",
        "maya": "מאיה",
        "shira": "שירה",
        "yael": "יעל",
        "inbar": "ענבר",
        "sarah": "שרה",
        "tamar": "תמר",
        "avital": "אביטל",
        "eden": "עדן",
        "mor": "מור",
        "lee": "לי",
        "li": "לי",
        "dana": "דנה",
        "michal": "מיכל",
        "hila": "הילה",
        "keren": "קרן",
        "efrat": "אפרת",
        "rachel": "רחל",
        "neta": "נטע",
        "stav": "סתיו",
        "hadar": "הדר",
        "shani": "שני",
        "ronit": "רונית",
        "osnat": "אסנת",
        "merav": "מירב",
        "naama": "נעמה",
        "sapir": "ספיר",
        "gili": "גילי",
        "reut": "רעות",
        "shirly": "שירלי",
        "mika": "מיקה",
    ]

    // MARK: - Hebrew → English (auto-generated reverse map)

    private static let heToEn: [String: String] = {
        Dictionary(enToHe.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
    }()

    // MARK: - Public API

    /// Returns the name transliterated to the app's current language.
    /// - If the app is in Hebrew and the name is in English → returns Hebrew version.
    /// - If the app is in English and the name is in Hebrew → returns English version.
    /// - If no translation is found, returns the original name as-is.
    static func localized(_ name: String) -> String {
        let isAppHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        let nameIsHebrew = name.unicodeScalars.contains { (0x0590...0x05FF).contains($0.value) }

        if isAppHebrew && !nameIsHebrew {
            // App is Hebrew, name is English → translate to Hebrew
            return enToHe[name.lowercased()] ?? name
        } else if !isAppHebrew && nameIsHebrew {
            // App is English, name is Hebrew → translate to English
            return (heToEn[name] ?? name).capitalized
        }
        return name
    }
}
