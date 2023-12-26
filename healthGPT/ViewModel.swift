import Combine
import HealthKit
import EventKit

class SleepViewModel: ObservableObject {
    @Published var totalSleep = "0"
    @Published var deepSleep = "0"
    @Published var remSleep = "0"
    @Published var coreSleep = "0"
    @Published var unspecifiedSleep = "0"
    var awake: String = ""
    
    @Published var minHeartRate: Double?
    @Published var maxHeartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var heartRateVariability: Double?
    @Published var AverageHeartRateVariability: Double?
    @Published var respiratoryRate: Double?
    @Published var bloodOxygen: Double?
    @Published var bodyTemperature: Double?
    @Published var averageHeartRate: Double?

    
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
    
    
    
    func requestHealthDataAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            healthDataManager.requestHealthDataAccess { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    func fetchAndProcessSleepData() async {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            // Request health data access
            let success = await requestHealthDataAccess()
            if success {
                // Fetch sleep data
                let sleepData = try await healthDataManager.fetchSleepData()
                print("Carlos: \(sleepData)")
                processSleepData(sleepData: sleepData)
                
                // Fetch additional health metrics
                await fetchAdditionalHealthData()
            }
        } catch {
            print("Error occurred: \(error)")
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
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
        
        if let averageHeartRate = averageHeartRate {
            keywords.append("Average Resting Heart Rate last 3 months \(averageHeartRate)")
        }
        
        if let bloodOxygen = bloodOxygen {
            keywords.append("Oxygen in Blood: \(bloodOxygen)")
        }
        
        if let heartRateVariability = heartRateVariability {
            keywords.append("Heart Rate Variability: \(heartRateVariability)")
        }
        
        if let AverageHeartRateVariability = AverageHeartRateVariability {
            keywords.append("Average Heart Rate Variability: \(AverageHeartRateVariability)")
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
        
        healthDataManager.fetchAverageRestingHeartRateForLastThreeMonths { [weak self] rate in
            DispatchQueue.main.async {
                self?.averageHeartRate = rate
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
    
    private func processHRVData(_ hrvValues: [Double]) {
        guard !hrvValues.isEmpty else {
            stressLevel = "No Data"
            return
        }
        
        // Calculate the baseline HRV as the average of historical HRV values
        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        print("Calculated Baseline HRV: \(baselineHRV)")
        DispatchQueue.main.async {
            self.AverageHeartRateVariability = baselineHRV
        }
        
        // Compare current HRV with the baseline
        if let currentHRV = heartRateVariability {
            // Determine stress level based on whether current HRV is lower than the baseline
            if currentHRV < baselineHRV {
                // Further determine the level of stress based on the difference from the baseline
                let hrvDifference = baselineHRV - currentHRV

                if hrvDifference > 10 { // Example threshold, adjust as needed
                    stressLevel = "High Stress"
                } else {
                    stressLevel = "Moderate Stress"
                }
            } else {
                stressLevel = "Low Stress"
            }
        } else {
            stressLevel = "HRV Data Unavailable"
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
    
    func processSleepData(sleepData: [HKCategorySample]?) {
        
        print("Processing Sleep Data")
        
        // Resetting values to 0
        var totalSleepSeconds = 0.0
        var deepSleepSeconds = 0.0
        var remSleepSeconds = 0.0
        var coreSleepSeconds = 0.0
        var unspecifiedSleepSeconds = 0.0
        //        var inBedSeconds = 0.0
        var awakeSeconds = 0.0
        
        guard let sleepData = sleepData else {
            print("No sleep data provided")
            return
        }
        
        // Sort the sleepData by start date
        let sortedSleepData = sleepData.sorted { $0.startDate < $1.startDate }
        
        var firstCoreSleepTime: String?
        var lastCoreSleepTime: String?
        
        for (index, sample) in sortedSleepData.enumerated() {
            var duration = sample.endDate.timeIntervalSince(sample.startDate)
            
            // Check for duplicated data (same start and end times)
            if index > 0 && sample.startDate == sortedSleepData[index - 1].startDate {
                // Skip duplicated data
                continue
            }
            
            // Check for overlapping time periods with the previous sample
            if index > 0 && sample.startDate < sortedSleepData[index - 1].endDate {
                // Calculate the overlapping duration
                let overlapDuration = sortedSleepData[index - 1].endDate.timeIntervalSince(sample.startDate)
                
                // Subtract the overlap from the current sample
                duration -= overlapDuration
            }
            
            print("Sample: \(sample), Duration: \(duration), Value: \(sample.value)")
            
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                unspecifiedSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSleepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSleepSeconds += duration
            default:
                print("Unknown sleep stage: \(sample.value)")
            }
            
            // Accumulate the total sleep duration including all sleep stages
            totalSleepSeconds += duration
            
            if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "HH:mm:ss"
                let startTime = dateFormatter.string(from: sample.startDate)
                let endTime = dateFormatter.string(from: sample.endDate)
                print("Core Sleep Start Time: \(startTime), End Time: \(endTime)")
                
                if firstCoreSleepTime == nil {
                    firstCoreSleepTime = startTime
                }
                lastCoreSleepTime = endTime
            }
            
        }
        if let firstTime = firstCoreSleepTime, let lastTime = lastCoreSleepTime {
            print("First Core Sleep Time: \(firstTime)")
            print("Last Core Sleep Time: \(lastTime)")
        }
        
        
        // Update the properties with formatted duration
        DispatchQueue.main.async {
            self.totalSleep = self.formatDuration(seconds: totalSleepSeconds)
            self.deepSleep = self.formatDuration(seconds: deepSleepSeconds)
            self.remSleep = self.formatDuration(seconds: remSleepSeconds)
            self.coreSleep = self.formatDuration(seconds: coreSleepSeconds)
            self.unspecifiedSleep = self.formatDuration(seconds: unspecifiedSleepSeconds)
            self.awake = self.formatDuration(seconds: awakeSeconds)
        }
        
        print("Total Sleep: \(totalSleep) seconds")
        print("Deep Sleep: \(deepSleep) seconds")
        print("REM Sleep: \(remSleep) seconds")
        print("Core Sleep: \(coreSleep) seconds")
    }
    
    
    
    
    func formatDuration(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        return "\(hours)h \(minutes)m"
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
        
    }
    
    
    
}
