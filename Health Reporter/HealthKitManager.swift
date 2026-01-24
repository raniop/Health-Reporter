//
//  HealthKitManager.swift
//  Health Reporter
//
//  Created on 24/01/2026.
//

import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    // סוגי נתונים שאנו רוצים לקרוא
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        
        // נתונים פיזיים
        if let type = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage) {
            types.insert(type)
        }
        
        // נתונים קרדיווסקולריים
        if let type = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(type)
        }
        
        // נתונים מטבוליים
        if let type = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(type)
        }
        
        // נתונים נשימתיים
        if let type = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .forcedVitalCapacity) {
            types.insert(type)
        }
        
        // נתונים תזונתיים
        if let type = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal) {
            types.insert(type)
        }
        
        // נתונים שינה
        if let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(type)
        }
        
        // נתונים נוספים
        if let type = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(type)
        }
        if let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(type)
        }
        
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
        fetchSleepData(startDate: start, endDate: end) { sleepHours, sleepData in
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
        
        group.notify(queue: .main) {
            healthData.lastUpdated = Date()
            completion(healthData, nil)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchSteps(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
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
    
    private func fetchSleepData(startDate: Date, endDate: Date, matchByEndDate: Bool = false, completion: @escaping (Double?, [SleepData]?) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, nil)
            return
        }
        let options: HKQueryOptions = matchByEndDate ? .strictEndDate : .strictStartDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: options)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                completion(nil, nil)
                return
            }
            
            var totalSleep: TimeInterval = 0
            var sleepDataArray: [SleepData] = []
            
            for sample in samples {
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    totalSleep += duration
                    sleepDataArray.append(SleepData(startDate: sample.startDate, endDate: sample.endDate, value: HKCategoryValueSleepAnalysis(rawValue: sample.value) ?? .asleepUnspecified))
                }
            }
            
            let sleepHours = totalSleep / 3600.0
            completion(sleepHours, sleepDataArray.isEmpty ? nil : sleepDataArray)
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
        fetchSleepData(startDate: weekStartDate, endDate: weekEndDate) { sleepHours, _ in
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
        fetchSleepData(startDate: weekStartDate, endDate: weekEndDate) { sleepHours, _ in
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
            var deepHours: Double?
            var remHours: Double?
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
            fetchSleepData(startDate: dayStart, endDate: dayEnd, matchByEndDate: true) { hours, sleepData in
                sleepHours = hours
                if let arr = sleepData {
                    var deep: Double = 0, rem: Double = 0
                    for s in arr {
                        let d = s.endDate.timeIntervalSince(s.startDate) / 3600.0
                        if s.value == .asleepDeep { deep += d }
                        else if s.value == .asleepREM { rem += d }
                    }
                    deepHours = deep > 0 ? deep : nil
                    remHours = rem > 0 ? rem : nil
                }
                g.leave()
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
                efficiencyPoints.append(EfficiencyDataPoint(date: dayStart, avgHeartRate: heartRate, distanceKm: dist, activeCalories: energy))
                sleepPoints.append(SleepDayPoint(date: dayStart, totalHours: sleepHours, deepHours: deepHours, remHours: remHours, bbt: nil))
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
            
            // MARK: - Debug גרפים 3, 4
            let sleepWithData = sleepPoints.filter { ($0.totalHours ?? 0) > 0 }
            let glucoseWithData = glucosePoints.filter { $0.glucose != nil }
            let energyWithData = glucosePoints.filter { ($0.activeEnergy ?? 0) > 0 }
            print("[ChartDebug] fetchChartData done. range=\(label), days=\(dayBuckets.count)")
            print("[ChartDebug] Sleep: total=\(sleepPoints.count), with totalHours>0=\(sleepWithData.count). Sample: \(sleepPoints.prefix(3).map { "\($0.date.description.prefix(10)):\($0.totalHours ?? -1)" })")
            print("[ChartDebug] Glucose: with value=\(glucoseWithData.count). Energy>0=\(energyWithData.count). Sample energy: \(glucosePoints.prefix(3).map { "\($0.activeEnergy ?? -1)" })")
            print("[ChartDebug] Readiness: points=\(readinessPoints.count). Sample recovery: \(readinessPoints.prefix(3).map { $0.recovery })")
            
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
}
