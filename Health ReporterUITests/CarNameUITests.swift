//
//  CarNameUITests.swift
//  Health ReporterUITests
//
//  UI Tests to verify car names only come from Gemini, never generic tier names
//

import XCTest

final class CarNameUITests: XCTestCase {

    var app: XCUIApplication!

    /// Generic tier names that should NEVER appear in the UI
    static let forbiddenGenericNames = [
        "Fiat Panda",
        "Toyota Corolla",
        "BMW M3",
        "Porsche 911 Turbo",
        "Ferrari SF90 Stradale"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Searches for forbidden generic car names in any visible text
    private func checkForForbiddenCarNames() -> String? {
        for name in Self.forbiddenGenericNames {
            // Check if any static text contains the forbidden name
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", name)
            let elements = app.staticTexts.matching(predicate)

            if elements.count > 0 {
                return name
            }
        }
        return nil
    }

    /// Waits for an element to exist
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    // MARK: - Tests

    @MainActor
    func testLaunchApp_shouldNotShowGenericCarNames() throws {
        // Launch with clear state (simulating new user without Gemini data)
        app.launchArguments = ["--uitesting", "--clearCache"]
        app.launch()

        // Wait for app to fully load
        sleep(3)

        // Check all visible text for forbidden generic names
        if let forbiddenName = checkForForbiddenCarNames() {
            XCTFail("Found forbidden generic car name in UI: '\(forbiddenName)'. Car names should only come from Gemini API!")
        }
    }

    @MainActor
    func testInsightsTab_shouldNotShowGenericCarNames() throws {
        app.launch()

        // Wait for main screen to load
        sleep(3)

        // Try to find and tap the Insights tab
        // Note: Tab name might be different based on localization
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            // Look for Insights tab - might be called "Insights" in the UI
            let insightsTab = tabBar.buttons.element(boundBy: 2) // Usually the 3rd tab
            if insightsTab.exists {
                insightsTab.tap()
                sleep(3) // Wait for content to load
            }
        }

        // Check for forbidden generic names
        if let forbiddenName = checkForForbiddenCarNames() {
            XCTFail("Found forbidden generic car name in Insights tab: '\(forbiddenName)'. Car names should only come from Gemini API!")
        }
    }

    @MainActor
    func testDashboard_shouldNotShowGenericCarNames() throws {
        app.launch()

        // Wait for dashboard to fully load
        sleep(5)

        // Scroll through the dashboard to reveal all content
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            sleep(1)
            scrollView.swipeUp()
            sleep(1)
        }

        // Check for forbidden generic names
        if let forbiddenName = checkForForbiddenCarNames() {
            XCTFail("Found forbidden generic car name in Dashboard: '\(forbiddenName)'. Car names should only come from Gemini API!")
        }
    }

    @MainActor
    func testAllTabs_shouldNotShowGenericCarNames() throws {
        app.launch()

        // Wait for main screen
        sleep(3)

        let tabBar = app.tabBars.firstMatch
        guard tabBar.waitForExistence(timeout: 5) else {
            // If no tab bar, just check current screen
            if let forbiddenName = checkForForbiddenCarNames() {
                XCTFail("Found forbidden generic car name: '\(forbiddenName)'")
            }
            return
        }

        // Check each tab
        let tabCount = tabBar.buttons.count
        for i in 0..<tabCount {
            let tab = tabBar.buttons.element(boundBy: i)
            if tab.exists && tab.isHittable {
                tab.tap()
                sleep(2) // Wait for content to load

                // Scroll to reveal all content
                let scrollView = app.scrollViews.firstMatch
                if scrollView.exists {
                    scrollView.swipeUp()
                    sleep(1)
                }

                // Check for forbidden names
                if let forbiddenName = checkForForbiddenCarNames() {
                    XCTFail("Found forbidden generic car name in tab \(i): '\(forbiddenName)'. Car names should only come from Gemini API!")
                }
            }
        }
    }

    // MARK: - Visual Verification Test

    @MainActor
    func testTakeScreenshots_forManualVerification() throws {
        // This test takes screenshots for manual verification
        app.launch()
        sleep(3)

        // Screenshot 1: Main screen
        let attachment1 = XCTAttachment(screenshot: app.screenshot())
        attachment1.name = "01_MainScreen"
        attachment1.lifetime = .keepAlways
        add(attachment1)

        // Navigate to each tab and take screenshots
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            let tabCount = tabBar.buttons.count
            for i in 0..<tabCount {
                let tab = tabBar.buttons.element(boundBy: i)
                if tab.exists && tab.isHittable {
                    tab.tap()
                    sleep(2)

                    let attachment = XCTAttachment(screenshot: app.screenshot())
                    attachment.name = "Tab_\(i)_Screenshot"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }

        // Add note for manual review
        print("""

        ═══════════════════════════════════════════════════════════════
        MANUAL VERIFICATION REQUIRED
        ═══════════════════════════════════════════════════════════════

        Please review the attached screenshots and verify that:

        1. NO generic car names appear anywhere:
           - Fiat Panda
           - Toyota Corolla
           - BMW M3
           - Porsche 911 Turbo
           - Ferrari SF90 Stradale

        2. If a car name IS shown, it should be a specific name from
           Gemini (like "Lexus LC 500", "Audi R8 V10", etc.)

        3. If there's no Gemini data, the car name field should be
           EMPTY or show a placeholder like "Waiting for analysis"

        ═══════════════════════════════════════════════════════════════

        """)
    }
}
