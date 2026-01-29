//
//  CarAnalysisModel.swift
//  Health Reporter
//
//  מודל נתונים לניתוח רכב מ-Gemini – תואם בדיוק את ה-prompt.
//

import Foundation

/// מודל שמייצג את התשובה המלאה של Gemini
struct CarAnalysisResponse {
    // 1. איזה רכב אני עכשיו?
    var carModel: String
    var carExplanation: String
    var carImageURL: String  // קישור לתמונת הרכב (נטען מ-Wikipedia)
    var carWikiName: String  // שם הרכב באנגלית לחיפוש בוויקיפדיה

    // 2. סקירת ביצועים מלאה
    var engine: String           // מנוע
    var transmission: String     // תיבת הילוכים
    var suspension: String       // מתלים
    var fuelEfficiency: String   // יעילות דלק
    var electronics: String      // אלקטרוניקה

    // 3. מה מגביל את הביצועים
    var bottlenecks: [String]
    var warningSignals: [String]

    // 4. תוכנית אופטימיזציה
    var upgrades: [String]
    var skippedMaintenance: [String]
    var stopImmediately: [String]

    // 5. תוכנית כוונון
    var trainingAdjustments: String
    var recoveryChanges: String
    var habitToAdd: String
    var habitToRemove: String

    // 6. הנחיות פעולה
    var directiveStop: String
    var directiveStart: String
    var directiveWatch: String

    // 7. סיכום
    var summary: String

    // התשובה המקורית (לצורך fallback)
    var rawResponse: String
}

/// Parser שמחלץ את הנתונים מתשובת Gemini
enum CarAnalysisParser {

    static func parse(_ response: String) -> CarAnalysisResponse {
        var result = CarAnalysisResponse(
            carModel: "",
            carExplanation: "",
            carImageURL: "",
            carWikiName: "",
            engine: "",
            transmission: "",
            suspension: "",
            fuelEfficiency: "",
            electronics: "",
            bottlenecks: [],
            warningSignals: [],
            upgrades: [],
            skippedMaintenance: [],
            stopImmediately: [],
            trainingAdjustments: "",
            recoveryChanges: "",
            habitToAdd: "",
            habitToRemove: "",
            directiveStop: "",
            directiveStart: "",
            directiveWatch: "",
            summary: "",
            rawResponse: response
        )

        // 1. חילוץ שם הרכב + שם לוויקי
        result.carModel = extractCarModel(from: response)
        result.carExplanation = extractCarExplanation(from: response)
        result.carWikiName = extractCarWikiName(from: response)

        // 2. סקירת ביצועים - מחפש כותרת בשורה נפרדת
        result.engine = extractSection(from: response, markers: ["\nמנוע\n", "\nENGINE\n", "**מנוע**"])
        result.transmission = extractSection(from: response, markers: ["\nתיבת הילוכים\n", "\nTRANSMISSION\n", "**תיבת הילוכים**"])
        result.suspension = extractSection(from: response, markers: ["\nמתלים\n", "\nSUSPENSION\n", "**מתלים**"])
        result.fuelEfficiency = extractSection(from: response, markers: ["\nיעילות דלק\n", "\nFUEL EFFICIENCY\n", "**יעילות דלק**"])
        result.electronics = extractSection(from: response, markers: ["\nאלקטרוניקה\n", "\nELECTRONICS\n", "**אלקטרוניקה**"])

        // 3. צווארי בקבוק וסימני אזהרה
        result.bottlenecks = extractBottlenecks(from: response)
        result.warningSignals = extractWarningSignals(from: response)

        // 4. תוכנית אופטימיזציה
        result.upgrades = extractListItems(from: response, sectionMarkers: ["UPGRADES", "שדרוגים", "upgrades"])
        result.skippedMaintenance = extractListItems(from: response, sectionMarkers: ["MAINTENANCE", "טיפול אני מדלג", "maintenance"])
        result.stopImmediately = extractListItems(from: response, sectionMarkers: ["STOP IMMEDIATELY", "להפסיק לעשות מיד", "stop doing immediately"])

        // 5. תוכנית כוונון
        result.trainingAdjustments = extractSection(from: response, markers: ["TRAINING ADJUSTMENTS", "התאמות אימון", "**התאמות אימון**", "התאמות אימון:"])
        result.recoveryChanges = extractSection(from: response, markers: ["RECOVERY CHANGES", "שינויים בהתאוששות", "**שינויים בהתאוששות ושינה**", "שינויים בהתאוששות"])
        result.habitToAdd = extractSection(from: response, markers: ["HABIT TO ADD", "הרגל להוסיף", "**הרגל אחד בעל השפעה גבוהה להוסיף**", "הרגל אחד להוסיף:", "הרגל להוסיף:"])
        result.habitToRemove = extractSection(from: response, markers: ["HABIT TO REMOVE", "הרגל להסיר", "**הרגל אחד להסיר**", "הרגל אחד להסיר:", "הרגל להסיר:"])

        // 6. הנחיות פעולה (STOP/START/WATCH)
        let directives = extractDirectives(from: response)
        result.directiveStop = directives.stop
        result.directiveStart = directives.start
        result.directiveWatch = directives.watch

        // 7. סיכום
        result.summary = extractSummary(from: response)

        return result
    }

