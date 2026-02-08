//
//  AIONMemoryExtractor.swift
//  Health Reporter
//
//  Extracts key insights from a completed Gemini analysis and updates
//  the user's AION memory. Does NOT call Gemini – uses only local data.
//

import Foundation
import FirebaseAuth

enum AIONMemoryExtractor {

    // MARK: - Main Entry Point

    /// Updates (or creates) the AION memory after a successful analysis.
    static func updateMemory(
        existingMemory: AIONMemory?,
        parsedAnalysis: CarAnalysisResponse,
        healthPayload: GeminiHealthPayload?,
        healthScore: Int
    ) -> AIONMemory {
        var memory = existingMemory ?? AIONMemoryManager.createInitialMemory()

        // 1. Update user profile baselines
        updateUserProfile(&memory, analysis: parsedAnalysis, payload: healthPayload)

        // 2. Build a compressed summary for this analysis
        let summary = buildAnalysisSummary(analysis: parsedAnalysis, healthScore: healthScore)

        // 3. Add to recent analyses (keep last 3)
        memory.recentAnalyses.insert(summary, at: 0)
        if memory.recentAnalyses.count > 3 {
            memory.recentAnalyses = Array(memory.recentAnalyses.prefix(3))
        }

        // 4. Update longitudinal insights
        updateLongitudinalInsights(&memory, analysis: parsedAnalysis)

        // 5. Update metadata
        memory.interactionCount += 1
        memory.lastUpdatedDate = Date()

        return memory
    }

    // MARK: - User Profile

    private static func updateUserProfile(
        _ memory: inout AIONMemory,
        analysis: CarAnalysisResponse,
        payload: GeminiHealthPayload?
    ) {
        // Name
        if memory.userProfile.displayName == nil {
            memory.userProfile.displayName = Auth.auth().currentUser?.displayName
        }

        // Data source
        let source = DataSourceManager.shared.effectiveSource()
        memory.userProfile.dataSource = source.displayName

        // Car
        let previousCar = memory.userProfile.currentCarModel
        let newCar = analysis.carWikiName.isEmpty ? analysis.carModelEn : analysis.carWikiName
        if !newCar.isEmpty {
            memory.userProfile.currentCarModel = newCar

            // Track car journey
            if let prev = previousCar, !prev.isEmpty, prev != newCar {
                let brief = memory.userProfile.carHistoryBrief ?? ""
                if brief.isEmpty {
                    memory.userProfile.carHistoryBrief = "Changed from \(prev) to \(newCar)"
                } else {
                    memory.userProfile.carHistoryBrief = brief + " → \(newCar)"
                }
            }
        }

        // Baselines from health payload
        guard let payload = payload else { return }

        // Typical sleep: average from weekly summaries
        let sleepValues = payload.weeklySummary.compactMap(\.avgSleepHours).filter { $0 > 0 }
        if !sleepValues.isEmpty {
            memory.userProfile.typicalSleepHours = round(sleepValues.reduce(0, +) / Double(sleepValues.count) * 10) / 10
        }

        // Baseline HRV: median from last 30 days of daily data
        let hrvValues = payload.dailyLast14.compactMap(\.hrvMs).filter { $0 > 0 }.sorted()
        if !hrvValues.isEmpty {
            memory.userProfile.baselineHRV = round(median(hrvValues))
        }

        // Baseline RHR: median from last 14 days
        let rhrValues = payload.dailyLast14.compactMap(\.restingHR).filter { $0 > 0 }.sorted()
        if !rhrValues.isEmpty {
            memory.userProfile.baselineRHR = round(median(rhrValues))
        }

        // VO2max range from weekly summaries
        let vo2Values = payload.weeklySummary.compactMap(\.avgVO2max).filter { $0 > 0 }
        if vo2Values.count >= 2 {
            let minV = Int(round(vo2Values.min()!))
            let maxV = Int(round(vo2Values.max()!))
            memory.userProfile.vo2maxRange = minV == maxV ? "\(minV)" : "\(minV)-\(maxV)"
        }

        // Fitness level from health score
        let score = AnalysisCache.loadHealthScore() ?? 0
        if score > 0 {
            memory.userProfile.fitnessLevel = fitnessLevel(from: score)
        }
    }

    // MARK: - Analysis Summary

