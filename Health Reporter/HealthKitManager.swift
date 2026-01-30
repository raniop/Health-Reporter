//
//  HealthKitManager.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import Foundation
import HealthKit

/// סיכום נתוני פעילות לטווח – רק מדדים רלוונטיים (ללא אופניים/שחייה).
struct ActivitySummary {
    var steps: Double?
    var distanceKm: Double?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Double?
    var flightsClimbed: Double?
    var moveTimeMinutes: Double?
    var standHours: Double?
    var rangeLabel: String
}

class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    // סוגי נתונים – מבקשים הרשאה להכל מראש (שינה, טמפרטורה, פעילות, תזונה, לב, נשימה וכו׳).
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        func addQ(_ id: HKQuantityTypeIdentifier) {
            if let t = HKObjectType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        func addC(_ id: HKCategoryTypeIdentifier) {
            if let t = HKObjectType.categoryType(forIdentifier: id) { types.insert(t) }
        }
        func addX(_ id: HKCharacteristicTypeIdentifier) {
            if let t = HKObjectType.characteristicType(forIdentifier: id) { types.insert(t) }
        }
        
        // פעילות וצעדים
        addQ(.stepCount)
        addQ(.distanceWalkingRunning)
        addQ(.distanceCycling)
        addQ(.distanceSwimming)
        addQ(.flightsClimbed)
        addQ(.activeEnergyBurned)
        addQ(.basalEnergyBurned)
        addQ(.appleExerciseTime)
        addQ(.appleMoveTime)
        addQ(.appleStandTime)
        addQ(.pushCount)
        addQ(.distanceWheelchair)
        
        // לב וכלי דם
        addQ(.heartRate)
        addQ(.restingHeartRate)
        addQ(.walkingHeartRateAverage)
        addQ(.heartRateRecoveryOneMinute)
        addQ(.heartRateVariabilitySDNN)
        addQ(.bloodPressureSystolic)
        addQ(.bloodPressureDiastolic)
        addQ(.oxygenSaturation)
        addQ(.vo2Max)
        addQ(.peripheralPerfusionIndex)
        addC(.highHeartRateEvent)
        addC(.lowHeartRateEvent)
        addC(.irregularHeartRhythmEvent)
        
        // גוף – משקל, גובה, טמפרטורה
        addQ(.height)
        addQ(.bodyMass)
        addQ(.bodyMassIndex)
        addQ(.bodyFatPercentage)
        addQ(.leanBodyMass)
        addQ(.bodyTemperature)
        addQ(.basalBodyTemperature)
        if #available(iOS 16.0, *) {
            addQ(.appleSleepingWristTemperature)
        }
        
        // נשימה
        addQ(.respiratoryRate)
        addQ(.forcedVitalCapacity)
        addQ(.forcedExpiratoryVolume1)
        addQ(.peakExpiratoryFlowRate)
        addQ(.oxygenSaturation)
        
        // שינה (איכות שינה = sleepAnalysis – שלבים, משך וכו׳)
        addC(.sleepAnalysis)
        addC(.appleStandHour)
        
        // תזונה
        addQ(.dietaryEnergyConsumed)
        addQ(.dietaryProtein)
        addQ(.dietaryCarbohydrates)
        addQ(.dietaryFatTotal)
        addQ(.dietaryFiber)
        addQ(.dietarySugar)
        addQ(.dietaryCaffeine)
        addQ(.dietaryWater)
        addQ(.dietaryCalcium)
        addQ(.dietaryCholesterol)
        addQ(.dietarySodium)
        addQ(.dietaryPotassium)
        addQ(.dietaryVitaminA)
        addQ(.dietaryVitaminC)
        addQ(.dietaryVitaminD)
        addQ(.dietaryIron)
        addQ(.dietaryMagnesium)
        addQ(.dietaryZinc)
        
        // סוכר, אינסולין
        addQ(.bloodGlucose)
        addQ(.insulinDelivery)
        
        // הליכה ויציבות
        addQ(.walkingSpeed)
        addQ(.walkingStepLength)
        addQ(.walkingAsymmetryPercentage)
        addQ(.walkingDoubleSupportPercentage)
        addQ(.appleWalkingSteadiness)
        addQ(.sixMinuteWalkTestDistance)
        addQ(.stairAscentSpeed)
        addQ(.stairDescentSpeed)
        
        // שחייה, אימון
        addQ(.swimmingStrokeCount)
        addQ(.numberOfTimesFallen)
        
        // אודיו וסביבה
        addQ(.environmentalAudioExposure)
        addQ(.headphoneAudioExposure)
        addC(.audioExposureEvent)
        
        // אחר
        addQ(.bloodAlcoholContent)
        addQ(.numberOfAlcoholicBeverages)
        addQ(.uvExposure)
        addC(.mindfulSession)
        addC(.handwashingEvent)
        addC(.toothbrushingEvent)
        
        // מאפיינים (גיל, מין וכו׳)
        addX(.dateOfBirth)
        addX(.biologicalSex)
        addX(.bloodType)
        addX(.fitzpatrickSkinType)
        addX(.wheelchairUse)
        
        return types
    }()
    
    private init() {}
    
    /// בודק אם HealthKit זמין במכשיר
    func isHealthDataAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /// מבקש הרשאות גישה לנתוני בריאות
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit לא זמין במכשיר זה"]))
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    /// קורא את כל נתוני הבריאות
    func fetchAllHealthData(completion: @escaping (HealthDataModel?, Error?) -> Void) {
        fetchAllHealthData(for: .month, includeWeeklySnapshots: false, completion: completion)
    }
    
    /// קורא נתוני בריאות לטווח נתון (יום / שבוע / חודש)
    func fetchAllHealthData(for range: DataRange, includeWeeklySnapshots: Bool = false, completion: @escaping (HealthDataModel?, Error?) -> Void) {
        fetchAllHealthData(includeWeeklySnapshots: includeWeeklySnapshots, startDate: range.interval().start, endDate: range.interval().end, completion: completion)
    }

    /// מביא נתוני פעילות לטווח – צעדים, מרחק, קלוריות, דקות אימון, קומות, Move, Stand בלבד.
    func fetchActivityForRange(_ range: DataRange, completion: @escaping (ActivitySummary?) -> Void) {
        let (start, end) = range.interval()
        let label = range.displayLabel()
        var steps: Double?, distanceKm: Double?, activeEnergyKcal: Double?, exerciseMinutes: Double?
        var flightsClimbed: Double?, moveTimeMinutes: Double?, standHours: Double?
        let g = DispatchGroup()
        g.enter()
        fetchSteps(startDate: start, endDate: end) { steps = $0; g.leave() }
        g.enter()
        fetchDistance(startDate: start, endDate: end) { distanceKm = $0; g.leave() }
        g.enter()
        fetchActiveEnergy(startDate: start, endDate: end) { activeEnergyKcal = $0; g.leave() }
        g.enter()
        fetchExerciseMinutes(startDate: start, endDate: end) { exerciseMinutes = $0; g.leave() }
        g.enter()
        fetchFlightsClimbed(startDate: start, endDate: end) { flightsClimbed = $0; g.leave() }
        g.enter()
        fetchMoveTimeMinutes(startDate: start, endDate: end) { moveTimeMinutes = $0; g.leave() }
        g.enter()
        fetchStandHours(startDate: start, endDate: end) { standHours = $0; g.leave() }
        g.notify(queue: .main) {
            completion(ActivitySummary(
                steps: steps,
                distanceKm: distanceKm,
                activeEnergyKcal: activeEnergyKcal,
                exerciseMinutes: exerciseMinutes,
                flightsClimbed: flightsClimbed,
                moveTimeMinutes: moveTimeMinutes,
                standHours: standHours,
                rangeLabel: label
            ))
        }
    }

    /// נתוני פעילות יומיים לגרפים – צעדים, מרחק, קלוריות לכל יום בטווח.
    struct ActivityTimeSeries {
        var steps: StepsGraphData
        var distance: EfficiencyGraphData
        var energy: GlucoseEnergyGraphData
    }

    func fetchActivityTimeSeries(_ range: DataRange, completion: @escaping (ActivityTimeSeries?) -> Void) {
        let (start, end) = range.interval()
        let label = range.displayLabel()
        let cal = Calendar.current
        var dayBuckets: [(Date, Date)] = []
        var cur = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while cur <= endDay {
            let dayStart = cur
            let nextDay = cal.date(byAdding: .day, value: 1, to: cur) ?? cur
            let dayEnd = nextDay > end ? end : nextDay
            dayBuckets.append((dayStart, dayEnd))
            cur = nextDay
        }
        if dayBuckets.isEmpty { dayBuckets = [(start, end)] }

        var stepsPoints: [StepsDataPoint] = []
        var effPoints: [EfficiencyDataPoint] = []
        var energyPoints: [GlucoseEnergyPoint] = []
        let group = DispatchGroup()

        for (dayStart, dayEnd) in dayBuckets {
            group.enter()
            var steps: Double?, dist: Double?, energy: Double?
            let g = DispatchGroup()
            g.enter()
            fetchSteps(startDate: dayStart, endDate: dayEnd) { steps = $0; g.leave() }
            g.enter()
            fetchDistance(startDate: dayStart, endDate: dayEnd) { dist = $0; g.leave() }
            g.enter()
            fetchActiveEnergy(startDate: dayStart, endDate: dayEnd) { energy = $0; g.leave() }
            g.notify(queue: .main) {
                stepsPoints.append(StepsDataPoint(date: dayStart, steps: steps ?? 0))
                effPoints.append(EfficiencyDataPoint(date: dayStart, avgHeartRate: nil, distanceKm: dist, activeCalories: energy))
                energyPoints.append(GlucoseEnergyPoint(date: dayStart, glucose: nil, activeEnergy: energy))
                group.leave()
            }
        }

        group.notify(queue: .main) {
            stepsPoints.sort { $0.date < $1.date }
            effPoints.sort { $0.date < $1.date }
            energyPoints.sort { $0.date < $1.date }
            completion(ActivityTimeSeries(
                steps: StepsGraphData(points: stepsPoints, periodLabel: label),
                distance: EfficiencyGraphData(points: effPoints, periodLabel: label),
                energy: GlucoseEnergyGraphData(points: energyPoints, periodLabel: label)
            ))
        }
    }
    
    /// קורא את כל נתוני הבריאות עם אפשרות לנתונים שבועיים
    func fetchAllHealthData(includeWeeklySnapshots: Bool = false, startDate: Date? = nil, endDate: Date? = nil, completion: @escaping (HealthDataModel?, Error?) -> Void) {
        var healthData = HealthDataModel()
        let group = DispatchGroup()
        
        let end = endDate ?? Date()
        let start = startDate ?? Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        
        // צעדים
        group.enter()
        fetchSteps(startDate: start, endDate: end) { steps in
            healthData.steps = steps
            group.leave()
        }
        
        // מרחק
        group.enter()
        fetchDistance(startDate: start, endDate: end) { distance in
            healthData.distance = distance
            group.leave()
        }
        
        // אנרגיה פעילה
        group.enter()
        fetchActiveEnergy(startDate: start, endDate: end) { energy in
            healthData.activeEnergy = energy
            group.leave()
        }
        
        // דופק
        group.enter()
        fetchHeartRate(startDate: start, endDate: end) { heartRate in
            healthData.heartRate = heartRate
            group.leave()
        }
        
        // דופק במנוחה
        group.enter()
        fetchRestingHeartRate(startDate: start, endDate: end) { restingHeartRate in
            healthData.restingHeartRate = restingHeartRate
            group.leave()
        }
        
        // לחץ דם
        group.enter()
        fetchBloodPressure(startDate: start, endDate: end) { systolic, diastolic in
            healthData.bloodPressureSystolic = systolic
            healthData.bloodPressureDiastolic = diastolic
            group.leave()
        }
        
        // ריווי חמצן
        group.enter()
        fetchOxygenSaturation(startDate: start, endDate: end) { oxygen in
            healthData.oxygenSaturation = oxygen
            group.leave()
        }
        
        // משקל
        group.enter()
        fetchBodyMass(startDate: start, endDate: end) { weight in
            healthData.bodyMass = weight
            group.leave()
        }
        
        // BMI
        group.enter()
        fetchBMI(startDate: start, endDate: end) { bmi in
            healthData.bodyMassIndex = bmi
            group.leave()
        }
        
        // אחוז שומן
        group.enter()
        fetchBodyFatPercentage(startDate: start, endDate: end) { bodyFat in
            healthData.bodyFatPercentage = bodyFat
            group.leave()
        }
        
        // שינה
        group.enter()
        fetchSleepData(startDate: start, endDate: end) { sleepHours, sleepData, _ in
            healthData.sleepHours = sleepHours
            healthData.sleepAnalysis = sleepData
            group.leave()
        }
        
        // קלוריות תזונתיות
        group.enter()
        fetchDietaryEnergy(startDate: start, endDate: end) { calories in
            healthData.dietaryEnergy = calories
            group.leave()
        }
        
        // סוכר בדם
        group.enter()
        fetchBloodGlucose(startDate: start, endDate: end) { glucose in
            healthData.bloodGlucose = glucose
            group.leave()
        }
        
        // VO2 Max
        group.enter()
        fetchVO2Max(startDate: start, endDate: end) { vo2Max in
            healthData.vo2Max = vo2Max
            group.leave()
        }

        // MARK: - Activity Rings Data

        // Exercise Minutes (Green Ring)
        group.enter()
        fetchExerciseMinutes(startDate: start, endDate: end) { minutes in
            healthData.exerciseMinutes = minutes
            group.leave()
        }

        // Stand Hours (Blue Ring)
        group.enter()
        fetchStandHours(startDate: start, endDate: end) { hours in
            healthData.standHours = hours
            group.leave()
        }

        // Move Time
        group.enter()
        fetchMoveTimeMinutes(startDate: start, endDate: end) { minutes in
            healthData.moveTimeMinutes = minutes
            group.leave()
        }

        // Flights Climbed
        group.enter()
        fetchFlightsClimbed(startDate: start, endDate: end) { flights in
            healthData.flightsClimbed = flights
            group.leave()
        }

        // Basal Energy (BMR)
        group.enter()
        fetchBasalEnergy(startDate: start, endDate: end) { energy in
            healthData.basalEnergy = energy
            group.leave()
        }

        // MARK: - Walking Metrics

        // Walking Speed
        group.enter()
        fetchWalkingSpeed(startDate: start, endDate: end) { speed in
            healthData.walkingSpeed = speed
            group.leave()
        }

        // Walking Step Length
        group.enter()
        fetchWalkingStepLength(startDate: start, endDate: end) { length in
            healthData.walkingStepLength = length
            group.leave()
        }

        // Walking Asymmetry
        group.enter()
        fetchWalkingAsymmetry(startDate: start, endDate: end) { asymmetry in
            healthData.walkingAsymmetry = asymmetry
            group.leave()
        }

        // Walking Steadiness
        group.enter()
        fetchWalkingSteadiness(startDate: start, endDate: end) { steadiness in
            healthData.walkingSteadiness = steadiness
            group.leave()
        }

        // Six Minute Walk Distance
        group.enter()
        fetchSixMinuteWalkDistance(startDate: start, endDate: end) { distance in
            healthData.sixMinuteWalkDistance = distance
            group.leave()
        }

        // Heart Rate Recovery
        group.enter()
        fetchHeartRateRecovery(startDate: start, endDate: end) { hrr in
            healthData.heartRateRecovery = hrr
            group.leave()
        }

        // Walking Heart Rate Average
        group.enter()
        fetchWalkingHeartRateAverage(startDate: start, endDate: end) { avgHR in
            healthData.walkingHeartRateAverage = avgHR
            group.leave()
        }

        // MARK: - Workouts

        group.enter()
        fetchWorkouts(startDate: start, endDate: end) { workouts in
            healthData.workoutCount = workouts.count
            healthData.totalWorkoutMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }
            healthData.totalWorkoutCalories = workouts.compactMap(\.totalCalories).reduce(0, +)
            healthData.workoutTypes = Array(Set(workouts.map(\.type)))
            healthData.lastWorkout = workouts.first
            // שומר את כל האימונים המפורטים (עד 50 אחרונים)
            healthData.recentWorkouts = Array(workouts.prefix(50))
            group.leave()
        }

        // Total Energy (Active + Basal)
        group.notify(queue: .main) {
            if let active = healthData.activeEnergy, let basal = healthData.basalEnergy {
                healthData.totalEnergy = active + basal
            }
            healthData.lastUpdated = Date()
            completion(healthData, nil)
        }
    }
    
    // MARK: - Helper Methods
    
    func fetchSteps(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count())
            completion(steps)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchDistance(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let distance = result?.sumQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .kilo))
            completion(distance)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchActiveEnergy(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let energy = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie())
            completion(energy)
        }
        
        healthStore.execute(query)
    }

    func fetchExerciseMinutes(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let unit = HKUnit.minute()
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            guard let qty = res?.sumQuantity(), qty.is(compatibleWith: unit) else { completion(nil); return }
            completion(qty.doubleValue(for: unit))
        }
        healthStore.execute(q)
    }

    private func fetchFlightsClimbed(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let unit = HKUnit.count()
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            guard let qty = res?.sumQuantity(), qty.is(compatibleWith: unit) else { completion(nil); return }
            completion(qty.doubleValue(for: unit))
        }
        healthStore.execute(q)
    }

    private func fetchMoveTimeMinutes(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleMoveTime) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let unitMin = HKUnit.minute()
        let unitCount = HKUnit.count()
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            guard let qty = res?.sumQuantity() else { completion(nil); return }
            if qty.is(compatibleWith: unitMin) { completion(qty.doubleValue(for: unitMin)); return }
            if qty.is(compatibleWith: unitCount) { completion(qty.doubleValue(for: unitCount)); return }
            completion(nil)
        }
        healthStore.execute(q)
    }

    private func fetchStandHours(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleStandTime) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let unitCount = HKUnit.count()
        let unitMin = HKUnit.minute()
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            guard let qty = res?.sumQuantity() else { completion(nil); return }
            if qty.is(compatibleWith: unitCount) {
                completion(qty.doubleValue(for: unitCount))
                return
            }
            if qty.is(compatibleWith: unitMin) {
                let mins = qty.doubleValue(for: unitMin)
                completion(mins / 60.0)
                return
            }
            completion(nil)
        }
        healthStore.execute(q)
    }

    private func fetchDistanceCycling(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .distanceCycling) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            completion(res?.sumQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .kilo)))
        }
        healthStore.execute(q)
    }

    private func fetchDistanceSwimming(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            completion(res?.sumQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .kilo)))
        }
        healthStore.execute(q)
    }
    
    private func fetchHeartRate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let heartRate = result?.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            completion(heartRate)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchRestingHeartRate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: restingHeartRateType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let restingHeartRate = result?.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
            completion(restingHeartRate)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchBloodPressure(startDate: Date, endDate: Date, completion: @escaping (Double?, Double?) -> Void) {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            completion(nil, nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let group = DispatchGroup()
        var systolic: Double?
        var diastolic: Double?
        
        group.enter()
        let systolicQuery = HKStatisticsQuery(quantityType: systolicType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            systolic = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.millimeterOfMercury())
            group.leave()
        }
        
        group.enter()
        let diastolicQuery = HKStatisticsQuery(quantityType: diastolicType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            diastolic = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.millimeterOfMercury())
            group.leave()
        }
        
        healthStore.execute(systolicQuery)
        healthStore.execute(diastolicQuery)
        
        group.notify(queue: .main) {
            completion(systolic, diastolic)
        }
    }
    
    private func fetchOxygenSaturation(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: oxygenType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let oxygen = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.percent())
            completion(oxygen)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchBodyMass(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: bodyMassType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let weight = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            completion(weight)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHeight(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else {
            completion(nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: heightType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let cm = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .centi))
            completion(cm)
        }
        healthStore.execute(query)
    }
    
    /// טוען גובה ומשקל אחרונים לפרופיל. תאריך: עד 10 שנים לאחור. completion: (heightCm, weightKg).
    func fetchProfileMetrics(completion: @escaping (Double?, Double?) -> Void) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .year, value: -10, to: end) ?? end
        var heightCm: Double?
        var weightKg: Double?
        let group = DispatchGroup()
        group.enter()
        fetchHeight(startDate: start, endDate: end) { h in
            heightCm = h
            group.leave()
        }
        group.enter()
        fetchBodyMass(startDate: start, endDate: end) { w in
            weightKg = w
            group.leave()
        }
        group.notify(queue: .main) {
            completion(heightCm, weightKg)
        }
    }

    /// גיל בשנים מתאריך לידה (Health). מחזיר nil אם אין הרשאה/נתון.
    func fetchDateOfBirth(completion: @escaping (Int?) -> Void) {
        guard isHealthDataAvailable() else { completion(nil); return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let comp = try self.healthStore.dateOfBirthComponents()
                guard let birth = Calendar.current.date(from: comp) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let age = Calendar.current.dateComponents([.year], from: birth, to: Date()).year
                DispatchQueue.main.async { completion(age) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    private func fetchBMI(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let bmiType = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: bmiType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let bmi = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.count())
            completion(bmi)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchBodyFatPercentage(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: bodyFatType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let bodyFat = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.percent())
            completion(bodyFat)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchSleepData(startDate: Date, endDate: Date, matchByEndDate: Bool = false, completion: @escaping (Double?, [SleepData]?, Int64?) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, nil, nil)
            return
        }
        let options: HKQueryOptions = matchByEndDate ? .strictEndDate : .strictStartDate
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: options)
        let asleepPredicate = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: HKCategoryValueSleepAnalysis.allAsleepValues)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, asleepPredicate])
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                completion(nil, nil, nil)
                return
            }
            
            var sleepDataArray: [SleepData] = []
            let intervals: [(start: Date, end: Date)] = samples.map { ($0.startDate, $0.endDate) }
            let merged = Self.mergeOverlappingSleepIntervals(intervals)
            let totalSecondsDouble = merged.map { iv in iv.end.timeIntervalSince(iv.start) }.reduce(0, +)
            let totalSeconds = Int64(ceil(totalSecondsDouble))
            let sleepHours = Double(totalSeconds) / 3600.0
            #if DEBUG
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm:ss"
            let rangeStr = merged.isEmpty ? "—" : "\(fmt.string(from: merged[0].start))–\(fmt.string(from: merged[merged.count - 1].end))"
            let rawSum = intervals.map { $0.end.timeIntervalSince($0.start) }.reduce(0, +)
            print("[Sleep DEBUG] samples=\(samples.count) merged=\(merged.count) rawSum=\(rawSum) mergedSum=\(totalSecondsDouble) totalSeconds=\(totalSeconds) range=\(rangeStr) → \(Int(totalSeconds)/3600)h \(Int(totalSeconds)%3600/60)m")
            if merged.count <= 12 {
                for (i, iv) in merged.enumerated() {
                    let d = iv.end.timeIntervalSince(iv.start)
                    print("[Sleep DEBUG]   merged[\(i)] \(fmt.string(from: iv.start))–\(fmt.string(from: iv.end)) = \(Int(d))s")
                }
            }
            #endif
            for sample in samples {
                sleepDataArray.append(SleepData(startDate: sample.startDate, endDate: sample.endDate, value: HKCategoryValueSleepAnalysis(rawValue: sample.value) ?? .asleepUnspecified))
            }
            completion(sleepHours, sleepDataArray.isEmpty ? nil : sleepDataArray, totalSeconds > 0 ? totalSeconds : nil)
        }
        
        healthStore.execute(query)
    }
    
    /// ממזג מקטעי שינה חופפים (כמו באפל) – מסכמים איחוד מקטעים, לא סכום גולמי.
    private static func mergeOverlappingSleepIntervals(_ intervals: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var out: [(start: Date, end: Date)] = [sorted[0]]
        for i in 1..<sorted.count {
            let cur = sorted[i]
            let last = out.last!
            if cur.start <= last.end {
                out[out.count - 1] = (last.start, cur.end > last.end ? cur.end : last.end)
            } else {
                out.append(cur)
            }
        }
        return out
    }
    
    /// זמן במיטה (inBed) – כמו באפל. מרכז מקטעים, סופר שעות.
    private func fetchTimeInBed(startDate: Date, endDate: Date, matchByEndDate: Bool = false, completion: @escaping (Double?) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }
        let options: HKQueryOptions = matchByEndDate ? .strictEndDate : .strictStartDate
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: options)
        let inBedPredicate = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: Set([HKCategoryValueSleepAnalysis.inBed]))
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, inBedPredicate])
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: []) { [weak self] _, samples, _ in
            guard let self = self, let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                completion(nil)
                return
            }
            let intervals: [(start: Date, end: Date)] = samples.map { ($0.startDate, $0.endDate) }
            let merged = Self.mergeOverlappingSleepIntervals(intervals)
            var totalSeconds: Int64 = 0
            for iv in merged {
                totalSeconds += Int64(round(iv.end.timeIntervalSince(iv.start)))
            }
            completion(Double(totalSeconds) / 3600.0)
        }
        healthStore.execute(query)
    }

    /// קצב נשימות בטווח (למשל בזמן שינה) – min/max נשימות לדקה.
    private func fetchRespiratoryRateInRange(startDate: Date, endDate: Date, completion: @escaping ((min: Double, max: Double)?) -> Void) {
        guard let rt = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let unit = HKUnit(from: "count/min")
        let query = HKSampleQuery(sampleType: rt, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: []) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                completion(nil)
                return
            }
            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            guard let mn = values.min(), let mx = values.max() else {
                completion(nil)
                return
            }
            completion((min: mn, max: mx))
        }
        healthStore.execute(query)
    }

    private func fetchDietaryEnergy(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie())
            completion(calories)
        }
        healthStore.execute(query)
    }

    private func fetchDietaryProtein(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            completion(res?.sumQuantity()?.doubleValue(for: HKUnit.gram()))
        }
        healthStore.execute(q)
    }

    private func fetchDietaryCarbs(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            completion(res?.sumQuantity()?.doubleValue(for: HKUnit.gram()))
        }
        healthStore.execute(q)
    }

    private func fetchDietaryFat(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            completion(res?.sumQuantity()?.doubleValue(for: HKUnit.gram()))
        }
        healthStore.execute(q)
    }

    private func fetchBloodGlucose(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: glucoseType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let glucose = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: HKUnit.liter()))
            completion(glucose)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchVO2Max(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: vo2MaxType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let vo2Max = result?.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "ml/kg*min"))
            completion(vo2Max)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchHRV(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let ms = result?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
            completion(ms)
        }
        healthStore.execute(query)
    }
    
    /// יוצר Weekly Snapshot לשבוע מסוים
    func createWeeklySnapshot(weekStartDate: Date, weekEndDate: Date, completion: @escaping (WeeklyHealthSnapshot) -> Void) {
        createWeeklySnapshot(weekStartDate: weekStartDate, weekEndDate: weekEndDate, previousWeekSnapshot: nil, completion: completion)
    }
    
    /// יוצר Weekly Snapshot לשבוע מסוים עם נתונים מהשבוע הקודם לחישובים
    func createWeeklySnapshot(weekStartDate: Date, weekEndDate: Date, previousWeekSnapshot: WeeklyHealthSnapshot?, completion: @escaping (WeeklyHealthSnapshot) -> Void) {
        var snapshot = WeeklyHealthSnapshot(weekStartDate: weekStartDate, weekEndDate: weekEndDate)
        let group = DispatchGroup()
        
        // דופק במנוחה (ממוצע שבועי)
        group.enter()
        fetchRestingHeartRate(startDate: weekStartDate, endDate: weekEndDate) { rhr in
            snapshot.restingHeartRate = rhr
            group.leave()
        }
        
        // שינה (סה"כ שעות)
        group.enter()
        fetchSleepData(startDate: weekStartDate, endDate: weekEndDate) { sleepHours, _, _ in
            snapshot.sleepDurationHours = sleepHours
            group.leave()
        }
        
        // קלוריות פעילות (סה"כ)
        group.enter()
        fetchActiveEnergy(startDate: weekStartDate, endDate: weekEndDate) { calories in
            snapshot.activeCalories = calories
            group.leave()
        }
        
        // VO2 Max (הכי עדכני)
        group.enter()
        fetchVO2Max(startDate: weekStartDate, endDate: weekEndDate) { vo2Max in
            snapshot.vo2Max = vo2Max
            group.leave()
        }
        
        // צעדים
        group.enter()
        fetchSteps(startDate: weekStartDate, endDate: weekEndDate) { steps in
            snapshot.steps = steps
            group.leave()
        }
        
        // מרחק
        group.enter()
        fetchDistance(startDate: weekStartDate, endDate: weekEndDate) { distance in
            snapshot.distanceKm = distance
            group.leave()
        }
        
        // דופק ממוצע
        group.enter()
        fetchHeartRate(startDate: weekStartDate, endDate: weekEndDate) { heartRate in
            snapshot.averageHeartRate = heartRate
            group.leave()
        }
        
        // משקל
        group.enter()
        fetchBodyMass(startDate: weekStartDate, endDate: weekEndDate) { weight in
            snapshot.bodyMass = weight
            group.leave()
        }
        
        // BMI
        group.enter()
        fetchBMI(startDate: weekStartDate, endDate: weekEndDate) { bmi in
            snapshot.bodyMassIndex = bmi
            group.leave()
        }
        
        // לחץ דם
        group.enter()
        fetchBloodPressure(startDate: weekStartDate, endDate: weekEndDate) { systolic, diastolic in
            snapshot.bloodPressureSystolic = systolic
            snapshot.bloodPressureDiastolic = diastolic
            group.leave()
        }
        
        // ריווי חמצן
        group.enter()
        fetchOxygenSaturation(startDate: weekStartDate, endDate: weekEndDate) { oxygen in
            snapshot.oxygenSaturation = oxygen
            group.leave()
        }
        
        // קלוריות תזונתיות
        group.enter()
        fetchDietaryEnergy(startDate: weekStartDate, endDate: weekEndDate) { calories in
            snapshot.dietaryEnergy = calories
            group.leave()
        }
        
        // Training Strain
        group.enter()
        calculateTrainingStrain(startDate: weekStartDate, endDate: weekEndDate) { strain in
            snapshot.trainingStrain = strain
            group.leave()
        }
        
        // Efficiency Factor
        group.enter()
        calculateEfficiencyFactor(distance: snapshot.distanceKm, averageHR: snapshot.averageHeartRate) { ef in
            snapshot.efficiencyFactor = ef
            group.leave()
        }
        
        // Recovery Score (נדרש HRV ו-RHR מהשבוע הקודם)
        group.enter()
        let previousHRV = previousWeekSnapshot?.heartRateVariability
        let previousRHR = previousWeekSnapshot?.restingHeartRate
        var currentHRV: Double?
        var currentRHR: Double?
        var currentSleep: Double?
        
        // נאסוף את הנתונים הנדרשים
        let recoveryGroup = DispatchGroup()
        recoveryGroup.enter()
        fetchRestingHeartRate(startDate: weekStartDate, endDate: weekEndDate) { rhr in
            currentRHR = rhr
            snapshot.restingHeartRate = rhr
            recoveryGroup.leave()
        }
        
        recoveryGroup.enter()
            fetchSleepData(startDate: weekStartDate, endDate: weekEndDate) { sleepHours, _, _ in
            currentSleep = sleepHours
            snapshot.sleepDurationHours = sleepHours
            recoveryGroup.leave()
        }
        
        recoveryGroup.notify(queue: .main) {
            self.calculateRecoveryScore(hrv: currentHRV, rhr: currentRHR, sleepHours: currentSleep, previousHRV: previousHRV, previousRHR: previousRHR) { recovery in
                snapshot.recoveryScore = recovery
                group.leave()
            }
        }

        // MARK: - Activity Rings Data

        // Exercise Minutes
        group.enter()
        fetchExerciseMinutes(startDate: weekStartDate, endDate: weekEndDate) { minutes in
            snapshot.exerciseMinutes = minutes
            group.leave()
        }

        // Stand Hours
        group.enter()
        fetchStandHours(startDate: weekStartDate, endDate: weekEndDate) { hours in
            snapshot.standHours = hours
            group.leave()
        }

        // Flights Climbed
        group.enter()
        fetchFlightsClimbed(startDate: weekStartDate, endDate: weekEndDate) { flights in
            snapshot.flightsClimbed = flights
            group.leave()
        }

        // MARK: - Workouts

        group.enter()
        fetchWorkouts(startDate: weekStartDate, endDate: weekEndDate) { workouts in
            snapshot.workoutCount = workouts.count
            snapshot.totalWorkoutMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }
            snapshot.workoutTypes = Array(Set(workouts.map(\.type)))
            group.leave()
        }

        // MARK: - Walking Metrics

        group.enter()
        fetchWalkingSpeed(startDate: weekStartDate, endDate: weekEndDate) { speed in
            snapshot.walkingSpeed = speed
            group.leave()
        }

        group.enter()
        fetchHeartRateRecovery(startDate: weekStartDate, endDate: weekEndDate) { hrr in
            snapshot.heartRateRecovery = hrr
            group.leave()
        }

        group.notify(queue: .main) {
            completion(snapshot)
        }
    }
    
    /// מחשב ממוצע HRV של 7 ימים
    func calculateHRV7DayAverage(endDate: Date, completion: @escaping (Double?) -> Void) {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -7, to: endDate) else {
            completion(nil)
            return
        }
        fetchHRV(startDate: start, endDate: endDate, completion: completion)
    }
    
    /// מחשב Training Strain (1-10) על בסיס HR zones
    func calculateTrainingStrain(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                completion(nil)
                return
            }
            
            // חישוב פשוט של strain על בסיס זמן ב-zones שונים
            // Zone 5 (90-100%): 10 points/hour
            // Zone 4 (80-90%): 7 points/hour
            // Zone 3 (70-80%): 4 points/hour
            // Zone 2 (60-70%): 2 points/hour
            // Zone 1 (50-60%): 1 point/hour
            
            var totalStrain: Double = 0
            var totalDuration: TimeInterval = 0
            
            for sample in samples {
                let hr = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                totalDuration += duration
                
                // חישוב strain על בסיס HR (הנחה: max HR = 220 - age, נשתמש ב-190 כערך ברירת מחדל)
                let maxHR: Double = 190
                let hrPercent = hr / maxHR
                
                var zoneMultiplier: Double = 0
                if hrPercent >= 0.9 {
                    zoneMultiplier = 10.0
                } else if hrPercent >= 0.8 {
                    zoneMultiplier = 7.0
                } else if hrPercent >= 0.7 {
                    zoneMultiplier = 4.0
                } else if hrPercent >= 0.6 {
                    zoneMultiplier = 2.0
                } else if hrPercent >= 0.5 {
                    zoneMultiplier = 1.0
                }
                
                totalStrain += zoneMultiplier * (duration / 3600.0) // שעות
            }
            
            // נרמול ל-1-10
            let normalizedStrain = min(10.0, totalStrain / max(1.0, totalDuration / 3600.0 / 24.0)) // נרמול ליום
            completion(normalizedStrain)
        }
        
        healthStore.execute(query)
    }
    
    /// מחשב Recovery Score (0-100%) על בסיס HRV, RHR, ושינה
    func calculateRecoveryScore(hrv: Double?, rhr: Double?, sleepHours: Double?, previousHRV: Double?, previousRHR: Double?, completion: @escaping (Double?) -> Void) {
        var score: Double = 50.0 // נקודת התחלה
        
        // HRV component (40% מהציון)
        if let hrv = hrv, let prevHRV = previousHRV, prevHRV > 0 {
            let hrvChange = (hrv / prevHRV) * 100.0
            if hrvChange >= 100 {
                score += 20.0 // HRV טוב
            } else if hrvChange >= 90 {
                score += 10.0
            } else if hrvChange < 90 {
                score -= 20.0 // HRV נמוך
            }
        }
        
        // RHR component (30% מהציון)
        if let rhr = rhr, let prevRHR = previousRHR, prevRHR > 0 {
            let rhrChange = (rhr / prevRHR) * 100.0
            if rhrChange <= 100 {
                score += 15.0 // RHR תקין או נמוך יותר
            } else if rhrChange <= 105 {
                score += 5.0
            } else {
                score -= 15.0 // RHR גבוה
            }
        }
        
        // Sleep component (30% מהציון)
        if let sleep = sleepHours {
            if sleep >= 8.0 {
                score += 15.0
            } else if sleep >= 7.0 {
                score += 10.0
            } else if sleep >= 6.0 {
                score += 5.0
            } else {
                score -= 15.0
            }
        }
        
        // נרמול ל-0-100
        score = max(0.0, min(100.0, score))
        completion(score)
    }
    
    /// מחשב Efficiency Factor (Pace/HR או Distance/HR)
    func calculateEfficiencyFactor(distance: Double?, averageHR: Double?, completion: @escaping (Double?) -> Void) {
        guard let dist = distance, let hr = averageHR, hr > 0, dist > 0 else {
            completion(nil)
            return
        }
        
        // EF = distance / HR (ככל שהערך גבוה יותר, כך היעילות טובה יותר)
        let ef = dist / hr
        completion(ef)
    }
    
    // MARK: - Chart Data (להגרפים המקצועיים)
    
    /// טוען נתונים יומיים לכל 6 הגרפים של AION
    func fetchChartData(for range: DataRange, completion: @escaping (AIONChartDataBundle?) -> Void) {
        let (start, end) = range.interval()
        let label = range.displayLabel()
        let cal = Calendar.current
        
        var dayBuckets: [(Date, Date)] = []
        var cur = cal.startOfDay(for: start)
        let endDay = end
        while cur <= endDay {
            let dayStart = cur
            let nextDay = cal.date(byAdding: .day, value: 1, to: cur) ?? cur
            let dayEnd = nextDay > endDay ? endDay : nextDay
            dayBuckets.append((dayStart, dayEnd))
            cur = nextDay
        }
        if dayBuckets.isEmpty { dayBuckets = [(start, end)] }
        
        var readinessPoints: [ReadinessDataPoint] = []
        var efficiencyPoints: [EfficiencyDataPoint] = []
        var sleepPoints: [SleepDayPoint] = []
        var glucosePoints: [GlucoseEnergyPoint] = []
        var nutritionPoints: [NutritionDayPoint] = []
        var stepsPoints: [StepsDataPoint] = []
        var rhrTrendPoints: [TrendDataPoint] = []
        var hrvTrendPoints: [TrendDataPoint] = []
        
        var lastRHR: Double?
        var lastHRV: Double?
        var lastRespiratory: Double?
        let group = DispatchGroup()
        
        for (dayStart, dayEnd) in dayBuckets {
            group.enter()
            var energy: Double?
            var steps: Double?
            var dist: Double?
            var sleepHours: Double?
            var sleepTotalSeconds: Int64?
            var deepHours: Double?
            var remHours: Double?
            var timeInBedHours: Double?
            var respiratoryMin: Double?
            var respiratoryMax: Double?
            var rhr: Double?
            var hrv: Double?
            var glucose: Double?
            var heartRate: Double?
            
            let g = DispatchGroup()
            g.enter()
            fetchActiveEnergy(startDate: dayStart, endDate: dayEnd) { energy = $0; g.leave() }
            g.enter()
            fetchSteps(startDate: dayStart, endDate: dayEnd) { steps = $0; g.leave() }
            g.enter()
            fetchDistance(startDate: dayStart, endDate: dayEnd) { dist = $0; g.leave() }
            g.enter()
            fetchTimeInBed(startDate: dayStart, endDate: dayEnd, matchByEndDate: true) { timeInBedHours = $0; g.leave() }
            g.enter()
            fetchSleepData(startDate: dayStart, endDate: dayEnd, matchByEndDate: true) { [weak self] hours, sleepData, secs in
                sleepHours = hours
                sleepTotalSeconds = secs
                if let arr = sleepData {
                    var deep: Double = 0, rem: Double = 0
                    for s in arr {
                        let d = s.endDate.timeIntervalSince(s.startDate) / 3600.0
                        if s.value == .asleepDeep { deep += d }
                        else if s.value == .asleepREM { rem += d }
                    }
                    deepHours = deep > 0 ? deep : nil
                    remHours = rem > 0 ? rem : nil
                    let sleepStart = arr.map(\.startDate).min()!
                    let sleepEnd = arr.map(\.endDate).max()!
                    self?.fetchRespiratoryRateInRange(startDate: sleepStart, endDate: sleepEnd) { res in
                        if let r = res {
                            respiratoryMin = r.min
                            respiratoryMax = r.max
                        }
                        g.leave()
                    }
                } else {
                    g.leave()
                }
            }
            g.enter()
            fetchRestingHeartRate(startDate: dayStart, endDate: dayEnd) { rhr = $0; g.leave() }
            g.enter()
            fetchHRV(startDate: dayStart, endDate: dayEnd) { hrv = $0; g.leave() }
            g.enter()
            fetchBloodGlucose(startDate: dayStart, endDate: dayEnd) { glucose = $0; g.leave() }
            g.enter()
            fetchHeartRate(startDate: dayStart, endDate: dayEnd) { heartRate = $0; g.leave() }
            var protein: Double?
            var carbs: Double?
            var fat: Double?
            g.enter()
            fetchDietaryProtein(startDate: dayStart, endDate: dayEnd) { protein = $0; g.leave() }
            g.enter()
            fetchDietaryCarbs(startDate: dayStart, endDate: dayEnd) { carbs = $0; g.leave() }
            g.enter()
            fetchDietaryFat(startDate: dayStart, endDate: dayEnd) { fat = $0; g.leave() }
            
            g.notify(queue: .main) {
                // רק אם יש נתון אמיתי אחד לפחות ליום זה – ניצור readiness point
                let hasDayData = energy != nil || sleepHours != nil || rhr != nil || hrv != nil
                if hasDayData {
                    let strain = min(10.0, (energy ?? 0) / 200.0)
                    var recovery: Double = 50
                    if let s = sleepHours {
                        if s >= 8 { recovery += 25 } else if s >= 7 { recovery += 15 } else if s >= 6 { recovery += 5 } else { recovery -= 20 }
                    }
                    if let r = rhr {
                        lastRHR = r
                        if r < 55 { recovery += 10 } else if r > 75 { recovery -= 15 }
                    }
                    recovery = max(0, min(100, recovery))
                    readinessPoints.append(ReadinessDataPoint(date: dayStart, recovery: recovery, strain: strain))
                }
                efficiencyPoints.append(EfficiencyDataPoint(date: dayStart, avgHeartRate: heartRate, distanceKm: dist, activeCalories: energy))
                sleepPoints.append(SleepDayPoint(date: dayStart, totalHours: sleepHours, totalSeconds: sleepTotalSeconds, deepHours: deepHours, remHours: remHours, bbt: nil, timeInBedHours: timeInBedHours, respiratoryMin: respiratoryMin, respiratoryMax: respiratoryMax))
                glucosePoints.append(GlucoseEnergyPoint(date: dayStart, glucose: glucose, activeEnergy: energy))
                nutritionPoints.append(NutritionDayPoint(date: dayStart, protein: protein, carbs: carbs, fat: fat, proteinGoal: nil, carbsGoal: nil, fatGoal: nil))
                stepsPoints.append(StepsDataPoint(date: dayStart, steps: steps ?? 0))
                if let r = rhr { rhrTrendPoints.append(TrendDataPoint(date: dayStart, value: r)) }
                if let h = hrv { hrvTrendPoints.append(TrendDataPoint(date: dayStart, value: h)) }
                
                if let h = hrv { lastHRV = h }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            readinessPoints.sort { $0.date < $1.date }
            efficiencyPoints.sort { $0.date < $1.date }
            sleepPoints.sort { $0.date < $1.date }
            glucosePoints.sort { $0.date < $1.date }
            nutritionPoints.sort { $0.date < $1.date }
            stepsPoints.sort { $0.date < $1.date }
            rhrTrendPoints.sort { $0.date < $1.date }
            hrvTrendPoints.sort { $0.date < $1.date }
            
            let rhrNorm = lastRHR.map { min(100, max(0, ($0 - 40) / 1.2)) }
            let hrvNorm = lastHRV.map { min(100, $0 / 1.5) }
            let autonomic = AutonomicRadarData(rhr: rhrNorm, hrv: hrvNorm, respiratory: lastRespiratory, stressIndicator: nil, periodLabel: label)
            
            let bundle = AIONChartDataBundle(
                range: range,
                rangeLabel: label,
                readiness: ReadinessGraphData(points: readinessPoints, periodLabel: label),
                efficiency: EfficiencyGraphData(points: efficiencyPoints, periodLabel: label),
                sleep: SleepArchitectureGraphData(points: sleepPoints, periodLabel: label),
                glucoseEnergy: GlucoseEnergyGraphData(points: glucosePoints, periodLabel: label),
                autonomic: autonomic,
                nutrition: NutritionGraphData(points: nutritionPoints, periodLabel: label),
                steps: StepsGraphData(points: stepsPoints, periodLabel: label),
                rhrTrend: RHRTrendGraphData(points: rhrTrendPoints, periodLabel: label),
                hrvTrend: HRVTrendGraphData(points: hrvTrendPoints, periodLabel: label)
            )
            completion(bundle)
        }
    }

    // MARK: - Data Source Detection

    /// זיהוי מקורות נתונים מדגימות HealthKit
    func detectDataSources(for dataType: HKSampleType, days: Int = 7, completion: @escaping (SourceDetectionResult?) -> Void) {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: dataType, predicate: predicate, limit: 100, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
            guard let samples = samples, !samples.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let result = DataSourceManager.shared.analyzeDataSources(samples: samples)
            DispatchQueue.main.async { completion(result) }
        }
        healthStore.execute(query)
    }

    /// זיהוי מקור עיקרי מכל סוגי הנתונים
    func detectPrimaryDataSource(completion: @escaping (HealthDataSource) -> Void) {
        // בודקים דופק מנוחה ו-HRV - הכי אמינים לזיהוי מכשיר
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(.appleWatch)
            return
        }

        let group = DispatchGroup()
        var allSamples: [HKSample] = []

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        // RHR samples
        group.enter()
        let rhrQuery = HKSampleQuery(sampleType: rhrType, predicate: predicate, limit: 50, sortDescriptors: nil) { _, samples, _ in
            if let s = samples { allSamples.append(contentsOf: s) }
            group.leave()
        }
        healthStore.execute(rhrQuery)

        // HRV samples
        group.enter()
        let hrvQuery = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 50, sortDescriptors: nil) { _, samples, _ in
            if let s = samples { allSamples.append(contentsOf: s) }
            group.leave()
        }
        healthStore.execute(hrvQuery)

        group.notify(queue: .main) {
            if allSamples.isEmpty {
                completion(.appleWatch)
                return
            }
            let result = DataSourceManager.shared.analyzeDataSources(samples: allSamples)
            completion(result.primarySource)
        }
    }

    // MARK: - Enhanced Sleep Data (Garmin/Oura detailed stages)

    /// שליפת נתוני שינה מפורטים עם כל השלבים
    func fetchDetailedSleepData(startDate: Date, endDate: Date, completion: @escaping (DetailedSleepStages?) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: datePredicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var deepSleep: TimeInterval = 0
            var remSleep: TimeInterval = 0
            var lightSleep: TimeInterval = 0
            var awakeTime: TimeInterval = 0
            var inBedTime: TimeInterval = 0

            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }

                switch value {
                case .asleepDeep:
                    deepSleep += duration
                case .asleepREM:
                    remSleep += duration
                case .asleepCore:
                    lightSleep += duration
                case .asleepUnspecified:
                    // אם אין פירוט - מניחים שינה קלה
                    lightSleep += duration
                case .awake:
                    awakeTime += duration
                case .inBed:
                    inBedTime += duration
                @unknown default:
                    break
                }
            }

            let totalSleep = deepSleep + remSleep + lightSleep
            let timeInBed = totalSleep + awakeTime + inBedTime

            let result = DetailedSleepStages(
                deepSleep: deepSleep,
                remSleep: remSleep,
                lightSleep: lightSleep,
                awakeTime: awakeTime,
                totalSleep: totalSleep,
                timeInBed: timeInBed
            )

            DispatchQueue.main.async { completion(result) }
        }
        healthStore.execute(query)
    }

    // MARK: - Body Temperature (Oura)

    /// שליפת טמפרטורת גוף בסיסית (Oura מסנכרן לאפל הלט')
    func fetchBasalBodyTemperature(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: tempType, quantitySamplePredicate: predicate, options: .mostRecent) { _, result, _ in
            let temp = result?.mostRecentQuantity()?.doubleValue(for: HKUnit.degreeCelsius())
            DispatchQueue.main.async { completion(temp) }
        }
        healthStore.execute(query)
    }

    /// שליפת סטיית טמפרטורה מהבסיס (7 ימים אחורה)
    func fetchBodyTemperatureDeviation(completion: @escaping (Double?) -> Void) {
        let end = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end

        var baselineTemp: Double?
        var recentTemp: Double?

        let group = DispatchGroup()

        // Baseline (7 days)
        group.enter()
        fetchBasalBodyTemperature(startDate: weekAgo, endDate: yesterday) { temp in
            baselineTemp = temp
            group.leave()
        }

        // Recent (last day)
        group.enter()
        fetchBasalBodyTemperature(startDate: yesterday, endDate: end) { temp in
            recentTemp = temp
            group.leave()
        }

        group.notify(queue: .main) {
            guard let baseline = baselineTemp, let recent = recentTemp else {
                completion(nil)
                return
            }
            completion(recent - baseline)
        }
    }

    // MARK: - SpO2 (Oxygen Saturation)

    /// שליפת רמת חמצן ממוצעת
    func fetchSpO2Average(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let o2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: o2Type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let spo2 = result?.averageQuantity()?.doubleValue(for: HKUnit.percent())
            DispatchQueue.main.async {
                // המרה מ-0-1 ל-0-100 אם צריך
                if let val = spo2, val <= 1 {
                    completion(val * 100)
                } else {
                    completion(spo2)
                }
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Heart Rate Samples for Strain Calculation

    /// שליפת דגימות דופק לחישוב Training Strain
    func fetchHeartRateSamples(startDate: Date, endDate: Date, completion: @escaping ([(value: Double, date: Date)]) -> Void) {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let unit = HKUnit(from: "count/min")
            let result = samples.map { (value: $0.quantity.doubleValue(for: unit), date: $0.startDate) }
            DispatchQueue.main.async { completion(result) }
        }
        healthStore.execute(query)
    }

    // MARK: - HRV Baseline

    /// שליפת ממוצע HRV ל-7 ימים (baseline)
    func fetchHRVBaseline(days: Int = 7, completion: @escaping (Double?) -> Void) {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end),
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            let hrv = result?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
            DispatchQueue.main.async { completion(hrv) }
        }
        healthStore.execute(query)
    }

    /// שליפת מערך HRV יומי לחישוב מגמה
    func fetchDailyHRVValues(days: Int = 7, completion: @escaping ([Double]) -> Void) {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else {
            completion([])
            return
        }

        var dailyValues: [Double] = []
        let group = DispatchGroup()
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: end),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            group.enter()
            fetchHRV(startDate: calendar.startOfDay(for: dayStart), endDate: calendar.startOfDay(for: dayEnd)) { hrv in
                if let h = hrv { dailyValues.append(h) }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(dailyValues.reversed()) // מהישן לחדש
        }
    }

    // MARK: - Enhanced Data Fetch with Source

    /// שליפת כל הנתונים המורחבים כולל מקור וציונים מחושבים
    func fetchEnhancedHealthData(for range: DataRange, completion: @escaping (HealthDataModel?) -> Void) {
        let (start, end) = range.interval()
        var model = HealthDataModel()

        let group = DispatchGroup()

        // Basic data
        group.enter()
        fetchAllHealthData(for: range) { basic, _ in
            if let b = basic {
                model = b
            }
            group.leave()
        }

        // Detect primary source
        group.enter()
        detectPrimaryDataSource { source in
            model.primaryDataSource = source
            group.leave()
        }

        // Detailed sleep stages
        group.enter()
        fetchDetailedSleepData(startDate: start, endDate: end) { stages in
            if let s = stages {
                model.sleepDeepHours = s.deepSleep / 3600
                model.sleepRemHours = s.remSleep / 3600
                model.sleepLightHours = s.lightSleep / 3600
                model.sleepAwakeMinutes = s.awakeTime / 60
                model.sleepEfficiency = s.timeInBed > 0 ? (s.totalSleep / s.timeInBed) * 100 : nil
                model.timeInBedHours = s.timeInBed / 3600
            }
            group.leave()
        }

        // Body temperature deviation (Oura)
        group.enter()
        fetchBodyTemperatureDeviation { deviation in
            model.bodyTemperatureDeviation = deviation
            group.leave()
        }

        // SpO2
        group.enter()
        fetchSpO2Average(startDate: start, endDate: end) { spo2 in
            model.spO2 = spo2
            group.leave()
        }

        // HRV baseline and trend
        group.enter()
        fetchHRVBaseline(days: 7) { baseline in
            model.hrv7DayBaseline = baseline
            group.leave()
        }

        group.enter()
        fetchDailyHRVValues(days: 7) { values in
            if let baseline = model.hrv7DayBaseline, !values.isEmpty {
                model.hrvTrend = CalculatedMetricsEngine.shared.calculateHRVTrend(recentHRV: values, baselineHRV: baseline)
            }
            group.leave()
        }

        group.notify(queue: .main) {
            // Calculate Readiness Score
            let readiness = CalculatedMetricsEngine.shared.calculateReadinessScore(
                hrv: model.heartRateVariability,
                hrvBaseline7Day: model.hrv7DayBaseline,
                rhr: model.restingHeartRate,
                rhrBaseline7Day: nil, // TODO: add RHR baseline
                sleepHours: model.sleepHours,
                sleepEfficiency: model.sleepEfficiency,
                previousDayStrain: nil,
                dataSource: model.primaryDataSource ?? .autoDetect
            )
            model.calculatedReadinessScore = Double(readiness.score)
            model.isReadinessCalculated = true

            completion(model)
        }
    }

    // MARK: - Workouts

    /// שליפת כל האימונים בטווח תאריכים
    func fetchWorkouts(startDate: Date, endDate: Date, completion: @escaping ([WorkoutData]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let workouts = samples as? [HKWorkout] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let workoutData = workouts.map { workout -> WorkoutData in
                let typeString = Self.workoutTypeString(workout.workoutActivityType)
                let duration = workout.duration / 60.0 // to minutes
                let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                let distance = workout.totalDistance?.doubleValue(for: .meter())

                return WorkoutData(
                    type: typeString,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    durationMinutes: duration,
                    totalCalories: calories,
                    totalDistance: distance,
                    averageHeartRate: nil, // Would need separate query
                    maxHeartRate: nil,
                    elevationGain: nil
                )
            }

            DispatchQueue.main.async { completion(workoutData) }
        }

        healthStore.execute(query)
    }

    /// המרת סוג אימון לטקסט
    private static func workoutTypeString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "Cross Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .hiking: return "Hiking"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .dance: return "Dance"
        case .coreTraining: return "Core Training"
        case .pilates: return "Pilates"
        case .mixedCardio: return "Mixed Cardio"
        case .cooldown: return "Cooldown"
        case .flexibility: return "Flexibility"
        default: return "Workout"
        }
    }

    // MARK: - Walking Metrics

    /// מהירות הליכה ממוצעת (קמ"ש)
    func fetchWalkingSpeed(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .walkingSpeed) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, res, _ in
            let mps = res?.averageQuantity()?.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
            completion(mps.map { $0 * 3.6 }) // convert m/s to km/h
        }
        healthStore.execute(q)
    }

    /// אורך צעד ממוצע (מטר)
    func fetchWalkingStepLength(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .walkingStepLength) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, res, _ in
            completion(res?.averageQuantity()?.doubleValue(for: HKUnit.meter()))
        }
        healthStore.execute(q)
    }

    /// אסימטריית הליכה (%)
    func fetchWalkingAsymmetry(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .walkingAsymmetryPercentage) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, res, _ in
            completion(res?.averageQuantity()?.doubleValue(for: HKUnit.percent()))
        }
        healthStore.execute(q)
    }

    /// יציבות הליכה
    func fetchWalkingSteadiness(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .mostRecent) { _, res, _ in
            completion(res?.mostRecentQuantity()?.doubleValue(for: HKUnit.percent()))
        }
        healthStore.execute(q)
    }

    /// מרחק מבחן 6 דקות הליכה
    func fetchSixMinuteWalkDistance(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .sixMinuteWalkTestDistance) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .mostRecent) { _, res, _ in
            completion(res?.mostRecentQuantity()?.doubleValue(for: HKUnit.meter()))
        }
        healthStore.execute(q)
    }

    /// Heart Rate Recovery (דקה אחת אחרי אימון)
    func fetchHeartRateRecovery(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .mostRecent) { _, res, _ in
            completion(res?.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")))
        }
        healthStore.execute(q)
    }

    /// אנרגיה בסיסית (BMR)
    func fetchBasalEnergy(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .cumulativeSum) { _, res, _ in
            completion(res?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()))
        }
        healthStore.execute(q)
    }

    /// Walking Heart Rate Average
    func fetchWalkingHeartRateAverage(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let t = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) else { completion(nil); return }
        let p = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: t, quantitySamplePredicate: p, options: .discreteAverage) { _, res, _ in
            completion(res?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")))
        }
        healthStore.execute(q)
    }

    // MARK: - Daily Health Data for Gemini Payload

    /// שליפת נתוני בריאות יומיים ל-X ימים (ברירת מחדל: 90 ימים)
    /// מחזיר מערך של RawDailyHealthEntry לשימוש ב-GeminiHealthPayloadBuilder
    func fetchDailyHealthData(days: Int = 90, completion: @escaping ([RawDailyHealthEntry]) -> Void) {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            completion([])
            return
        }

        var entries: [Date: RawDailyHealthEntry] = [:]
        let group = DispatchGroup()

        // Initialize entries for each day
        for dayOffset in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: endDate) {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart] = RawDailyHealthEntry(date: dayStart)
            }
        }

        // Fetch Sleep Data (daily)
        group.enter()
        fetchDailySleepData(startDate: startDate, endDate: endDate) { sleepData in
            for (date, data) in sleepData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.sleepHours = data.totalHours
                entries[dayStart]?.deepSleepHours = data.deepHours
                entries[dayStart]?.remSleepHours = data.remHours
            }
            group.leave()
        }

        // Fetch HRV Data (daily)
        group.enter()
        fetchDailyMetric(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), startDate: startDate, endDate: endDate) { hrvData in
            for (date, value) in hrvData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.hrvMs = value
            }
            group.leave()
        }

        // Fetch Resting Heart Rate (daily)
        group.enter()
        fetchDailyMetric(.restingHeartRate, unit: HKUnit(from: "count/min"), startDate: startDate, endDate: endDate) { rhrData in
            for (date, value) in rhrData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.restingHR = value
            }
            group.leave()
        }

        // Fetch Steps (daily)
        group.enter()
        fetchDailySteps(startDate: startDate, endDate: endDate) { stepsData in
            for (date, value) in stepsData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.steps = value
            }
            group.leave()
        }

        // Fetch Active Calories (daily)
        group.enter()
        fetchDailyActiveCalories(startDate: startDate, endDate: endDate) { caloriesData in
            for (date, value) in caloriesData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.activeCalories = value
            }
            group.leave()
        }

        // Fetch VO2 Max (daily - usually less frequent)
        group.enter()
        fetchDailyMetric(.vo2Max, unit: HKUnit(from: "ml/kg*min"), startDate: startDate, endDate: endDate) { vo2Data in
            for (date, value) in vo2Data {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.vo2max = value
            }
            group.leave()
        }

        // Fetch Weight (daily - usually less frequent)
        group.enter()
        fetchDailyMetric(.bodyMass, unit: HKUnit.gramUnit(with: .kilo), startDate: startDate, endDate: endDate) { weightData in
            for (date, value) in weightData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.weightKg = value
            }
            group.leave()
        }

        // Fetch Body Fat % (daily - usually less frequent)
        group.enter()
        fetchDailyMetric(.bodyFatPercentage, unit: HKUnit.percent(), startDate: startDate, endDate: endDate) { bfData in
            for (date, value) in bfData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.bodyFatPercent = value * 100 // Convert from 0-1 to 0-100
            }
            group.leave()
        }

        // Fetch Workouts (count per day)
        group.enter()
        fetchDailyWorkoutCount(startDate: startDate, endDate: endDate) { workoutData in
            for (date, count) in workoutData {
                let dayStart = calendar.startOfDay(for: date)
                entries[dayStart]?.workoutCount = count
            }
            group.leave()
        }

        group.notify(queue: .main) {
            // Convert to sorted array
            let result = entries.values.sorted { $0.date < $1.date }
            completion(result)
        }
    }

    // MARK: - Helper: Fetch Daily Metric

    private func fetchDailyMetric(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, startDate: Date, endDate: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion([])
            return
        }

        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1

        let anchorDate = calendar.startOfDay(for: startDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            options: [.discreteAverage],
            anchorDate: anchorDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            var data: [(Date, Double)] = []

            results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let average = statistics.averageQuantity()?.doubleValue(for: unit) {
                    data.append((statistics.startDate, average))
                }
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Helper: Fetch Daily Steps

    private func fetchDailySteps(startDate: Date, endDate: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion([])
            return
        }

        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1

        let anchorDate = calendar.startOfDay(for: startDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            options: [.cumulativeSum],
            anchorDate: anchorDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            var data: [(Date, Double)] = []

            results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let sum = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) {
                    data.append((statistics.startDate, sum))
                }
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Helper: Fetch Daily Active Calories

    private func fetchDailyActiveCalories(startDate: Date, endDate: Date, completion: @escaping ([(Date, Double)]) -> Void) {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion([])
            return
        }

        let calendar = Calendar.current
        var interval = DateComponents()
        interval.day = 1

        let anchorDate = calendar.startOfDay(for: startDate)

        let query = HKStatisticsCollectionQuery(
            quantityType: caloriesType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
            options: [.cumulativeSum],
            anchorDate: anchorDate,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, results, _ in
            var data: [(Date, Double)] = []

            results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let sum = statistics.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) {
                    data.append((statistics.startDate, sum))
                }
            }

            DispatchQueue.main.async {
                completion(data)
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Helper: Fetch Daily Sleep Data

    struct DailySleepData {
        var totalHours: Double
        var deepHours: Double?
        var remHours: Double?
    }

    private func fetchDailySleepData(startDate: Date, endDate: Date, completion: @escaping ([(Date, DailySleepData)]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let calendar = Calendar.current
            var dailyData: [Date: DailySleepData] = [:]

            guard let sleepSamples = samples as? [HKCategorySample] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            for sample in sleepSamples {
                // Use end date for the day (sleep typically ends in the morning)
                let dayStart = calendar.startOfDay(for: sample.endDate)
                let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // hours

                if dailyData[dayStart] == nil {
                    dailyData[dayStart] = DailySleepData(totalHours: 0, deepHours: nil, remHours: nil)
                }

                // Get current values to avoid overlapping accesses
                var current = dailyData[dayStart] ?? DailySleepData(totalHours: 0, deepHours: nil, remHours: nil)

                // iOS 16+ sleep stages
                if #available(iOS 16.0, *) {
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                         HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        current.totalHours += duration
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        current.totalHours += duration
                        current.deepHours = (current.deepHours ?? 0) + duration
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        current.totalHours += duration
                        current.remHours = (current.remHours ?? 0) + duration
                    default:
                        break
                    }
                } else {
                    // iOS 15 and earlier
                    if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        current.totalHours += duration
                    }
                }

                dailyData[dayStart] = current
            }

            let result = dailyData.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
            DispatchQueue.main.async { completion(result) }
        }

        healthStore.execute(query)
    }

    // MARK: - Helper: Fetch Daily Workout Count

    private func fetchDailyWorkoutCount(startDate: Date, endDate: Date, completion: @escaping ([(Date, Int)]) -> Void) {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let calendar = Calendar.current
            var dailyCount: [Date: Int] = [:]

            guard let workouts = samples as? [HKWorkout] else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            for workout in workouts {
                let dayStart = calendar.startOfDay(for: workout.startDate)
                dailyCount[dayStart, default: 0] += 1
            }

            let result = dailyCount.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
            DispatchQueue.main.async { completion(result) }
        }

        healthStore.execute(query)
    }
}
