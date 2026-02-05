//
//  DebugTestHelper.swift
//  Health Reporter
//
//  מחלקת עזר לבדיקות ידניות - מאפשרת לדמות מצבים שונים
//  שים לב: להשתמש רק ב-DEBUG mode!
//

import Foundation

#if DEBUG

/// כלי עזר לבדיקות ידניות
/// כדי להשתמש: הוסף כפתור נסתר או קרא לפונקציות מ-lldb
final class DebugTestHelper {

    static let shared = DebugTestHelper()
    private init() {}

    // MARK: - Test User Configuration

    /// המייל של יוזר הטסט - כשמתחברים עם המייל הזה, הנתונים מאופסים ומוכנסים נתונים מדומים
    static let testUserEmail = "rani@ophirins.co.il"

    /// בודק אם המייל הוא של יוזר הטסט
    static func isTestUser(email: String?) -> Bool {
        return email?.lowercased() == testUserEmail.lowercased()
    }

    /// מופעל אוטומטית כשיוזר הטסט מתחבר - מאפס ומכניס נתוני בריאות מדומים
    /// שים לב: לא מכניסים נתוני Gemini מדומים! הנתונים נשלחים ל-Gemini האמיתי
    func setupTestUserData() {
        print("🧪 [TEST USER] ========================================")
        print("🧪 [TEST USER] Detected test user login!")
        print("🧪 [TEST USER] Resetting all data...")
        print("🧪 [TEST USER] ========================================")

        // איפוס כל הנתונים (כולל Gemini cache)
        resetAllData()

        // הכנסת נתוני בריאות מדומים בלבד
        // הנתונים האלה יישלחו ל-Gemini האמיתי בזמן ה-onboarding
        injectMockHealthData()

        // לא מכניסים נתוני Gemini מדומים!
        // Gemini יקבל את נתוני הבריאות המדומים ויחזיר רכב אמיתי
        // injectMockGeminiData() - הוסר בכוונה!

        // סימון שצריך להציג onboarding (יתחיל מ-Splash ויעבור את כל ה-flow)
        markAsNewUser()

        print("🧪 [TEST USER] ✅ Setup complete!")
        print("🧪 [TEST USER] Mock health data injected:")
        print("🧪 [TEST USER]   📍 Activity:")
        print("🧪 [TEST USER]      - Steps: 8,500 | Distance: 6.2 km")
        print("🧪 [TEST USER]      - Active Energy: 450 cal | Total: 2,100 cal")
        print("🧪 [TEST USER]      - Exercise: 45 min | Stand: 10 hrs | Flights: 8")
        print("🧪 [TEST USER]   ❤️ Cardiovascular:")
        print("🧪 [TEST USER]      - HR: 72 bpm | Resting: 62 bpm | Walking: 95 bpm")
        print("🧪 [TEST USER]      - HRV: 45ms (7-day avg: 48ms)")
        print("🧪 [TEST USER]      - VO2 Max: 42 | SpO2: 97%")
        print("🧪 [TEST USER]      - BP: 118/76 mmHg")
        print("🧪 [TEST USER]   😴 Sleep:")
        print("🧪 [TEST USER]      - Total: 7.2h (Deep: 1.5h, REM: 1.8h, Light: 3.4h)")
        print("🧪 [TEST USER]      - Efficiency: 85% | Awake: 30 min")
        print("🧪 [TEST USER]   ⚖️ Body:")
        print("🧪 [TEST USER]      - Weight: 75 kg | BMI: 24.2 | Body Fat: 18%")
        print("🧪 [TEST USER]   🚶 Walking Metrics:")
        print("🧪 [TEST USER]      - Speed: 5.2 km/h | Step Length: 0.72m")
        print("🧪 [TEST USER]      - Steadiness: 92% | Asymmetry: 3.5%")
        print("🧪 [TEST USER]   🏋️ Workouts: 3 (145 min total, 680 cal)")
        print("🧪 [TEST USER]   📊 Scores: Readiness 75 | Strain 6.5")
        print("🧪 [TEST USER] ========================================")
        print("🧪 [TEST USER] Flow: Splash → Onboarding → REAL Gemini API → Car Reveal")
        print("🧪 [TEST USER] ========================================")
    }

