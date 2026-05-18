//
//  LivityAnalysisNarrative.swift
//  Health Reporter
//
//  Builds a rich, multi-paragraph daily analysis from the Livity metric bundle.
//  This is the narrative shown on the Overview AI Analysis card — it combines
//  recovery, body battery, sleep, current phase, and stress into actionable prose
//  (English + Hebrew), with graceful fallbacks when metrics are missing.
//

import Foundation

enum LivityAnalysisNarrative {

    // MARK: - Entry point

    static func build(for metrics: LivityDailyMetrics) -> String? {
        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew

        // Collect the numeric signals once; a missing metric just drops that clause.
        let recovery = metrics.recoveryScore.map { Int($0) }
        let battery = metrics.bodyBattery
        let sleep = metrics.sleepScore.map { Int($0) }
        let phase = metrics.bodyBatteryPhase?.name
        let stress = metrics.stressNow

        // If we have effectively nothing to say, bail so the card can show a different state.
        let signals = [recovery, battery, sleep, stress].compactMap { $0 }
        guard !signals.isEmpty else { return nil }

        return isHebrew
            ? buildHebrew(recovery: recovery, battery: battery, sleep: sleep, phase: phase, stress: stress)
            : buildEnglish(recovery: recovery, battery: battery, sleep: sleep, phase: phase, stress: stress)
    }

    // MARK: - English

