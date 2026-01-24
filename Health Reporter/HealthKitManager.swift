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
        var healthData = HealthDataModel()
        let group = DispatchGroup()
        var fetchError: Error?
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        // צעדים
        group.enter()
        fetchSteps(startDate: startDate, endDate: endDate) { steps in
            healthData.steps = steps
            group.leave()
        }
        
        // מרחק
        group.enter()
        fetchDistance(startDate: startDate, endDate: endDate) { distance in
            healthData.distance = distance
            group.leave()
        }
        
        // אנרגיה פעילה
        group.enter()
        fetchActiveEnergy(startDate: startDate, endDate: endDate) { energy in
            healthData.activeEnergy = energy
            group.leave()
        }
        
        // דופק
        group.enter()
        fetchHeartRate(startDate: startDate, endDate: endDate) { heartRate in
            healthData.heartRate = heartRate
            group.leave()
        }
        
        // דופק במנוחה
        group.enter()
        fetchRestingHeartRate(startDate: startDate, endDate: endDate) { restingHeartRate in
            healthData.restingHeartRate = restingHeartRate
            group.leave()
        }
        
        // לחץ דם
        group.enter()
        fetchBloodPressure(startDate: startDate, endDate: endDate) { systolic, diastolic in
            healthData.bloodPressureSystolic = systolic
            healthData.bloodPressureDiastolic = diastolic
            group.leave()
        }
        
        // ריווי חמצן
        group.enter()
        fetchOxygenSaturation(startDate: startDate, endDate: endDate) { oxygen in
            healthData.oxygenSaturation = oxygen
            group.leave()
        }
        
        // משקל
        group.enter()
        fetchBodyMass(startDate: startDate, endDate: endDate) { weight in
            healthData.bodyMass = weight
            group.leave()
        }
        
        // BMI
        group.enter()
        fetchBMI(startDate: startDate, endDate: endDate) { bmi in
            healthData.bodyMassIndex = bmi
            group.leave()
        }
        
        // אחוז שומן
        group.enter()
        fetchBodyFatPercentage(startDate: startDate, endDate: endDate) { bodyFat in
            healthData.bodyFatPercentage = bodyFat
            group.leave()
        }
        
        // שינה
        group.enter()
        fetchSleepData(startDate: startDate, endDate: endDate) { sleepHours, sleepData in
            healthData.sleepHours = sleepHours
            healthData.sleepAnalysis = sleepData
            group.leave()
        }
        
        // קלוריות תזונתיות
        group.enter()
        fetchDietaryEnergy(startDate: startDate, endDate: endDate) { calories in
            healthData.dietaryEnergy = calories
            group.leave()
        }
        
        // סוכר בדם
        group.enter()
        fetchBloodGlucose(startDate: startDate, endDate: endDate) { glucose in
            healthData.bloodGlucose = glucose
            group.leave()
        }
        
        // VO2 Max
        group.enter()
        fetchVO2Max(startDate: startDate, endDate: endDate) { vo2Max in
            healthData.vo2Max = vo2Max
            group.leave()
        }
        
        group.notify(queue: .main) {
            healthData.lastUpdated = Date()
            if fetchError == nil {
                completion(healthData, nil)
            } else {
                completion(healthData, fetchError)
            }
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
    
    private func fetchSleepData(startDate: Date, endDate: Date, completion: @escaping (Double?, [SleepData]?) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                completion(nil, nil)
                return
            }
            
            var totalSleep: TimeInterval = 0
            var sleepDataArray: [SleepData] = []
            
            for sample in samples {
                if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                   sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
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
}