    // MARK: - Extraction Helpers

    private static func extractCarModel(from text: String) -> String {
        // מילות מפתח שאסור שיהיו שם הרכב
        let blacklist = ["stop", "start", "watch", "מנוע", "תיבת", "מתלים", "יעילות", "אלקטרוניקה", "סיכום", "הנחיות", "סקירת", "חשוב", "כתוב", "car_wiki"]

        // קודם כל - מחפש בסקשן 1 בלבד
        var section1 = ""
        let sectionMarkers = ["1. איזה רכב אני", "איזה רכב אני", "## 1", "WHICH CAR AM I", "הרכב שאני"]
        for marker in sectionMarkers {
            if let sectionStart = text.range(of: marker, options: .caseInsensitive) {
                let after = String(text[sectionStart.upperBound...])
                // מוצא את סוף הסקשן
                let endMarkers = ["2. סקירת", "## 2", "סקירת ביצועים", "PERFORMANCE REVIEW"]
                for endMarker in endMarkers {
                    if let sectionEnd = after.range(of: endMarker, options: .caseInsensitive) {
                        section1 = String(after[..<sectionEnd.lowerBound])
                        break
                    }
                }
                if section1.isEmpty {
                    section1 = String(after.prefix(600))
                }
                break
            }
        }

        print("=== SECTION 1 FOR CAR MODEL: '\(section1.prefix(400))' ===")

        // תבניות לזיהוי שם הרכב
        let searchTexts = section1.isEmpty ? [text] : [section1, text]

        for searchText in searchTexts {
            let patterns = [
                // פורמט חדש - שם רכב בשורה נפרדת אחרי הכותרת
                // "פורשה טייקאן (Porsche Taycan)"
                #"עכשיו\??\s*\n+([^\n\[]+)\s*\("#,
                #"עכשיו\??\s*\n+([א-ת\s]+)\s*\(([A-Za-z\s]+)\)"#,
                // שם רכב באנגלית בסוגריים
                #"\(([A-Z][a-z]+\s+[A-Za-z0-9\s\-]+)\)"#,
                // פורמט "אתה כרגע כמו X:"
                #"אתה כרגע כמו\s+([^:]+):"#,
                #"אתה כרגע\s+([A-Za-z][A-Za-z0-9\s\-]+[A-Za-z0-9])"#,
                #"אתה\s+([A-Za-z][A-Za-z0-9\s\-]+[A-Za-z0-9])"#,
                // פורמט ישן עם markdown
                #"אתה כרגע\s+\*\*([^*]+)\*\*"#,
                #"אתה כרגע כמו\s+\*\*([^*]+)\*\*"#,
                #"\*\*([^*\n]{4,50})\*\*"#,
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: searchText, options: [], range: NSRange(searchText.startIndex..., in: searchText)),
                   let range = Range(match.range(at: 1), in: searchText) {
                    var carName = String(searchText[range])
                        .replacingOccurrences(of: "**", with: "")
                        .replacingOccurrences(of: "[CAR_WIKI:", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    // הסרת נקודה או נקודתיים בסוף
                    while carName.hasSuffix(".") || carName.hasSuffix(":") {
                        carName = String(carName.dropLast()).trimmingCharacters(in: .whitespaces)
                    }

                    // סינון מילות מפתח
                    let lower = carName.lowercased()
                    let isBlacklisted = blacklist.contains { lower.hasPrefix($0) || lower == $0 }

                    if !isBlacklisted && !carName.isEmpty && carName.count > 2 && carName.count < 60 {
                        print("=== EXTRACTED CAR MODEL: '\(carName)' (pattern: \(pattern)) ===")
                        return carName
                    }
                }
            }
        }

        // Fallback: try to find car name from CAR_WIKI tag
        let wikiName = extractCarWikiName(from: text)
        if !wikiName.isEmpty {
            print("=== EXTRACTED CAR MODEL FROM WIKI NAME: '\(wikiName)' ===")
            return wikiName
        }

        print("=== CAR MODEL: COULD NOT EXTRACT ===")
        return "רכב לא מזוהה"
    }

