//
//  OverviewDetails.swift
//  Health Reporter
//
//  Full-screen detail views opened when the user taps any of the Overview cards:
//  Body Battery, Stress, Energy Balance (Nutrition), Strain, Sleep, Recovery, Daylight.
//
//  Each view mirrors the Livity-style design: detail header (back + date pill),
//  scrollable content with the primary metric ring, AI analysis, breakdowns,
//  and monthly-trend mini-charts.
//

import SwiftUI

// MARK: - Shared detail chrome

/// Host view used by every detail screen. Wraps the content in a background,
/// renders the standard detail header, and exposes a scroll container.
struct LivityDetailShell<Content: View>: View {
    let title: String
    let selectedDate: Date
    let onDismiss: () -> Void
    let content: Content

    /// Horizontal translation for the interactive swipe-back gesture.
    @State private var dragOffset: CGFloat = 0

    init(title: String,
         selectedDate: Date,
         onDismiss: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.selectedDate = selectedDate
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        ZStack {
            LivityTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                LivityDetailHeader(
                    title: title,
                    selectedDate: selectedDate,
                    onBack: onDismiss,
                    // Tap on the date pill: dismiss the detail and ask the
                    // Overview screen to surface its calendar picker. The
                    // chevron under the date implied a picker; previously
                    // tapping it just dismissed silently, which the user read
                    // as a bug.
                    onDateTap: {
                        onDismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            NotificationCenter.default.post(name: .livityRequestDatePicker, object: nil)
                        }
                    }
                )
                ScrollView {
                    VStack(spacing: LivityTheme.cardSpacing) {
                        content
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, LivityTheme.horizontalPadding)
                    .padding(.top, 4)
                }
            }
        }
        .offset(x: dragOffset)
        // Edge-pan-to-dismiss: matches the iOS navigation back-swipe behaviour.
        // Only activates when the gesture starts within the leading 30pt to avoid
        // hijacking horizontal swipes on inner controls.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .global)
                .onChanged { value in
                    guard value.startLocation.x < 30,
                          value.translation.width > 0 else { return }
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let shouldDismiss = value.startLocation.x < 30
                        && (value.translation.width > 80 || value.predictedEndTranslation.width > 200)
                    if shouldDismiss {
                        withAnimation(.easeOut(duration: 0.18)) {
                            dragOffset = UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onDismiss() }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

// MARK: - Section header used inside details

private struct DetailSectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LivityTheme.textPrimary)
            Spacer()
            trailing?()
        }
    }
}

// MARK: - AI analysis card (expandable body copy)

private struct DetailAIAnalysisCard: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(LivityTheme.bad)
                Text("AI ANALYSIS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(LivityTheme.textPrimary)
                .lineLimit(expanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { expanded.toggle() }) {
                HStack(spacing: 4) {
                    Text(expanded ? "Show Less" : "Read More")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.info)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.info)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LivityTheme.badTint.opacity(0.7))
        )
    }
}

// MARK: - Mini line chart placeholder (monthly trends)

private struct TrendSparkline: View {
    let color: Color
    let points: [CGFloat]

    init(color: Color, points: [CGFloat] = Self.sample) {
        self.color = color
        self.points = points
    }

    static let sample: [CGFloat] = [0.3, 0.5, 0.35, 0.7, 0.4, 0.6, 0.25, 0.55, 0.8, 0.4, 0.5, 0.3, 0.6, 0.55, 0.65, 0.45]

    var body: some View {
        GeometryReader { geo in
            let maxY = geo.size.height
            let stepX = geo.size.width / CGFloat(max(points.count - 1, 1))

            ZStack {
                // Zero line
                Path { p in
                    p.move(to: CGPoint(x: 0, y: maxY * 0.5))
                    p.addLine(to: CGPoint(x: geo.size.width, y: maxY * 0.5))
                }
                .stroke(LivityTheme.separator, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                // Line
                Path { p in
                    for (i, v) in points.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = maxY - (v * maxY)
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Dots
                ForEach(Array(points.enumerated()), id: \.offset) { i, v in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .position(x: CGFloat(i) * stepX, y: maxY - (v * maxY))
                }
            }
        }
    }
}

private struct TrendRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    /// Today's raw value (the headline). e.g. "5,432" steps, "86 %", "535 kcal".
    let valueText: String
    let valueColor: Color
    /// Delta vs baseline + percentile context line.
    let deltaText: String
    let comparison: String
    var points: [CGFloat]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                    Text(title.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(valueText)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text(deltaText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(valueColor)
                    Text(comparison)
                        .font(.system(size: 10))
                        .foregroundStyle(LivityTheme.textTertiary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LivityTheme.textTertiary)
                    .padding(.leading, 4)
            }
            if let points {
                TrendSparkline(color: valueColor, points: points)
                    .frame(height: 56)
            } else {
                TrendSparkline(color: valueColor)
                    .frame(height: 56)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LivityTheme.cardFill)
        )
    }
}

// MARK: - Monthly trend computation helpers

/// Normalizes a history (min→0.1, max→0.9). Equal values map to 0.5.
private func normalizedTrendPoints(_ history: [Double]) -> [CGFloat] {
    guard !history.isEmpty else { return [] }
    guard let mn = history.min(), let mx = history.max(), mx > mn else {
        return history.map { _ in 0.5 }
    }
    let span = mx - mn
    return history.map { CGFloat(0.1 + ($0 - mn) / span * 0.8) }
}

/// Summary for a single "Monthly Trends" row. The headline is today's *raw* value
/// (e.g. "5,432" steps, "535 kcal"). The delta and percentile are shown as context
/// underneath so the user always sees their actual measurement first.
private struct TrendSummary {
    let points: [CGFloat]
    let valueText: String       // today's raw value, e.g. "5,432" or "86 %"
    let valueColor: Color
    let deltaText: String       // e.g. "↓ 1,200 vs 30-day avg"
    let comparison: String      // "Worse than usual" / "Better than usual"

    /// - Parameters:
    ///   - history: full historical series, oldest→newest, today's value last.
    ///   - higherIsBetter: whether a larger value is "better" for this metric.
    ///   - formatValue: formats today's raw value (e.g. "5,432" steps, "86 %").
    ///   - formatDelta: formats |today − baseline|.
    ///
    /// Baseline (mean + percentile) is computed across the *non-zero* days only —
    /// otherwise days when HealthKit had no samples (watch off, etc.) drag the
    /// denominator and produce misleading "100% worse than usual" labels.
    /// The sparkline shows the most recent 30 days for readability.
    static func make(
        history: [Double],
        higherIsBetter: Bool = true,
        formatValue: (Double) -> String,
        formatDelta: (Double) -> String
    ) -> TrendSummary? {
        guard history.count >= 2 else { return nil }
        let baseline = history.dropLast()
        let today = history.last ?? 0
        let nonZero = baseline.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return nil }
        let mean = nonZero.reduce(0, +) / Double(nonZero.count)
        let delta = today - mean
        // Rank today only against days that actually had data — otherwise lots of
        // "0" days inflate the percentile to 100% on every fresh / partial day.
        let betterCount: Int
        if higherIsBetter {
            betterCount = nonZero.filter { $0 > today }.count
        } else {
            betterCount = nonZero.filter { $0 < today }.count
        }
        let percentile = Double(betterCount) / Double(nonZero.count) * 100
        let isWorse = higherIsBetter ? (delta < 0) : (delta > 0)
        let arrow = delta < 0 ? "↓" : (delta > 0 ? "↑" : "→")
        let valueText = formatValue(today)
        let valueColor = isWorse ? LivityTheme.warning : LivityTheme.good
        let deltaText = "\(arrow) \(formatDelta(abs(delta))) vs 30-day avg"
        let comparison = String(format: "%@ (%.0f%% of days)",
                                isWorse ? "Worse than usual" : "Better than usual",
                                percentile)
        let chartWindow = Array(history.suffix(30))
        return TrendSummary(
            points: normalizedTrendPoints(chartWindow),
            valueText: valueText,
            valueColor: valueColor,
            deltaText: deltaText,
            comparison: comparison
        )
    }
}

/// Formatters used both for "today's raw value" and the |delta vs baseline| label.
private func formatKcalValue(_ v: Double) -> String {
    let n = Int(v.rounded())
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return "\(f.string(from: NSNumber(value: n)) ?? "\(n)") kcal"
}
private func formatIntValue(_ v: Double) -> String {
    let n = Int(v.rounded())
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}
private func formatMinutesValue(_ v: Double) -> String {
    let m = Int(v.rounded())
    if m < 60 { return "\(m)m" }
    return "\(m / 60)h \(m % 60)m"
}
private func formatPercentValue(_ v: Double) -> String {
    String(format: "%.0f %%", v)
}

/// Intraday stress curve with right-side y-axis labels and bottom hour ticks.
/// Colour gradient (green→yellow→orange→red) maps to stress intensity.
/// Intraday Body Battery curve. There's no native HealthKit "battery" series,
/// so we derive it from the same Karvonen intensity samples that drive Stress
/// (`stressIntraday`): low intensity → battery charging up, high intensity →
/// battery draining. We smooth the raw inverse with a centered moving average
/// so the line reads as a slow physiological trend instead of a noisy heart-rate
/// echo.
struct BodyBatteryIntradayChart: View {
    /// Stress intensity samples (0–100) collected through the day.
    let samples: [(date: Date, value: Int)]
    let dayStart: Date

    /// Half-window for smoothing, in samples on each side. ~30 = ~3-5 minutes
    /// of HR samples on a typical Apple Watch wear day; tuned by eye to match
    /// the slow rhythm Garmin/Whoop body-battery curves show.
    private static let smoothingHalfWindow: Int = 30

