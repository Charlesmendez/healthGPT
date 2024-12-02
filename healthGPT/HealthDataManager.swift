//
//  HealthDataManager.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//

import HealthKit
import EventKit


class HealthDataManager {
    let healthStore = HKHealthStore()
    
    func requestHealthDataAccess(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        // Define the types you want to read
        let typesToRead: Set<HKObjectType> = [
            // Existing data types
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!,
            
            // **Newly added data types**
            HKObjectType.workoutType(),
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                completion(false)
                return
            }
            completion(success)
        }
    }

    
    func fetchSleepData() async -> [HKCategorySample]? {
        let timeZone = TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = timeZone  // Set the calendar's time zone

        // Get the start of the current day in the user's time zone
        let startOfToday = calendar.startOfDay(for: Date())

        // Calculate the start date as 6 p.m. (18:00) of the previous day
        guard let startDate = calendar.date(byAdding: .hour, value: -6, to: startOfToday) else {
            return nil
        }

        // Calculate the end date as 12 p.m. (12:00) of today
        guard let endDate = calendar.date(byAdding: .hour, value: 12, to: startOfToday) else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        dateFormatter.timeZone = timeZone

        // Create the date range predicate without strict options
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])

        // Create the asleep predicate
        let asleepPredicate = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: HKCategoryValueSleepAnalysis.allAsleepValues)

        // Combine the predicates
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, asleepPredicate])

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let healthStore = HKHealthStore()

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: combinedPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(returning: nil)
                } else if let samples = samples as? [HKCategorySample], !samples.isEmpty {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: nil)
                }
            }

            healthStore.execute(query)
        }
    }

    func fetchHeartRateRangeWhileAsleep(for date: Date, completion: @escaping ((min: Double, max: Double)?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current

        // Adjusting sleep time: between 10 PM (previous day) to 8 AM (current day)
        let sleepStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!) ?? date
        let sleepEnd = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date


        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: sleepEnd, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteMin, .discreteMax]) { _, result, error in
            if let error = error {
                completion(nil)
                return
            }

            guard let result = result,
                  let minQuantity = result.minimumQuantity(),
                  let maxQuantity = result.maximumQuantity() else {
                completion(nil)
                return
            }

            let minHeartRate = minQuantity.doubleValue(for: HKUnit(from: "count/min"))
            let maxHeartRate = maxQuantity.doubleValue(for: HKUnit(from: "count/min"))
            completion((min: minHeartRate, max: maxHeartRate))
        }

        healthStore.execute(query)
    }



    
    
    func fetchRestingHeartRate(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }
        
        // Calculate the start and end times for the last 24 hours
        let calendar = Calendar.current
        let twentyFourHoursAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: twentyFourHoursAgo, end: date, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: restingHeartRateType, predicate: predicate, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
            if let error = error {
                completion(nil)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            
            let restingHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            completion(restingHeartRate)
        }
        
        healthStore.execute(query)
    }
    
    func fetchAverageRestingHeartRateForLastThreeMonths(completion: @escaping (Double?) -> Void) {
        guard let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            completion(nil)
            return
        }

        // Calculate the start time for the last 3 months
        let calendar = Calendar.current
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()

        let predicate = HKQuery.predicateForSamples(withStart: threeMonthsAgo, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: restingHeartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
            if let error = error {
                completion(nil)
                return
            }

            guard let heartRateSamples = samples as? [HKQuantitySample], !heartRateSamples.isEmpty else {
                completion(nil)
                return
            }

            let totalHeartRate = heartRateSamples.reduce(0) { total, sample in
                total + sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }

            let averageHeartRate = totalHeartRate / Double(heartRateSamples.count)
            completion(averageHeartRate)
        }

        healthStore.execute(query)
    }

    
    func fetchHeartRateVariability(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let heartRateVariabilityType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }
        
        // Calculate the start and end times for the last 24 hours
        let calendar = Calendar.current
        let twentyFourHoursAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: twentyFourHoursAgo, end: date, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: heartRateVariabilityType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            if let error = error {
                completion(nil)
                return
            }
            
            guard let result = result, let averageQuantity = result.averageQuantity() else {
                completion(nil)
                return
            }
            
            let averageHRV = averageQuantity.doubleValue(for: HKUnit(from: "ms"))
            completion(averageHRV)
        }
        
        healthStore.execute(query)
    }
    
    func fetchHeartRateVariabilityForLast30Days(completion: @escaping ([Double]?) -> Void) {
          guard let heartRateVariabilityType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
              completion(nil)
              return
          }

          let calendar = Calendar.current
          let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
          let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date(), options: .strictStartDate)

          let query = HKStatisticsCollectionQuery(quantityType: heartRateVariabilityType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: thirtyDaysAgo, intervalComponents: DateComponents(day: 1))

       
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    completion(nil)
                    return
                }

                var hrvValues: [Double] = []
                results?.enumerateStatistics(from: thirtyDaysAgo, to: Date()) { statistic, _ in
                    if let averageQuantity = statistic.averageQuantity() {
                        let averageHRV = averageQuantity.doubleValue(for: HKUnit(from: "ms"))
                        hrvValues.append(averageHRV)
                    }
                }

                completion(hrvValues)
            }

            healthStore.execute(query)
        
      }
    
    func fetchAverageBloodOxygenLevel(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let bloodOxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            completion(nil)
            return
        }
        
        // Calculate the start and end times for the last 24 hours
        let calendar = Calendar.current
        let twentyFourHoursAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: twentyFourHoursAgo, end: date, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: bloodOxygenType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            if let error = error {
                completion(nil)
                return
            }
            
            guard let result = result, let averageQuantity = result.averageQuantity() else {
                completion(nil)
                return
            }
            
            let averageBloodOxygenLevel = averageQuantity.doubleValue(for: HKUnit.percent())
            completion(averageBloodOxygenLevel)
        }
        
        healthStore.execute(query)
    }
    
    func fetchBodyTemperatureWhileAtSleep(for date: Date, completion: @escaping (Double?, String?) -> Void) {
        guard let wristTemperatureType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            completion(nil, nil)
            return
        }

        // Create a sort descriptor to get the most recent reading
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let predicate = HKQuery.predicateForSamples(withStart: nil, end: date, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: wristTemperatureType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                completion(nil, nil)
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil, nil)
                return
            }

            let lastNightTemperature = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())

            // Calculate the baseline
            self.calculateBodyTemperatureBaseline { baseline in
                guard let baseline = baseline else {
                    completion(lastNightTemperature, nil) // Return last night's temperature if baseline calculation fails
                    return
                }

                // Compare with the baseline
                let comparisonResult = self.compareBodyTemperatureWithBaseline(lastNightTemperature: lastNightTemperature, baseline: baseline)

                completion(lastNightTemperature, comparisonResult)
            }
        }

        healthStore.execute(query)
    }

    // fix since apple stopped sending body temp data
    func calculateBodyTemperatureBaseline(completion: @escaping (Double?) -> Void) {
        guard let wristTemperatureType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            completion(nil)
            return
        }

        // Adjusted predicate to include all samples up to today.
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: endDate, options: .strictEndDate)

        let query = HKStatisticsQuery(quantityType: wristTemperatureType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            if let error = error {
                completion(nil)
                return
            }

            guard let averageTemperature = result?.averageQuantity()?.doubleValue(for: HKUnit.degreeCelsius()),
                  let startDate = result?.startDate, // These properties represent the range of all samples included.
                  let endDate = result?.endDate else {
                completion(nil)
                return
            }

            completion(averageTemperature)
        }

        healthStore.execute(query)
    }

    
    func compareBodyTemperatureWithBaseline(lastNightTemperature: Double, baseline: Double) -> String {
        let temperatureDifference = lastNightTemperature - baseline
        let formattedDifference = String(format: "%.2f", temperatureDifference)

        if temperatureDifference > 0 {
            return "You are above the baseline by \(formattedDifference)°C"
        } else if temperatureDifference < 0 {
            return "You are below the baseline by \(formattedDifference)°C"
        } else {
            return "Your body temperature is at the baseline"
        }
    }


    
   
        func fetchRespiratoryRate(for date: Date, completion: @escaping (Double?) -> Void) {
            guard let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
                completion(nil)
                return
            }
            
            // Create a sort descriptor to get the most recent reading
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            // Define a predicate for sleep periods
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: date, options: .strictStartDate)
            
            let query = HKSampleQuery(sampleType: respiratoryRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    completion(nil)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    completion(nil)
                    return
                }
                
                let respiratoryRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                completion(respiratoryRate)
            }
            
            healthStore.execute(query)
        }

    func fetchAverageRespiratoryRateForLastWeek(completion: @escaping (Double?) -> Void) {
        guard let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(nil)
            return
        }

        // Calculate the start time for the last week
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let predicate = HKQuery.predicateForSamples(withStart: oneWeekAgo, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(sampleType: respiratoryRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
            if let error = error {
                completion(nil)
                return
            }

            guard let respiratorySamples = samples as? [HKQuantitySample], !respiratorySamples.isEmpty else {
                completion(nil)
                return
            }

            let totalRespiratoryRate = respiratorySamples.reduce(0) { total, sample in
                total + sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }

            let averageRespiratoryRate = totalRespiratoryRate / Double(respiratorySamples.count)
            completion(averageRespiratoryRate)
        }

        healthStore.execute(query)
    }


}
