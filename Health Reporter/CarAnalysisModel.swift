//
//  CarAnalysisModel.swift
//  Health Reporter
//
//  מודל נתונים לניתוח רכב מ-Gemini – תואם בדיוק את ה-prompt.
//

import Foundation

// MARK: - JSON Response Models (Codable)

/// מודל JSON מובנה לתשובת Gemini
struct CarAnalysisJSONResponse: Codable {
    let carIdentity: CarIdentityJSON
    let performanceReview: PerformanceReviewJSON
    let bottlenecks: [String]
    let optimizationPlan: OptimizationPlanJSON
    let tuneUpPlan: TuneUpPlanJSON
    let directives: DirectivesJSON
    let forecast: String
    let supplements: [SupplementJSON]
}

struct CarIdentityJSON: Codable {
    let model: String
    let wikiName: String
    let explanation: String
}

struct PerformanceReviewJSON: Codable {
    let engine: String
    let transmission: String
    let suspension: String
    let fuelEfficiency: String
    let electronics: String
}

struct OptimizationPlanJSON: Codable {
    let upgrades: [String]
    let skippedMaintenance: [String]
    let stopImmediately: [String]
}

struct TuneUpPlanJSON: Codable {
    let trainingAdjustments: String
    let recoveryChanges: String
    let habitToAdd: String
    let habitToRemove: String
}

struct DirectivesJSON: Codable {
    let stop: String
    let start: String
    let watch: String
}

struct SupplementJSON: Codable {
    let name: String
    let englishName: String?
    let dosage: String
    let reason: String
    let category: String
}

// MARK: - Supplement Recommendation Model

/// מודל המלצת תוסף תזונה
struct SupplementRecommendation {
    let name: String        // שם התוסף (עברית + אנגלית)
    let dosage: String      // מינון ותזמון
    let reason: String      // סיבה ספציפית מהנתונים
    let category: SupplementCategory
}

/// קטגוריות תוספי תזונה
enum SupplementCategory: String, CaseIterable {
    case performance = "ביצועים ואימון"
    case recovery = "התאוששות ודלקת"
    case sleep = "שינה והתאוששות"
    case general = "בריאות כללית"
}

// MARK: - Car Analysis Response

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

    // 8. תוספי תזונה מומלצים
    var supplements: [SupplementRecommendation]

    // התשובה המקורית (לצורך fallback)
    var rawResponse: String
}

/// Parser שמחלץ את הנתונים מתשובת Gemini
enum CarAnalysisParser {

    // MARK: - JSON Parsing (Primary)

    /// מנסה לפרסר את התשובה כ-JSON מובנה
    static func parseJSON(_ response: String) -> CarAnalysisResponse? {
        // ניקוי - הסרת ```json ו-``` אם קיימים
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Decode
        guard let data = cleaned.data(using: .utf8) else {
            print("=== JSON PARSE: Failed to convert to data ===")
            return nil
        }

        do {
            let json = try JSONDecoder().decode(CarAnalysisJSONResponse.self, from: data)
            print("=== JSON PARSE: Successfully decoded JSON response ===")
            return convertJSONToResponse(json, rawResponse: response)
        } catch {
            print("=== JSON PARSE ERROR: \(error) ===")
            return nil
        }
    }