    /// Each smoothed point: battery (0–100) = 100 − smoothed stress.
    private var batteryPoints: [(date: Date, value: Int)] {
        guard !samples.isEmpty else { return [] }
        let n = samples.count
        var out: [(Date, Int)] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            let lo = max(0, i - Self.smoothingHalfWindow)
            let hi = min(n - 1, i + Self.smoothingHalfWindow)
            var sum = 0
            for j in lo...hi { sum += samples[j].value }
            let avg = Double(sum) / Double(hi - lo + 1)
            let battery = max(0, min(100, 100 - Int(avg.rounded())))
            out.append((samples[i].date, battery))
        }
        return out
    }

    var body: some View {
        let points = batteryPoints
        GeometryReader { geo in
            let yLabelWidth: CGFloat = 28
            let chartW = geo.size.width - yLabelWidth
            let chartH = geo.size.height - 18
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: dayStart)
            let dayLength: TimeInterval = 24 * 60 * 60
            let yMax: CGFloat = 100

            ZStack {
                VStack(spacing: 0) {
                    ForEach([100, 75, 50, 25, 0], id: \.self) { val in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(LivityTheme.separator.opacity(0.3))
                                .frame(height: 1)
                            Text("\(val)")
                                .font(.system(size: 10))
                                .foregroundStyle(LivityTheme.textTertiary)
                                .frame(width: yLabelWidth, alignment: .trailing)
                        }
                        if val != 0 { Spacer() }
                    }
                }
                .frame(height: chartH)
                .frame(maxHeight: .infinity, alignment: .top)

                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Text("0").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("6").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("12").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("18").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("24").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                    }
                    .padding(.trailing, yLabelWidth)
                    .frame(height: 14)
                }

                if points.count >= 2 {
                    let xFor: (Date) -> CGFloat = { date in
                        let t = max(0, min(dayLength, date.timeIntervalSince(startOfDay)))
                        return CGFloat(t / dayLength) * chartW
                    }
                    let yFor: (Int) -> CGFloat = { v in
                        chartH - chartH * CGFloat(v) / yMax
                    }

                    Path { p in
                        guard let first = points.first else { return }
                        p.move(to: CGPoint(x: xFor(first.date), y: chartH))
                        for s in points {
                            p.addLine(to: CGPoint(x: xFor(s.date), y: yFor(s.value)))
                        }
                        if let last = points.last {
                            p.addLine(to: CGPoint(x: xFor(last.date), y: chartH))
                        }
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            LivityTheme.good.opacity(0.45),
                            LivityTheme.caution.opacity(0.25),
                            LivityTheme.bad.opacity(0.10)
                        ]),
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: chartW, height: chartH)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Path { p in
                        for (i, s) in points.enumerated() {
                            let pt = CGPoint(x: xFor(s.date), y: yFor(s.value))
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                    }
                    .stroke(LinearGradient(
                        gradient: Gradient(colors: [LivityTheme.bad, LivityTheme.caution, LivityTheme.good]),
                        startPoint: .bottom, endPoint: .top),
                            style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                    .frame(width: chartW, height: chartH)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct StressIntradayChart: View {
    let samples: [(date: Date, value: Int)]
    let dayStart: Date

    var body: some View {
        GeometryReader { geo in
            let yLabelWidth: CGFloat = 28
            let chartW = geo.size.width - yLabelWidth
            let chartH = geo.size.height - 18  // bottom hour labels
            let cal = Calendar.current
            let startOfDay = cal.startOfDay(for: dayStart)
            let dayLength: TimeInterval = 24 * 60 * 60
            let yMax: CGFloat = 100

            ZStack {
                // Y-axis labels and dashed gridlines
                VStack(spacing: 0) {
                    ForEach([100, 75, 50, 25, 0], id: \.self) { val in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(LivityTheme.separator.opacity(0.3))
                                .frame(height: 1)
                            Text("\(val)")
                                .font(.system(size: 10))
                                .foregroundStyle(LivityTheme.textTertiary)
                                .frame(width: yLabelWidth, alignment: .trailing)
                        }
                        if val != 0 { Spacer() }
                    }
                }
                .frame(height: chartH)
                .frame(maxHeight: .infinity, alignment: .top)

                // Bottom hour labels
                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Text("0").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("6").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("12").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("18").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                        Spacer()
                        Text("24").font(.system(size: 10)).foregroundStyle(LivityTheme.textTertiary)
                    }
                    .padding(.trailing, yLabelWidth)
                    .frame(height: 14)
                }

                // Curve + gradient fill — drawn in the chart area only.
                if samples.count >= 2 {
                    let xFor: (Date) -> CGFloat = { date in
                        let t = max(0, min(dayLength, date.timeIntervalSince(startOfDay)))
                        return CGFloat(t / dayLength) * chartW
                    }
                    let yFor: (Int) -> CGFloat = { v in
                        chartH - chartH * CGFloat(v) / yMax
                    }

                    // Filled area below the line
                    Path { p in
                        guard let first = samples.first else { return }
                        p.move(to: CGPoint(x: xFor(first.date), y: chartH))
                        for s in samples {
                            p.addLine(to: CGPoint(x: xFor(s.date), y: yFor(s.value)))
                        }
                        if let last = samples.last {
                            p.addLine(to: CGPoint(x: xFor(last.date), y: chartH))
                        }
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            LivityTheme.bad.opacity(0.45),
                            LivityTheme.caution.opacity(0.35),
                            LivityTheme.good.opacity(0.10)
                        ]),
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: chartW, height: chartH)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Stroke line
                    Path { p in
                        for (i, s) in samples.enumerated() {
                            let pt = CGPoint(x: xFor(s.date), y: yFor(s.value))
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                    }
                    .stroke(LinearGradient(
                        gradient: Gradient(colors: [LivityTheme.good, LivityTheme.caution, LivityTheme.bad]),
                        startPoint: .bottom, endPoint: .top),
                            style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                    .frame(width: chartW, height: chartH)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// Formats a duration for heart-zone rows: "6h 2m 39s", "14m 32s", "42s", or "0s".
private func formatDuration(seconds: Double) -> String {
    let total = Int(seconds.rounded())
    guard total > 0 else { return "0s" }
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return "\(h)h \(m)m \(s)s" }
    if m > 0 { return "\(m)m \(s)s" }
    return "\(s)s"
}

@ViewBuilder
private func trendRowView(icon: String, title: String, history: [Double],
                          higherIsBetter: Bool = true,
                          format: (Double) -> String) -> some View {
    if let summary = TrendSummary.make(history: history,
                                       higherIsBetter: higherIsBetter,
                                       formatValue: format,
                                       formatDelta: format) {
        TrendRow(
            icon: icon, iconColor: summary.valueColor,
            title: title, valueText: summary.valueText, valueColor: summary.valueColor,
            deltaText: summary.deltaText, comparison: summary.comparison,
            points: summary.points
        )
    } else {
        TrendRow(
            icon: icon, iconColor: LivityTheme.textTertiary,
            title: title, valueText: "—", valueColor: LivityTheme.textTertiary,
            deltaText: "Not enough history", comparison: "",
            points: Array(repeating: 0.5, count: 16)
        )
    }
}

// MARK: - Body Battery detail

struct LivityBodyBatteryDetail: View {
    let metrics: LivityDailyMetrics
    let onDismiss: () -> Void

    @State private var virtualCoachExpanded = false
    @State private var phasesExpanded = false

    /// Full day of circadian phases. These are textbook chronobiology archetypes —
    /// every user sees the same ranges; we don't have intraday physiology data
    /// granular enough to personalise them yet. Times are rounded to the hour to
    /// avoid implying minute-level precision we don't have.
    private static var allPhases: [(name: String, range: String, icon: String, color: Color)] {
        [
            ("livity.phase.earlyNight".localized, "22:00 – 03:00", "moon.stars.fill", LivityTheme.purple),
            ("livity.phase.circadianNadir".localized, "03:00 – 05:00", "moon.zzz.fill", LivityTheme.info),
            ("livity.phase.earlyMorning".localized, "05:00 – 08:00", "sunrise.fill", LivityTheme.good),
            ("livity.phase.morningPeak".localized, "08:00 – 12:00", "sun.max.fill", LivityTheme.good),
            ("livity.phase.midday".localized, "12:00 – 14:00", "sun.max.circle.fill", LivityTheme.caution),
            ("livity.phase.afternoonDip".localized, "14:00 – 16:00", "sun.min.fill", LivityTheme.warning),
            ("livity.phase.evening".localized, "17:00 – 21:00", "sunset.fill", LivityTheme.warning)
        ]
    }

    private var percent: Int { metrics.bodyBattery ?? 0 }
    private var accent: Color {
        percent >= 50 ? LivityTheme.good : percent >= 25 ? LivityTheme.warning : LivityTheme.bad
    }

    var body: some View {
        LivityDetailShell(title: "Body Battery", selectedDate: metrics.date, onDismiss: onDismiss) {
            // Ring + percent card
            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 20) {
                    LivityRingWithContent(progress: Double(percent) / 100, color: accent, lineWidth: 10, size: 110) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(accent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(percent)")
                                .font(.system(size: 46, weight: .bold))
                                .foregroundStyle(accent)
                            Text("%")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(accent)
                        }
                        Text("livity.bodyBattery.currentLevel".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(LivityTheme.textSecondary)
                        HStack(spacing: 6) {
                            Text(Self.timeFormatter.string(from: Date()))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LivityTheme.textSecondary)
                            LivityChip(text: "Estimate", tint: LivityTheme.chipFill)
                        }
                    }
                    Spacer()
                }

                Divider().overlay(LivityTheme.separator)

                // Virtual coach
                Button { withAnimation { virtualCoachExpanded.toggle() } } label: {
                    HStack {
                        Image(systemName: "lightbulb.fill").foregroundStyle(LivityTheme.warning)
                        Text("livity.bbDetail.virtualCoach".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Spacer()
                        Image(systemName: virtualCoachExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LivityTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                if virtualCoachExpanded {
                    Text("livity.bbDetail.virtualCoachText".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: LivityTheme.cardRadius).fill(LivityTheme.goodTint.opacity(0.55)))

            // Charged / Drained chips — derived from sleep restoration vs strain+stress depletion.
            // Without an intraday battery curve we approximate: sleep recharges, activity drains.
            let chargedPct: Int = Int(((metrics.sleepScore ?? 0) * 0.6).rounded())
            let strainShare = (metrics.strainPercent ?? 0) * 0.5
            let stressShare = Double(metrics.stressNow ?? 0) * 0.4
            let drainedPct: Int = Int(min(100, max(0, strainShare + stressShare)).rounded())
            HStack(spacing: 12) {
                statChip(icon: "battery.100.bolt", tint: LivityTheme.goodTint, color: LivityTheme.good,
                         title: "livity.bbDetail.charged".localized, value: "\(chargedPct)%")
                statChip(icon: "battery.25", tint: LivityTheme.badTint, color: LivityTheme.bad,
                         title: "livity.bbDetail.drained".localized, value: "\(drainedPct)%")
            }

            // Battery chart section
            VStack(alignment: .leading, spacing: 8) {
                DetailSectionHeader(icon: "chart.line.uptrend.xyaxis", iconColor: LivityTheme.info, title: "livity.bbDetail.chart".localized)
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill)
                    if metrics.stressIntraday.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "bolt.slash")
                                .font(.system(size: 24))
                                .foregroundStyle(LivityTheme.textTertiary)
                            Text("No intraday heart rate data for this day")
                                .font(.system(size: 13))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    } else {
                        BodyBatteryIntradayChart(samples: metrics.stressIntraday, dayStart: metrics.date)
                            .padding(14)
                    }
                }
                .frame(height: 240)
            }

            // Circadian rhythms
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(icon: "circle.dashed", iconColor: LivityTheme.info, title: "livity.bbDetail.rhythms".localized)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        circadianChip(name: "livity.phase.earlyNight".localized, range: "22:07 – 02:55", dotColor: .purple)
                        circadianChip(name: "livity.phase.circadianNadir".localized, range: "02:55 – 05:02", dotColor: LivityTheme.info)
                        circadianChip(name: "livity.phase.earlyMorning".localized, range: "05:02 – 07:30", dotColor: LivityTheme.good)
                        circadianChip(name: "livity.phase.afternoonDip".localized, range: "13:52 – 16:13", dotColor: LivityTheme.warning)
                    }
                }
            }

            // Current phase card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    LivityChip(text: "livity.bbDetail.currentPhase".localized, tint: LivityTheme.warningTint)
                    Spacer()
                    Text(Self.timeFormatter.string(from: Date()))
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textTertiary)
                }
                HStack(spacing: 10) {
                    Image(systemName: "sun.min.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(LivityTheme.warning))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metrics.bodyBatteryPhase?.name ?? "livity.phase.afternoonDip".localized)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Text("\(metrics.bodyBatteryPhase?.startTime ?? "13:52") – \(metrics.bodyBatteryPhase?.endTime ?? "16:13")")
                            .font(.system(size: 13))
                            .foregroundStyle(LivityTheme.textSecondary)
                    }
                    Spacer()
                    Button { withAnimation { phasesExpanded.toggle() } } label: {
                        Image(systemName: phasesExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LivityTheme.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(LivityTheme.chipFill))
                    }
                    .buttonStyle(.plain)
                }
                LivityChip(text: metrics.bodyBatteryPhase?.subtitle ?? "livity.phase.afternoonDip.subtitle".localized,
                           icon: "bolt.fill",
                           tint: LivityTheme.warningTint)
                if phasesExpanded {
                    Divider().overlay(LivityTheme.separator).padding(.top, 4)
                    VStack(spacing: 10) {
                        ForEach(Self.allPhases, id: \.name) { phase in
                            phaseRow(name: phase.name, range: phase.range, icon: phase.icon, color: phase.color)
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill))

            // What is body battery info
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(icon: "info.circle.fill", iconColor: LivityTheme.info, title: "livity.bbDetail.whatIs".localized)
                Text("livity.bbDetail.description".localized)
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    infoRow(icon: "heart.fill", tint: LivityTheme.info, text: "livity.bbDetail.factor.hrv".localized)
                    infoRow(icon: "bolt.fill", tint: LivityTheme.info, text: "livity.bbDetail.factor.stress".localized)
                    infoRow(icon: "figure.walk", tint: LivityTheme.info, text: "livity.bbDetail.factor.activity".localized)
                    infoRow(icon: "bed.double.fill", tint: LivityTheme.info, text: "livity.bbDetail.factor.sleep".localized)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill))
        }
    }

    private func statChip(icon: String, tint: Color, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivityTheme.textSecondary)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint))
    }

    private func phaseRow(name: String, range: String, icon: String, color: Color) -> some View {
        let isCurrent = (metrics.bodyBatteryPhase?.name ?? "Afternoon Dip") == name
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color))
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(range)
                    .font(.system(size: 12))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Spacer()
            if isCurrent {
                LivityChip(text: "livity.bbDetail.now".localized, tint: LivityTheme.warningTint)
            }
        }
    }

    private func circadianChip(name: String, range: String, dotColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
            Text(range)
                .font(.system(size: 12))
                .foregroundStyle(LivityTheme.textSecondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(LivityTheme.cardFill))
    }

    private func infoRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(LivityTheme.textPrimary)
            Spacer()
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