    private static func buildAnalysisSummary(
        analysis: CarAnalysisResponse,
        healthScore: Int
    ) -> AIONAnalysisSummary {
        // Build concise key findings from bottlenecks + directives
        let findingsEn = buildKeyFindings(
            bottlenecks: analysis.bottlenecksEn,
            summary: analysis.summaryEn
        )
        let findingsHe = buildKeyFindings(
            bottlenecks: analysis.bottlenecksHe,
            summary: analysis.summaryHe
        )

        let carModel = analysis.carWikiName.isEmpty ? analysis.carModelEn : analysis.carWikiName
        let supplementNames = analysis.supplements.map(\.nameEn).filter { !$0.isEmpty }

        return AIONAnalysisSummary(
            date: Date(),
            carModel: carModel,
            healthScore: healthScore,
            keyFindings_en: findingsEn,
            keyFindings_he: findingsHe,
            directiveStop: analysis.directiveStopEn,
            directiveStart: analysis.directiveStartEn,
            directiveWatch: analysis.directiveWatchEn,
            supplements: supplementNames
        )
    }

    private static func buildKeyFindings(bottlenecks: [String], summary: String) -> String {
        // Take first 2 bottlenecks + first sentence of summary, max ~150 chars
        var parts: [String] = []

        for bottleneck in bottlenecks.prefix(2) {
            let trimmed = bottleneck.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                parts.append(trimmed)
            }
        }

        if parts.isEmpty && !summary.isEmpty {
            // Use first sentence of summary as fallback
            let firstSentence = summary.components(separatedBy: ".").first ?? summary
            parts.append(firstSentence.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let result = parts.joined(separator: ". ")
        // Truncate if too long
        if result.count > 200 {
            return String(result.prefix(197)) + "..."
        }
        return result
    }

    // MARK: - Longitudinal Insights

    private static func updateLongitudinalInsights(
        _ memory: inout AIONMemory,
        analysis: CarAnalysisResponse
    ) {
        // Update supplement history
        let currentSupplements = analysis.supplements.map(\.nameEn).filter { !$0.isEmpty }
        if !currentSupplements.isEmpty {
            memory.longitudinalInsights.supplementHistory = currentSupplements.joined(separator: ", ")
        }

        // Detect persistent weaknesses: if the same bottleneck theme appears in 2+ recent analyses
        if memory.recentAnalyses.count >= 2 {
            let previousFindings = memory.recentAnalyses.dropFirst().map(\.keyFindings_en).joined(separator: " ").lowercased()
            var persistent: [String] = []

            for bottleneck in analysis.bottlenecksEn {
                let keywords = extractKeywords(from: bottleneck)
                let matchCount = keywords.filter { previousFindings.contains($0) }.count
                if matchCount >= 2 {
                    persistent.append(bottleneck)
                }
            }

            if !persistent.isEmpty {
                memory.longitudinalInsights.persistentWeaknesses = persistent
            }
        }

        // Update sleep trend from weekly summary comparison
        if memory.recentAnalyses.count >= 2 {
            let scores = memory.recentAnalyses.map(\.healthScore)
            if scores.count >= 2 {
                let recent = scores[0]
                let previous = scores[1]
                let diff = recent - previous
                if abs(diff) >= 5 {
                    let trend = diff > 0 ? "improving" : "declining"
                    let event = "\(dateString(Date())): Health score \(trend) (\(previous) → \(recent))"

                    // Add to notable events, keep last 5
                    memory.longitudinalInsights.notableEvents.insert(event, at: 0)
                    if memory.longitudinalInsights.notableEvents.count > 5 {
                        memory.longitudinalInsights.notableEvents = Array(memory.longitudinalInsights.notableEvents.prefix(5))
                    }
                }
            }
        }

        // Extract training pattern from tune-up plan
        let training = analysis.trainingAdjustmentsEn
        if !training.isEmpty && training.count > 10 {
            // Compress to a short description
            let firstSentence = training.components(separatedBy: ".").first ?? training
            memory.longitudinalInsights.trainingPattern = String(firstSentence.prefix(100))
        }

        // Extract recovery pattern
        let recovery = analysis.recoveryChangesEn
        if !recovery.isEmpty && recovery.count > 10 {
            let firstSentence = recovery.components(separatedBy: ".").first ?? recovery
            memory.longitudinalInsights.recoveryPattern = String(firstSentence.prefix(100))
        }
    }

    // MARK: - Helpers

    private static func median(_ sortedValues: [Double]) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        let mid = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return (sortedValues[mid - 1] + sortedValues[mid]) / 2
        } else {
            return sortedValues[mid]
        }
    }

    private static func fitnessLevel(from score: Int) -> String {
        switch score {
        case 0..<40: return "beginner"
        case 40..<60: return "intermediate"
        case 60..<80: return "advanced"
        default: return "elite"
        }
    }

    private static func extractKeywords(from text: String) -> [String] {
        // Extract meaningful words (4+ characters) for comparison
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 4 }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}