    private static func extractCarExplanation(from text: String) -> String {
        // קודם כל: לוקח רק את סקשן 1
        var section1 = ""
        let startMarkers = ["1. איזה רכב אני", "איזה רכב אני", "## 1"]
        for startMarker in startMarkers {
            if let sectionStart = text.range(of: startMarker, options: .caseInsensitive) {
                let after = String(text[sectionStart.upperBound...])
                let endMarkers = ["2. סקירת", "## 2", "## 3", "סקירת ביצועים מלאה", "מנוע\n"]
                var endIdx = after.endIndex
                for endMarker in endMarkers {
                    if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx {
                        endIdx = r.lowerBound
                    }
                }
                section1 = String(after[..<endIdx])
                break
            }
        }

        if section1.isEmpty { return "" }

        // מחפש את ההסבר - הטקסט שמתחיל ב"אתה כרגע כמו"
        var explanation = ""

        // מחפש את המשפט שמתחיל ב"אתה כרגע כמו"
        if let explStart = section1.range(of: "אתה כרגע כמו", options: .caseInsensitive) {
            // לוקח מכאן עד סוף הסקשן
            explanation = String(section1[explStart.lowerBound...])
        } else if let explStart = section1.range(of: "אתה כרגע", options: .caseInsensitive) {
            explanation = String(section1[explStart.lowerBound...])
        } else {
            // Fallback - לוקח הכל אחרי שורת שם הרכב
            let lines = section1.components(separatedBy: "\n")
            var foundCarName = false
            var explanationLines: [String] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                if trimmed.contains("[CAR_WIKI") { continue }
                if !foundCarName && (trimmed.contains("(") || trimmed.first?.isLetter == true) {
                    foundCarName = true
                    continue
                }
                if foundCarName {
                    explanationLines.append(trimmed)
                }
            }
            explanation = explanationLines.joined(separator: " ")
        }

        // ניקוי
        explanation = explanation
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // הסרת tags
        explanation = removeImageURL(from: explanation)