// MARK: - Stress / Strain detail (shared layout)

struct LivityStrainDetail: View {
    let metrics: LivityDailyMetrics
    let isStressVariant: Bool
    let onDismiss: () -> Void

    private var percent: Int {
        isStressVariant ? (metrics.stressNow ?? 0) : Int(metrics.strainPercent ?? 0)
    }
    private var accent: Color {
        if isStressVariant {
            return LivityStressBand.from(value: percent).color
        }
        return percent >= 67 ? LivityTheme.good : percent >= 33 ? LivityTheme.warning : LivityTheme.bad
    }
    private var title: String { isStressVariant ? "Stress Level" : "Strain" }
    private var headerColor: Color { LivityTheme.badTint.opacity(0.55) }

    var body: some View {
        LivityDetailShell(title: title, selectedDate: metrics.date, onDismiss: onDismiss) {
            if isStressVariant {
                stressBody
            } else {
                strainBody
            }
        }
    }

    // MARK: - Stress layout (intraday HR-based view)

    @ViewBuilder
    private var stressBody: some View {
        todaysStressCard()
        if !metrics.stressIntraday.isEmpty {
            stressChartCard()
        }
        stressBreakdownCard()
        stressExplainerCard()
    }

    @ViewBuilder
    private func todaysStressCard() -> some View {
        let nowValue = metrics.stressNow
        let band: (label: String, color: Color)? = nowValue.map {
            switch $0 {
            case ..<20: return ("Relaxed", LivityTheme.good)
            case ..<40: return ("Low Stress", LivityTheme.good)
            case ..<60: return ("Moderate", LivityTheme.caution)
            case ..<80: return ("High Stress", LivityTheme.bad)
            default: return ("Very High", LivityTheme.bad)
            }
        }
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile").foregroundStyle(LivityTheme.good)
                    Text("TODAY'S STRESS").font(.system(size: 12, weight: .bold)).foregroundStyle(LivityTheme.textPrimary)
                }
                Text(nowValue.map(String.init) ?? "—")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(band?.color ?? LivityTheme.textPrimary)
                Text(band?.label ?? "No data")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(band?.color ?? LivityTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(width: 1).overlay(LivityTheme.separator)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 12) {
                stressStatRow(icon: "waveform.path.ecg", iconColor: LivityTheme.good,
                              label: "Average", value: metrics.stressAverage, valueColor: LivityTheme.good)
                stressStatRow(icon: "arrow.up", iconColor: LivityTheme.caution,
                              label: "Peak", value: metrics.stressPeak, valueColor: LivityTheme.caution)
                stressStatRow(icon: "arrow.down", iconColor: LivityTheme.good,
                              label: "Low", value: metrics.stressLow, valueColor: LivityTheme.good)
            }
            .padding(.leading, 12)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: LivityTheme.cardRadius).fill(LivityTheme.goodTint.opacity(0.5)))
    }

    private func stressStatRow(icon: String, iconColor: Color, label: String, value: Int?, valueColor: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(iconColor).frame(width: 14)
            Text(label).font(.system(size: 13)).foregroundStyle(LivityTheme.textSecondary)
            Spacer()
            Text(value.map(String.init) ?? "—")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }

    @ViewBuilder
    private func stressChartCard() -> some View {
        let intraday = metrics.stressIntraday
        let last = intraday.last
        let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
        let lastBand: (label: String, color: Color)? = last.map {
            switch $0.value {
            case ..<20: return ("Relaxed", LivityTheme.good)
            case ..<40: return ("Low Stress", LivityTheme.good)
            case ..<60: return ("Moderate", LivityTheme.caution)
            case ..<80: return ("High Stress", LivityTheme.bad)
            default: return ("Very High", LivityTheme.bad)
            }
        }
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "chart.xyaxis.line", iconColor: LivityTheme.info, title: "Stress Chart")
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let last {
                            HStack(spacing: 6) {
                                Image(systemName: "clock").foregroundStyle(LivityTheme.textSecondary)
                                Text(timeFmt.string(from: last.date)).font(.system(size: 13, weight: .semibold)).foregroundStyle(LivityTheme.textPrimary)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(LivityTheme.chipFill))
                        }
                        Spacer()
                        if let last, let band = lastBand {
                            HStack(spacing: 6) {
                                Text("\(last.value)").font(.system(size: 14, weight: .bold)).foregroundStyle(band.color)
                                Text("%").font(.system(size: 11)).foregroundStyle(LivityTheme.textSecondary)
                                Image(systemName: "heart.fill").foregroundStyle(band.color)
                                Text(band.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(band.color)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(band.color.opacity(0.15)))
                        }
                    }
                    StressIntradayChart(samples: intraday, dayStart: metrics.date)
                        .frame(height: 200)
                }
                .padding(14)
            }
        }
    }

    private func computeStressBreakdown() -> (low: Double, medium: Double, high: Double) {
        // Each sample contributes the gap-until-next-sample (capped at 5 min) into
        // its band. Mirrors the Heart Zones calculation so totals are consistent.
        let intraday = metrics.stressIntraday
        var low: Double = 0, medium: Double = 0, high: Double = 0
        let cap: TimeInterval = 5 * 60
        for i in 0..<intraday.count {
            let gap: TimeInterval
            if i + 1 < intraday.count {
                gap = min(max(0, intraday[i + 1].date.timeIntervalSince(intraday[i].date)), cap)
            } else {
                gap = 60
            }
            let mins = gap / 60
            switch intraday[i].value {
            case ..<40: low += mins
            case ..<60: medium += mins
            default: high += mins
            }
        }
        return (low, medium, high)
    }

    @ViewBuilder
    private func stressBreakdownCard() -> some View {
        let breakdown = computeStressBreakdown()
        let lowMin = breakdown.low
        let medMin = breakdown.medium
        let highMin = breakdown.high
        let total = max(0.0001, lowMin + medMin + highMin)
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "chart.pie.fill", iconColor: LivityTheme.info, title: "Stress Breakdown")
            VStack(spacing: 14) {
                stressBreakdownRow(label: "Low Stress", color: LivityTheme.good, minutes: lowMin, total: total)
                stressBreakdownRow(label: "Medium Stress", color: LivityTheme.caution, minutes: medMin, total: total)
                stressBreakdownRow(label: "High Stress", color: LivityTheme.bad, minutes: highMin, total: total)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
        }
    }

    private func stressBreakdownRow(label: String, color: Color, minutes: Double, total: Double) -> some View {
        let pct = total > 0 ? minutes / total : 0
        return VStack(spacing: 6) {
            HStack {
                Text(label).font(.system(size: 14)).foregroundStyle(LivityTheme.textPrimary)
                Spacer()
                Text(String(format: "%.0f%%", pct * 100))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                Text(formatHM(minutes: minutes))
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LivityTheme.separator.opacity(0.4)).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * pct, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func formatHM(minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    @ViewBuilder
    private func stressExplainerCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "questionmark.circle.fill", iconColor: LivityTheme.info, title: "What is Stress Level?")
            VStack(alignment: .leading, spacing: 12) {
                Text("AION estimates stress from your heart rate throughout the day using the Karvonen heart-rate-reserve formula (your max HR minus your resting HR). The result is mapped onto a 0–100 scale based on how hard your heart is working compared to rest.")
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    stressBandLegendRow(range: "0–20", label: "Relaxed", color: LivityTheme.good)
                    stressBandLegendRow(range: "20–40", label: "Low Stress", color: LivityTheme.good)
                    stressBandLegendRow(range: "40–60", label: "Moderate", color: LivityTheme.caution)
                    stressBandLegendRow(range: "60–80", label: "High Stress", color: LivityTheme.bad)
                    stressBandLegendRow(range: "80–100", label: "Very High", color: LivityTheme.bad)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
        }
    }

    private func stressBandLegendRow(range: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(range)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 70, alignment: .leading)
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 14)).foregroundStyle(LivityTheme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Strain layout (activity-based view, unchanged)

    @ViewBuilder
    private var strainBody: some View {
        VStack(spacing: 14) {
            LivityRingWithContent(progress: Double(percent) / 100, color: accent, lineWidth: 11, size: 130) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(percent)")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }
            LivityChip(text: "Estimate", tint: LivityTheme.chipFill)
            DetailAIAnalysisCard(text:
                LivityAnalysisNarrative.buildStrain(for: metrics)
                ?? "Not enough data yet to analyse your strain for today.")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: LivityTheme.cardRadius).fill(headerColor))

        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "figure.run", iconColor: LivityTheme.info, title: "Activities")
            if metrics.workouts.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 22))
                        .foregroundStyle(LivityTheme.info)
                    Text("No activities recorded for today")
                        .font(.system(size: 13))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
            } else {
                VStack(spacing: 8) {
                    ForEach(metrics.workouts) { workout in
                        workoutRow(workout)
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "heart.fill", iconColor: LivityTheme.bad, title: "Today's Heart Zones")
            let zoneMinutes = metrics.heartZoneMinutes
            let zoneTotal = zoneMinutes.reduce(0, +)
            let b = metrics.heartZoneBounds
            let zoneLabels: [String] = b.count >= 4
                ? ["<\(b[0] + 1) bpm",
                   "\(b[0] + 1) – \(b[1]) bpm",
                   "\(b[1] + 1) – \(b[2]) bpm",
                   "\(b[2] + 1) – \(b[3]) bpm",
                   "≥\(b[3] + 1) bpm"]
                : ["Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5"]
            let zoneColors: [Color] = [
                LivityTheme.good,
                Color(red: 0.85, green: 0.74, blue: 0.25),
                LivityTheme.warning,
                LivityTheme.bad,
                LivityTheme.purple
            ]
            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { i in
                    let mins = zoneMinutes.indices.contains(i) ? zoneMinutes[i] : 0
                    let fraction = zoneTotal > 0 ? mins / zoneTotal : 0
                    heartZoneRow(
                        n: i + 1,
                        label: zoneLabels[i],
                        color: zoneColors[i],
                        time: formatDuration(seconds: mins * 60),
                        percent: zoneTotal > 0 ? String(format: "%.2f%%", fraction * 100) : "0.00%",
                        progress: fraction
                    )
                }
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "Monthly Trends")
            trendRowView(icon: "gauge.with.dots.needle.67percent", title: "Strain Score",
                         history: metrics.strainHistory, format: formatPercentValue)
            trendRowView(icon: "flame.fill", title: "Active Energy",
                         history: metrics.activeEnergyHistory, format: formatKcalValue)
            trendRowView(icon: "bolt.fill", title: "Total Energy",
                         history: metrics.totalEnergyHistory, format: formatKcalValue)
            trendRowView(icon: "figure.walk", title: "Steps",
                         history: metrics.stepsHistory, format: formatIntValue)
            trendRowView(icon: "stopwatch", title: "Exercise Time",
                         history: metrics.exerciseMinutesHistory, format: formatMinutesValue)
            trendRowView(icon: "figure.stairs", title: "Floors Climbed",
                         history: metrics.floorsClimbedHistory, format: formatIntValue)
        }
    }

    private func workoutRow(_ workout: LivityWorkout) -> some View {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f
        }()
        let durMin = Int(workout.durationMinutes.rounded())
        let durText = durMin >= 60 ? "\(durMin / 60)h \(durMin % 60)m" : "\(durMin)m"
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(LivityTheme.info.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: workout.icon).foregroundStyle(LivityTheme.info)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text("\(timeFormatter.string(from: workout.startDate)) · \(durText)")
                    .font(.system(size: 12))
                    .foregroundStyle(LivityTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let kcal = workout.activeEnergyKcal {
                    Text("\(Int(kcal.rounded())) kcal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivityTheme.warning)
                }
                if let km = workout.distanceKm, km > 0 {
                    Text(String(format: "%.2f km", km))
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
    }

    private func heartZoneRow(n: Int, label: String, color: Color, time: String, percent: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Zone \(n) ·")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                Text(time)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                LivityChip(text: percent, tint: color.opacity(0.18))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.08)))
    }
}

// MARK: - Nutrition / Energy Balance detail

struct LivityNutritionDetail: View {
    let metrics: LivityDailyMetrics
    let onDismiss: () -> Void

    @State private var trendPeriod: Int = 0 // 0 = 7d, 1 = 30d

    var body: some View {
        LivityDetailShell(title: "Nutrition", selectedDate: metrics.date, onDismiss: onDismiss) {
            // Energy balance card
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife").foregroundStyle(LivityTheme.good)
                        Text("ENERGY BALANCE")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                    }
                    Text(metrics.energyLogged ? "Logged" : "No food logged today")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("Use MyFitnessPal, Cronometer, or any Apple Health app")
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "fork.knife")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(LivityTheme.good.opacity(0.8))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: LivityTheme.cardRadius).fill(LivityTheme.goodTint.opacity(0.55)))

            // Daily goals pill
            HStack(spacing: 10) {
                Rectangle().fill(LivityTheme.good).frame(width: 3, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY GOALS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LivityTheme.textSecondary)
                    Text("Maintenance")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(LivityTheme.textTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: LivityTheme.cardRadius).fill(LivityTheme.cardFill))

            // Energy expenditure — real values from HealthKit
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(icon: "flame.fill", iconColor: LivityTheme.warning, title: "Energy Expenditure")
                let active = metrics.activeEnergyKcal ?? 0
                let total = metrics.totalEnergyKcal ?? 0
                let basal = max(0, total - active)
                // TEF (thermic effect of food) ≈ 10% of consumed calories. Only counted when food is logged.
                let tef = (metrics.caloriesConsumed ?? 0) * 0.10
                let tdee = total + tef
                let denom = max(1, tdee)
                let basalPct = basal / denom
                let activePct = active / denom
                let tefPct = tef / denom
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle().fill(LivityTheme.info).frame(width: geo.size.width * basalPct, height: 8)
                            Rectangle().fill(LivityTheme.warning).frame(width: geo.size.width * activePct, height: 8)
                            Rectangle().fill(LivityTheme.good).frame(width: geo.size.width * tefPct, height: 8)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)

                    HStack(alignment: .top, spacing: 0) {
                        expColumn(color: LivityTheme.info, label: "Basal",
                                  value: formatKcal(basal),
                                  pct: String(format: "%.0f%%", basalPct * 100))
                        expColumn(color: LivityTheme.warning, label: "Active",
                                  value: formatKcal(active),
                                  pct: String(format: "%.0f%%", activePct * 100))
                        expColumn(color: LivityTheme.good, label: "TEF",
                                  value: formatKcal(tef),
                                  pct: String(format: "%.0f%%", tefPct * 100))
                    }

                    Divider().overlay(LivityTheme.separator)

                    HStack {
                        Text("Total Daily Energy Expenditure")
                            .font(.system(size: 14))
                            .foregroundStyle(LivityTheme.textSecondary)
                        Spacer()
                        Text(formatKcal(tdee))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                    }
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk").foregroundStyle(LivityTheme.textSecondary)
                            Text("Activity Level")
                                .font(.system(size: 14))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                        Spacer()
                        Text(ProfileStore.shared.activityGoal.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LivityTheme.warning)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.warningTint.opacity(0.5)))
            }

            // Macro targets — protein target comes from Profile → Nutrition Preferences:
            // either the user's manual gram target OR (when set to auto) 1.4 g/kg of
            // their logged body weight. We never fabricate a weight if the user hasn't
            // logged one in Apple Health.
            do {
                let prefs = ProfileStore.shared
                let proteinTarget: Double? = {
                    if !prefs.proteinAuto { return Double(prefs.proteinManualG) }
                    if let weight = metrics.bodyMassKg { return weight * 1.4 }
                    return nil
                }()
                let calorieTarget: Double? = {
                    if !prefs.calorieAuto { return Double(prefs.calorieManual) }
                    if let total = metrics.totalEnergyKcal { return total }
                    return nil
                }()
                let proteinActual = metrics.dietaryProtein ?? 0
                let carbs = metrics.dietaryCarbs ?? 0
                let fat = metrics.dietaryFat ?? 0

                if proteinTarget != nil || calorieTarget != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "Macro Targets")
                        VStack(alignment: .leading, spacing: 12) {
                            if let calorieTarget {
                                macroRow(label: "Calories", actual: metrics.caloriesConsumed ?? 0,
                                         target: calorieTarget, color: LivityTheme.warning)
                            }
                            if let proteinTarget {
                                macroRow(label: "Protein", actual: proteinActual,
                                         target: proteinTarget, color: LivityTheme.info)
                            }
                            if carbs > 0 {
                                macroRow(label: "Carbs", actual: carbs,
                                         target: carbs, color: LivityTheme.caution)
                            }
                            if fat > 0 {
                                macroRow(label: "Fat", actual: fat,
                                         target: fat, color: LivityTheme.good)
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "scalemass").foregroundStyle(LivityTheme.textSecondary)
                                Text(prefs.proteinAuto
                                     ? (metrics.bodyMassKg.map { String(format: "Auto · %.0fkg body weight", $0) } ?? "Auto")
                                     : "Manual targets")
                                    .font(.system(size: 12))
                                    .foregroundStyle(LivityTheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "Macro Targets")
                        VStack(spacing: 6) {
                            Image(systemName: "scalemass").font(.system(size: 22)).foregroundStyle(LivityTheme.info)
                            Text("Log your body weight in Apple Health")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LivityTheme.textPrimary)
                            Text("Or set a manual protein target in Profile → Nutrition Preferences.")
                                .font(.system(size: 12))
                                .foregroundStyle(LivityTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
                    }
                }
            }

            // Energy Balance Trend — real history
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "Energy Balance Trend")
                    HStack(spacing: 6) {
                        segmentButton(title: "7 Days", selected: trendPeriod == 0) { trendPeriod = 0 }
                        segmentButton(title: "30 Days", selected: trendPeriod == 1) { trendPeriod = 1 }
                    }
                }
                let windowSize = trendPeriod == 0 ? 7 : 30
                let intake = Array(metrics.caloriesConsumedHistory.suffix(windowSize))
                let burn = Array(metrics.caloriesBurnedHistory.suffix(windowSize))
                let loggedIntake = intake.filter { $0 > 0 }
                let avgIntake = loggedIntake.isEmpty ? 0 : loggedIntake.reduce(0, +) / Double(loggedIntake.count)
                let pairs = zip(intake, burn).map { $0 - $1 }
                let loggedBalance = Array(zip(intake, burn)).filter { $0.0 > 0 }.map { $0.0 - $0.1 }
                let avgBalance = loggedBalance.isEmpty ? 0 : loggedBalance.reduce(0, +) / Double(loggedBalance.count)
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(LivityTheme.goodTint.opacity(0.35))
                        if loggedIntake.isEmpty && burn.allSatisfy({ $0 == 0 }) {
                            Text("No data")
                                .font(.system(size: 13))
                                .foregroundStyle(LivityTheme.textTertiary)
                        } else {
                            energyBalanceChart(intake: intake, burn: burn, balance: pairs)
                                .padding(10)
                        }
                    }
                    .frame(height: 140)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Avg. Intake").font(.system(size: 12)).foregroundStyle(LivityTheme.textSecondary)
                            Text(formatKcal(avgIntake))
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(LivityTheme.good)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Avg. Balance").font(.system(size: 12)).foregroundStyle(LivityTheme.textSecondary)
                            Text(signedKcal(avgBalance))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(avgBalance >= 0 ? LivityTheme.warning : LivityTheme.good)
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
            }
        }
    }

    private func expColumn(color: Color, label: String, value: String, pct: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(LivityTheme.textPrimary)
            }
            Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(LivityTheme.textPrimary)
            Text(pct).font(.system(size: 11)).foregroundStyle(LivityTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroRow(label: String, actual: Double, target: Double, color: Color) -> some View {
        let progress = target > 0 ? min(1.0, actual / target) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(label) Target")
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(actual.rounded()))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("/ \(Int(target.rounded()))g")
                        .font(.system(size: 13))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LivityTheme.separator.opacity(0.5)).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func formatKcal(_ value: Double) -> String {
        let n = Int(value.rounded())
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "\(f.string(from: NSNumber(value: n)) ?? "\(n)") kcal"
    }

    private func signedKcal(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        let sign = rounded >= 0 ? "+" : "−"
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "\(sign)\(f.string(from: NSNumber(value: abs(rounded))) ?? "\(abs(rounded))") kcal"
    }

    @ViewBuilder
    private func energyBalanceChart(intake: [Double], burn: [Double], balance: [Double]) -> some View {
        GeometryReader { geo in
            let allValues = intake + burn
            let mx = (allValues.max() ?? 1)
            let minV: Double = 0
            let span = max(1, mx - minV)
            let stepX = intake.count > 1 ? geo.size.width / CGFloat(intake.count - 1) : 0
            ZStack {
                // Burned (orange)
                Path { p in
                    for (i, v) in burn.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = geo.size.height - CGFloat((v - minV) / span) * geo.size.height
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(LivityTheme.warning, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                // Intake (green) — only connect non-zero points
                Path { p in
                    var started = false
                    for (i, v) in intake.enumerated() {
                        guard v > 0 else { started = false; continue }
                        let x = CGFloat(i) * stepX
                        let y = geo.size.height - CGFloat((v - minV) / span) * geo.size.height
                        if !started { p.move(to: CGPoint(x: x, y: y)); started = true } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(LivityTheme.good, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    private func segmentButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? LivityTheme.textPrimary : LivityTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(selected ? LivityTheme.chipFill : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sleep detail

struct LivitySleepDetail: View {
    let metrics: LivityDailyMetrics
    let onDismiss: () -> Void

    private var percent: Int { Int(metrics.sleepScore ?? 0) }
    private var accent: Color {
        percent >= 70 ? LivityTheme.good : percent >= 50 ? LivityTheme.warning : LivityTheme.bad
    }

    var body: some View {
        LivityDetailShell(title: "Sleep", selectedDate: metrics.date, onDismiss: onDismiss) {
            // Ring + AI
            VStack(spacing: 14) {
                LivityRingWithContent(progress: Double(percent) / 100, color: accent, lineWidth: 11, size: 120) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(percent)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Text("%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LivityTheme.textSecondary)
                    }
                }
                DetailAIAnalysisCard(text:
                    LivityAnalysisNarrative.buildSleep(for: metrics)
                    ?? "No sleep recorded yet for today.")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: LivityTheme.cardRadius).fill(LivityTheme.badTint.opacity(0.5)))

            Text("There is no data to show for today, select previous dates or go to sleep and check it out next morning!")
                .font(.system(size: 13))
                .foregroundStyle(LivityTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Sleep coach — derived from real history
            sleepCoachCard()

            // Sleep stages
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(icon: "bed.double.fill", iconColor: LivityTheme.info, title: "Sleep Stages")
                let total = metrics.sleepTotalMinutes ?? 0
                let deep = metrics.sleepDeepMinutes ?? 0
                let core = metrics.sleepCoreMinutes ?? 0
                let rem = metrics.sleepREMMinutes ?? 0
                let awake = metrics.sleepAwakeMinutes ?? 0
                VStack(spacing: 8) {
                    stageRow(color: LivityTheme.info, icon: "moon.fill", name: "Deep",
                             value: formatMinutesShort(deep),
                             pct: total > 0 ? String(format: "%.1f%%", deep / total * 100) : "0.0%",
                             progress: total > 0 ? deep / total : 0)
                    stageRow(color: LivityTheme.info, icon: "bed.double.fill", name: "Core",
                             value: formatMinutesShort(core),
                             pct: total > 0 ? String(format: "%.1f%%", core / total * 100) : "0.0%",
                             progress: total > 0 ? core / total : 0)
                    stageRow(color: LivityTheme.info, icon: "eye", name: "REM",
                             value: formatMinutesShort(rem),
                             pct: total > 0 ? String(format: "%.1f%%", rem / total * 100) : "0.0%",
                             progress: total > 0 ? rem / total : 0)
                    stageRow(color: LivityTheme.warning, icon: "sun.max.fill", name: "Awake",
                             value: formatMinutesShort(awake),
                             pct: (total + awake) > 0 ? String(format: "%.1f%%", awake / (total + awake) * 100) : "0.0%",
                             progress: (total + awake) > 0 ? awake / (total + awake) : 0)
                    stageRow(color: LivityTheme.good, icon: "clock.fill", name: "Total Sleep Time",
                             value: formatMinutesShort(total),
                             pct: nil,
                             progress: min(1.0, total / 480.0))
                }
            }

            // Heart rate + respiratory rate
            sleepEmptyCard(icon: "heart.fill", color: LivityTheme.info, title: "Sleep Heart Rate", emptyTitle: "No heart rate data",
                           subtitle: "Heart rate during sleep is recorded by Apple Watch or compatible devices")
            sleepEmptyCard(icon: "lungs.fill", color: LivityTheme.info, title: "Sleep Respiratory Rate", emptyTitle: "No respiratory rate data",
                           subtitle: "Respiratory rate is recorded during sleep by Apple Watch or compatible devices")

            // Sleep inconsistencies — derived from real bedtime/wake history
            sleepInconsistenciesCard()

            // Monthly trends
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "Monthly Trends")
                trendRowView(icon: "moon.stars.fill", title: "Sleep Score",
                             history: metrics.sleepScoreHistory, format: formatPercentValue)
                trendRowView(icon: "moon.fill", title: "Deep Sleep",
                             history: metrics.sleepDeepHistory, format: formatMinutesValue)
                trendRowView(icon: "eye", title: "REM",
                             history: metrics.sleepREMHistory, format: formatMinutesValue)
                trendRowView(icon: "sun.max.fill", title: "Awake",
                             history: metrics.sleepAwakeHistory, higherIsBetter: false,
                             format: formatMinutesValue)
                trendRowView(icon: "clock.fill", title: "Sleep Time",
                             history: metrics.sleepTotalHistory, format: formatMinutesValue)
            }
        }
    }

    private struct SleepCoachInputs {
        let recommendedMinutes: Double
        let recHours: Int
        let recMin: Int
        let wakeDate: Date
        let bedDate: Date
        let extraTonight: Double
        let weeklyDebtHours: Double
        let last7Count: Int
    }

    private func sleepCoachInputs() -> SleepCoachInputs {
        let prefs = LivityPreferences.shared
        let goalMinutes = prefs.sleepGoalMinutes
        let last7 = Array(metrics.sleepTotalHistory.suffix(7)).filter { $0 > 0 }
        let debtMinutes = max(0, last7.reduce(0) { $0 + max(0, goalMinutes - $1) })
        let extraTonight = min(60, debtMinutes / 3)
        let recommendedMinutes = goalMinutes + extraTonight
        let wakeDate = prefs.wakeTargetDate(for: metrics.date)
        let bedDate = Calendar.current.date(byAdding: .minute, value: -Int(recommendedMinutes), to: wakeDate) ?? wakeDate
        return SleepCoachInputs(
            recommendedMinutes: recommendedMinutes,
            recHours: Int(recommendedMinutes / 60),
            recMin: Int(recommendedMinutes.truncatingRemainder(dividingBy: 60)),
            wakeDate: wakeDate,
            bedDate: bedDate,
            extraTonight: extraTonight,
            weeklyDebtHours: debtMinutes / 60,
            last7Count: last7.count
        )
    }

    /// Standard deviation of bedtimes (in minutes-of-day, accounting for wrap-around).
    private func bedtimeStdDevMinutes(_ bedtimes: [Date]) -> Double? {
        guard bedtimes.count >= 3 else { return nil }
        let cal = Calendar.current
        // Map each bedtime to minutes-of-day, treating before-noon as previous-night (add 24h).
        let minutes: [Double] = bedtimes.map { date in
            let h = Double(cal.component(.hour, from: date))
            let m = Double(cal.component(.minute, from: date))
            let raw = h * 60 + m
            return raw < 12 * 60 ? raw + 24 * 60 : raw
        }
        let mean = minutes.reduce(0, +) / Double(minutes.count)
        let variance = minutes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(minutes.count)
        return variance.squareRoot()
    }

    @ViewBuilder
    private func sleepInconsistenciesCard() -> some View {
        let bedtimes = metrics.bedtimeHistory.compactMap { $0 }
        let wakeTimes = metrics.wakeTimeHistory.compactMap { $0 }
        let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
        let inputs = sleepCoachInputs()
        let goalMinutes = LivityPreferences.shared.sleepGoalMinutes

        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "Sleep Inconsistencies")
            if bedtimes.count < 3 {
                VStack(spacing: 6) {
                    Image(systemName: "moon.stars").font(.system(size: 22)).foregroundStyle(LivityTheme.info)
                    Text("Need at least 3 nights of sleep data")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    Text("Wear your watch overnight or sync sleep data from Apple Health to see your weekly schedule.")
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
            } else {
                let std = bedtimeStdDevMinutes(bedtimes) ?? 0
                let consistencyLabel = std < 30 ? "Consistent" : std < 60 ? "Variable" : "Irregular"
                let consistencyColor: Color = std < 30 ? LivityTheme.good : std < 60 ? LivityTheme.warning : LivityTheme.bad
                let debtHours = inputs.weeklyDebtHours
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "moon.zzz.fill").foregroundStyle(LivityTheme.info)
                                Text(String(format: "%.1fh", debtHours))
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(LivityTheme.textPrimary)
                            }
                            Text("SLEEP DEBT (7d)").font(.system(size: 11, weight: .semibold)).foregroundStyle(LivityTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: std < 30 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(consistencyColor)
                                Text(consistencyLabel).font(.system(size: 15, weight: .bold)).foregroundStyle(LivityTheme.textPrimary)
                            }
                            Text(String(format: "±%.0f min variance", std))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                    Text("Last \(min(7, bedtimes.count)) nights")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivityTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    let weekDateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f }()
                    let pairs: [(bed: Date, wake: Date)] = zip(metrics.bedtimeHistory, metrics.wakeTimeHistory)
                        .compactMap { bed, wake in
                            guard let bed, let wake else { return nil }
                            return (bed, wake)
                        }
                    ForEach(Array(pairs.suffix(7).enumerated()), id: \.offset) { _, pair in
                        let durMin = pair.wake.timeIntervalSince(pair.bed) / 60
                        let belowGoal = durMin < goalMinutes
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(weekDateFmt.string(from: pair.wake))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LivityTheme.textPrimary)
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading) {
                                        Text("Bedtime").font(.system(size: 11)).foregroundStyle(LivityTheme.textSecondary)
                                        Text(timeFmt.string(from: pair.bed)).font(.system(size: 14, weight: .bold)).foregroundStyle(LivityTheme.textPrimary)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Wake up").font(.system(size: 11)).foregroundStyle(LivityTheme.textSecondary)
                                        Text(timeFmt.string(from: pair.wake)).font(.system(size: 14, weight: .bold)).foregroundStyle(LivityTheme.textPrimary)
                                    }
                                }
                            }
                            Spacer()
                            LivityChip(
                                text: belowGoal ? "Below Goal" : "On Goal",
                                icon: belowGoal ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                                tint: belowGoal ? LivityTheme.badTint : LivityTheme.goodTint
                            )
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
            }
        }
        // wakeTimes is unused but kept for future per-day metrics; suppress warning.
        let _ = wakeTimes
    }

    @ViewBuilder
    private func sleepCoachCard() -> some View {
        let inputs = sleepCoachInputs()
        let recHours = inputs.recHours
        let recMin = inputs.recMin
        let wakeDate = inputs.wakeDate
        let bedDate = inputs.bedDate
        let extraTonight = inputs.extraTonight
        let weeklyDebtHours = inputs.weeklyDebtHours
        let last7Count = inputs.last7Count
        let goalMinutes = LivityPreferences.shared.sleepGoalMinutes
        let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
        let debtChip = extraTonight >= 5
            ? "+\(Int(extraTonight)) min vs your goal"
            : "On track with your goal"
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "moon.stars.fill", iconColor: LivityTheme.info, title: "Sleep Coach")
            Text(last7Count == 0
                 ? "Need at least one night of sleep data to personalise this."
                 : "Personalized recommendation for tonight")
                .font(.system(size: 12))
                .foregroundStyle(LivityTheme.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended for Tonight")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(LivityTheme.textSecondary)
                        Text("\(recHours)h \(recMin)m")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(LivityTheme.info)
                        LivityChip(text: debtChip, tint: extraTonight > 0 ? LivityTheme.badTint : LivityTheme.goodTint)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        timeCell(icon: "bed.double.fill", title: "Suggested Bedtime", value: timeFmt.string(from: bedDate))
                        timeCell(icon: "alarm.fill", title: "Suggested Wake Up", value: timeFmt.string(from: wakeDate))
                        HStack(spacing: 4) {
                            Image(systemName: "target").foregroundStyle(LivityTheme.textSecondary)
                            Text("Goal").font(.system(size: 11)).foregroundStyle(LivityTheme.textSecondary)
                            Spacer()
                            Text("\(Int(goalMinutes / 60))h").font(.system(size: 12, weight: .semibold)).foregroundStyle(LivityTheme.textPrimary)
                        }
                    }
                }
                Divider().overlay(LivityTheme.separator)
                VStack(alignment: .leading, spacing: 6) {
                    Text("What's Affecting Your Sleep")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LivityTheme.textPrimary)
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill").foregroundStyle(weeklyDebtHours > 1 ? LivityTheme.bad : LivityTheme.good)
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Sleep Debt").font(.system(size: 13, weight: .semibold)).foregroundStyle(LivityTheme.textPrimary)
                                Spacer()
                                LivityChip(
                                    text: weeklyDebtHours > 0 ? String(format: "%.1fh", weeklyDebtHours) : "0h",
                                    tint: weeklyDebtHours > 1 ? LivityTheme.badTint : LivityTheme.goodTint
                                )
                            }
                            Text(last7Count == 0
                                 ? "No sleep recorded in the past 7 days"
                                 : String(format: "You're %.1fh behind your goal over the past %d nights", weeklyDebtHours, last7Count))
                                .font(.system(size: 12))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                    if last7Count < 5 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(LivityTheme.warning)
                            Text("More sleep data needed for accurate recommendations")
                                .font(.system(size: 12))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
        }
    }

    private func timeCell(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(LivityTheme.info)
            VStack(alignment: .leading) {
                Text(title).font(.system(size: 10)).foregroundStyle(LivityTheme.textSecondary)
                Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(LivityTheme.textPrimary)
            }
        }
    }

    private func stageRow(color: Color, icon: String, name: String, value: String, pct: String?, progress: Double) -> some View {
        let valueColor: Color = progress > 0 ? LivityTheme.textPrimary : LivityTheme.bad
        return VStack(spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(name).font(.system(size: 14, weight: .semibold)).foregroundStyle(LivityTheme.textPrimary)
                Spacer()
                Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(valueColor)
                if let pct {
                    LivityChip(text: pct, tint: color.opacity(0.22))
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LivityTheme.separator).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, progress)), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(LivityTheme.cardFill))
    }

    private func formatMinutesShort(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    private func sleepEmptyCard(icon: String, color: Color, title: String, emptyTitle: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: icon, iconColor: color, title: title)
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(color)
                Text(emptyTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
        }
    }
}

