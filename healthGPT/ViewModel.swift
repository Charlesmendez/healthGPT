import Combine
import HealthKit

class SleepViewModel: ObservableObject {
    @Published var totalSleep = "0"
    @Published var deepSleep = "0"
    @Published var remSleep = "0"
    @Published var coreSleep = "0"
    @Published var unspecifiedSleep = "0"
    @Published var inBed = "0"
    
//    @Published var averageHeartRate: Double?
    @Published var minHeartRate: Double?
    @Published var maxHeartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var heartRateVariability: Double?
    @Published var respiratoryRate: Double?
    @Published var bloodOxygen: Double?
    @Published var bodyTemperature: Double?
    
    // Computed property to get the heart rate range as a string
    var heartRateRangeString: String? {
        if let minRate = minHeartRate, let maxRate = maxHeartRate {
            return "\(String(format: "%.1f", minRate)) - \(String(format: "%.1f", maxRate))"
        } else {
            return nil
        }
    }

    private var healthDataManager = HealthDataManager()

    @Published var isLoading = false
    
    @Published var readinessSummary: String?
    @Published var allHealthMetricsAvailable = false
    
    @Published var bodyTemperatureComparison: String?
    
    @Published var stressLevel: String = "Unknown"



    func fetchSleepData() {
        self.isLoading = true
        healthDataManager.requestHealthDataAccess { [weak self] success in
            if success {
                self?.healthDataManager.fetchSleepData { sleepData in
                    self?.processSleepData(sleepData)
                    // Fetch additional health metrics
                    self?.fetchAdditionalHealthData()
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        }
    }
    
    func fetchReadinessSummary() {
            TextRecognition().findCommonalitiesInArray(keywords: getSleepMetricsAsKeywords()) { summary in
                DispatchQueue.main.async {
                    self.readinessSummary = summary // Update the readinessSummary in the view model
                }
            }
        }

    
    func getSleepMetricsAsKeywords() -> [String] {
            var keywords: [String] = []
            
            keywords.append("Total Sleep: \(totalSleep)")
        
            keywords.append("Deep Sleep: \(deepSleep)")
            keywords.append("REM Sleep: \(remSleep)")
            keywords.append("Core Sleep: \(coreSleep)")
           
        
            if let minHeartRate = minHeartRate, let maxHeartRate = maxHeartRate {
                keywords.append("Heart Rate Range: \(minHeartRate) - \(maxHeartRate) bpm")
            } else {
                // Handle the case where one or both values are nil
                keywords.append("Heart Rate Range: Data not available")
            }

            if let restingHeartRate = restingHeartRate {
                keywords.append("Resting Heart Rate: \(restingHeartRate) bpm")
            }
        
            if let bloodOxygen = bloodOxygen {
                keywords.append("Oxygen in Blood: \(bloodOxygen)")
            }
        
            if let heartRateVariability = heartRateVariability {
                keywords.append("Heart Rate Variability: \(heartRateVariability)")
            }

            if let respiratoryRate = respiratoryRate {
                keywords.append("Respiratory Rate: \(respiratoryRate)")
            }
        
            if let bodyTemperatureComparison = bodyTemperatureComparison {
                keywords.append("Body temperature Comparisson according to baseline: \(bodyTemperatureComparison)")
            }
        
            keywords.append("Stress Level: \(stressLevel)")
        
            // Add other sleep metrics similarly

            return keywords
        }

    private func fetchAdditionalHealthData() {
            // Fetch Average Heart Rate
        healthDataManager.fetchHeartRateRangeWhileAsleep(for: Date()) { [weak self] range in
            DispatchQueue.main.async {
                if let range = range {
                    self?.minHeartRate = range.min
                    self?.maxHeartRate = range.max
                } else {
                    // Handle the case where no data is returned
                    self?.minHeartRate = nil
                    self?.maxHeartRate = nil
                }
                self?.checkAllHealthMetricsAvailable() // Check if all metrics are available
            }
        }


            // Fetch Resting Heart Rate
            healthDataManager.fetchRestingHeartRate(for: Date()) { [weak self] rate in
                DispatchQueue.main.async {
                    self?.restingHeartRate = rate
                    self?.checkAllHealthMetricsAvailable() // Check if all metrics are available
                }
            }
            
            healthDataManager.fetchHeartRateVariability(for: Date()) { [weak self] rate in
                DispatchQueue.main.async {
                    self?.heartRateVariability = rate
                    self?.checkAllHealthMetricsAvailable() // Check if all metrics are available
                }
            }
        healthDataManager.fetchHeartRateVariabilityForLast30Days { [weak self] hrvData in
               DispatchQueue.main.async {
                   if let hrvValues = hrvData {
                       print("Received HRV data for last 30 days: \(hrvValues)")
                       self?.processHRVData(hrvValues)
                       self?.checkAllHealthMetricsAvailable()
                   } else {
                       print("HRV data for last 30 days is nil")
                   }
               }
           }
            
            healthDataManager.fetchAverageBloodOxygenLevel(for: Date()) { [weak self] rate in
                DispatchQueue.main.async {
                    self?.bloodOxygen = rate
                    self?.checkAllHealthMetricsAvailable() // Check if all metrics are available
                }
            }
        
        // Fetch Body Temperature while at sleep
        healthDataManager.fetchBodyTemperatureWhileAtSleep(for: Date()) { [weak self] lastNightTemperature, comparisonResult in
            DispatchQueue.main.async {
                self?.bodyTemperature = lastNightTemperature
                self?.bodyTemperatureComparison = comparisonResult
                self?.checkAllHealthMetricsAvailable() // Check if all metrics are available
            }
        }



        
        healthDataManager.fetchRespiratoryRate(for: Date()) { [weak self] rate in
            DispatchQueue.main.async {
                self?.respiratoryRate = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }


            // Add calls to fetch other metrics
    }
    
    // Add this new function to process HRV data
    private func processHRVData(_ hrvValues: [Double]) {
        guard !hrvValues.isEmpty else {
            stressLevel = "No Data"
            return
        }

        let averageHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        print("Calculated Average HRV: \(averageHRV)")

        // Simple logic to determine stress level based on average HRV
        if averageHRV < 30 {
            stressLevel = "High Stress"
        } else if averageHRV < 50 {
            stressLevel = "Moderate Stress"
        } else {
            stressLevel = "Low Stress"
        }
        print("Updated Stress Level: \(stressLevel)")
    }

    // Method to check if all health metrics are available
           private func checkAllHealthMetricsAvailable() {
               if let _ = maxHeartRate,
                  let _ = minHeartRate,
                  let _ = restingHeartRate,
                  let _ = heartRateVariability,
                  let _ = bodyTemperature,
                  let _ = respiratoryRate,
                  let _ = bodyTemperatureComparison,
                  stressLevel != "Unknown",
                  let _ = bloodOxygen {
                   allHealthMetricsAvailable = true
                   fetchReadinessSummary() // Fetch readiness summary once all metrics are available
               }
           }
    
    private func processSleepData(_ sleepData: [HKCategorySample]) {
        let deepSleepIntervals = self.filterIntervals(from: sleepData, for: .asleepDeep)
        let remSleepIntervals = self.filterIntervals(from: sleepData, for: .asleepREM)
        let coreSleepIntervals = self.filterIntervals(from: sleepData, for: .asleepCore)
        let unspecifiedSleepIntervals = self.filterIntervals(from: sleepData, for: .asleepUnspecified)
        let inBedIntervals = self.filterIntervals(from: sleepData, for: .inBed)

        DispatchQueue.main.async {
            let deepSleepDuration = self.calculateSpentTime(for: deepSleepIntervals)
            let remSleepDuration = self.calculateSpentTime(for: remSleepIntervals)
            let coreSleepDuration = self.calculateSpentTime(for: coreSleepIntervals)

            self.deepSleep = self.formatDuration(deepSleepDuration)
            self.remSleep = self.formatDuration(remSleepDuration)
            self.coreSleep = self.formatDuration(coreSleepDuration)
            self.unspecifiedSleep = self.formatDuration(self.calculateSpentTime(for: unspecifiedSleepIntervals))
            self.inBed = self.formatDuration(self.calculateSpentTime(for: inBedIntervals))
            
            // Sum Deep, REM, and Core sleep durations for total sleep
            let totalSleepDuration = deepSleepDuration + remSleepDuration + coreSleepDuration
            self.totalSleep = self.formatDuration(totalSleepDuration)
            
            
        }
    }


    private func filterIntervals(from sleepData: [HKCategorySample], for category: HKCategoryValueSleepAnalysis) -> [DateInterval] {
        return sleepData.filter { $0.value == category.rawValue }
                        .map { DateInterval(start: $0.startDate, end: $0.endDate) }
    }

    private func calculateSpentTime(for intervals: [DateInterval]) -> TimeInterval {
           guard intervals.count > 1 else {
               return intervals.first?.duration ?? 0
           }

           let sorted = intervals.sorted { $0.start < $1.start }
           
           var total: TimeInterval = 0
           var start = sorted[0].start
           var end = sorted[0].end
           
           for i in 1..<sorted.count {
               if sorted[i].start > end {
                   total += end.timeIntervalSince(start)
                   start = sorted[i].start
                   end = sorted[i].end
               } else if sorted[i].end > end {
                   end = sorted[i].end
               }
           }
           
           total += end.timeIntervalSince(start)
           return total
       }

       private func formatDuration(_ duration: TimeInterval) -> String {
           let totalHours = Int(duration / 3600)
           let totalMinutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
           return "\(totalHours) hours, \(totalMinutes) minutes"
       }
    
    private func fetchAdditionalHealthData(for date: Date) {
        healthDataManager.fetchHeartRateRangeWhileAsleep(for: Date()) { [weak self] range in
            DispatchQueue.main.async {
                if let range = range {
                    self?.minHeartRate = range.min
                    self?.maxHeartRate = range.max
                } else {
                    // Handle the case where no data is returned
                    self?.minHeartRate = nil
                    self?.maxHeartRate = nil
                }
                self?.checkAllHealthMetricsAvailable() // Check if all metrics are available
            }
        }

            healthDataManager.fetchRestingHeartRate(for: date) { [weak self] rate in
                DispatchQueue.main.async {
                    self?.restingHeartRate = rate
                }
            }
            healthDataManager.fetchHeartRateVariability(for: date) { [weak self] rate in
                DispatchQueue.main.async {
                    self?.restingHeartRate = rate
                }
            }
            healthDataManager.fetchAverageBloodOxygenLevel(for: date) { [weak self] rate in
                DispatchQueue.main.async {
                    self?.bloodOxygen = rate
                }
            }

            // Add calls to fetch other metrics
        }



}