    /// ממיר את ה-JSON המפורסר למודל CarAnalysisResponse
    private static func convertJSONToResponse(_ json: CarAnalysisJSONResponse, rawResponse: String) -> CarAnalysisResponse {
        // המרת supplements
        let supplements = json.supplements.map { s in
            let category: SupplementCategory
            switch s.category.lowercased() {
            case "sleep": category = .sleep
            case "performance": category = .performance
            case "recovery": category = .recovery
            default: category = .general
            }
            return SupplementRecommendation(
                name: s.name,
                dosage: s.dosage,
                reason: s.reason,
                category: category
            )
        }

        return CarAnalysisResponse(
            carModel: json.carIdentity.model,
            carExplanation: json.carIdentity.explanation,
            carImageURL: "",
            carWikiName: json.carIdentity.wikiName,
            engine: json.performanceReview.engine,
            transmission: json.performanceReview.transmission,
            suspension: json.performanceReview.suspension,
            fuelEfficiency: json.performanceReview.fuelEfficiency,
            electronics: json.performanceReview.electronics,
            bottlenecks: json.bottlenecks,
            warningSignals: [],
            upgrades: json.optimizationPlan.upgrades,
            skippedMaintenance: json.optimizationPlan.skippedMaintenance,
            stopImmediately: json.optimizationPlan.stopImmediately,
            trainingAdjustments: json.tuneUpPlan.trainingAdjustments,
            recoveryChanges: json.tuneUpPlan.recoveryChanges,
            habitToAdd: json.tuneUpPlan.habitToAdd,
            habitToRemove: json.tuneUpPlan.habitToRemove,
            directiveStop: json.directives.stop,
            directiveStart: json.directives.start,
            directiveWatch: json.directives.watch,
            summary: json.forecast,
            supplements: supplements,
            rawResponse: rawResponse
        )
    }

    // MARK: - Main Parse Function

    static func parse(_ response: String) -> CarAnalysisResponse {
        // נסיון ראשון: JSON מובנה
        if let jsonResult = parseJSON(response) {
            print("=== PARSER: Used JSON mode successfully ===")
            return jsonResult
        }

        print("=== PARSER: JSON failed, falling back to regex-based parsing ===")
        return parseLegacy(response)
    }

    // MARK: - Legacy Regex-Based Parsing (Fallback)

    private static func parseLegacy(_ response: String) -> CarAnalysisResponse {
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
            supplements: [],
            rawResponse: response
        )

        // 1. חילוץ שם הרכב + שם לוויקי
        result.carModel = extractCarModel(from: response)
        result.carExplanation = extractCarExplanation(from: response)
        result.carWikiName = extractCarWikiName(from: response)

        // 2. סקירת ביצועים - מחפש כותרת בשורה נפרדת או בפורמט markdown
        // Note: The section content starts AFTER the marker line, not at a colon/parenthesis
        result.engine = extractPerformanceSection(from: response, sectionName: "מנוע", nextSections: ["תיבת הילוכים", "TRANSMISSION"])
        result.transmission = extractPerformanceSection(from: response, sectionName: "תיבת הילוכים", nextSections: ["מתלים", "SUSPENSION"])
        result.suspension = extractPerformanceSection(from: response, sectionName: "מתלים", nextSections: ["יעילות דלק", "FUEL"])
        result.fuelEfficiency = extractPerformanceSection(from: response, sectionName: "יעילות דלק", nextSections: ["אלקטרוניקה", "ELECTRONICS"])
        result.electronics = extractPerformanceSection(from: response, sectionName: "אלקטרוניקה", nextSections: ["3.", "מה מגביל", "BOTTLENECK"])

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

        // 8. תוספי תזונה מומלצים
        result.supplements = extractSupplements(from: response)