// MARK: - Recovery detail

struct LivityRecoveryDetail: View {
    let metrics: LivityDailyMetrics
    let onDismiss: () -> Void

    private var hasScore: Bool { metrics.recoveryScore != nil }
    private var percent: Int { Int(metrics.recoveryScore ?? 0) }
    private var accent: Color {
        guard hasScore else { return LivityTheme.textTertiary }
        return percent >= 70 ? LivityTheme.good : percent >= 50 ? LivityTheme.caution : LivityTheme.bad
    }
    private var heroTint: Color {
        guard hasScore else { return LivityTheme.neutralTint }
        return percent >= 70 ? LivityTheme.goodTint : percent >= 50 ? LivityTheme.cautionTint : LivityTheme.badTint
    }

    private var aiText: String {
        guard hasScore else {
            return "No recovery data available yet. Wear your Apple Watch overnight to capture HRV and resting heart rate."
        }
        switch percent {
        case 85...:
            return "Your recovery is excellent at \(percent)%. HRV and resting heart rate both sit well above baseline — your body is primed for a demanding day. Go for that harder session if you planned one."
        case 70..<85:
            return "Your recovery is strong at \(percent)%. HRV and RHR both look healthy, so normal training loads are appropriate today."
        case 50..<70:
            return "Your recovery is moderate at \(percent)%. HRV and RHR are near baseline but not optimal — consider a lighter training day or prioritising sleep tonight."
        case 30..<50:
            return "Your recovery is below average at \(percent)%. Your body is showing signs of accumulated strain — prefer active recovery or rest today."
        default:
            return "Your recovery is low at \(percent)%. HRV is suppressed or RHR is elevated. Rest, hydration, and extra sleep are the priority."
        }
    }

