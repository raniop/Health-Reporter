//
//  AIONChartViews.swift
//  Health Reporter
//
//  Charts in Biological Correlations style – dark background, cyan-to-lime gradient line.
//

import SwiftUI
import Charts

// MARK: - Chart colors (cyan / turquoise / lime – matching the logo)
// Dynamic surface and text colors based on light/dark background
private enum ChartColors {
    static let primary = Color(uiColor: AIONDesign.accentPrimary)
    static let secondary = Color(uiColor: AIONDesign.accentSecondary)
    static let success = Color(uiColor: AIONDesign.accentSuccess)
    static var surface: Color { Color(uiColor: AIONDesign.surface) }
    static var background: Color { Color(uiColor: AIONDesign.background) }
    static var textSecondary: Color { Color(uiColor: AIONDesign.textSecondary) }

    static var lineGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary, success],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Dark chart container
private struct ChartDarkBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ChartColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Like chartDarkStyle but with horizontal padding – prevents Y-axis label clipping.
private struct ChartDarkBackgroundPadded: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .background(ChartColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension View {
    func chartDarkStyle() -> some View { modifier(ChartDarkBackground()) }
    /// For use in the activity page – Y-axis is not clipped.
    func chartDarkStylePadded() -> some View { modifier(ChartDarkBackgroundPadded()) }
}

// MARK: - 1. Readiness matrix (recovery vs strain)
struct ReadinessChartView: View {
    let data: ReadinessGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.recovery".localized, p.recovery))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.strain".localized, p.strain * 10))
                        .foregroundStyle(ChartColors.secondary)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 100)
            } else {
                ChartPlaceholderView(message: "chart.noReadinessData".localized, icon: "chart.line.uptrend.xyaxis")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - 2. Cardio efficiency (heart rate vs distance)
struct EfficiencyChartView: View {
    let data: EfficiencyGraphData
    private var hasHR: Bool { data.points.contains { $0.avgHeartRate != nil } }
    private var hasDistance: Bool { data.points.contains { ($0.distanceKm ?? 0) > 0 } }
    private var hasData: Bool { hasHR || hasDistance }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    if let hr = p.avgHeartRate {
                        BarMark(x: .value("chart.date".localized, p.date), y: .value("chart.heartRate".localized, hr), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.primary)
                    }
                    if let km = p.distanceKm, km > 0 {
                        LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.km".localized, km * 10))
                            .foregroundStyle(ChartColors.lineGradient)
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "chart.noHRDistanceData".localized, icon: "heart.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - 3. Sleep architecture
struct SleepArchitectureChartView: View {
    let data: SleepArchitectureGraphData
    private var visiblePoints: [SleepDayPoint] { data.points.filter { ($0.totalHours ?? 0) > 0 } }
    private var hasData: Bool { !visiblePoints.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(visiblePoints) { p in
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.sleep".localized, p.totalHours!))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 12)
            } else {
                ChartPlaceholderView(message: "chart.noSleepData".localized, icon: "bed.double.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - 4. Glucose and energy
struct GlucoseEnergyChartView: View {
    let data: GlucoseEnergyGraphData
    private var hasGlucose: Bool { data.points.contains { $0.glucose != nil } }
    private var hasEnergy: Bool { data.points.contains { ($0.activeEnergy ?? 0) > 0 } }
    private var hasData: Bool { hasGlucose || hasEnergy }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    if let g = p.glucose {
                        LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.glucose".localized, g))
                            .foregroundStyle(ChartColors.lineGradient)
                            .interpolationMethod(.catmullRom)
                    }
                    if let e = p.activeEnergy, e > 0 {
                        BarMark(x: .value("chart.date".localized, p.date), y: .value("chart.energy".localized, e / 50), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.secondary)
                    }
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "chart.noGlucoseEnergyData".localized, icon: "flame.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - 5. Autonomic balance
struct AutonomicRadarChartView: View {
    let data: AutonomicRadarData
    private var hasAny: Bool { data.rhr != nil || data.hrv != nil || data.respiratory != nil }
    var body: some View {
        Group {
            if hasAny {
                let rhr = data.rhr ?? 0
                let hrv = data.hrv ?? 0
                let resp = data.respiratory ?? 0
                Chart {
                    BarMark(x: .value("chart.metric".localized, "RHR"), y: .value("chart.value".localized, rhr), width: .ratio(0.5))
                        .foregroundStyle(ChartColors.primary)
                    BarMark(x: .value("chart.metric".localized, "HRV"), y: .value("chart.value".localized, hrv), width: .ratio(0.5))
                        .foregroundStyle(ChartColors.secondary)
                    BarMark(x: .value("chart.metric".localized, "chart.breathing".localized), y: .value("chart.value".localized, resp), width: .ratio(0.5))
                        .foregroundStyle(ChartColors.success)
                }
                .chartXScale(domain: ["RHR", "HRV", "chart.breathing".localized])
                .chartYScale(domain: 0 ... 100)
            } else {
                ChartPlaceholderView(message: "chart.noAutonomicData".localized, icon: "waveform.path.ecg")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - 6. Nutrition vs goals
struct NutritionChartView: View {
    let data: NutritionGraphData
    private var hasData: Bool {
        data.points.prefix(7).contains { p in
            (p.protein ?? 0) > 0 || (p.carbs ?? 0) > 0 || (p.fat ?? 0) > 0
        }
    }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points.prefix(7)) { p in
                    if let pr = p.protein, pr > 0 {
                        BarMark(x: .value("chart.date".localized, p.date), y: .value("chart.protein".localized, pr), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.primary)
                    }
                    if let c = p.carbs, c > 0 {
                        BarMark(x: .value("chart.date".localized, p.date), y: .value("chart.carbs".localized, c), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.secondary)
                    }
                    if let f = p.fat, f > 0 {
                        BarMark(x: .value("chart.date".localized, p.date), y: .value("chart.fat".localized, f), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.success)
                    }
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "chart.noNutritionData".localized, icon: "leaf.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - Placeholder (dark style – like the image)
struct ChartPlaceholderView: View {
    let message: String
    let icon: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(ChartColors.textSecondary)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(ChartColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChartColors.background)
    }
}

// MARK: - Alternatives for empty charts (same style – gradient, dark background)

struct DistanceChartView: View {
    let data: EfficiencyGraphData
    private var visiblePoints: [EfficiencyDataPoint] { data.points.filter { ($0.distanceKm ?? 0) > 0 } }
    private var points: [DayValuePoint] {
        visiblePoints.compactMap { p in
            guard let km = p.distanceKm, km > 0 else { return nil }
            return DayValuePoint(id: "\(p.date.timeIntervalSince1970)", day: dayLabel(from: p.date), value: km)
        }
    }
    private var hasData: Bool { !points.isEmpty }
    private var yMax: Double {
        let m = visiblePoints.compactMap(\.distanceKm).max() ?? 1
        return max(m * 1.15, 0.5)
    }
    var body: some View {
        Group {
            if hasData {
                Chart(points) { p in
                    BarMark(x: .value("chart.day".localized, p.day), y: .value("chart.km".localized, p.value), width: .ratio(0.55))
                        .foregroundStyle(LinearGradient(colors: [ChartColors.primary, ChartColors.success], startPoint: .bottom, endPoint: .top))
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... yMax)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(ChartColors.textSecondary)
                        AxisValueLabel().foregroundStyle(ChartColors.textSecondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            } else {
                ChartPlaceholderView(message: "chart.noDistanceData".localized, icon: "figure.walk")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStylePadded()
    }
}

struct ActiveEnergyChartView: View {
    let data: GlucoseEnergyGraphData
    private var visiblePoints: [GlucoseEnergyPoint] { data.points.filter { ($0.activeEnergy ?? 0) > 0 } }
    private var points: [DayValuePoint] {
        visiblePoints.compactMap { p in
            guard let kcal = p.activeEnergy, kcal > 0 else { return nil }
            return DayValuePoint(id: "\(p.date.timeIntervalSince1970)", day: dayLabel(from: p.date), value: kcal)
        }
    }
    private var hasData: Bool { !points.isEmpty }
    private var yMax: Double {
        let m = visiblePoints.compactMap(\.activeEnergy).max() ?? 1
        return max(m * 1.15, 50)
    }
    var body: some View {
        Group {
            if hasData {
                Chart(points) { p in
                    LineMark(x: .value("chart.day".localized, p.day), y: .value("chart.calories".localized, p.value))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... yMax)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(ChartColors.textSecondary)
                        AxisValueLabel().foregroundStyle(ChartColors.textSecondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            } else {
                ChartPlaceholderView(message: "chart.noActiveEnergyData".localized, icon: "flame.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStylePadded()
    }
}

struct AvgHeartRateTrendChartView: View {
    let data: EfficiencyGraphData
    private var visiblePoints: [EfficiencyDataPoint] { data.points.compactMap { p in p.avgHeartRate != nil ? p : nil } }
    private var hasData: Bool { !visiblePoints.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(visiblePoints) { p in
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.heartRate".localized, p.avgHeartRate!))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "chart.noHeartRateData".localized, icon: "heart.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - Weekly efficiency chart (bar chart Mon-Sun) – main dashboard
struct DashboardEfficiencyBarChartView: View {
    let data: ReadinessGraphData
    private var points: [(day: String, value: Double)] {
        let last7 = Array(data.points.suffix(7))
        return last7.enumerated().map { _, p in
            let formatter = DateFormatter()
            formatter.locale = LocalizationManager.shared.currentLocale
            formatter.dateFormat = "EEE"
            let day = formatter.string(from: p.date)
            return (day: day, value: p.recovery)
        }
    }
    private var hasData: Bool { !points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(points, id: \.day) { p in
                    BarMark(x: .value("chart.day".localized, p.day), y: .value("chart.recovery".localized, p.value), width: .ratio(0.55))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ChartColors.primary, ChartColors.success],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 105)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { _ in
                        AxisGridLine().foregroundStyle(ChartColors.textSecondary)
                        AxisValueLabel().foregroundStyle(ChartColors.textSecondary)
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            } else {
                ChartPlaceholderView(message: "chart.noData".localized, icon: "chart.bar.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

struct RecoveryTrendChartView: View {
    let data: ReadinessGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.recovery".localized, p.recovery))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 105)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { _ in
                        AxisGridLine().foregroundStyle(ChartColors.textSecondary)
                        AxisValueLabel().foregroundStyle(ChartColors.textSecondary)
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            } else {
                ChartPlaceholderView(message: "chart.noData".localized, icon: "chart.line.uptrend.xyaxis")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

struct StrainTrendChartView: View {
    let data: ReadinessGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.strain".localized, p.strain * 10))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 100)
            } else {
                ChartPlaceholderView(message: "chart.noData".localized, icon: "chart.line.uptrend.xyaxis")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

private struct DayValuePoint: Identifiable {
    let id: String
    let day: String
    let value: Double
}

private func dayLabel(from date: Date) -> String {
    let f = DateFormatter()
    f.locale = LocalizationManager.shared.currentLocale
    f.dateFormat = "d MMM"
    return f.string(from: date)
}

struct StepsChartView: View {
    let data: StepsGraphData
    private var visiblePoints: [StepsDataPoint] { data.points.filter { $0.steps > 0 } }
    private var points: [DayValuePoint] {
        visiblePoints.map { p in
            DayValuePoint(id: "\(p.date.timeIntervalSince1970)", day: dayLabel(from: p.date), value: p.steps)
        }
    }
    private var hasData: Bool { !points.isEmpty }
    private var yMax: Double {
        let m = visiblePoints.map(\.steps).max() ?? 1
        return max(m * 1.15, 1000)
    }
    var body: some View {
        Group {
            if hasData {
                Chart(points) { p in
                    BarMark(x: .value("chart.day".localized, p.day), y: .value("chart.steps".localized, p.value), width: .ratio(0.55))
                        .foregroundStyle(LinearGradient(colors: [ChartColors.primary, ChartColors.success], startPoint: .bottom, endPoint: .top))
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... yMax)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(ChartColors.textSecondary)
                        AxisValueLabel().foregroundStyle(ChartColors.textSecondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            } else {
                ChartPlaceholderView(message: "chart.noStepsData".localized, icon: "figure.walk")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStylePadded()
    }
}

struct RHRTrendChartView: View {
    let data: RHRTrendGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("chart.restingHR".localized, p.value))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "chart.noRestingHRData".localized, icon: "heart.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

struct HRVTrendChartView: View {
    let data: HRVTrendGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("chart.date".localized, p.date), y: .value("HRV", p.value))
                        .foregroundStyle(ChartColors.lineGradient)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "chart.noHRVData".localized, icon: "waveform.path.ecg")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .chartDarkStyle()
    }
}

// MARK: - Identifiable

extension ReadinessDataPoint: Identifiable { var id: Date { date } }
extension EfficiencyDataPoint: Identifiable { var id: Date { date } }
extension SleepDayPoint: Identifiable { var id: Date { date } }
extension GlucoseEnergyPoint: Identifiable { var id: Date { date } }
extension NutritionDayPoint: Identifiable { var id: Date { date } }
extension StepsDataPoint: Identifiable { var id: Date { date } }
extension TrendDataPoint: Identifiable { var id: Date { date } }