        return result
    }

    // MARK: - Extraction Helpers

    private static func extractCarModel(from text: String) -> String {
        // מילות מפתח שאסור שיהיו שם הרכב
        let blacklist = ["stop", "start", "watch", "מנוע", "תיבת", "מתלים", "יעילות", "אלקטרוניקה", "סיכום", "הנחיות", "סקירת", "חשוב", "כתוב", "car_wiki", "generation", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth", "model", "version", "type", "series"]

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

        // קודם כל - מחפש שם רכב באנגלית מה-CAR_WIKI tag (הכי אמין!)
        // מחפש ידנית כדי לא לקרוא לפונקציה אחרת
        let wikiPatterns = [
            #"\[CAR_WIKI:\s*([^\]\n]+)\]"#,
            #"CAR_WIKI:\s*([^\]\n]+)"#,
        ]
        for pattern in wikiPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                var wikiCarName = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                // מסיר סוגריים עם generation וכו'
                if let parenStart = wikiCarName.firstIndex(of: "(") {
                    wikiCarName = String(wikiCarName[..<parenStart]).trimmingCharacters(in: .whitespaces)
                }
                if !wikiCarName.isEmpty && wikiCarName.count > 3 && !wikiCarName.hasPrefix("http") {
                    print("=== EXTRACTED CAR MODEL (from WIKI tag): '\(wikiCarName)' ===")
                    return wikiCarName
                }
            }
        }

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
                        .replacingOccurrences(of: "[CAR_WIKI]", with: "")
                        .replacingOccurrences(of: "CAR_WIKI:", with: "")
                        .replacingOccurrences(of: "CAR_WIKI", with: "")
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    // הסרת נקודה, נקודתיים או סוגר בסוף
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
        // נסיון 1: מחפש סקשן 1 מפורש
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

        // נסיון 2: פורמט חדש - הטקסט מתחיל עם שם רכב, אחריו CAR_WIKI, ואז ההסבר
        if section1.isEmpty {
            // מחפש את הטקסט שאחרי שורת CAR_WIKI עד "סקירת ביצועים"
            if let wikiEnd = text.range(of: "[CAR_WIKI:", options: .caseInsensitive) {
                // מוצא את סוף שורת ה-CAR_WIKI
                let afterWiki = String(text[wikiEnd.upperBound...])
                if let closeBracket = afterWiki.firstIndex(of: "]") {
                    let afterTag = String(afterWiki[afterWiki.index(after: closeBracket)...])
                    // מוצא את סוף הסקשן
                    let endMarkers = ["סקירת ביצועים", "מנוע\n", "2.", "## 2"]
                    var endIdx = afterTag.endIndex
                    for endMarker in endMarkers {
                        if let r = afterTag.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx {
                            endIdx = r.lowerBound
                        }
                    }
                    section1 = String(afterTag[..<endIdx])
                }
            }
        }

        // נסיון 3: לוקח את 2-3 השורות הראשונות אחרי שורת השם
        if section1.isEmpty || section1.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
            let lines = text.components(separatedBy: "\n")
            var explanationLines: [String] = []
            var skipCount = 0
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                // מדלג על שורת השם ושורת CAR_WIKI
                if trimmed.contains("[CAR_WIKI") || trimmed.contains("CAR_WIKI:") {
                    skipCount += 1
                    continue
                }
                if skipCount == 0 && (trimmed.count < 50 || !trimmed.contains(" ")) {
                    // זו כנראה שורת שם הרכב
                    skipCount += 1
                    continue
                }
                // עוצר כשמגיעים לסקירת ביצועים
                if trimmed.contains("סקירת ביצועים") || trimmed.hasPrefix("מנוע") {
                    break
                }
                if skipCount > 0 {
                    explanationLines.append(trimmed)
                    if explanationLines.count >= 3 { break }
                }
            }
            if !explanationLines.isEmpty {
                section1 = explanationLines.joined(separator: " ")
            }
        }

        var explanation = section1

        // מחפש את המשפט שמתחיל ב"אתה כרגע כמו" אם קיים
        if let explStart = explanation.range(of: "אתה כרגע כמו", options: .caseInsensitive) {
            explanation = String(explanation[explStart.lowerBound...])
        } else if let explStart = explanation.range(of: "אתה כרגע", options: .caseInsensitive) {
            explanation = String(explanation[explStart.lowerBound...])
        }

        // ניקוי
        explanation = explanation
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "[CAR_WIKI:", with: "")
            .replacingOccurrences(of: "[CAR_WIKI]", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // הסרת שאריות מכותרת הסקשן
        let headerRemnants = ["עכשיו?", "עכשיו", "?"]
        for remnant in headerRemnants {
            if explanation.hasPrefix(remnant) {
                explanation = String(explanation.dropFirst(remnant.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // הסרת tags אחרים (URL וכו')
        explanation = removeImageURL(from: explanation)

        print("=== EXTRACTED CAR EXPLANATION: '\(explanation.prefix(150))...' ===")
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
                var name = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)

                // מסיר סוגריים עם מידע על דור/גרסה - לדוגמה "(eighth generation)"
                if let parenStart = name.firstIndex(of: "(") {
                    name = String(name[..<parenStart]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

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

    /// Extracts performance section content (מנוע, תיבת הילוכים, etc.)
    /// The section name appears on its own line, and content follows on the NEXT line(s)
    private static func extractPerformanceSection(from text: String, sectionName: String, nextSections: [String]) -> String {
        // Find the section header - it can be on its own line or with ** markers
        let patterns = [
            // Header on its own line (new format)
            "(?:^|\\n)\\s*\(sectionName)\\s*\\n",
            // Header with ** markers (old format)
            "\\*\\*\(sectionName)\\*\\*",
            // Header followed by colon
            "\(sectionName):",
            "\(sectionName) \\("
        ]

        var startIdx: String.Index? = nil
        var afterHeader = ""

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                startIdx = range.upperBound
                afterHeader = String(text[range.upperBound...])
                break
            }
        }

        // Fallback: simple string search
        if startIdx == nil {
            if let range = text.range(of: sectionName + "\n", options: .caseInsensitive) {
                afterHeader = String(text[range.upperBound...])
            } else if let range = text.range(of: sectionName, options: .caseInsensitive) {
                // Skip to the end of the line containing the section name
                let remaining = String(text[range.upperBound...])
                if let newlineIdx = remaining.firstIndex(of: "\n") {
                    afterHeader = String(remaining[remaining.index(after: newlineIdx)...])
                } else {
                    afterHeader = remaining
                }
            }
        }

        if afterHeader.isEmpty {
            return ""
        }

        // Find where the next section starts
        var endIdx = afterHeader.endIndex

        // Check for next sections
        for nextSection in nextSections {
            // Look for section header on its own line
            let nextPatterns = [
                "(?:^|\\n)\\s*\(nextSection)\\s*\\n",
                "\\*\\*\(nextSection)\\*\\*",
                "\(nextSection):"
            ]

            for pattern in nextPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: afterHeader, options: [], range: NSRange(afterHeader.startIndex..., in: afterHeader)),
                   let range = Range(match.range, in: afterHeader),
                   range.lowerBound < endIdx {
                    endIdx = range.lowerBound
                }
            }

            // Simple search fallback
            if let r = afterHeader.range(of: "\n" + nextSection, options: .caseInsensitive), r.lowerBound < endIdx {
                endIdx = r.lowerBound
            }
        }

        // Also check for section numbers and other markers
        let genericEndMarkers = ["\n3.", "\n4.", "\n5.", "\n6.", "\n7.", "## ", "---", "\n\n\n"]
        for endMarker in genericEndMarkers {
            if let r = afterHeader.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx && r.lowerBound != afterHeader.startIndex {
                endIdx = r.lowerBound
            }
        }

        var content = String(afterHeader[..<endIdx])

        // Clean up the content
        content = content
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading punctuation that might be left over from header
        while content.hasPrefix(")") || content.hasPrefix(":") || content.hasPrefix("(") {
            content = String(content.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        print("=== EXTRACTED \(sectionName): '\(content.prefix(100))...' ===")
        return content
    }

    private static func extractSection(from text: String, markers: [String]) -> String {
        for marker in markers {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                let after = String(text[range.upperBound...])
                // מוצא את סוף הסעיף (עד הסעיף הבא או שורה ריקה כפולה)
                // תומך גם בפורמט markdown ישן וגם בפורמט ALL CAPS חדש
                let endMarkers = [
                    // פורמט חדש - ALL CAPS / עברית בשורה נפרדת
                    "\n\nמנוע\n", "\n\nתיבת הילוכים\n", "\n\nמתלים\n", "\n\nיעילות דלק\n", "\n\nאלקטרוניקה\n",
                    "\nמנוע\n", "\nתיבת הילוכים\n", "\nמתלים\n", "\nיעילות דלק\n", "\nאלקטרוניקה\n",
                    "\nENGINE\n", "\nTRANSMISSION\n", "\nSUSPENSION\n", "\nFUEL", "\nELECTRONICS\n",
                    "\n\nהתאמות אימון\n", "\n\nשינויים בהתאוששות", "\n\nהרגל אחד", "\n\nהרגל להוסיף", "\n\nהרגל להסיר",
                    "\nהתאמות אימון\n", "\nשינויים בהתאוששות", "\nהרגל אחד", "\nהרגל להוסיף", "\nהרגל להסיר",
                    // סעיפים שמגיעים אחרי הרגל להסיר
                    "\n\nSTOP", "\n\nSTART", "\n\nWATCH", "\nSTOP\n", "\nSTART\n", "\nWATCH\n",
                    "\n\nסיכום", "\nסיכום\n", "\nSUMMARY\n", "\n\nSUMMARY",
                    "\n\nהנחיות פעולה", "\nהנחיות פעולה\n",
                    "\n\nתוספי תזונה", "\nתוספי תזונה\n", "\n\nSUPPLEMENTS", "\nSUPPLEMENTS\n",
                    // Section numbers
                    "\n3.", "\n4.", "\n5.", "\n6.", "\n7.", "\n8.", "תוספי תזונה",
                    // פורמט ישן - markdown
                    "**מנוע**", "**תיבת הילוכים**", "**מתלים**", "**יעילות דלק**", "**אלקטרוניקה**",
                    "**התאמות אימון**", "**שינויים בהתאוששות**", "**הרגל אחד בעל השפעה**", "**הרגל אחד להסיר**",
                    "הרגל אחד להסיר:", "הרגל להסיר:", "הרגל אחד להוסיף:",
                    "**סיכום**", "**הנחיות פעולה**", "**תוספי תזונה**",
                    "## ", "---", "\n\n\n"
                ]
                var endIdx = after.endIndex
                for endMarker in endMarkers {
                    if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx && r.lowerBound != after.startIndex {
                        endIdx = r.lowerBound
                    }
                }
                var content = String(after[..<endIdx])

                // Remove first newline if present
                content = content.trimmingCharacters(in: .newlines)

                // הסרת הסימון הראשוני אם יש - only if it's near the start
                if content.hasPrefix(")") {
                    content = String(content.dropFirst())
                } else if content.hasPrefix(":") {
                    content = String(content.dropFirst())
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

        // First try to extract as list items
        let listItems = extractListItems(from: text, sectionMarkers: markers)
        if !listItems.isEmpty {
            return listItems
        }

        // If no list items found, extract as paragraph text
        for marker in markers {
            guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }

            var after = String(text[range.upperBound...])

            // Skip past the rest of the header line (e.g., "עכשיו?")
            // The actual content starts on the NEXT line
            if let firstNewline = after.firstIndex(of: "\n") {
                after = String(after[after.index(after: firstNewline)...])
            }

            // Find end of section
            let endMarkers = ["4. תוכנית", "## 4", "תוכנית אופטימיזציה", "אילו שדרוגים", "סימני אזהרה", "---", "\n\n\n"]
            var endIdx = after.endIndex
            for endMarker in endMarkers {
                if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx && r.lowerBound != after.startIndex {
                    endIdx = r.lowerBound
                }
            }

            var content = String(after[..<endIdx])
            // Clean up the content
            content = content
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove any leftover header text like "מה מגביל את הביצועים עכשיו?"
            if content.hasPrefix("מה מגביל") {
                if let questionMark = content.firstIndex(of: "?") {
                    content = String(content[content.index(after: questionMark)...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            print("=== EXTRACTED BOTTLENECKS CONTENT: '\(content.prefix(150))...' ===")

            // Split by sentences if long enough
            if content.count > 20 {
                // Split by periods, keeping meaningful sentences
                let sentences = content.components(separatedBy: ".")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { sentence in
                        // Filter out short sentences and leftover header text
                        guard sentence.count > 15 else { return false }
                        // Filter out the repeated question "מה מגביל את הביצועים עכשיו"
                        if sentence.contains("מה מגביל את הביצועים") { return false }
                        return true
                    }

                if !sentences.isEmpty {
                    return sentences.map { $0 + "." }
                }

                // Fallback: return the whole content as single item if it doesn't contain the question
                if !content.contains("מה מגביל את הביצועים") {
                    return [content]
                }
            }
        }

        return []
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
                let endMarkers = ["---", "###", "\n\n\n", "## 8", "תוספי תזונה"]
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

    // MARK: - Supplements Extraction

    /// חילוץ המלצות תוספי תזונה מתשובת Gemini
    private static func extractSupplements(from text: String) -> [SupplementRecommendation] {
        var supplements: [SupplementRecommendation] = []

        // מחפש סקשן "תוספי תזונה"
        let markers = ["תוספי תזונה מומלצים", "המלצות תוספי תזונה", "## 8. תוספי תזונה", "SUPPLEMENTS", "תוספים מומלצים"]

        for marker in markers {
            guard let range = text.range(of: marker, options: .caseInsensitive) else { continue }

            let after = String(text[range.upperBound...])

            // מוצא את סוף הסקשן
            let endMarkers = ["---", "## 9", "###", "\n\n\n", "סיכום", "SUMMARY"]
            var endIdx = after.endIndex
            for endMarker in endMarkers {
                if let r = after.range(of: endMarker, options: .caseInsensitive), r.lowerBound < endIdx {
                    endIdx = r.lowerBound
                }
            }

            let section = String(after[..<endIdx])

            // מחפש תבנית: **שם** (מינון) - סיבה [CATEGORY: xxx]
            let pattern = #"\*\*([^*]+)\*\*\s*\(([^)]+)\)\s*[-–]\s*([^\[]+)\[CATEGORY:\s*(\w+)\]"#

            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))

                for match in matches {
                    guard match.numberOfRanges >= 5,
                          let nameRange = Range(match.range(at: 1), in: section),
                          let dosageRange = Range(match.range(at: 2), in: section),
                          let reasonRange = Range(match.range(at: 3), in: section),
                          let categoryRange = Range(match.range(at: 4), in: section) else { continue }

                    let name = String(section[nameRange]).trimmingCharacters(in: .whitespaces)
                    let dosage = String(section[dosageRange]).trimmingCharacters(in: .whitespaces)
                    let reason = String(section[reasonRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let categoryStr = String(section[categoryRange]).lowercased()

                    let category: SupplementCategory
                    switch categoryStr {
                    case "sleep": category = .sleep
                    case "performance": category = .performance
                    case "recovery": category = .recovery
                    default: category = .general
                    }

                    supplements.append(SupplementRecommendation(
                        name: name,
                        dosage: dosage,
                        reason: reason,
                        category: category
                    ))
                }
            }

            // אם לא מצאנו עם הפורמט המדויק, ננסה פורמט פשוט יותר
            if supplements.isEmpty {
                // מחפש תבנית: **שם** (מינון) - סיבה
                let simplePattern = #"\*\*([^*]+)\*\*\s*\(([^)]+)\)\s*[-–]\s*([^\n]+)"#

                if let regex = try? NSRegularExpression(pattern: simplePattern, options: []) {
                    let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))

                    for match in matches {
                        guard match.numberOfRanges >= 4,
                              let nameRange = Range(match.range(at: 1), in: section),
                              let dosageRange = Range(match.range(at: 2), in: section),
                              let reasonRange = Range(match.range(at: 3), in: section) else { continue }

                        let name = String(section[nameRange]).trimmingCharacters(in: .whitespaces)
                        let dosage = String(section[dosageRange]).trimmingCharacters(in: .whitespaces)
                        var reason = String(section[reasonRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                        // הסרת [CATEGORY:...] אם קיים
                        if let catRange = reason.range(of: #"\[CATEGORY:[^\]]+\]"#, options: .regularExpression) {
                            reason = String(reason[..<catRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                        }

                        supplements.append(createSupplement(name: name, dosage: dosage, reason: reason))
                    }
                }
            }

            // פורמט נוסף: שם (מינון) - סיבה (בלי **) או עם bullets/מספרים
            if supplements.isEmpty {
                // מחפש: - שם (מינון) - סיבה או 1. שם (מינון) - סיבה
                let bulletPattern = #"(?:[-•]\s*|\d+\.\s*)([^(]+)\(([^)]+)\)\s*[-–:]\s*([^\n]+)"#

                if let regex = try? NSRegularExpression(pattern: bulletPattern, options: []) {
                    let matches = regex.matches(in: section, options: [], range: NSRange(section.startIndex..., in: section))

                    for match in matches {
                        guard match.numberOfRanges >= 4,
                              let nameRange = Range(match.range(at: 1), in: section),
                              let dosageRange = Range(match.range(at: 2), in: section),
                              let reasonRange = Range(match.range(at: 3), in: section) else { continue }

                        let name = String(section[nameRange])
                            .replacingOccurrences(of: "**", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        let dosage = String(section[dosageRange]).trimmingCharacters(in: .whitespaces)
                        let reason = String(section[reasonRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                        supplements.append(createSupplement(name: name, dosage: dosage, reason: reason))
                    }
                }
            }

            // פורמט אחרון: שם בשורה נפרדת עם מינון וסיבה
            if supplements.isEmpty {
                // מחפש שורות עם מבנה: שם\nמינון: xxx\nסיבה: xxx
                let lines = section.components(separatedBy: .newlines)
                var i = 0
                while i < lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    // אם השורה נראית כמו שם תוסף (קצרה, בלי נקודותיים)
                    if line.count > 2 && line.count < 40 && !line.contains(":") && !line.hasPrefix("-") && !line.hasPrefix("•") {
                        let name = line.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                        var dosage = ""
                        var reason = ""

                        // בודק שורות הבאות
                        for j in (i+1)..<min(i+4, lines.count) {
                            let nextLine = lines[j].trimmingCharacters(in: .whitespaces)
                            if nextLine.lowercased().hasPrefix("מינון") || nextLine.lowercased().hasPrefix("dosage") {
                                dosage = nextLine.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                            } else if nextLine.lowercased().hasPrefix("סיבה") || nextLine.lowercased().hasPrefix("reason") || nextLine.lowercased().hasPrefix("למה") {
                                reason = nextLine.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                            }
                        }

                        if !name.isEmpty && (!dosage.isEmpty || !reason.isEmpty) {
                            supplements.append(createSupplement(name: name, dosage: dosage.isEmpty ? "לפי הוראות" : dosage, reason: reason.isEmpty ? name : reason))
                            i += 3
                            continue
                        }
                    }
                    i += 1
                }
            }

            if !supplements.isEmpty { break }
        }

        print("=== EXTRACTED \(supplements.count) SUPPLEMENTS ===")
        for sup in supplements {
            print("  - \(sup.name) (\(sup.dosage)): \(sup.reason.prefix(50))... [\(sup.category.rawValue)]")
        }

        return supplements
    }

    /// פונקציית עזר ליצירת תוסף עם זיהוי קטגוריה אוטומטי
    private static func createSupplement(name: String, dosage: String, reason: String) -> SupplementRecommendation {
        let lowerReason = reason.lowercased()
        let lowerName = name.lowercased()

        let category: SupplementCategory
        if lowerReason.contains("שינה") || lowerReason.contains("sleep") || lowerName.contains("מגנזיום") || lowerName.contains("melatonin") || lowerName.contains("magnesium") {
            category = .sleep
        } else if lowerReason.contains("אימון") || lowerReason.contains("training") || lowerReason.contains("ביצועים") || lowerName.contains("קריאטין") || lowerName.contains("creatine") || lowerName.contains("beta-alanine") {
            category = .performance
        } else if lowerReason.contains("התאוששות") || lowerReason.contains("recovery") || lowerReason.contains("דלקת") || lowerName.contains("אומגה") || lowerName.contains("omega") || lowerName.contains("turmeric") || lowerName.contains("כורכום") {
            category = .recovery
        } else {
            category = .general
        }

        return SupplementRecommendation(
            name: name,
            dosage: dosage,
            reason: reason,
            category: category
        )
    }
}
