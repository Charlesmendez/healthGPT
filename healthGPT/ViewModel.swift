import Foundation
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
    private var hasSavedReadinessScore = false
    private var readinessScoreSaveDate: Date?
    @Published var averageRespiratoryRateForLastWeek: Double?

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
            let success = await requestHealthDataAccess()
            if success {
                let sleepData = try await healthDataManager.fetchSleepData()
                processSleepData(sleepData: sleepData)
                fetchAdditionalHealthData()
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
                self.readinessSummary = summary
                Task {
                    await self.saveReadinessScore()
                }
            }
        }
    }

    

    func saveReadinessScore() async {
        guard let score = extractReadinessScore() else {
            print("Failed to extract readiness score")
            return
        }

        do {
            print("Saving readiness score at \(Date()): \(score)")
            try await SupabaseManager.shared.saveReadinessScore(date: Date(), score: score)
            print("Readiness score saved successfully")
        } catch {
            print("Error saving readiness score: \(error)")
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
        
        if let averageRespiratoryRateForLastWeek = averageRespiratoryRateForLastWeek {
            keywords.append("Average Respiratory Rate: \(averageRespiratoryRateForLastWeek)")
        }

        if let bodyTemperatureComparison = bodyTemperatureComparison {
            keywords.append("Body temperature Comparison according to baseline: \(bodyTemperatureComparison)")
        }

        keywords.append("Balance disruption causes like stress, bad sleep and others based on HRV: \(stressLevel)")

        return keywords
    }

    private func fetchAdditionalHealthData() {
        // Fetch Heart Rate Range While Asleep
        healthDataManager.fetchHeartRateRangeWhileAsleep(for: Date()) { [weak self] range in
            DispatchQueue.main.async {
                if let range = range {
                    self?.minHeartRate = range.min
                    self?.maxHeartRate = range.max
                } else {
                    self?.minHeartRate = nil
                    self?.maxHeartRate = nil
                }
                self?.checkAllHealthMetricsAvailable()
            }
        }

        // Fetch Resting Heart Rate
        healthDataManager.fetchRestingHeartRate(for: Date()) { [weak self] rate in
            DispatchQueue.main.async {
                self?.restingHeartRate = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }

        // Fetch Average Resting Heart Rate for Last Three Months
        healthDataManager.fetchAverageRestingHeartRateForLastThreeMonths { [weak self] rate in
            DispatchQueue.main.async {
                self?.averageHeartRate = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }

        // Fetch Heart Rate Variability
        healthDataManager.fetchHeartRateVariability(for: Date()) { [weak self] rate in
            DispatchQueue.main.async {
                self?.heartRateVariability = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }

        // Fetch HRV Data for Last 30 Days
        healthDataManager.fetchHeartRateVariabilityForLast30Days { [weak self] hrvData in
            DispatchQueue.main.async {
                if let hrvValues = hrvData {
                    self?.processHRVData(hrvValues)
                    self?.checkAllHealthMetricsAvailable()
                }
            }
        }

        // Fetch Average Blood Oxygen Level
        healthDataManager.fetchAverageBloodOxygenLevel(for: Date()) { [weak self] rate in
            DispatchQueue.main.async {
                self?.bloodOxygen = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }

        // Fetch Body Temperature While Asleep
        healthDataManager.fetchBodyTemperatureWhileAtSleep(for: Date()) { [weak self] lastNightTemperature, comparisonResult in
            DispatchQueue.main.async {
                self?.bodyTemperature = lastNightTemperature
                self?.bodyTemperatureComparison = comparisonResult
                self?.checkAllHealthMetricsAvailable()
            }
        }

        // Fetch Respiratory Rate for today
        healthDataManager.fetchRespiratoryRate(for: Date()) { [weak self] rate in
            DispatchQueue.main.async {
                self?.respiratoryRate = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }

        // Fetch Average Respiratory Rate for Last Week
        healthDataManager.fetchAverageRespiratoryRateForLastWeek { [weak self] averageRate in
            DispatchQueue.main.async {
                self?.averageRespiratoryRateForLastWeek = averageRate
                self?.checkAllHealthMetricsAvailable()
            }
        }
    }

    private func processHRVData(_ hrvValues: [Double]) {
        guard !hrvValues.isEmpty else {
            stressLevel = "No Data"
            return
        }

        let baselineHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        DispatchQueue.main.async {
            self.AverageHeartRateVariability = baselineHRV
        }

        if let currentHRV = heartRateVariability {
            let hrvDifference = baselineHRV - currentHRV

            if currentHRV < baselineHRV {
                if hrvDifference > 10 {
                    stressLevel = "High"
                } else {
                    stressLevel = "Moderate"
                }
            } else {
                stressLevel = "Low"
            }
        } else {
            stressLevel = "HRV Data Unavailable"
        }
    }

    private func checkAllHealthMetricsAvailable() {
        if let _ = maxHeartRate,
           let _ = minHeartRate,
           let _ = restingHeartRate,
           let _ = heartRateVariability,
           let _ = AverageHeartRateVariability,
           let _ = bodyTemperature,
           let _ = respiratoryRate,
           let _ = bodyTemperatureComparison,
           stressLevel != "Unknown",
           let _ = bloodOxygen {
            allHealthMetricsAvailable = true
            fetchReadinessSummary()
        }
    }

    func processSleepData(sleepData: [HKCategorySample]?) {
        var totalSleepSeconds = 0.0
        var deepSleepSeconds = 0.0
        var remSleepSeconds = 0.0
        var coreSleepSeconds = 0.0
        var unspecifiedSleepSeconds = 0.0
        var awakeSeconds = 0.0

        guard let sleepData = sleepData else {
            print("No sleep data provided")
            return
        }

        let sortedSleepData = sleepData.sorted { $0.startDate < $1.startDate }

        for (index, sample) in sortedSleepData.enumerated() {
            var duration = sample.endDate.timeIntervalSince(sample.startDate)

            if index > 0 && sample.startDate == sortedSleepData[index - 1].startDate {
                continue
            }

            if index > 0 && sample.startDate < sortedSleepData[index - 1].endDate {
                let overlapDuration = sortedSleepData[index - 1].endDate.timeIntervalSince(sample.startDate)
                duration -= overlapDuration
            }

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

            totalSleepSeconds += duration
        }

        DispatchQueue.main.async {
            self.totalSleep = self.formatDuration(seconds: totalSleepSeconds)
            self.deepSleep = self.formatDuration(seconds: deepSleepSeconds)
            self.remSleep = self.formatDuration(seconds: remSleepSeconds)
            self.coreSleep = self.formatDuration(seconds: coreSleepSeconds)
            self.unspecifiedSleep = self.formatDuration(seconds: unspecifiedSleepSeconds)
            self.awake = self.formatDuration(seconds: awakeSeconds)
        }
    }

    func formatDuration(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }

    func extractReadinessScore() -> Int? {
        guard let summary = readinessSummary else { return nil }
        let pattern = "\\d+"

        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: summary, options: [], range: NSRange(location: 0, length: summary.utf16.count)),
           let range = Range(match.range, in: summary) {
            let numberString = String(summary[range])
            return Int(numberString)
        }
        return nil
    }

}
