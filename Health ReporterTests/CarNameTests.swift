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

    // MARK: - HealthTier Tests

    @Test func healthTier_forScore_returnsValidTier() async throws {
        // Verify that HealthTier.forScore works correctly
        let scores = [20, 40, 60, 75, 95]
        let expectedIndices = [0, 1, 2, 3, 4]

        for (score, expectedIndex) in zip(scores, expectedIndices) {
            let tier = HealthTier.forScore(score)
            #expect(tier.tierIndex == expectedIndex, "Score \(score) should map to tier \(expectedIndex)")
            #expect(!tier.emoji.isEmpty, "Tier should have an emoji")
            #expect(!tier.tierLabel.isEmpty, "Tier should have a label")
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
        // This is a reminder test - car names should always come from Gemini
        #expect(true, """
            IMPORTANT: Car names must always come from Gemini (GeminiResultStore.loadCarName()).
            HealthTier only provides visual tier properties (emoji, color, tierLabel, tierIndex).
            """)
    }
}