    var body: some View {
        LivityDetailShell(title: "Recovery", selectedDate: metrics.date, onDismiss: onDismiss) {
            // Hero
            VStack(spacing: 14) {
                LivityRingWithContent(progress: Double(percent) / 100, color: accent, lineWidth: 11, size: 120) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(hasScore ? "\(percent)" : "—")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        if hasScore {
                            Text("%")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(LivityTheme.textSecondary)
                        }
                    }
                }
                DetailAIAnalysisCard(text: aiText)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: LivityTheme.cardRadius).fill(heroTint.opacity(0.7)))

            // Snapshot cards — Today | 2-Month Avg | Change. Show only HRV + RHR
            // up top because they're the two signals that *drive* the recovery
            // score; everything else lives in Monthly Trends below.
            RecoverySnapshotCard(
                icon: "waveform.path.ecg", iconColor: LivityTheme.info,
                title: "Heart Rate Variability",
                today: metrics.hrv, history: metrics.hrvHistory,
                lastMeasured: metrics.hrvSampleDate,
                unit: "ms", digits: 0, higherIsBetter: true
            )

            RecoverySnapshotCard(
                icon: "heart.fill", iconColor: LivityTheme.bad,
                title: "Resting Heart Rate",
                today: metrics.restingHR, history: metrics.restingHRHistory,
                lastMeasured: metrics.restingHRSampleDate,
                unit: "bpm", digits: 0, higherIsBetter: false
            )

            // Section divider — Monthly Trends section only contains metrics
            // we *measure* (HRV, RHR, Resp, SpO2, WristTemp). Recovery score
            // is intentionally excluded: it's a derived value computed from
            // today's HRV/RHR snapshot, so a sparkline would mix the live
            // formula with daily-averaged history and visibly disagree with
            // the hero number.
            DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "Monthly Trends")
                .padding(.top, 4)

            RecoveryTrendCard(
                icon: "waveform.path.ecg", iconColor: LivityTheme.info,
                title: "HRV",
                today: metrics.hrv, history: metrics.hrvHistory,
                unit: "ms", digits: 0, higherIsBetter: true
            )

            RecoveryTrendCard(
                icon: "heart.fill", iconColor: LivityTheme.bad,
                title: "RHR",
                today: metrics.restingHR, history: metrics.restingHRHistory,
                unit: "bpm", digits: 0, higherIsBetter: false
            )

            RecoveryTrendCard(
                icon: "lungs.fill", iconColor: LivityTheme.info,
                title: "Respiratory",
                today: metrics.respiratoryRate, history: metrics.respiratoryRateHistory,
                unit: "BRPM", digits: 0, higherIsBetter: false
            )

            RecoveryTrendCard(
                icon: "drop.fill", iconColor: LivityTheme.info,
                title: "SpO₂",
                today: metrics.spo2, history: metrics.spo2History,
                unit: "%", digits: 0, higherIsBetter: true
            )

            RecoveryTrendCard(
                icon: "thermometer.medium", iconColor: LivityTheme.warning,
                title: "Wrist Temperature",
                today: metrics.wristTempFahrenheit, history: metrics.wristTempHistory,
                unit: "°F", digits: 1, higherIsBetter: true
            )

            // Cardio fitness — VO2 max from Apple Health (ml/(kg·min)).
            RecoveryTrendCard(
                icon: "wind", iconColor: LivityTheme.purple,
                title: "Cardio Fitness",
                today: metrics.vo2Max, history: metrics.vo2MaxHistory,
                unit: "VO₂ max", digits: 1, higherIsBetter: true
            )

            // Mindfulness — daily minute totals from the Mindfulness app or any
            // Health-Kit-writing meditation app.
            RecoveryTrendCard(
                icon: "leaf.circle.fill", iconColor: LivityTheme.good,
                title: "Mindful Minutes",
                today: metrics.mindfulMinutes, history: metrics.mindfulMinutesHistory,
                unit: "min", digits: 0, higherIsBetter: true
            )

            // Blood pressure — show systolic as the headline. Diastolic is
            // recorded as a separate quantity but always paired with systolic
            // in the same reading.
            if let sys = metrics.bloodPressureSystolic, sys > 0 {
                BloodPressureCard(
                    systolic: sys,
                    diastolic: metrics.bloodPressureDiastolic,
                    sampleDate: metrics.bloodPressureSampleDate,
                    systolicHistory: metrics.bloodPressureSystolicHistory
                )
            }

            // Blood glucose (mg/dL) — most recent reading + history.
            if metrics.bloodGlucose != nil || !metrics.bloodGlucoseHistory.filter({ $0 > 0 }).isEmpty {
                RecoveryTrendCard(
                    icon: "drop.degreesign", iconColor: LivityTheme.warning,
                    title: "Blood Glucose",
                    today: metrics.bloodGlucose, history: metrics.bloodGlucoseHistory,
                    unit: "mg/dL", digits: 0, higherIsBetter: false
                )
            }

            // AFib burden (% of time in atrial fibrillation, iOS 16+).
            if let afib = metrics.atrialFibBurdenPct, afib > 0 {
                RecoveryTrendCard(
                    icon: "heart.text.square.fill", iconColor: LivityTheme.bad,
                    title: "AFib Burden",
                    today: afib, history: metrics.atrialFibBurdenHistory,
                    unit: "%", digits: 1, higherIsBetter: false
                )
            }

            // Sleeping breathing disturbances (iOS 18+) — overnight event count.
            if metrics.sleepBreathingDisturbances != nil || !metrics.sleepBreathingDisturbancesHistory.filter({ $0 > 0 }).isEmpty {
                RecoveryTrendCard(
                    icon: "lungs.fill", iconColor: LivityTheme.bad,
                    title: "Sleep Breathing Issues",
                    today: metrics.sleepBreathingDisturbances,
                    history: metrics.sleepBreathingDisturbancesHistory,
                    unit: "events", digits: 0, higherIsBetter: false
                )
            }

            // Walking speed (m/s) — Apple Watch mobility metric.
            if metrics.walkingSpeed != nil || !metrics.walkingSpeedHistory.filter({ $0 > 0 }).isEmpty {
                RecoveryTrendCard(
                    icon: "figure.walk.motion", iconColor: LivityTheme.info,
                    title: "Walking Speed",
                    today: metrics.walkingSpeed, history: metrics.walkingSpeedHistory,
                    unit: "m/s", digits: 2, higherIsBetter: true
                )
            }

            // Symptoms logged today (each is a category sample with severity
            // 1-3). Hidden when nothing is logged so the section doesn't
            // surface an empty state.
            if !metrics.symptomsToday.isEmpty {
                SymptomsTodayCard(symptoms: metrics.symptomsToday)
            }
        }
    }
}