    private static func buildEnglish(recovery: Int?, battery: Int?, sleep: Int?, phase: String?, stress: Int?) -> String {
        var lead = ""
        if let recovery, let battery {
            let recoveryDescriptor = recovery >= 70 ? "strong" : recovery >= 50 ? "moderate" : "below your goal minimum"
            let batteryDescriptor = battery >= 70 ? "still holding strong" : battery >= 40 ? "running moderate" : "only \(battery)%"
            let energyVerdict = (recovery < 60 && battery < 50)
                ? "indicating a significant energy deficit"
                : (recovery >= 70 && battery >= 70)
                    ? "showing a well-charged system"
                    : "showing a mixed picture"
            lead = "You're at \(recovery)% recovery, which is \(recoveryDescriptor), and your battery is \(batteryDescriptor), \(energyVerdict)."
        } else if let recovery {
            lead = "You're at \(recovery)% recovery today."
        } else if let battery {
            lead = "Your body battery is at \(battery)%."
        }

        var middle = ""
        if let sleep {
            let sleepDescriptor = sleep >= 80 ? "a good sleep score of \(sleep)" : sleep >= 60 ? "a moderate sleep score of \(sleep)" : "a low sleep score of \(sleep)"
            if (recovery ?? 100) < 60 || (battery ?? 100) < 50 {
                middle = " Despite \(sleepDescriptor), the combination of the other signals suggests that your body is not fully rested."
            } else {
                middle = " With \(sleepDescriptor), you've built a solid base for the day."
            }
        }

        var closing = ""
        if let phase, !phase.isEmpty {
            let intensity = ((recovery ?? 70) < 60 || (battery ?? 70) < 50) ? "light to moderate" : "moderate to higher-intensity"
            closing = " Given the \(phase.lowercased()) and the need for energy, it's best to opt for \(intensity) activity to help boost your energy levels and recovery."
        } else if recovery != nil || battery != nil {
            closing = " Choose activity intensity that matches how you feel — push when you're fresh, recover when you're depleted."
        }

        var stressLine = ""
        if let stress {
            if stress >= 60 {
                stressLine = " Stress is elevated at \(stress); a brief breathing reset or walk can help bring it down."
            } else if stress <= 30 {
                stressLine = " Stress is well-controlled at \(stress), which supports recovery."
            }
        }

        let closer = " This approach will help you stay within your goal range and maintain your overall well-being."

        return (lead + middle + closing + stressLine + closer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Detail-screen narratives (data-driven)

    /// Returns the average of the values in `history` excluding today's value (last entry) and zeros.
    private static func baselineAverage(_ history: [Double]) -> Double? {
        guard history.count >= 2 else { return nil }
        let baseline = history.dropLast().filter { $0 > 0 }
        guard !baseline.isEmpty else { return nil }
        return baseline.reduce(0, +) / Double(baseline.count)
    }

    private static func percentDelta(today: Double, mean: Double) -> Int? {
        guard mean > 0 else { return nil }
        return Int(((today - mean) / mean * 100).rounded())
    }

    static func buildStress(for metrics: LivityDailyMetrics) -> String? {
        guard let stress = metrics.stressNow else { return nil }
        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        let band: String
        if isHebrew {
            band = stress < 30 ? "נמוך" : stress < 50 ? "בינוני" : stress < 70 ? "מוגבר" : "גבוה"
        } else {
            band = stress < 30 ? "low" : stress < 50 ? "moderate" : stress < 70 ? "elevated" : "high"
        }
        let avgClause: String
        if let avg = metrics.stressAverage, abs(avg - stress) > 5 {
            let dir = stress > avg ? (isHebrew ? "מעל" : "above") : (isHebrew ? "מתחת ל" : "below")
            avgClause = isHebrew
                ? " זה \(dir) הממוצע היומי שלך (\(avg))."
                : " That's \(dir) your daily average (\(avg))."
        } else {
            avgClause = ""
        }
        let advice: String
        if stress >= 60 {
            advice = isHebrew
                ? " נסה דקה של נשימה מודעת או הליכה קצרה כדי להוריד את העומס."
                : " Try a minute of mindful breathing or a short walk to ease it down."
        } else if stress <= 30 {
            advice = isHebrew
                ? " המצב מאוזן — תזמון טוב לאימון או למשימה תובענית."
                : " You're in a calm window — a good time for focused work or a workout."
        } else {
            advice = isHebrew
                ? " שמור על הקצב; הפסקות קצרות יעזרו לשמור על הרמה הזו."
                : " Maintain the pace; short breaks will help keep stress in check."
        }
        let prefix = isHebrew
            ? "רמת המתח הנוכחית שלך היא \(stress) (\(band))."
            : "Your current stress is \(stress) (\(band))."
        return prefix + avgClause + advice
    }

    static func buildStrain(for metrics: LivityDailyMetrics) -> String? {
        guard let strain = metrics.strainPercent else { return nil }
        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        let pct = Int(strain.rounded())
        var clauses: [String] = []
        if let stepsToday = metrics.steps,
           let mean = baselineAverage(metrics.stepsHistory.map { Double($0) }),
           let delta = percentDelta(today: Double(stepsToday), mean: mean) {
            let absDelta = abs(delta)
            let direction: String
            if isHebrew {
                direction = delta < 0 ? "מתחת ל" : "מעל"
                clauses.append("צעדים \(absDelta)% \(direction)ממוצע 30 הימים שלך")
            } else {
                direction = delta < 0 ? "below" : "above"
                clauses.append("steps \(absDelta)% \(direction) your 30-day average")
            }
        }
        if let exerciseToday = metrics.exerciseMinutes,
           let mean = baselineAverage(metrics.exerciseMinutesHistory),
           let delta = percentDelta(today: exerciseToday, mean: mean) {
            let absDelta = abs(delta)
            if isHebrew {
                let dir = delta < 0 ? "מתחת ל" : "מעל"
                clauses.append("זמן אימון \(absDelta)% \(dir)ממוצע (\(Int(mean.rounded())) דקות)")
            } else {
                let dir = delta < 0 ? "below" : "above"
                clauses.append("exercise time \(absDelta)% \(dir) your typical \(Int(mean.rounded())) minutes")
            }
        }
        let breakdown = clauses.isEmpty ? "" :
            (isHebrew ? " זה נובע בעיקר מ" : " That reflects ") + clauses.joined(separator: isHebrew ? " ו" : " and ") + "."
        let prefix = isHebrew
            ? "המאמץ הנוכחי שלך הוא \(pct)%."
            : "Your current strain is \(pct)%."
        return prefix + breakdown
    }

    static func buildSleep(for metrics: LivityDailyMetrics) -> String? {
        guard let total = metrics.sleepTotalMinutes, total > 0 else {
            let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
            return isHebrew
                ? "אין נתוני שינה ללילה האחרון. שאיבת הנתונים תרוץ אוטומטית כשתסונכרן עם השעון או תיכנס לאפליקציית הבריאות."
                : "No sleep recorded for last night. Wear your watch overnight or sync from Apple Health to start tracking."
        }
        let isHebrew = LocalizationManager.shared.currentLanguage == .hebrew
        let hours = Int(total / 60)
        let minutes = Int(total.truncatingRemainder(dividingBy: 60))
        let deep = Int((metrics.sleepDeepMinutes ?? 0).rounded())
        let rem = Int((metrics.sleepREMMinutes ?? 0).rounded())
        let goalHours: Double = 7
        let deltaHours = total / 60 - goalHours
        let goalClause: String
        if abs(deltaHours) < 0.5 {
            goalClause = isHebrew ? " זה תואם את יעד \(Int(goalHours)) השעות שלך." : " That meets your \(Int(goalHours))-hour goal."
        } else if deltaHours < 0 {
            let short = abs(deltaHours)
            goalClause = isHebrew
                ? String(format: " זה %.1f שעות מתחת ליעד %d השעות.", short, Int(goalHours))
                : String(format: " That's %.1fh below your %d-hour goal.", short, Int(goalHours))
        } else {
            goalClause = isHebrew
                ? String(format: " מעל היעד שלך ב־%.1f שעות.", deltaHours)
                : String(format: " About %.1fh above your goal.", deltaHours)
        }
        let stages = isHebrew
            ? " עמוק \(deep) דקות, REM \(rem) דקות."
            : " Deep \(deep) min, REM \(rem) min."
        let prefix = isHebrew
            ? "ישנת \(hours)ש' \(minutes)ד' אתמול."
            : "You slept \(hours)h \(minutes)m last night."
        return prefix + goalClause + stages
    }

    // MARK: - Hebrew

    private static func buildHebrew(recovery: Int?, battery: Int?, sleep: Int?, phase: String?, stress: Int?) -> String {
        var lead = ""
        if let recovery, let battery {
            let recoveryDescriptor = recovery >= 70 ? "חזקה" : recovery >= 50 ? "בינונית" : "מתחת ליעד המינימלי שלך"
            let batteryDescriptor = battery >= 70 ? "עדיין מלאה" : battery >= 40 ? "בינונית" : "נמוכה — רק \(battery)%"
            let energyVerdict = (recovery < 60 && battery < 50)
                ? "מצביע על גירעון אנרגיה משמעותי"
                : (recovery >= 70 && battery >= 70)
                    ? "מצביע על מערכת טעונה היטב"
                    : "מצייר תמונה מעורבת"
            lead = "אתה ב־\(recovery)% התאוששות, שהיא \(recoveryDescriptor), והסוללה שלך \(batteryDescriptor), מה ש\(energyVerdict)."
        } else if let recovery {
            lead = "ההתאוששות שלך היום היא \(recovery)%."
        } else if let battery {
            lead = "סוללת הגוף שלך נמצאת על \(battery)%."
        }

        var middle = ""
        if let sleep {
            let sleepDescriptor = sleep >= 80 ? "ציון שינה טוב של \(sleep)" : sleep >= 60 ? "ציון שינה בינוני של \(sleep)" : "ציון שינה נמוך של \(sleep)"
            if (recovery ?? 100) < 60 || (battery ?? 100) < 50 {
                middle = " למרות \(sleepDescriptor), השילוב של המדדים האחרים מרמז שהגוף שלך לא נח במלואו."
            } else {
                middle = " עם \(sleepDescriptor), בנית בסיס איתן ליום."
            }
        }

        var closing = ""
        if let phase, !phase.isEmpty {
            let intensity = ((recovery ?? 70) < 60 || (battery ?? 70) < 50) ? "קלה עד בינונית" : "בינונית ומעלה"
            closing = " בהתחשב בשלב \(phase) ובצורך באנרגיה, עדיף לבחור בפעילות \(intensity) כדי לסייע בהעלאת רמות האנרגיה וההתאוששות."
        } else if recovery != nil || battery != nil {
            closing = " התאם את עצימות הפעילות לאיך שאתה מרגיש — דחוף כשאתה רענן, התאושש כשאתה מותש."
        }

        var stressLine = ""
        if let stress {
            if stress >= 60 {
                stressLine = " המתח גבוה (\(stress)); נשימה מודעת קצרה או הליכה יכולות לעזור להוריד אותו."
            } else if stress <= 30 {
                stressLine = " המתח מאוזן (\(stress)), מה שתומך בהתאוששות."
            }
        }

        let closer = " גישה זו תעזור לך להישאר בטווח היעד ולשמור על הרווחה הכללית שלך."

        return (lead + middle + closing + stressLine + closer).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
