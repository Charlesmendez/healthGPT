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
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                print("Error requesting HealthKit authorization: \(error.localizedDescription)")
                completion(false)
                return
            }
            completion(success)
        }
    }

    
    func fetchSleepData() async -> [HKCategorySample]? {
        var calendar = Calendar.current

           // Get the start of the current day
        let startOfToday = calendar.startOfDay(for: Date())

           // Calculate the start date as 10 p.m. the previous day
           guard let startDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: startOfToday, matchingPolicy: .previousTimePreservingSmallerComponents, repeatedTimePolicy: .first, direction: .backward) else {
               print("Failed to calculate start date")
               return nil
           }

           // Calculate the end date as 10 a.m. today
           guard let endDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfToday) else {
               print("Failed to calculate end date")
               return nil
           }

           // Debug: Print the start and end dates
           let dateFormatter = DateFormatter()
           dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
           dateFormatter.timeZone = TimeZone.current
           print("Start date: \(dateFormatter.string(from: startDate))")
           print("End date: \(dateFormatter.string(from: endDate))")

        // Create the date range predicate
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // Create the asleep predicate
        let asleepPredicate = HKCategoryValueSleepAnalysis.predicateForSamples(equalTo: HKCategoryValueSleepAnalysis.allAsleepValues)

        // Combine the predicates
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, asleepPredicate])

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let healthStore = HKHealthStore()

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: combinedPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, samples, error) in
                if let error = error {
                    print("Error fetching sleep data: \(error)")
                    continuation.resume(returning: nil)
                } else if let samples = samples as? [HKCategorySample] {
                    print("Carlos Samples: \(samples)")
                    continuation.resume(returning: samples)
                } else {
                    print("No samples or casting issue")
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }


    func fetchHeartRateRangeWhileAsleep(for date: Date, completion: @escaping ((min: Double, max: Double)?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("Heart rate type not available")
            completion(nil)
            return
        }

        let calendar = Calendar.current

        // Adjusting sleep time: between 10 PM (previous day) to 8 AM (current day)
        let sleepStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!) ?? date
        let sleepEnd = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date

        print("Sleep Start: \(sleepStart), Sleep End: \(sleepEnd)")

        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: sleepEnd, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteMin, .discreteMax]) { _, result, error in
            if let error = error {
                print("Error in heart rate range query: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let result = result,
                  let minQuantity = result.minimumQuantity(),
                  let maxQuantity = result.maximumQuantity() else {
                print("No heart rate data available for the specified date range")
                completion(nil)
                return
            }

            let minHeartRate = minQuantity.doubleValue(for: HKUnit(from: "count/min"))
            let maxHeartRate = maxQuantity.doubleValue(for: HKUnit(from: "count/min"))
            print("Heart Rate Range while asleep: \(minHeartRate) - \(maxHeartRate) bpm")
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
                print("Error fetching resting heart rate: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("No resting heart rate data available for the last 24 hours")
                completion(nil)
                return
            }
            
            let restingHeartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            print("Resting Heart Rate: \(restingHeartRate) bpm")
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
                print("Error fetching resting heart rate: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let heartRateSamples = samples as? [HKQuantitySample], !heartRateSamples.isEmpty else {
                print("No resting heart rate data available for the last 3 months")
                completion(nil)
                return
            }

            let totalHeartRate = heartRateSamples.reduce(0) { total, sample in
                total + sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            }

            let averageHeartRate = totalHeartRate / Double(heartRateSamples.count)
            print("Average Resting Heart Rate for Last 3 Months: \(averageHeartRate) bpm")
            completion(averageHeartRate)
        }

        healthStore.execute(query)
    }

    
    func fetchHeartRateVariability(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let heartRateVariabilityType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            print("Heart Rate Variability type not available")
            completion(nil)
            return
        }
        
        // Calculate the start and end times for the last 24 hours
        let calendar = Calendar.current
        let twentyFourHoursAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: twentyFourHoursAgo, end: date, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: heartRateVariabilityType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            if let error = error {
                print("Error in Heart Rate Variability query: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let result = result, let averageQuantity = result.averageQuantity() else {
                print("No Heart Rate Variability data available for the last 24 hours")
                completion(nil)
                return
            }
            
            let averageHRV = averageQuantity.doubleValue(for: HKUnit(from: "ms"))
            print("Average Heart Rate Variability: \(averageHRV) ms")
            completion(averageHRV)
        }
        
        print("Executing Average HRV query...")
        healthStore.execute(query)
    }
    
    func fetchHeartRateVariabilityForLast30Days(completion: @escaping ([Double]?) -> Void) {
          guard let heartRateVariabilityType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
              print("Heart Rate Variability type not available")
              completion(nil)
              return
          }

          let calendar = Calendar.current
          let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
          let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date(), options: .strictStartDate)

          let query = HKStatisticsCollectionQuery(quantityType: heartRateVariabilityType, quantitySamplePredicate: predicate, options: .discreteAverage, anchorDate: thirtyDaysAgo, intervalComponents: DateComponents(day: 1))

       
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    print("Error in 30 days HRV query: \(error.localizedDescription)")
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

                print("30 days HRV values: \(hrvValues)")
                completion(hrvValues)
            }

            print("Executing 30 days HRV query...")
            healthStore.execute(query)
        
      }
    
    func fetchAverageBloodOxygenLevel(for date: Date, completion: @escaping (Double?) -> Void) {
        guard let bloodOxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            print("Blood Oxygen type not available")
            completion(nil)
            return
        }
        
        // Calculate the start and end times for the last 24 hours
        let calendar = Calendar.current
        let twentyFourHoursAgo = calendar.date(byAdding: .hour, value: -24, to: date) ?? date
        
        let predicate = HKQuery.predicateForSamples(withStart: twentyFourHoursAgo, end: date, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: bloodOxygenType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            if let error = error {
                print("Error in Blood Oxygen query: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let result = result, let averageQuantity = result.averageQuantity() else {
                print("No Blood Oxygen data available for the last 24 hours")
                completion(nil)
                return
            }
            
            let averageBloodOxygenLevel = averageQuantity.doubleValue(for: HKUnit.percent())
            print("Average Blood Oxygen Level: \(averageBloodOxygenLevel)%")
            completion(averageBloodOxygenLevel)
        }
        
        print("Executing Average Blood Oxygen Level query...")
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
                print("Error fetching wrist temperature while at sleep: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else {
                print("No wrist temperature data while at sleep available for the date: \(date)")
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

    
    func calculateBodyTemperatureBaseline(completion: @escaping (Double?) -> Void) {
        guard let wristTemperatureType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) // 30 days ago

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)

        let query = HKStatisticsQuery(quantityType: wristTemperatureType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
            if let error = error {
                print("Error calculating body temperature baseline: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let averageTemperature = result?.averageQuantity()?.doubleValue(for: HKUnit.degreeCelsius()) else {
                print("No body temperature data available for the last 30 days")
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
                    print("Error fetching respiratory rate while sleeping: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    print("No respiratory rate data while sleeping available for the date: \(date)")
                    completion(nil)
                    return
                }
                
                let respiratoryRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                completion(respiratoryRate)
            }
            
            healthStore.execute(query)
        }





}