// MARK: - Blood pressure card (systolic / diastolic pair)

/// Specialised trend card that shows systolic over diastolic on the same row,
/// the actual sample timestamp, and a sparkline of systolic history. Diastolic
/// gets its own series too but isn't charted to keep the card scannable.
private struct BloodPressureCard: View {
    let systolic: Double
    let diastolic: Double?
    let sampleDate: Date?
    let systolicHistory: [Double]

    private var validHistory: [Double] { systolicHistory.filter { $0 > 0 } }
    private var baseline: Double? {
        let recent = Array(validHistory.suffix(60))
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }
    private var changePct: Double? {
        guard let avg = baseline, avg > 0 else { return nil }
        return (systolic - avg) / avg * 100
    }
    private var headlineColor: Color {
        guard let pct = changePct else { return LivityTheme.textSecondary }
        // Lower BP is generally healthier — flag rises in red.
        return pct <= 0 ? LivityTheme.good : LivityTheme.bad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(LivityTheme.bad)
                    Text("BLOOD PRESSURE")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(LivityTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(systolic))")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(headlineColor)
                        Text("/")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(LivityTheme.textSecondary)
                        Text(diastolic.map { "\(Int($0))" } ?? "—")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(headlineColor)
                        Text("mmHg")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(headlineColor.opacity(0.85))
                    }
                    if let date = sampleDate {
                        Text(Self.timeFormatter.string(from: date))
                            .font(.system(size: 11))
                            .foregroundStyle(LivityTheme.textTertiary)
                    }
                }
            }
            if let baseline, validHistory.count >= 2 {
                LivityAreaTrendChart(
                    history: systolicHistory,
                    baseline: baseline,
                    higherIsBetter: false,
                    accentColor: LivityTheme.bad
                )
                .frame(height: 80)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.bad.opacity(0.08)))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()
}

