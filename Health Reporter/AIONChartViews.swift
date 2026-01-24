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
struct SleepArchitectureChartView: View {
    let data: SleepArchitectureGraphData
    var body: some View {
        Chart(data.points) { p in
            if let h = p.totalHours {
                BarMark(x: .value("תאריך", p.date), y: .value("שינה", h), width: .ratio(0.5))
                    .foregroundStyle(ChartColors.sleep)
            }
        }
        .chartXScale(domain: .automatic)
        .chartYScale(domain: 0 ... 12)
    }
}

// MARK: - 4. Glucose & Energy
struct GlucoseEnergyChartView: View {
    let data: GlucoseEnergyGraphData
    var body: some View {
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
    var body: some View {
        Chart(data.points.prefix(7)) { p in
            if let pr = p.protein {
                BarMark(x: .value("תאריך", p.date), y: .value("חלבון", pr), width: .ratio(0.5))
                    .foregroundStyle(ChartColors.strain)
            }
        }
        .chartXScale(domain: .automatic)
        .chartYScale(domain: .automatic(includesZero: true))
    }
}

// MARK: - Chart colors (SwiftUI)
private enum ChartColors {
    static let recovery = Color(red: 13/255, green: 126/255, blue: 167/255)
    static let strain = Color(red: 232/255, green: 93/255, blue: 4/255)
    static let sleep = Color(red: 92/255, green: 77/255, blue: 125/255)
    static let glucose = Color(red: 202/255, green: 103/255, blue: 2/255)
}

extension ReadinessDataPoint: Identifiable { var id: Date { date } }
extension EfficiencyDataPoint: Identifiable { var id: Date { date } }
extension SleepDayPoint: Identifiable { var id: Date { date } }
extension GlucoseEnergyPoint: Identifiable { var id: Date { date } }
extension NutritionDayPoint: Identifiable { var id: Date { date } }