        // הסרת שאריות מכותרת הסקשן (כמו "עכשיו?", "?", סימני שאלה בודדים)
        let headerRemnants = ["עכשיו?", "עכשיו", "?"]
        for remnant in headerRemnants {
            if explanation.hasPrefix(remnant) {
                explanation = String(explanation.dropFirst(remnant.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // הסרת "אתה כרגע ." או "אתה כרגע" מתחילת ההסבר (שארית מהמשפט "אתה כרגע **שם הרכב**.")
        if let regex = try? NSRegularExpression(pattern: #"^אתה כרגע\s*\.?\s*"#, options: []) {
            explanation = regex.stringByReplacingMatches(in: explanation, options: [], range: NSRange(explanation.startIndex..., in: explanation), withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return explanation
    }

    /// מסיר קישורי תמונה ותגי metadata מהטקסט
    private static func removeImageURL(from text: String) -> String {
        var result = text
        // הסרת פורמטים שונים של URL ותגיות
        let patterns = [
            #"\[CAR_IMAGE_URL:\s*https?://[^\]\s]+\]"#,
            #"CAR_IMAGE_URL:\s*https?://[^\s\]\n]+"#,
            #"\[CAR_WIKI:\s*[^\]]+\]"#,
            #"CAR_WIKI:\s*[^\n]+"#,
            #"https://upload\.wikimedia\.org/wikipedia/commons/[^\s\]\n]+"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        // ניקוי רווחים כפולים
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractCarWikiName(from text: String) -> String {
        // מחפש שם הרכב באנגלית בפורמט [CAR_WIKI: ...]
        let patterns = [
            #"\[CAR_WIKI:\s*([^\]\n]+)\]"#,
            #"CAR_WIKI:\s*([^\]\n]+)"#,
            #"\[CAR_IMAGE_URL:\s*([^\]\n]+)\]"#,  // backward compat
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty && !name.hasPrefix("http") {
                    print("=== EXTRACTED CAR WIKI NAME: \(name) ===")
                    return name
                }
            }
        }

        // Fallback: try to extract English name from car model
        let engPatterns = [
            #"\(([A-Za-z][A-Za-z0-9\s\-\.]+)\)"#,  // text in parentheses like (Subaru Forester)
            #"([A-Z][a-z]+(?:\s+[A-Za-z0-9\-]+)+)"#  // consecutive English words like Subaru Forester
        ]

        for pattern in engPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if name.count >= 5 && name.count < 50 {
                    print("=== EXTRACTED CAR NAME (fallback): \(name) ===")
                    return name
                }
            }
        }

        print("=== NO CAR WIKI NAME FOUND ===")
        return ""
    }

    private static func extractSection(from text: String, markers: [String]) -> String {
        for marker in markers {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                let after = String(text[range.upperBound...])
                // מוצא את סוף הסעיף (עד הסעיף הבא או שורה ריקה כפולה)
                // תומך גם בפורמט markdown ישן וגם בפורמט ALL CAPS חדש
                let endMarkers = [
                    // פורמט חדש - ALL CAPS
                    "\nמנוע", "\nתיבת הילוכים", "\nמתלים", "\nיעילות דלק", "\nאלקטרוניקה",
                    "\nENGINE", "\nTRANSMISSION", "\nSUSPENSION", "\nFUEL", "\nELECTRONICS",
                    "\nהתאמות אימון", "\nשינויים בהתאוששות", "\nהרגל אחד", "\nהרגל להוסיף", "\nהרגל להסיר",
                    // פורמט ישן - markdown
                    "**מנוע**", "**תיבת הילוכים**", "**מתלים**", "**יעילות דלק**", "**אלקטרוניקה**",
                    "**התאמות אימון**", "**שינויים בהתאוששות**", "**הרגל אחד בעל השפעה**", "**הרגל אחד להסיר**",
                    "הרגל אחד להסיר:", "הרגל להסיר:", "הרגל אחד להוסיף:",
                    "## ", "---", "\n\n\n", "\n\n"
                ]
                var endIdx = after.endIndex
                for endMarker in endMarkers {
                    if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx && r.lowerBound != after.startIndex {
                        endIdx = r.lowerBound
                    }
                }
                var content = String(after[..<endIdx])
                // הסרת הסימון הראשוני אם יש
                if let colonRange = content.range(of: ")") ?? content.range(of: ":") {
                    content = String(content[colonRange.upperBound...])
                }
                return content
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private static func extractBottlenecks(from text: String) -> [String] {
        let markers = ["3. מה מגביל", "מה מגביל את הביצועים", "צווארי בקבוק", "bottlenecks", "צוואר בקבוק"]
        return extractListItems(from: text, sectionMarkers: markers)
    }

    private static func extractWarningSignals(from text: String) -> [String] {
        let markers = ["סימן אזהרה", "סימני אזהרה", "warning signs", "אזהרה מוקדם"]
        return extractListItems(from: text, sectionMarkers: markers)
    }

    private static func extractListItems(from text: String, sectionMarkers: [String]) -> [String] {
        var items: [String] = []

        for marker in sectionMarkers {
            guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }

            let after = String(text[range.upperBound...])
            // מוצא את סוף הסעיף
            let endMarkers = ["## ", "---", "\n\n\n", "**", "תוכנית"]
            var endIdx = after.endIndex
            for endMarker in endMarkers {
                if let r = after.range(of: endMarker), r.lowerBound < endIdx && r.lowerBound != after.startIndex {
                    endIdx = r.lowerBound
                }
            }

            let section = String(after[..<endIdx])
            let lines = section.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // בודק אם זה פריט ברשימה
                if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") ||
                   trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil {
                    var item = trimmed
                    // הסרת הסימון
                    item = item.replacingOccurrences(of: #"^[-•*]\s*"#, with: "", options: .regularExpression)
                    item = item.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                    item = item.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                    if !item.isEmpty && item.count > 5 {
                        items.append(item)
                    }
                }
            }

            if !items.isEmpty { break }
        }

        return items
    }

    private static func extractDirectives(from text: String) -> (stop: String, start: String, watch: String) {
        var stop = ""
        var start = ""
        var watch = ""

        // STOP - תומך בפורמט ALL CAPS חדש וגם markdown ישן
        let stopPatterns = [
            #"STOP\s*\n+([^\n]+)"#,           // ALL CAPS על שורה נפרדת
            #"STOP:\s*([^\n]+)"#,              // STOP: בשורה אחת
            #"\*\*STOP:\*\*\s*([^\n]+)"#,      // markdown
            #"עצור\s*\n+([^\n]+)"#,            // עברית
            #"עצור:\s*([^\n]+)"#,
        ]
        for pattern in stopPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                stop = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !stop.isEmpty { break }
            }
        }

        // START - תומך בפורמט ALL CAPS חדש וגם markdown ישן
        let startPatterns = [
            #"START\s*\n+([^\n]+)"#,           // ALL CAPS על שורה נפרדת
            #"START:\s*([^\n]+)"#,              // START: בשורה אחת
            #"\*\*START:\*\*\s*([^\n]+)"#,      // markdown
            #"התחל\s*\n+([^\n]+)"#,             // עברית
            #"התחל:\s*([^\n]+)"#,
        ]
        for pattern in startPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                start = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !start.isEmpty { break }
            }
        }

        // WATCH - תומך בפורמט ALL CAPS חדש וגם markdown ישן
        let watchPatterns = [
            #"WATCH\s*\n+([^\n]+)"#,           // ALL CAPS על שורה נפרדת
            #"WATCH:\s*([^\n]+)"#,              // WATCH: בשורה אחת
            #"\*\*WATCH:\*\*\s*([^\n]+)"#,      // markdown
            #"עקוב\s*\n+([^\n]+)"#,             // עברית
            #"עקוב:\s*([^\n]+)"#,
        ]
        for pattern in watchPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                watch = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !watch.isEmpty { break }
            }
        }

        return (stop, start, watch)
    }

    private static func extractSummary(from text: String) -> String {
        // תומך בפורמט ALL CAPS חדש וגם בפורמט ישן
        let markers = [
            "SUMMARY", "סיכום", "## 7. סיכום", "**סיכום**", "סיכום:",
            "אם הרכב הזה ימשיך", "BOTTOM LINE"
        ]

        for marker in markers {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                let after = String(text[range.upperBound...])
                // לוקח עד סוף הטקסט או עד סימן סיום
                let endMarkers = ["---", "###", "\n\n\n"]
                var endIdx = after.endIndex
                for endMarker in endMarkers {
                    if let r = after.range(of: endMarker), r.lowerBound < endIdx {
                        endIdx = r.lowerBound
                    }
                }
                let summary = String(after[..<endIdx])
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !summary.isEmpty {
                    return summary
                }
            }
        }
        return ""
    }
}
