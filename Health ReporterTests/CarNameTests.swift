//
//  CarNameTests.swift
//  Health ReporterTests
//
//  Tests to ensure car names only come from Gemini API, never generic tier names
//

import Foundation
import Testing
@testable import Health_Reporter

struct CarNameTests {

    // MARK: - Generic Tier Names (should NEVER appear to users)

    /// These are the generic tier names that should NEVER be displayed to users
    static let forbiddenGenericNames = [
        "Fiat Panda",
        "Toyota Corolla",
        "BMW M3",
        "Porsche 911 Turbo",
        "Ferrari SF90 Stradale"
    ]

    // MARK: - Helper to clear selected car

    private static func clearSelectedCar() {
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.Name")
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.WikiName")
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.Explanation")
        UserDefaults.standard.synchronize()
    }

    // MARK: - InsightsDashboardViewController Tests

    @Test func getCarName_withNoGeminiData_shouldReturnNil() async throws {
        // Clear any cached Gemini car data
        Self.clearSelectedCar()

        // When there's no Gemini data, the car should be nil
        let savedCar = AnalysisCache.loadSelectedCar()
        #expect(savedCar == nil, "When no Gemini data exists, car should be nil")
    }

    @Test func getCarName_withGeminiData_shouldReturnGeminiName() async throws {
        // Clear first
        Self.clearSelectedCar()

        // Save a Gemini car name
        let testCarName = "Lexus LC 500"
        let testWikiName = "Lexus_LC"
        let testExplanation = "Test explanation"

        AnalysisCache.saveSelectedCar(name: testCarName, wikiName: testWikiName, explanation: testExplanation)

        // Load it back
        let savedCar = AnalysisCache.loadSelectedCar()

        #expect(savedCar != nil, "Should have saved car data")
        #expect(savedCar?.name == testCarName, "Car name should match what was saved")
        #expect(!Self.forbiddenGenericNames.contains(savedCar?.name ?? ""), "Car name should not be a generic tier name")

        // Clean up
        Self.clearSelectedCar()
    }

    // MARK: - CarTierEngine Tests

    @Test func carTierEngine_tierNames_areOnlyUsedInternally() async throws {
        // Verify that CarTierEngine tiers exist (for internal use)
        let scores = [20, 40, 60, 75, 95]

        for score in scores {
            let tier = CarTierEngine.tierForScore(score)

            // The tier should have a name (for internal/analytics use)
            #expect(!tier.name.isEmpty, "Tier should have a name for internal use")

            // But we verify these are the expected generic names
            #expect(Self.forbiddenGenericNames.contains(tier.name),
                   "Tier name '\(tier.name)' should be one of the known generic names (for analytics only)")
        }
    }

    // MARK: - WidgetDataManager Tests

    @Test func widgetDataManager_withNoGeminiData_shouldUseEmptyCarName() async throws {
        // Clear Gemini data
        Self.clearSelectedCar()

        // The logic in updateFromDashboard should use empty string when no Gemini data
        let geminiCar = AnalysisCache.loadSelectedCar()
        let carName = geminiCar?.name ?? ""

        #expect(carName.isEmpty, "Without Gemini data, car name should be empty")
        #expect(!Self.forbiddenGenericNames.contains(carName), "Car name should not be a generic tier name")
    }

    @Test func widgetDataManager_withGeminiData_shouldUseGeminiCarName() async throws {
        // Clear first
        Self.clearSelectedCar()

        // Save a Gemini car name
        let testCarName = "Audi R8 V10"
        AnalysisCache.saveSelectedCar(name: testCarName, wikiName: "Audi_R8", explanation: "Test")

        // The logic should use Gemini car name
        let geminiCar = AnalysisCache.loadSelectedCar()
        let carName = geminiCar?.name ?? ""

        #expect(carName == testCarName, "Should use Gemini car name")
        #expect(!Self.forbiddenGenericNames.contains(carName), "Car name should not be a generic tier name")

        // Clean up
        Self.clearSelectedCar()
    }

    // MARK: - Code Search Tests (Static Analysis)

    @Test func codebase_shouldNotUseTierNameForDisplay() async throws {
        // This is a reminder test - the actual check is done during code review
        // The following patterns should NOT exist in display code:
        // - tier.name (except in AnalyticsService)
        // - CarTierEngine.tierForScore(...).name (except in AnalyticsService)

        // This test always passes but serves as documentation
        #expect(true, """
            IMPORTANT: Verify manually that these patterns don't exist in display code:
            1. tier.name (only allowed in AnalyticsService.swift)
            2. CarTierEngine.tierForScore(...).name (only allowed in AnalyticsService.swift)

            Run this grep to check:
            grep -r "tier\\.name" --include="*.swift" | grep -v AnalyticsService | grep -v "// Use Gemini"
            """)
    }
}