    // MARK: - Data Reset

    private func resetAllData() {
        print("🧪 [TEST USER] Clearing all cached data...")

        // ניקוי AnalysisCache (כולל נתוני Gemini)
        AnalysisCache.clear()

        // ניקוי נתוני רכב
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.Name")
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.WikiName")
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.Explanation")

        // ניקוי pending car reveal
        UserDefaults.standard.removeObject(forKey: "AION.PendingCarReveal")
        UserDefaults.standard.removeObject(forKey: "AION.NewCar.Name")
        UserDefaults.standard.removeObject(forKey: "AION.NewCar.WikiName")
        UserDefaults.standard.removeObject(forKey: "AION.NewCar.Explanation")
        UserDefaults.standard.removeObject(forKey: "AION.PreviousCar.Name")

        // ניקוי onboarding status - משתמשים ב-OnboardingManager
        OnboardingManager.resetOnboarding()

        UserDefaults.standard.synchronize()
    }

    // MARK: - Mock Health Data

    private func injectMockHealthData() {
        print("🧪 [TEST USER] Injecting mock health data...")

        // יצירת נתוני בריאות מדומים מלאים ושמירתם ב-cache
        var mockData = HealthDataModel()

        // MARK: - Activity & Movement
        mockData.steps = 8500
        mockData.distance = 6.2 // km
        mockData.activeEnergy = 450
        mockData.basalEnergy = 1650
        mockData.totalEnergy = 2100
        mockData.flightsClimbed = 8
        mockData.exerciseMinutes = 45
        mockData.standHours = 10
        mockData.moveTimeMinutes = 65

        // MARK: - Heart & Cardiovascular
        mockData.heartRate = 72
        mockData.restingHeartRate = 62
        mockData.walkingHeartRateAverage = 95
        mockData.heartRateVariability = 45
        mockData.hrv7DayBaseline = 48
        mockData.hrvTrend = 0.15
        mockData.heartRateRecovery = 25
        mockData.oxygenSaturation = 98
        mockData.spO2 = 97
        mockData.bloodPressureSystolic = 118
        mockData.bloodPressureDiastolic = 76
        mockData.vo2Max = 42

        // MARK: - Sleep Data
        mockData.sleepHours = 7.2
        mockData.sleepDeepHours = 1.5
        mockData.sleepRemHours = 1.8
        mockData.sleepLightHours = 3.4
        mockData.sleepAwakeMinutes = 30
        mockData.sleepEfficiency = 85
        mockData.timeInBedHours = 8.0

        // MARK: - Body Measurements
        mockData.bodyMass = 75
        mockData.bodyMassIndex = 24.2
        mockData.bodyFatPercentage = 18
        mockData.leanBodyMass = 61.5
        mockData.bodyTemperature = 36.6
        mockData.bodyTemperatureDeviation = 0.1

        // MARK: - Respiratory
        mockData.respiratoryRate = 14
        mockData.respiratoryRateAvg = 13.5

        // MARK: - Walking Metrics
        mockData.walkingSpeed = 5.2
        mockData.walkingStepLength = 0.72
        mockData.walkingAsymmetry = 3.5
        mockData.walkingSteadiness = 92
        mockData.sixMinuteWalkDistance = 520

        // MARK: - Nutrition (דוגמה)
        mockData.dietaryEnergy = 2200
        mockData.dietaryProtein = 120
        mockData.dietaryCarbohydrates = 250
        mockData.dietaryFat = 75

        // MARK: - Metabolic
        mockData.bloodGlucose = 5.2

        // MARK: - Calculated Scores
        mockData.calculatedReadinessScore = 75
        mockData.calculatedTrainingStrain = 6.5
        mockData.isReadinessCalculated = true

        // MARK: - Workouts
        mockData.workoutCount = 3
        mockData.totalWorkoutMinutes = 145
        mockData.totalWorkoutCalories = 680
        mockData.workoutTypes = ["Running", "Strength Training", "Walking"]

        // יצירת אימון אחרון לדוגמה
        let lastWorkout = WorkoutData(
            type: "Running",
            startDate: Date().addingTimeInterval(-3600 * 4), // לפני 4 שעות
            endDate: Date().addingTimeInterval(-3600 * 3.5), // לפני 3.5 שעות
            durationMinutes: 32,
            totalCalories: 320,
            totalDistance: 5200,
            averageHeartRate: 145,
            maxHeartRate: 168,
            elevationGain: 45
        )
        mockData.lastWorkout = lastWorkout

        // רשימת אימונים אחרונים
        let workouts = [
            lastWorkout,
            WorkoutData(
                type: "Strength Training",
                startDate: Date().addingTimeInterval(-3600 * 28),
                endDate: Date().addingTimeInterval(-3600 * 27),
                durationMinutes: 55,
                totalCalories: 280,
                totalDistance: nil,
                averageHeartRate: 125,
                maxHeartRate: 155,
                elevationGain: nil
            ),
            WorkoutData(
                type: "Walking",
                startDate: Date().addingTimeInterval(-3600 * 52),
                endDate: Date().addingTimeInterval(-3600 * 51),
                durationMinutes: 58,
                totalCalories: 180,
                totalDistance: 4800,
                averageHeartRate: 98,
                maxHeartRate: 115,
                elevationGain: 25
            )
        ]
        mockData.recentWorkouts = workouts

        // MARK: - Data Source
        mockData.primaryDataSource = .appleWatch
        mockData.detectedSources = [.appleWatch]

        // שמירה ב-HealthDataCache
        HealthDataCache.shared.healthData = mockData

        // יצירת chartBundle מדומה עם 7 ימים של נתונים
        let mockBundle = createMockChartBundle()
        HealthDataCache.shared.chartBundle = mockBundle
        // isLoaded יחושב אוטומטית כי יש healthData ו-chartBundle

        // אימות שהנתונים נשמרו
        if let saved = HealthDataCache.shared.healthData {
            print("🧪 [TEST USER] ✅ Mock data saved to cache: steps=\(saved.steps ?? 0), hrv=\(saved.heartRateVariability ?? 0)")
        } else {
            print("🧪 [TEST USER] ❌ ERROR: Mock data NOT saved to cache!")
        }

        if HealthDataCache.shared.chartBundle != nil {
            print("🧪 [TEST USER] ✅ Mock chartBundle saved to cache")
        }
    }