// MARK: - Symptoms-today card

/// Lists every symptom the user logged in Apple Health today, sorted by
/// severity. Severity uses the standard 1-3 scale: mild / moderate / severe.
private struct SymptomsTodayCard: View {
    let symptoms: [(name: String, severity: Int)]

    private func color(for severity: Int) -> Color {
        switch severity {
        case 3: return LivityTheme.bad
        case 2: return LivityTheme.warning
        default: return LivityTheme.caution
        }
    }
    private func label(for severity: Int) -> String {
        switch severity {
        case 3: return "Severe"
        case 2: return "Moderate"
        default: return "Mild"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "exclamationmark.bubble.fill", iconColor: LivityTheme.warning, title: "Symptoms Today")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(symptoms.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Circle()
                            .fill(color(for: item.severity))
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Spacer()
                        Text(label(for: item.severity))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(color(for: item.severity))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.warningTint.opacity(0.4)))
    }
}

// MARK: - Recovery snapshot (Today | Avg | Change)

/// Compact snapshot row used at the top of the Recovery detail. Three columns
/// (today / 2-month avg / change %) plus a "Last measured" timestamp. Stays
/// short so the user doesn't need to scroll past a forest of charts before
/// seeing the headline numbers.
private struct RecoverySnapshotCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let today: Double?
    let history: [Double]
    /// End-date of the actual most-recent HealthKit sample — used for the
    /// "Last measured" line. Never substitute `Date()` here; nil = no real
    /// measurement to report and the line should be hidden.
    let lastMeasured: Date?
    let unit: String
    let digits: Int
    let higherIsBetter: Bool

    private var validHistory: [Double] { history.filter { $0 > 0 } }
    private var twoMonthAvg: Double? {
        let recent = Array(validHistory.suffix(60))
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }
    private var changePct: Double? {
        guard let t = today, t > 0, let avg = twoMonthAvg, avg > 0 else { return nil }
        return (t - avg) / avg * 100
    }
    private var changeColor: Color {
        guard let pct = changePct else { return LivityTheme.textSecondary }
        let isImprovement = higherIsBetter ? pct >= 0 : pct <= 0
        return isImprovement ? LivityTheme.good : LivityTheme.bad
    }
    private var lastMeasuredText: String? {
        guard let date = lastMeasured else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "Last measured: \(f.string(from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailSectionHeader(icon: icon, iconColor: iconColor, title: title)
            HStack(spacing: 0) {
                snapshotColumn(value: formatted(today), label: "TODAY", color: iconColor)
                Divider().frame(width: 1, height: 36).overlay(LivityTheme.separator)
                snapshotColumn(value: formatted(twoMonthAvg), label: "2 MONTH AVG", color: iconColor)
                Divider().frame(width: 1, height: 36).overlay(LivityTheme.separator)
                snapshotColumn(value: changePctText, label: "CHANGE", color: changeColor)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 14).fill(iconColor.opacity(0.10)))

            if let lastMeasuredText {
                Text(lastMeasuredText)
                    .font(.system(size: 11))
                    .foregroundStyle(LivityTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text("No measurement today")
                    .font(.system(size: 11))
                    .foregroundStyle(LivityTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func snapshotColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(LivityTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatted(_ value: Double?) -> String {
        guard let v = value, v > 0 else { return "0 \(unit)" }
        return String(format: "%.\(digits)f %@", v, unit)
    }

    private var changePctText: String {
        guard let pct = changePct else { return "0.0%" }
        let arrow = pct >= 0 ? "↗" : "↘"
        return String(format: "%@ %.1f%%", arrow, abs(pct))
    }
}

// MARK: - Recovery monthly-trend card (with area chart)

/// Header (icon + title left, arrow + value + delta right) on top of a
/// 30-day area chart. The chart and dots get coloured by each day's
/// position relative to the user's mean — green when the day's value is
/// in the "good" direction, red when not. Days with no measurement are
/// dropped entirely so the line doesn't dive to zero on missing data.
private struct RecoveryTrendCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let today: Double?
    let history: [Double]
    let unit: String
    let digits: Int
    let higherIsBetter: Bool

    private var validHistory: [Double] { history.filter { $0 > 0 } }
    private var baseline: Double? {
        let recent = Array(validHistory.suffix(60))
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }
    private var changePct: Double? {
        guard let t = today, t > 0, let avg = baseline, avg > 0 else { return nil }
        return (t - avg) / avg * 100
    }
    private var headlineColor: Color {
        guard let pct = changePct else { return LivityTheme.textSecondary }
        let isImprovement = higherIsBetter ? pct >= 0 : pct <= 0
        return isImprovement ? LivityTheme.good : LivityTheme.bad
    }
    private var arrow: String {
        guard let pct = changePct else { return "→" }
        if abs(pct) < 0.5 { return "→" }
        return pct >= 0 ? "↗" : "↘"
    }
    private var comparisonLabel: String {
        guard let pct = changePct else { return "Normal" }
        if abs(pct) < 2 { return "Normal" }
        let isImprovement = higherIsBetter ? pct >= 0 : pct <= 0
        return isImprovement ? "Better than usual" : "Worse than usual"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(iconColor)
                    Text(title.uppercased())
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(LivityTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(arrow)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(headlineColor)
                        Text(today.map { String(format: "%.\(digits)f", $0) } ?? "—")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(headlineColor)
                        Text(unit)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(headlineColor.opacity(0.85))
                    }
                    if let pct = changePct, abs(pct) >= 0.1 {
                        Text(String(format: "%.2f%%", abs(pct)))
                            .font(.system(size: 12))
                            .foregroundStyle(LivityTheme.textPrimary)
                    }
                    Text(comparisonLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LivityTheme.textTertiary)
            }
            if let baseline, validHistory.count >= 2 {
                LivityAreaTrendChart(
                    history: history,
                    baseline: baseline,
                    higherIsBetter: higherIsBetter,
                    accentColor: iconColor
                )
                .frame(height: 80)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(iconColor.opacity(0.08)))
    }
}

// MARK: - Area trend chart

/// 30-day area chart used by Recovery monthly-trend cards. Draws the curve
/// across the most recent values (skipping zero-fill days), fills below it
/// with a green→red gradient anchored to the user's baseline, and dots each
/// sample by whether it's "good" or "bad" for this metric.
private struct LivityAreaTrendChart: View {
    let history: [Double]
    let baseline: Double
    let higherIsBetter: Bool
    let accentColor: Color

    private var points: [(index: Int, value: Double)] {
        let window = Array(history.suffix(30))
        return window.enumerated()
            .compactMap { idx, v in v > 0 ? (idx, v) : nil }
    }

    var body: some View {
        GeometryReader { geo in
            let pts = points
            if pts.count < 2 {
                EmptyView()
            } else {
                let values = pts.map(\.value)
                let mn = values.min() ?? 0
                let mx = values.max() ?? 1
                let span = max(mx - mn, 0.0001)
                let xStep = geo.size.width / CGFloat(max(1, min(30, history.suffix(30).count) - 1))
                let yFor: (Double) -> CGFloat = { v in
                    geo.size.height - geo.size.height * CGFloat((v - mn) / span) * 0.85 - geo.size.height * 0.075
                }
                let baselineY = yFor(min(max(baseline, mn), mx))

                ZStack {
                    // Filled area beneath the curve.
                    Path { p in
                        guard let first = pts.first else { return }
                        p.move(to: CGPoint(x: CGFloat(first.index) * xStep, y: geo.size.height))
                        for s in pts {
                            p.addLine(to: CGPoint(x: CGFloat(s.index) * xStep, y: yFor(s.value)))
                        }
                        if let last = pts.last {
                            p.addLine(to: CGPoint(x: CGFloat(last.index) * xStep, y: geo.size.height))
                        }
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            LivityTheme.good.opacity(0.40),
                            LivityTheme.caution.opacity(0.20),
                            LivityTheme.bad.opacity(0.10)
                        ]),
                        startPoint: .top, endPoint: .bottom))

                    // Dashed baseline.
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: baselineY))
                        p.addLine(to: CGPoint(x: geo.size.width, y: baselineY))
                    }
                    .stroke(LivityTheme.separator.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    // Per-segment line so colour can switch as the value crosses
                    // the baseline.
                    ForEach(0..<(pts.count - 1), id: \.self) { i in
                        let a = pts[i]
                        let b = pts[i + 1]
                        Path { p in
                            p.move(to: CGPoint(x: CGFloat(a.index) * xStep, y: yFor(a.value)))
                            p.addLine(to: CGPoint(x: CGFloat(b.index) * xStep, y: yFor(b.value)))
                        }
                        .stroke(segmentColor(a.value, b.value), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }

                    // Dots, coloured per their relation to baseline.
                    ForEach(Array(pts.enumerated()), id: \.offset) { _, item in
                        Circle()
                            .fill(dotColor(for: item.value))
                            .frame(width: 5, height: 5)
                            .position(x: CGFloat(item.index) * xStep, y: yFor(item.value))
                    }
                }
            }
        }
    }

    private func isGood(_ value: Double) -> Bool {
        higherIsBetter ? value >= baseline : value <= baseline
    }

    private func dotColor(for value: Double) -> Color {
        let dev = abs(value - baseline) / max(baseline, 0.0001)
        if dev < 0.02 { return LivityTheme.caution }
        return isGood(value) ? LivityTheme.good : LivityTheme.bad
    }

    private func segmentColor(_ a: Double, _ b: Double) -> Color {
        switch (isGood(a), isGood(b)) {
        case (true, true): return LivityTheme.good
        case (false, false): return LivityTheme.bad
        default: return LivityTheme.caution
        }
    }
}

// MARK: - Daylight detail (modal with X in corner)

struct LivityDaylightDetailSheet: View {
    let metrics: LivityDailyMetrics
    let onDismiss: () -> Void

    @State private var selectedPeriod: String = "1M"

