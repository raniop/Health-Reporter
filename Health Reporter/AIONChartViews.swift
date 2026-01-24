//
//  AIONChartViews.swift
//  Health Reporter
//
//  6 הגרפים המקצועיים של AION – SwiftUI Charts.
//

import SwiftUI
import Charts

// MARK: - 1. Readiness Matrix (Recovery vs Strain)
struct ReadinessChartView: View {
    let data: ReadinessGraphData
    var body: some View {
        Chart(data.points) { p in
            LineMark(x: .value("תאריך", p.date), y: .value("התאוששות", p.recovery))
                .foregroundStyle(ChartColors.recovery)
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("תאריך", p.date), y: .value("עומס", p.strain * 10))
                .foregroundStyle(ChartColors.strain)
                .interpolationMethod(.catmullRom)
        }
        .chartXScale(domain: .automatic)
        .chartYScale(domain: 0 ... 100)
    }
}

// MARK: - 2. Cardiovascular Efficiency
struct EfficiencyChartView: View {
    let data: EfficiencyGraphData
    var body: some View {
        Chart(data.points) { p in
            if let hr = p.avgHeartRate {
                BarMark(x: .value("תאריך", p.date), y: .value("דופק", hr), width: .ratio(0.5))
                    .foregroundStyle(ChartColors.recovery)
            }
            if let km = p.distanceKm, km > 0 {
                LineMark(x: .value("תאריך", p.date), y: .value("ק\"מ", km * 10))
                    .foregroundStyle(ChartColors.strain)
                    .interpolationMethod(.catmullRom)
            }
        }
        .chartXScale(domain: .automatic)
        .chartYScale(domain: .automatic(includesZero: true))
    }
}

// MARK: - 3. Sleep Architecture
// BarMark עם Date ב־X לא הופיע; משתמשים ב־LineMark (כמו גרף 1/6) שהצגה עובדת.
struct SleepArchitectureChartView: View {
    let data: SleepArchitectureGraphData
    private var visiblePoints: [SleepDayPoint] { data.points.filter { ($0.totalHours ?? 0) > 0 } }
    private var hasData: Bool { !visiblePoints.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(visiblePoints) { p in
                    LineMark(x: .value("תאריך", p.date), y: .value("שינה", p.totalHours!))
                        .foregroundStyle(ChartColors.sleep)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 12)
            } else {
                ChartPlaceholderView(message: "אין נתוני שינה להצגה", icon: "bed.double.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .onAppear {
            print("[ChartDebug] SleepArchitectureChartView onAppear: points=\(data.points.count), visible=\(visiblePoints.count), hasData=\(hasData)")
        }
    }
}

// MARK: - 4. Glucose & Energy (מבנה כמו Efficiency; אנרגיה־בלבד → ActiveEnergyChartView בדשבורד)
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
                        LineMark(x: .value("תאריך", p.date), y: .value("סוכר", g))
                            .foregroundStyle(ChartColors.glucose)
                            .interpolationMethod(.catmullRom)
                    }
                    if let e = p.activeEnergy, e > 0 {
                        BarMark(x: .value("תאריך", p.date), y: .value("אנרגיה", e / 50), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.strain.opacity(0.6))
                    }
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני גלוקוז או אנרגיה להצגה", icon: "flame.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
        .onAppear {
            print("[ChartDebug] GlucoseEnergyChartView onAppear: points=\(data.points.count), hasGlucose=\(hasGlucose), hasEnergy=\(hasEnergy), hasData=\(hasData)")
        }
    }
}

// MARK: - 5. Autonomic Balance (Radar)
struct AutonomicRadarChartView: View {
    let data: AutonomicRadarData
    var body: some View {
        let rhr = data.rhr ?? 50
        let hrv = data.hrv ?? 50
        let resp = data.respiratory ?? 50
        Chart {
            BarMark(x: .value("מדד", "RHR"), y: .value("ערך", rhr), width: .ratio(0.5))
                .foregroundStyle(ChartColors.recovery)
            BarMark(x: .value("מדד", "HRV"), y: .value("ערך", hrv), width: .ratio(0.5))
                .foregroundStyle(ChartColors.strain)
            BarMark(x: .value("מדד", "נשימה"), y: .value("ערך", resp), width: .ratio(0.5))
                .foregroundStyle(ChartColors.sleep)
        }
        .chartXScale(domain: ["RHR", "HRV", "נשימה"])
        .chartYScale(domain: 0 ... 100)
    }
}

// MARK: - 6. Nutrition Adherence
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
                    if let pr = p.protein {
                        BarMark(x: .value("תאריך", p.date), y: .value("חלבון", pr), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.strain)
                    }
                    if let c = p.carbs, c > 0 {
                        BarMark(x: .value("תאריך", p.date), y: .value("פחמימות", c), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.glucose)
                    }
                    if let f = p.fat, f > 0 {
                        BarMark(x: .value("תאריך", p.date), y: .value("שומן", f), width: .ratio(0.5))
                            .foregroundStyle(ChartColors.sleep)
                    }
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני תזונה להצגה", icon: "leaf.fill")
            }
        }
    }
}