    /// יצירת chartBundle מדומה עם 7 ימים של נתונים
    private func createMockChartBundle() -> AIONChartDataBundle {
        let today = Date()
        var stepsPoints: [StepsDataPoint] = []
        var sleepPoints: [SleepDayPoint] = []
        var hrvPoints: [TrendDataPoint] = []
        var rhrPoints: [TrendDataPoint] = []
        var efficiencyPoints: [EfficiencyDataPoint] = []
        var glucoseEnergyPoints: [GlucoseEnergyPoint] = []
        var readinessPoints: [ReadinessDataPoint] = []
        var nutritionPoints: [NutritionDayPoint] = []

        // 7 ימים של נתונים מדומים
        for dayOffset in (0..<7).reversed() {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today)!

            // Steps - וריאציות סביב 8500
            let stepsVariation = Double.random(in: -1500...1500)
            stepsPoints.append(StepsDataPoint(date: date, steps: 8500 + stepsVariation))

            // Sleep - וריאציות סביב 7.2 שעות
            let sleepVariation = Double.random(in: -1.0...1.0)
            sleepPoints.append(SleepDayPoint(
                date: date,
                totalHours: 7.2 + sleepVariation,
                totalSeconds: nil,
                deepHours: 1.5 + Double.random(in: -0.3...0.3),
                remHours: 1.8 + Double.random(in: -0.3...0.3),
                bbt: nil,
                timeInBedHours: 8.0 + sleepVariation,
                respiratoryMin: nil,
                respiratoryMax: nil
            ))

            // HRV - וריאציות סביב 45
            let hrvVariation = Double.random(in: -8...8)
            hrvPoints.append(TrendDataPoint(date: date, value: 45 + hrvVariation))

            // RHR - וריאציות סביב 62
            let rhrVariation = Double.random(in: -4...4)
            rhrPoints.append(TrendDataPoint(date: date, value: 62 + rhrVariation))

            // Efficiency
            efficiencyPoints.append(EfficiencyDataPoint(
                date: date,
                avgHeartRate: 72 + Double.random(in: -5...5),
                distanceKm: 6.2 + Double.random(in: -1...1),
                activeCalories: 450 + Double.random(in: -50...50)
            ))

            // Glucose Energy
            glucoseEnergyPoints.append(GlucoseEnergyPoint(
                date: date,
                glucose: 5.2 + Double.random(in: -0.3...0.3),
                activeEnergy: 450 + Double.random(in: -50...50)
            ))

            // Readiness
            readinessPoints.append(ReadinessDataPoint(
                date: date,
                recovery: 75 + Double.random(in: -10...10),
                strain: 6.5 + Double.random(in: -1.5...1.5)
            ))

            // Nutrition
            nutritionPoints.append(NutritionDayPoint(
                date: date,
                protein: 120 + Double.random(in: -20...20),
                carbs: 250 + Double.random(in: -30...30),
                fat: 75 + Double.random(in: -10...10),
                proteinGoal: 130,
                carbsGoal: 280,
                fatGoal: 80
            ))
        }