    private let periods = ["1D", "1W", "1M", "3M", "6M", "1Y"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Time in Daylight Trends")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(LivityTheme.chipFill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let history = metrics.daylightHistory
                    let nonZero = history.filter { $0 > 0 }
                    let monthlyAvg: Int? = nonZero.isEmpty ? nil : nonZero.reduce(0, +) / nonZero.count
                    let topDateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()
                    let monthFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f }()
                    // Top stats — real values only; "—" when no data, never invented.
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topDateFmt.string(from: metrics.date)).font(.system(size: 13)).foregroundStyle(LivityTheme.textSecondary)
                            Text(metrics.daylightMinutes.map { formatHoursMinutes($0) } ?? "—")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(LivityTheme.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("30-day Average").font(.system(size: 13)).foregroundStyle(LivityTheme.textSecondary)
                            Text(monthlyAvg.map { formatHoursMinutes($0) } ?? "—")
                                .font(.system(size: 24, weight: .bold)).foregroundStyle(LivityTheme.textPrimary)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill))

                    // Month + period
                    HStack {
                        Text(monthFmt.string(from: metrics.date))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LivityTheme.textPrimary)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(periods, id: \.self) { p in
                                Button { selectedPeriod = p } label: {
                                    Text(p)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(selectedPeriod == p ? LivityTheme.textPrimary : LivityTheme.textSecondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(selectedPeriod == p ? Color.white : Color.clear))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LivityTheme.chipFill))
                    }

                    // Chart — sparkline of the windowed history. We only have 30-day data
                    // available right now; "1Y" / "6M" simply truncate to what we have.
                    let windowed = windowedDaylightHistory(history: history, period: selectedPeriod)
                    VStack(alignment: .leading, spacing: 10) {
                        if windowed.isEmpty {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill)
                                Text("No daylight data for this period")
                                    .font(.system(size: 13))
                                    .foregroundStyle(LivityTheme.textTertiary)
                            }
                            .frame(height: 200)
                        } else {
                            TrendSparkline(color: LivityTheme.warning, points: normalizedTrendPoints(windowed.map(Double.init)))
                                .frame(height: 200)
                            HStack {
                                if let firstDate = dateForOffset(windowed.count - 1) { Text(topDateFmt.string(from: firstDate)).font(.system(size: 11)).foregroundStyle(LivityTheme.textTertiary) }
                                Spacer()
                                Text(topDateFmt.string(from: metrics.date)).font(.system(size: 11)).foregroundStyle(LivityTheme.textTertiary)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "sun.max.fill").foregroundStyle(LivityTheme.warning)
                            Text("What is Time in Daylight?")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(LivityTheme.textPrimary)
                        }
                        Text("Time in daylight measures how long you spend in natural sunlight each day. Daylight exposure is essential for regulating your circadian rhythm, boosting vitamin D production, improving mood, and supporting better sleep quality.")
                            .font(.system(size: 13))
                            .foregroundStyle(LivityTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .background(LivityTheme.background.ignoresSafeArea())
    }

    private func formatHoursMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// Truncates the daylight history to the selected period. We only fetch 30 days
    /// of history right now, so 3M/6M/1Y collapse to whatever we have.
    private func windowedDaylightHistory(history: [Int], period: String) -> [Int] {
        let count: Int
        switch period {
        case "1D": count = 1
        case "1W": count = 7
        case "1M": count = 30
        case "3M": count = 90
        case "6M": count = 180
        case "1Y": count = 365
        default: count = history.count
        }
        return Array(history.suffix(min(count, history.count)))
    }

    /// Date offset back from the selected day; used for chart axis labels.
    private func dateForOffset(_ daysBack: Int) -> Date? {
        Calendar.current.date(byAdding: .day, value: -daysBack, to: metrics.date)
    }
}

// MARK: - Car Tier detail sheet

struct LivityCarTierDetailSheet: View {
    let metrics: LivityDailyMetrics
    let onDismiss: () -> Void

    @StateObject private var imageLoader = LivityCarImageLoader()

    private var carScore: Int? { GeminiResultStore.loadCarScore() ?? GeminiResultStore.loadHealthScore() }
    private var carModel: String? { GeminiResultStore.loadCarName() }
    private var carWikiName: String? { GeminiResultStore.loadCarWikiName() ?? GeminiResultStore.loadCarName() }
    private var tier: HealthTier? { carScore.map(HealthTier.forScore) }
    private var breakdown: [String: Int] { GeminiResultStore.loadScoreBreakdown() ?? [:] }

    private let componentOrder: [(key: String, labelKey: String, icon: String)] = [
        ("health",        "livity.carTier.metric.health",        "heart.fill"),
        ("sleep",         "livity.carTier.metric.sleep",         "moon.fill"),
        ("readiness",     "livity.carTier.metric.readiness",     "bolt.fill"),
        ("energy",        "livity.carTier.metric.energy",        "battery.100.bolt"),
        ("nervousSystem", "livity.carTier.metric.nervousSystem", "waveform.path.ecg"),
        ("activity",      "livity.carTier.metric.activity",      "figure.walk"),
        ("loadBalance",   "livity.carTier.metric.loadBalance",   "scale.3d"),
        ("recoveryDebt",  "livity.carTier.metric.recoveryDebt",  "arrow.counterclockwise")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("livity.carTier.title".localized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(LivityTheme.chipFill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    if !breakdownRows.isEmpty {
                        breakdownSection
                    }
                    whatIsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .background(LivityTheme.background.ignoresSafeArea())
        .onAppear { imageLoader.load(wikiName: carWikiName) }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let tier, let score = carScore {
            VStack(spacing: 14) {
                if let wiki = imageLoader.image {
                    Image(uiImage: wiki)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                } else if imageLoader.isLoading {
                    ZStack {
                        if let image = UIImage(named: tier.imageName) {
                            Image(uiImage: image).resizable().scaledToFit().opacity(0.3)
                        } else {
                            Text(tier.emoji).font(.system(size: 80)).opacity(0.3)
                        }
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                } else if let image = UIImage(named: tier.imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                } else {
                    Text(tier.emoji).font(.system(size: 80))
                }
                VStack(spacing: 4) {
                    Text(carModel?.isEmpty == false ? carModel! : tier.tierLabel)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(tier.tierLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(tier.color))
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .heavy))
                        .foregroundStyle(Color(tier.color))
                    Text("%")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(tier.color))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(tier.color).opacity(0.12)))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "car")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(LivityTheme.info.opacity(0.6))
                Text("livity.carTier.empty.title".localized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text("livity.carTier.empty.subtitle".localized)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 20).fill(LivityTheme.infoTint))
        }
    }

    // MARK: - Breakdown

    private var breakdownRows: [(labelKey: String, icon: String, value: Int)] {
        componentOrder.compactMap { item in
            guard let v = breakdown[item.key], item.key != "car" else { return nil }
            return (item.labelKey, item.icon, v)
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "livity.carTier.breakdown".localized)
            VStack(spacing: 0) {
                ForEach(Array(breakdownRows.enumerated()), id: \.offset) { idx, row in
                    breakdownRow(labelKey: row.labelKey, icon: row.icon, value: row.value)
                    if idx < breakdownRows.count - 1 {
                        Divider().overlay(LivityTheme.separator)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 16).fill(LivityTheme.cardFill))
        }
    }

    private func breakdownRow(labelKey: String, icon: String, value: Int) -> some View {
        let color = colorForScore(value)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(labelKey.localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LivityTheme.textPrimary)
            Spacer()
            // Mini bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LivityTheme.chipFill)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, value))) / 100)
                }
            }
            .frame(width: 72, height: 6)
            Text("\(value)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(minWidth: 30, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }

    private func colorForScore(_ v: Int) -> Color {
        if v >= 70 { return LivityTheme.good }
        if v >= 45 { return LivityTheme.caution }
        return LivityTheme.bad
    }

    // MARK: - Info

    private var whatIsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill").foregroundStyle(LivityTheme.info)
                Text("livity.carTier.whatIs".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
            }
            Text("livity.carTier.description".localized)
                .font(.system(size: 13))
                .foregroundStyle(LivityTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
    }
}

// MARK: - AI Analysis detail sheet

struct LivityAIAnalysisDetailSheet: View {
    let onDismiss: () -> Void

    private var result: GeminiDailyResult? { GeminiResultStore.load() }

    private struct MetricSection {
        let titleKey: String
        let icon: String
        let score: Int?
        let explanation: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("livity.aiDetail.title".localized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LivityTheme.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(LivityTheme.chipFill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            ScrollView {
                if let result {
                    VStack(alignment: .leading, spacing: 18) {
                        heroSection(result: result)
                        recommendationsSection(result: result)
                        metricsSection(result: result)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                } else {
                    emptyState
                        .padding(40)
                }
            }
        }
        .background(LivityTheme.background.ignoresSafeArea())
    }

    // MARK: - Sections

    private func heroSection(result: GeminiDailyResult) -> some View {
        let score = result.scores.healthScore ?? 0
        let accent: Color = score >= 70 ? LivityTheme.good : score >= 45 ? LivityTheme.caution : LivityTheme.bad
        return VStack(spacing: 14) {
            ZStack {
                Circle().stroke(accent.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(100, score))) / 100)
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(score)").font(.system(size: 40, weight: .heavy)).foregroundStyle(accent)
                    Text("livity.aiDetail.healthScore".localized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LivityTheme.textSecondary)
                }
            }
            .frame(width: 140, height: 140)

            if let exp = result.scores.healthScoreExplanation, !exp.isEmpty {
                Text(exp)
                    .font(.system(size: 14))
                    .foregroundStyle(LivityTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(LivityTheme.infoTint.opacity(0.5)))
    }

    private func recommendationsSection(result: GeminiDailyResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "lightbulb.fill", iconColor: LivityTheme.warning, title: "livity.aiDetail.recommendations".localized)
            VStack(spacing: 10) {
                if !result.homeRecommendationMedical.isEmpty {
                    recommendationCard(icon: "stethoscope", tint: LivityTheme.info, titleKey: "livity.aiDetail.reco.medical", body: result.homeRecommendationMedical)
                }
                if !result.homeRecommendationSports.isEmpty {
                    recommendationCard(icon: "figure.run", tint: LivityTheme.good, titleKey: "livity.aiDetail.reco.sports", body: result.homeRecommendationSports)
                }
                if !result.homeRecommendationNutrition.isEmpty {
                    recommendationCard(icon: "fork.knife", tint: LivityTheme.warning, titleKey: "livity.aiDetail.reco.nutrition", body: result.homeRecommendationNutrition)
                }
            }
        }
    }

    private func recommendationCard(icon: String, tint: Color, titleKey: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(titleKey.localized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Text(body)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
    }

    private func metricsSection(result: GeminiDailyResult) -> some View {
        let s = result.scores
        let sections: [MetricSection] = [
            .init(titleKey: "livity.carTier.metric.sleep", icon: "moon.fill", score: s.sleepScore, explanation: s.sleepScoreExplanation),
            .init(titleKey: "livity.carTier.metric.readiness", icon: "bolt.fill", score: s.readinessScore, explanation: s.readinessScoreExplanation),
            .init(titleKey: "livity.carTier.metric.energy", icon: "battery.100.bolt", score: s.energyScore, explanation: s.energyScoreExplanation),
            .init(titleKey: "livity.carTier.metric.nervousSystem", icon: "waveform.path.ecg", score: s.nervousSystemBalance, explanation: s.nervousSystemBalanceExplanation),
            .init(titleKey: "livity.carTier.metric.activity", icon: "figure.walk", score: s.activityScore, explanation: s.activityScoreExplanation),
            .init(titleKey: "livity.carTier.metric.recoveryDebt", icon: "arrow.counterclockwise", score: s.recoveryDebt, explanation: s.recoveryDebtExplanation)
        ].filter { ($0.score != nil) || ($0.explanation?.isEmpty == false) }

        return VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(icon: "chart.bar.fill", iconColor: LivityTheme.info, title: "livity.aiDetail.breakdown".localized)
            VStack(spacing: 10) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    metricDetailCard(section: section)
                }
            }
        }
    }

    private func metricDetailCard(section: MetricSection) -> some View {
        let score = section.score ?? 0
        let color: Color = score >= 70 ? LivityTheme.good : score >= 45 ? LivityTheme.caution : LivityTheme.bad
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(color.opacity(0.18)).frame(width: 32, height: 32)
                    Image(systemName: section.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(section.titleKey.localized)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LivityTheme.textPrimary)
                Spacer()
                if section.score != nil {
                    Text("\(score)")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(color)
                }
            }
            if let exp = section.explanation, !exp.isEmpty {
                Text(exp)
                    .font(.system(size: 13))
                    .foregroundStyle(LivityTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(LivityTheme.cardFill))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(LivityTheme.info.opacity(0.6))
            Text("livity.aiDetail.empty.title".localized)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(LivityTheme.textPrimary)
            Text("livity.aiDetail.empty.subtitle".localized)
                .font(.system(size: 13))
                .foregroundStyle(LivityTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
