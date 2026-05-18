//
//  OverviewCards.swift
//  Health Reporter
//
//  Card components for the Livity-style Overview: Body Battery, Stress, Energy Balance,
//  Strain, Sleep, Recovery, Time in Daylight, AI Analysis, and the "No sleep data yet" banner.
//

import SwiftUI

// MARK: - Sleep banner (top of screen when no overnight data)

struct LivitySleepBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(LivityTheme.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("livity.banner.noSleepTitle".localized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text("livity.banner.noSleepSubtitle".localized)
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LivityTheme.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                .fill(LivityTheme.infoTint.opacity(0.5))
        )
    }
}

// MARK: - AI Analysis card (pro-gated)

/// Main Overview AI Analysis card — a pure text summary of the user's day.
/// Pro + data → expandable analysis text with Read More / Show Less.
/// Pro + no data yet → "Generating AI Analysis…" placeholder.
/// Free → blurred teaser + Unlock AION Pro CTA.
struct LivityAIAnalysisCard: View {
    let isPro: Bool
    let metrics: LivityDailyMetrics
    let onTap: () -> Void

    @State private var expanded = false

    /// Rich narrative built from the live Livity metrics — this is what the legacy screen
    /// showed. We prefer this over Gemini's terse 1-2 sentence explanation because it
    /// references concrete recovery/battery/sleep numbers with a concluding recommendation.
    private var analysisText: String? {
        guard isPro else { return nil }
        if let narrative = LivityAnalysisNarrative.build(for: metrics), !narrative.isEmpty {
            return narrative
        }
        // Last-resort fallback to Gemini's shorter explanation if metrics are missing.
        guard let result = GeminiResultStore.load() else { return nil }
        let s = result.scores
        let candidates: [String?] = [
            s.healthScoreExplanation,
            s.readinessScoreExplanation,
            s.energyScoreExplanation,
            s.sleepScoreExplanation
        ]
        for candidate in candidates {
            if let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivityTheme.info)
                Text("livity.ai.title".localized)
                    .font(.livitySectionTitle)
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }

            if !isPro {
                teaser
            } else if let text = analysisText {
                analysisBody(text: text)
            } else {
                generatingPlaceholder
            }
        }
        .padding(LivityTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                .fill(LivityTheme.infoTint.opacity(0.45))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isPro && analysisText != nil {
                // Analysis text is already inline — tap expands, not opens sheet.
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } else {
                onTap()
            }
        }
    }

    // MARK: - Variants

    private var teaser: some View {
        VStack(spacing: 14) {
            Text("livity.ai.prompt".localized)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LivityTheme.textPrimary)
                .multilineTextAlignment(.center)
                .blur(radius: 4)
            Button(action: onTap) {
                Text("livity.ai.unlock".localized)
                    .font(.livityButton)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(LivityTheme.info))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LivityTheme.cardInnerRadius)
                .fill(LivityTheme.cardFill.opacity(0.6))
        )
    }

    private var generatingPlaceholder: some View {
        HStack(spacing: 10) {
            ProgressView().scaleEffect(0.85)
            Text("livity.ai.generating".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(LivityTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
    }

    private func analysisBody(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(LivityTheme.textPrimary)
                .lineLimit(expanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: expanded)

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack(spacing: 4) {
                    Text(expanded ? "livity.detail.showLess".localized : "livity.detail.showMore".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                    Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(LivityTheme.info)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Body Battery

struct LivityBodyBatteryCard: View {
    let percent: Int?
    let phase: BodyBatteryPhase?
    let onTap: () -> Void

    private var status: LivityStatus {
        guard let p = percent else { return .neutral }
        return p >= 50 ? .good : p >= 25 ? .warning : .bad
    }

    var body: some View {
        Button(action: onTap) {
            LivityCard(status: status) {
                VStack(alignment: .leading, spacing: 14) {
                    LivityCardHeader(icon: "battery.75percent", iconColor: status.accent, title: "livity.bodyBattery.title".localized)

                    HStack(alignment: .center, spacing: 14) {
                        LivityRingWithContent(progress: Double(percent ?? 0) / 100, color: status.accent, lineWidth: 9, size: 88) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(status.accent)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            LivityNumberUnit(number: percent.map { "\($0)" } ?? "–", unit: "%", color: status.accent)
                        }

                        Spacer(minLength: 0)

                        if let phase {
                            VStack(alignment: .trailing, spacing: 6) {
                                HStack(spacing: 5) {
                                    Image(systemName: phase.kind.pillIcon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(phase.kind.pillAccent)
                                    Text(phase.name)
                                        .font(.livityChip)
                                        .foregroundStyle(LivityTheme.textPrimary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(phase.kind.pillTint))
                                Text("\(phase.startTime) – \(phase.endTime)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(LivityTheme.textSecondary)
                                Text(phase.subtitle)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(phase.kind.pillAccent)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Today's Stress

struct LivityStressCard: View {
    let value: Int?
    let average: Int?
    let peak: Int?
    let low: Int?
    let onTap: () -> Void

    private var band: LivityStressBand { LivityStressBand.from(value: value ?? 0) }
    private var status: LivityStatus {
        switch band {
        case .relaxed, .low: return .good
        case .medium: return .warning
        case .high: return .bad
        }
    }

    var body: some View {
        Button(action: onTap) {
            LivityCard(status: status) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        LivityCardHeader(icon: "brain.head.profile", iconColor: status.accent, title: "livity.stress.title".localized)
                        Text(value.map { "\($0)" } ?? "–")
                            .font(.livityCardNumber)
                            .foregroundStyle(LivityTheme.textPrimary)
                        Text(band.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(band.color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 110)
                        .overlay(LivityTheme.separator)

                    VStack(spacing: 8) {
                        LivityMetricRow(icon: "waveform", iconColor: LivityTheme.good, label: "livity.stress.average".localized, value: average.map { "\($0)" } ?? "–", valueColor: LivityTheme.good)
                        LivityMetricRow(icon: "arrow.up", iconColor: LivityTheme.bad, label: "livity.stress.peak".localized, value: peak.map { "\($0)" } ?? "–", valueColor: LivityTheme.bad)
                        LivityMetricRow(icon: "arrow.down", iconColor: LivityTheme.good, label: "livity.stress.low".localized, value: low.map { "\($0)" } ?? "–", valueColor: LivityTheme.good)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Energy Balance

struct LivityEnergyBalanceCard: View {
    let isLogged: Bool
    let caloriesConsumed: Double?
    let caloriesBurned: Double?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            LivityCard(status: .good) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        LivityCardHeader(icon: "fork.knife", iconColor: LivityTheme.good, title: "livity.energy.title".localized)
                        if isLogged, let consumed = caloriesConsumed, let burned = caloriesBurned {
                            let delta = consumed - burned
                            let deltaText = "\(delta >= 0 ? "+" : "")\(Int(delta)) kcal"
                            Text(deltaText)
                                .font(.livityCardNumber)
                                .foregroundStyle(LivityTheme.textPrimary)
                            Text("\(Int(consumed)) in • \(Int(burned)) out")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LivityTheme.textSecondary)
                        } else {
                            Text("livity.energy.noFood".localized)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(LivityTheme.textPrimary)
                            Text("livity.energy.useApps".localized)
                                .font(.system(size: 13))
                                .foregroundStyle(LivityTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(LivityTheme.good.opacity(0.8))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Strain

struct LivityStrainCard: View {
    let percent: Double?
    let bucket: String?
    let totalEnergyKcal: Double?
    let activeEnergyKcal: Double?
    let steps: Int?
    let onTap: () -> Void

    private var status: LivityStatus {
        guard let p = percent else { return .neutral }
        return p >= 67 ? .good : p >= 33 ? .warning : .bad
    }

    var body: some View {
        Button(action: onTap) {
            LivityCard(status: status) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        LivityRingWithContent(progress: (percent ?? 0) / 100, color: status.accent, lineWidth: 9, size: 96) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(percent ?? 0))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(LivityTheme.textPrimary)
                                Text("%")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LivityTheme.textSecondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(status.accent)
                                Text("livity.strain.title".localized)
                                    .font(.livitySectionTitle)
                                    .foregroundStyle(LivityTheme.textPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(LivityTheme.textTertiary)
                            }
                            strainRow(icon: "bolt.fill", label: "livity.strain.totalEnergy".localized, value: totalEnergyKcal.map { "\(formatted($0))" } ?? "–", unit: "livity.unit.kcal".localized)
                            strainRow(icon: "flame.fill", label: "livity.strain.activeEnergy".localized, value: activeEnergyKcal.map { "\(formatted($0))" } ?? "–", unit: "livity.unit.kcal".localized)
                            strainRow(icon: "figure.walk", label: "livity.strain.steps".localized, value: steps.map { formatted(Double($0)) } ?? "–", unit: nil)
                        }
                        Spacer(minLength: 0)
                    }

                    if let bucket {
                        HStack {
                            LivityChip(text: bucket, icon: nil, tint: status.accent.opacity(0.15))
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func strainRow(icon: String, label: String, value: String, unit: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(status.accent)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(LivityTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(status.accent)
            if let unit {
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(status.accent)
            }
        }
    }

    private func formatted(_ v: Double) -> String {
        let f = NumberFormatter()
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: v)) ?? String(Int(v))
    }
}

// MARK: - Sleep

struct LivitySleepCard: View {
    let score: Double?
    let bucket: String?
    let deep: Double?
    let rem: Double?
    let awake: Double?
    let total: Double?
    let onTap: () -> Void

    private var status: LivityStatus {
        guard let s = score, s > 0 else { return .bad }
        return s >= 70 ? .good : s >= 50 ? .warning : .bad
    }

    var body: some View {
        Button(action: onTap) {
            LivityCard(status: status) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 14) {
                        LivityRingWithContent(progress: (score ?? 0) / 100, color: status.accent, lineWidth: 9, size: 96) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(score ?? 0))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(LivityTheme.textPrimary)
                                Text("%")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LivityTheme.textSecondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(status.accent)
                                Text("livity.sleep.title".localized)
                                    .font(.livitySectionTitle)
                                    .foregroundStyle(LivityTheme.textPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(LivityTheme.textTertiary)
                            }
                            row(icon: "moon.fill", label: "livity.sleep.deep".localized, value: formatMinutes(deep))
                            row(icon: "brain", label: "livity.sleep.rem".localized, value: formatMinutes(rem))
                            row(icon: "eye", label: "livity.sleep.awake".localized, value: formatMinutes(awake))
                            row(icon: "clock", label: "livity.sleep.time".localized, value: formatMinutes(total))
                        }
                        Spacer(minLength: 0)
                    }
                    if let bucket {
                        HStack { LivityChip(text: bucket, tint: status.accent.opacity(0.15)); Spacer() }.padding(.top, 8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func row(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(status.accent.opacity(0.8))
                .frame(width: 14)
            Text(label).font(.system(size: 14)).foregroundStyle(LivityTheme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(LivityTheme.textPrimary)
        }
    }

    private func formatMinutes(_ m: Double?) -> String {
        guard let m, m > 0 else { return "--" }
        let h = Int(m) / 60
        let min = Int(m) % 60
        return h > 0 ? "\(h)h \(min)m" : "\(min)m"
    }
}

// MARK: - Recovery

struct LivityRecoveryCard: View {
    let score: Double?
    let bucket: String?
    let hrv: Double?
    let rhr: Double?
    let respiratoryRate: Double?
    let spo2: Double?
    let wristTempF: Double?
    let onTap: () -> Void

    /// Recovery uses its own palette: green/yellow/red (not orange) so mid-range reads as "caution", not "warning".
    private enum Level { case good, caution, bad }

    private var level: Level {
        guard let s = score, s > 0 else { return .bad }
        return s >= 70 ? .good : s >= 50 ? .caution : .bad
    }

    private var accent: Color {
        switch level {
        case .good: return LivityTheme.good
        case .caution: return LivityTheme.caution
        case .bad: return LivityTheme.bad
        }
    }

    private var tintFill: Color {
        switch level {
        case .good: return LivityTheme.goodTint
        case .caution: return LivityTheme.cautionTint
        case .bad: return LivityTheme.badTint
        }
    }

    // MARK: - Per-metric status (independent of the overall recovery score)

    private static func hrvColor(_ v: Double) -> Color {
        v >= 60 ? LivityTheme.good : v >= 40 ? LivityTheme.caution : LivityTheme.bad
    }
    private static func rhrColor(_ v: Double) -> Color {
        v <= 55 ? LivityTheme.good : v <= 65 ? LivityTheme.caution : LivityTheme.bad
    }
    private static func respColor(_ v: Double) -> Color {
        (12...20).contains(v) ? LivityTheme.good : LivityTheme.caution
    }
    private static func spo2Color(_ v: Double) -> Color {
        v >= 95 ? LivityTheme.good : v >= 90 ? LivityTheme.caution : LivityTheme.bad
    }
    private static func tempColor(_ v: Double) -> Color {
        (96.0...100.0).contains(v) ? LivityTheme.good : LivityTheme.caution
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    LivityRingWithContent(progress: (score ?? 0) / 100, color: accent, lineWidth: 9, size: 96) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(score ?? 0))")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(LivityTheme.textPrimary)
                            Text("%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LivityTheme.bad)
                            Text("livity.recovery.title".localized)
                                .font(.livitySectionTitle)
                                .foregroundStyle(LivityTheme.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(LivityTheme.textTertiary)
                        }
                        .padding(.bottom, 2)

                        row(icon: "waveform.path.ecg", iconColor: hrv.map(Self.hrvColor) ?? LivityTheme.textTertiary,
                            label: "livity.recovery.hrv".localized,
                            value: hrv.map { String(format: "%.2f", $0) } ?? "—",
                            unit: "ms",
                            color: hrv.map(Self.hrvColor) ?? LivityTheme.textTertiary)

                        row(icon: "heart.fill", iconColor: LivityTheme.bad,
                            label: "livity.recovery.rhr".localized,
                            value: rhr.map { String(format: "%.2f", $0) } ?? "—",
                            unit: "bpm",
                            color: rhr.map(Self.rhrColor) ?? LivityTheme.textTertiary)

                        row(icon: "lungs.fill", iconColor: LivityTheme.good,
                            label: "livity.recovery.resp".localized,
                            value: respiratoryRate.map { String(format: "%.2f", $0) } ?? "—",
                            unit: "BRPM",
                            color: respiratoryRate.map(Self.respColor) ?? LivityTheme.textTertiary)

                        row(icon: "drop.fill", iconColor: LivityTheme.good,
                            label: "livity.recovery.spo2".localized,
                            value: spo2.map { String(format: "%.2f", $0) } ?? "—",
                            unit: "%",
                            color: spo2.map(Self.spo2Color) ?? LivityTheme.textTertiary)

                        row(icon: "thermometer.medium", iconColor: LivityTheme.good,
                            label: "livity.recovery.wristTemp".localized,
                            value: wristTempF.map { String(format: "%.2f", $0) } ?? "—",
                            unit: "°F",
                            color: wristTempF.map(Self.tempColor) ?? LivityTheme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                if let bucket {
                    HStack { LivityChip(text: bucket, tint: accent.opacity(0.15)); Spacer() }.padding(.top, 8)
                }
            }
            .padding(LivityTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                    .fill(tintFill)
            )
        }
        .buttonStyle(.plain)
    }

    private func row(icon: String, iconColor: Color, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(LivityTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LivityTheme.textSecondary)
        }
    }
}

// MARK: - Time in Daylight

struct LivityDaylightCard: View {
    let minutes: Int?
    let percentVsGoal: Double?
    let history: [Int]
    let onTap: () -> Void

    /// Average over the history window, used as the dashed reference line.
    private var average: Double {
        guard !history.isEmpty else { return 0 }
        return Double(history.reduce(0, +)) / Double(history.count)
    }

    private var hasChartData: Bool {
        history.contains(where: { $0 > 0 })
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.warning)
                    Text("livity.daylight.title".localized)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(minutes.map { "\($0)m" } ?? "—")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    if let pct = percentVsGoal {
                        LivityChip(
                            text: "\(pct >= 0 ? "↑" : "↓") \(Int(abs(pct)))%",
                            tint: pct >= 0 ? LivityTheme.goodTint : LivityTheme.warningTint
                        )
                    }
                }

                Group {
                    if hasChartData {
                        DaylightMiniChart(history: history, average: average)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "sun.max")
                                .font(.system(size: 30, weight: .regular))
                                .foregroundStyle(LivityTheme.warning.opacity(0.6))
                            Text("livity.daylight.noHistory".localized)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                    .fill(LivityTheme.warningTint)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Your Car (health-tier vehicle)

/// Square card that mirrors the Daylight card. Shows the real car image of the user's
/// current health tier, the score with a progress ring, and the car model name.
struct LivityCarTierCard: View {
    let score: Int?
    let carModel: String?
    let carWikiName: String?
    let onTap: () -> Void

    @StateObject private var imageLoader = LivityCarImageLoader()

    private var tier: HealthTier? {
        guard let score else { return nil }
        return HealthTier.forScore(score)
    }

    var body: some View {
        Button(action: onTap) {
            Group {
                if let tier, let score {
                    populatedCard(tier: tier, score: score)
                } else {
                    emptyCard
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: LivityTheme.cardRadius, style: .continuous)
                    .fill(LivityTheme.infoTint)
            )
        }
        .buttonStyle(.plain)
        .onAppear { imageLoader.load(wikiName: carWikiName) }
        .onChange(of: carWikiName) { _, new in imageLoader.load(wikiName: new) }
    }

    // MARK: - Populated

    private func populatedCard(tier: HealthTier, score: Int) -> some View {
        let accent = Color(tier.color)
        return VStack(alignment: .leading, spacing: 6) {
            // Header: title + score ring
            HStack(alignment: .top) {
                Text("livity.carTier.title".localized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.18), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                        .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(accent)
                }
                .frame(width: 32, height: 32)
            }

            // Real car image — hero of the card
            ZStack {
                carImage(for: tier)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Model name + tier label
            VStack(alignment: .leading, spacing: 2) {
                Text(carModel?.isEmpty == false ? carModel! : tier.tierLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(tier.tierLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
        }
        .padding(10)
    }

    // MARK: - Empty

    private var emptyCard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "car.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivityTheme.info)
                Text("livity.carTier.title".localized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            Spacer(minLength: 0)
            Image(systemName: "car.side.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(LivityTheme.info.opacity(0.55))
            Text("livity.carTier.empty".localized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LivityTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func carImage(for tier: HealthTier) -> some View {
        if let wiki = imageLoader.image {
            Image(uiImage: wiki)
                .resizable()
                .scaledToFit()
        } else if imageLoader.isLoading {
            ZStack {
                if let uiImage = UIImage(named: tier.imageName) {
                    Image(uiImage: uiImage).resizable().scaledToFit().opacity(0.3)
                } else {
                    Text(tier.emoji).font(.system(size: 52)).opacity(0.3)
                }
                ProgressView().scaleEffect(0.8)
            }
        } else if let uiImage = UIImage(named: tier.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Text(tier.emoji)
                .font(.system(size: 52))
        }
    }
}

/// Mini line chart with a gradient stroke (red for low, amber for mid, green for high)
/// and dashed average reference line. Used both in the card and the detail sheet.
private struct DaylightMiniChart: View {
    let history: [Int]
    let average: Double

    private func color(for minutes: Int) -> Color {
        if minutes >= 90 { return LivityTheme.good }
        if minutes >= 45 { return LivityTheme.warning }
        return LivityTheme.bad
    }

    var body: some View {
        GeometryReader { geo in
            let values = history
            guard !values.isEmpty else {
                return AnyView(Color.clear)
            }
            let maxV = max(CGFloat(values.max() ?? 1), 1)
            let stepX = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : 0
            let avgY = geo.size.height - (CGFloat(average) / maxV) * geo.size.height

            return AnyView(
                ZStack {
                    // Dashed average line
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: avgY))
                        p.addLine(to: CGPoint(x: geo.size.width, y: avgY))
                    }
                    .stroke(LivityTheme.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    // Line stroke
                    Path { p in
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = geo.size.height - (CGFloat(v) / maxV) * geo.size.height
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [LivityTheme.bad, LivityTheme.warning, LivityTheme.good],
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                    // Point markers — colored by level
                    ForEach(Array(values.enumerated()), id: \.offset) { idx, v in
                        let x = CGFloat(idx) * stepX
                        let y = geo.size.height - (CGFloat(v) / maxV) * geo.size.height
                        Circle()
                            .fill(color(for: v))
                            .frame(width: 5, height: 5)
                            .position(x: x, y: y)
                    }
                }
            )
        }
    }
}