// MARK: - Placeholder when chart has no data
struct ChartPlaceholderView: View {
    let message: String
    let icon: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .tertiarySystemFill))
    }
}

// MARK: - Chart colors (SwiftUI)
private enum ChartColors {
    static let recovery = Color(red: 13/255, green: 126/255, blue: 167/255)
    static let strain = Color(red: 232/255, green: 93/255, blue: 4/255)
    static let sleep = Color(red: 92/255, green: 77/255, blue: 125/255)
    static let glucose = Color(red: 202/255, green: 103/255, blue: 2/255)
}

// MARK: - חלופות לגרפים ריקים

struct DistanceChartView: View {
    let data: EfficiencyGraphData
    private var visiblePoints: [EfficiencyDataPoint] { data.points.filter { ($0.distanceKm ?? 0) > 0 } }
    private var hasData: Bool { !visiblePoints.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(visiblePoints) { p in
                    BarMark(x: .value("תאריך", p.date), y: .value("ק\"מ", p.distanceKm!), width: .ratio(0.5))
                        .foregroundStyle(ChartColors.recovery)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני מרחק", icon: "figure.walk")
            }
        }
    }
}

// LineMark במקום BarMark – BarMark+Date לא הוצג; LineMark עובד (גרף 1/6).
struct ActiveEnergyChartView: View {
    let data: GlucoseEnergyGraphData
    private var visiblePoints: [GlucoseEnergyPoint] { data.points.filter { ($0.activeEnergy ?? 0) > 0 } }
    private var hasData: Bool { !visiblePoints.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(visiblePoints) { p in
                    LineMark(x: .value("תאריך", p.date), y: .value("קלוריות", (p.activeEnergy ?? 0) / 50))
                        .foregroundStyle(ChartColors.strain)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני אנרגיה פעילה", icon: "flame.fill")
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: .infinity)
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
                    LineMark(x: .value("תאריך", p.date), y: .value("דופק", p.avgHeartRate!))
                        .foregroundStyle(ChartColors.strain)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני דופק", icon: "heart.fill")
            }
        }
    }
}

struct RecoveryTrendChartView: View {
    let data: ReadinessGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("תאריך", p.date), y: .value("התאוששות", p.recovery))
                        .foregroundStyle(ChartColors.recovery)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 100)
            } else {
                ChartPlaceholderView(message: "אין נתונים", icon: "chart.line.uptrend.xyaxis")
            }
        }
        .onAppear { print("[ChartDebug] RecoveryTrendChartView onAppear: points=\(data.points.count), hasData=\(hasData)") }
    }
}

struct StrainTrendChartView: View {
    let data: ReadinessGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("תאריך", p.date), y: .value("עומס", p.strain * 10))
                        .foregroundStyle(ChartColors.strain)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: 0 ... 100)
            } else {
                ChartPlaceholderView(message: "אין נתונים", icon: "chart.line.uptrend.xyaxis")
            }
        }
        .onAppear { print("[ChartDebug] StrainTrendChartView onAppear: points=\(data.points.count), hasData=\(hasData)") }
    }
}

struct StepsChartView: View {
    let data: StepsGraphData
    private var visiblePoints: [StepsDataPoint] { data.points.filter { $0.steps > 0 } }
    private var hasData: Bool { !visiblePoints.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(visiblePoints) { p in
                    BarMark(x: .value("תאריך", p.date), y: .value("צעדים", p.steps), width: .ratio(0.5))
                        .foregroundStyle(ChartColors.recovery)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני צעדים", icon: "figure.walk")
            }
        }
    }
}

struct RHRTrendChartView: View {
    let data: RHRTrendGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("תאריך", p.date), y: .value("דופק מנוחה", p.value))
                        .foregroundStyle(ChartColors.strain)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני דופק מנוחה", icon: "heart.fill")
            }
        }
    }
}

struct HRVTrendChartView: View {
    let data: HRVTrendGraphData
    private var hasData: Bool { !data.points.isEmpty }
    var body: some View {
        Group {
            if hasData {
                Chart(data.points) { p in
                    LineMark(x: .value("תאריך", p.date), y: .value("HRV", p.value))
                        .foregroundStyle(ChartColors.sleep)
                        .interpolationMethod(.catmullRom)
                }
                .chartXScale(domain: .automatic)
                .chartYScale(domain: .automatic(includesZero: true))
            } else {
                ChartPlaceholderView(message: "אין נתוני HRV", icon: "waveform.path.ecg")
            }
        }
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