        return AIONChartDataBundle(
            range: .day,
            rangeLabel: "Today",
            readiness: ReadinessGraphData(points: readinessPoints, periodLabel: "7 Days"),
            efficiency: EfficiencyGraphData(points: efficiencyPoints, periodLabel: "7 Days"),
            sleep: SleepArchitectureGraphData(points: sleepPoints, periodLabel: "7 Days"),
            glucoseEnergy: GlucoseEnergyGraphData(points: glucoseEnergyPoints, periodLabel: "7 Days"),
            autonomic: AutonomicRadarData(
                rhr: 62,
                hrv: 45,
                respiratory: 14,
                stressIndicator: 35,
                periodLabel: "Today"
            ),
            nutrition: NutritionGraphData(points: nutritionPoints, periodLabel: "7 Days"),
            steps: StepsGraphData(points: stepsPoints, periodLabel: "7 Days"),
            rhrTrend: RHRTrendGraphData(points: rhrPoints, periodLabel: "7 Days"),
            hrvTrend: HRVTrendGraphData(points: hrvPoints, periodLabel: "7 Days")
        )
    }

    // MARK: - Mock Gemini Data

    private func injectMockGeminiData() {
        print("🧪 [TEST USER] Injecting mock Gemini data...")

        let carName = "Lexus LC 500"
        let wikiName = "Lexus_LC"
        let healthScore = 78

        // שמירת נתוני רכב
        AnalysisCache.saveSelectedCar(
            name: carName,
            wikiName: wikiName,
            explanation: "Your biometric data shows excellent recovery patterns and consistent sleep quality, reflecting a vehicle that balances luxury with performance."
        )

        // שמירת ציון
        AnalysisCache.saveHealthScore(healthScore)

        // שמירת weekly stats ישירות ל-UserDefaults (כי אין לנו bundle אמיתי)
        UserDefaults.standard.set(7.2, forKey: "AION.AvgSleepHours")
        UserDefaults.standard.set(75.0, forKey: "AION.AvgReadiness")
        UserDefaults.standard.set(65.0, forKey: "AION.AvgStrain")
        UserDefaults.standard.set(45.0, forKey: "AION.AvgHRV")

        // שמירת insights מלאים
        let insights = """
        ## Body Condition Score: \(healthScore)/100

        Your body is performing like a **\(carName)** - a sophisticated machine that combines luxury comfort with impressive performance capabilities.

        ### Selected Car: \(carName)
        **Wiki Name:** \(wikiName)
        **Why This Car:** Your biometric data shows excellent recovery patterns and consistent sleep quality. Like the LC 500, you balance comfort with capability.

        ### Weekly Performance Summary
        | Metric | Current | Previous | Trend |
        |--------|---------|----------|-------|
        | Avg Sleep | 7.2h | 6.8h | ↑ Improving |
        | Avg HRV | 45ms | 42ms | ↑ Good |
        | Resting HR | 62 bpm | 64 bpm | ↑ Better |
        | Daily Steps | 8,500 | 7,200 | ↑ Great |
        | Active Cal | 450 | 380 | ↑ Excellent |

        ### Recovery Score: 75/100
        Your body is recovering well from daily stressors. The nervous system shows good balance.

        ### Top Bottleneck
        🎯 **Sleep Consistency**
        While your total sleep hours are good, the consistency could improve. Try maintaining a more regular bedtime.

        ### Quick Optimization
        💡 **Morning Routine**
        Add 15 minutes of light stretching or mobility work in the morning to enhance recovery and energy levels.

        ### Tune-Up Recommendations
        1. **Hydration**: Aim for 2.5L of water daily
        2. **Movement Breaks**: Take 5-minute walks every 2 hours
        3. **Evening Wind-down**: Start dimming lights 1 hour before bed

        ### Weekly Directives
        - Focus on sleep quality over quantity
        - Maintain current activity levels
        - Consider adding one recovery day mid-week
        """

        AnalysisCache.save(insights: insights, healthDataHash: "test_user_\(Date().timeIntervalSince1970)")

        // Pre-fetch תמונת הרכב
        WidgetDataManager.shared.prefetchCarImage(wikiName: wikiName) { success in
            print("🧪 [TEST USER] Car image prefetch: \(success ? "✅ Success" : "❌ Failed")")
        }
    }

    // MARK: - Onboarding

    private func markAsNewUser() {
        print("🧪 [TEST USER] Marking as new user (will show onboarding)...")
        // שימוש ב-OnboardingManager.resetOnboarding() כדי לאפס את המפתחות הנכונים
        OnboardingManager.resetOnboarding()
        UserDefaults.standard.synchronize()
    }

    // MARK: - Car Name Testing (Original Methods)

    /// מדמה מצב של יוזר חדש ללא נתוני Gemini
    func simulateNewUserNoGeminiData() {
        print("🧪 [DEBUG] Simulating new user with NO Gemini data...")

        AnalysisCache.clear()

        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.Name")
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.WikiName")
        UserDefaults.standard.removeObject(forKey: "AION.SelectedCar.Explanation")
        UserDefaults.standard.synchronize()

        print("🧪 [DEBUG] ✅ Cleared all Gemini/car data")
        print("🧪 [DEBUG] Expected: NO car name should appear anywhere (no Porsche, BMW, etc.)")
    }

    /// מדמה מצב של יוזר עם נתוני Gemini שמורים
    func simulateUserWithGeminiData(
        carName: String = "Lexus LC 500",
        wikiName: String = "Lexus_LC",
        healthScore: Int = 78
    ) {
        print("🧪 [DEBUG] Simulating user with Gemini data...")
        print("🧪 [DEBUG] Car: \(carName), Score: \(healthScore)")

        AnalysisCache.saveSelectedCar(
            name: carName,
            wikiName: wikiName,
            explanation: "Your biometric data reflects a vehicle that balances performance with reliability."
        )

        AnalysisCache.saveHealthScore(healthScore)

        let sampleInsights = """
        ## Body Condition Score: \(healthScore)/100

        ### Selected Car: \(carName)
        **Wiki Name:** \(wikiName)
        **Why This Car:** Your biometric data reflects a vehicle that balances performance with reliability.
        """

        AnalysisCache.save(insights: sampleInsights, healthDataHash: "debug_test_\(Date().timeIntervalSince1970)")

        print("🧪 [DEBUG] ✅ Saved Gemini data")
        print("🧪 [DEBUG] Expected: Car name '\(carName)' should appear, NOT generic names")
    }

    /// מדמה מצב של גילוי רכב חדש (pending car reveal)
    func simulatePendingCarReveal(
        newCarName: String = "Porsche Taycan",
        newWikiName: String = "Porsche_Taycan",
        previousCarName: String = "Tesla Model 3"
    ) {
        print("🧪 [DEBUG] Simulating pending car reveal...")

        AnalysisCache.saveSelectedCar(
            name: previousCarName,
            wikiName: "Tesla_Model_3",
            explanation: "Previous car"
        )

        UserDefaults.standard.set(true, forKey: "AION.PendingCarReveal")
        UserDefaults.standard.set(newCarName, forKey: "AION.NewCar.Name")
        UserDefaults.standard.set(newWikiName, forKey: "AION.NewCar.WikiName")
        UserDefaults.standard.set("Your improved metrics earned you an upgrade!", forKey: "AION.NewCar.Explanation")
        UserDefaults.standard.set(previousCarName, forKey: "AION.PreviousCar.Name")
        UserDefaults.standard.synchronize()

        print("🧪 [DEBUG] ✅ Set pending car reveal")
        print("🧪 [DEBUG] Previous: \(previousCarName) → New: \(newCarName)")
    }

    // MARK: - Verification

    func printCurrentCarData() {
        print("\n🧪 [DEBUG] ========== CURRENT CAR DATA ==========")

        if let car = AnalysisCache.loadSelectedCar() {
            print("🚗 Selected Car: \(car.name)")
            print("   Wiki Name: \(car.wikiName)")
            print("   Explanation: \(car.explanation.prefix(50))...")
        } else {
            print("🚗 Selected Car: NONE (nil)")
        }

        if let score = AnalysisCache.loadHealthScore() {
            print("📊 Health Score: \(score)")
        } else {
            print("📊 Health Score: NONE (nil)")
        }

        let hasPending = AnalysisCache.hasPendingCarReveal()
        print("🔔 Pending Car Reveal: \(hasPending)")

        if hasPending, let pending = AnalysisCache.getPendingCar() {
            print("   New Car: \(pending.name)")
            print("   Previous: \(pending.previousName)")
        }

        let forbiddenNames = ["Fiat Panda", "Toyota Corolla", "BMW M3", "Porsche 911 Turbo", "Ferrari SF90 Stradale"]
        if let car = AnalysisCache.loadSelectedCar() {
            if forbiddenNames.contains(car.name) {
                print("⚠️ WARNING: Car name is a GENERIC TIER NAME! This is a BUG!")
            } else {
                print("✅ Car name is NOT a generic tier name (good!)")
            }
        }

        print("🧪 [DEBUG] ===========================================\n")
    }

    func verifyNoGenericCarNames() -> Bool {
        let forbiddenNames = ["Fiat Panda", "Toyota Corolla", "BMW M3", "Porsche 911 Turbo", "Ferrari SF90 Stradale"]

        if let car = AnalysisCache.loadSelectedCar() {
            let isGeneric = forbiddenNames.contains(car.name)
            if isGeneric {
                print("❌ FAIL: Car name '\(car.name)' is a generic tier name!")
                return false
            }
        }

        print("✅ PASS: No generic car names found")
        return true
    }
}

// MARK: - Quick Access from LLDB

func debugSimulateNewUser() {
    DebugTestHelper.shared.simulateNewUserNoGeminiData()
}

func debugSimulateGeminiUser() {
    DebugTestHelper.shared.simulateUserWithGeminiData()
}

func debugSimulatePendingReveal() {
    DebugTestHelper.shared.simulatePendingCarReveal()
}

func debugPrintCarData() {
    DebugTestHelper.shared.printCurrentCarData()
}

func debugVerifyCarNames() -> Bool {
    return DebugTestHelper.shared.verifyNoGenericCarNames()
}

func debugSetupTestUser() {
    DebugTestHelper.shared.setupTestUserData()
}

#endif
