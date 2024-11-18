import Foundation
import Combine
import HealthKit
import EventKit

@MainActor
class SleepViewModel: ObservableObject {
    // Existing @Published properties
    @Published var totalSleep = "0"
    @Published var deepSleep = "0"
    @Published var remSleep = "0"
    @Published var coreSleep = "0"
    @Published var unspecifiedSleep = "0"
    @Published var awake: String = ""
    
    @Published var minHeartRate: Double?
    @Published var maxHeartRate: Double?
    @Published var restingHeartRate: Double?
    @Published var heartRateVariability: Double?
    @Published var AverageHeartRateVariability: Double?
    @Published var respiratoryRate: Double?
    @Published var bloodOxygen: Double?
    @Published var bodyTemperature: Double?
    @Published var averageHeartRate: Double?
    @Published var readinessScore: Int?
    @Published var averageRespiratoryRateForLastWeek: Double?
    @Published var readinessScores: [ReadinessScoreEntry] = []
    @Published var weeklyWorkouts: [WorkoutEntry] = []
    
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
    
    @Published var cardiovascularLoad: Double = 0.0
    @Published var muscularLoad: Double = 0.0
    @Published var totalLoad: Double = 0.0
    
    private let healthStore = HKHealthStore()
    
    @Published var missingMetrics: [String] = []
    
    // Cache properties
    private var lastFetchDate: Date?
    private let cacheFetchDateKey = "lastFetchDate"
    private let cacheReadinessSummaryKey = "readinessSummary"
    private let cacheReadinessScoresKey = "readinessScores"
    
    init() {
        loadCache()
    }
    
    // Load cached data
    private func loadCache() {
        if let date = UserDefaults.standard.object(forKey: cacheFetchDateKey) as? Date {
            self.lastFetchDate = date
        }
        if let summary = UserDefaults.standard.string(forKey: cacheReadinessSummaryKey) {
            self.readinessSummary = summary
        }
        loadReadinessScoresFromCache()
    }
    
    // Save fetch date and readiness summary to cache
    private func saveCache() {
        self.lastFetchDate = Date()
        UserDefaults.standard.set(self.lastFetchDate, forKey: cacheFetchDateKey)
        if let summary = self.readinessSummary {
            UserDefaults.standard.set(summary, forKey: cacheReadinessSummaryKey)
        }
    }
    
    // Save readinessScores to cache
    private func saveReadinessScoresToCache() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(readinessScores)
            UserDefaults.standard.set(data, forKey: cacheReadinessScoresKey)
            print("Readiness scores saved to cache.")
        } catch {
            print("Error encoding readinessScores: \(error)")
        }
    }
    
    // Load readinessScores from cache
    private func loadReadinessScoresFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheReadinessScoresKey) {
            do {
                let decoder = JSONDecoder()
                let scores = try decoder.decode([ReadinessScoreEntry].self, from: data)
                self.readinessScores = scores
                print("Readiness scores loaded from cache. Count: \(scores.count)")
            } catch {
                print("Error decoding readinessScores: \(error)")
            }
        }
    }
    
    // Initialize data fetching
    func initializeData() async {
        if await isNewDataAvailable() {
            print("New data available. Fetching and processing sleep and workout data...")
            await fetchAndProcessSleepData()
            await fetchWeeklyWorkouts()
        } else {
            print("No new HealthKit data available. Using cached data.")
            loadReadinessScoresFromCache()
        }
        // Always fetch readiness scores
        await fetchReadinessScores()
    }
    
    // Determine whether to fetch new data by checking new sleep and workout data since lastFetchDate
    func isNewDataAvailable() async -> Bool {
        guard let lastFetch = lastFetchDate else {
            print("No previous fetch date found. New data is available.")
            return true // No data fetched yet
        }
        
        let now = Date()
        
        // Define sample types
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("Sleep Analysis Type is unavailable.")
            return false
        }
        let workoutType = HKObjectType.workoutType() // Non-optional, no guard let needed
        
        // Define predicates
        let sleepPredicate = HKQuery.predicateForSamples(withStart: lastFetch, end: now, options: .strictStartDate)
        let workoutPredicate = HKQuery.predicateForSamples(withStart: lastFetch, end: now, options: .strictStartDate)
        
        // Perform serial checks for new sleep and workout data
        let sleepHasNewData = await hasNewData(sampleType: sleepType, predicate: sleepPredicate)
        let workoutHasNewData = await hasNewData(sampleType: workoutType, predicate: workoutPredicate)
        
        return sleepHasNewData || workoutHasNewData
    }
    
    private func hasNewData(sampleType: HKSampleType, predicate: NSPredicate) async -> Bool {
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Error querying \(sampleType.identifier): \(error)")
                    continuation.resume(returning: false)
                    return
                }
                
                if let samples = samples, !samples.isEmpty {
                    print("New data found for \(sampleType.identifier)")
                    continuation.resume(returning: true)
                } else {
                    print("No new data found for \(sampleType.identifier)")
                    continuation.resume(returning: false)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    
    
    
    func fetchCardiovascularLoad(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        let workoutType = HKObjectType.workoutType()
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("Heart Rate Type is unavailable.")
            completion()
            return
        }
        
        let age = getAge(healthStore: healthStore)
        
        // **Limit to workouts in the last 7 days**
        // **Limit to workouts in the last 7 days**
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: [])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: 0,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] query, samples, error in
            guard let self = self else {
                print("Self is nil in fetchCardiovascularLoad")
                completion()
                return
            }
            guard let workouts = samples as? [HKWorkout], error == nil else {
                print("Error fetching workouts: \(String(describing: error))")
                completion()
                return
            }
            
            print("Fetched \(workouts.count) workouts for cardiovascular load")
            
            for workout in workouts {
                group.enter()
                let heartRatePredicate = HKQuery.predicateForSamples(
                    withStart: workout.startDate,
                    end: workout.endDate,
                    options: []
                )
                let heartRateQuery = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: heartRatePredicate,
                    limit: 0,
                    sortDescriptors: nil
                ) { [weak self] query, hrSamples, error in
                    defer { group.leave() }
                    guard let self = self else {
                        print("Self is nil in heartRateQuery")
                        return
                    }
                    guard let hrSamples = hrSamples as? [HKQuantitySample], error == nil else {
                        print("Error fetching heart rate samples: \(String(describing: error))")
                        return
                    }
                    
                    print("Fetched \(hrSamples.count) heart rate samples for workout on \(workout.startDate)")
                    
                    let mhr = 220 - age
                    var cardioLoad = 0.0
                    
                    for sample in hrSamples {
                        let hr = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                        let hrPercentage = hr / Double(mhr)
                        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                        var pointsPerMinute = 0.0
                        
                        switch hrPercentage {
                        case 0.5..<0.6:
                            pointsPerMinute = 1.0
                        case 0.6..<0.7:
                            pointsPerMinute = 2.0
                        case 0.7..<0.8:
                            pointsPerMinute = 3.0
                        case 0.8..<0.9:
                            pointsPerMinute = 4.0
                        case 0.9...1.0:
                            pointsPerMinute = 5.0
                        default:
                            pointsPerMinute = 0.0
                        }
                        
                        cardioLoad += pointsPerMinute * duration
                    }
                    
                    print("Cardio load for this workout: \(cardioLoad)")
                    
                    DispatchQueue.main.async {
                        self.cardiovascularLoad += cardioLoad
                    }
                }
                self.healthStore.execute(heartRateQuery)
            }
            
            group.notify(queue: .main) {
                print("Total cardiovascular load: \(self.cardiovascularLoad)")
                completion()
            }
        }
        
        self.healthStore.execute(query)
    }
    func fetchMuscularLoad(completion: @escaping () -> Void) {
        let workoutType = HKObjectType.workoutType()
        
        // **Limit to workouts in the last 7 days**
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now, options: [])
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: 0,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] query, samples, error in
            guard let self = self else {
                print("Self is nil in fetchMuscularLoad")
                completion()
                return
            }
            guard let workouts = samples as? [HKWorkout], error == nil else {
                print("Error fetching workouts for muscular load: \(String(describing: error))")
                completion()
                return
            }
            
            print("Fetched \(workouts.count) workouts for muscular load")
            
            var totalMuscularLoad = 0.0
            
            for workout in workouts {
                let duration = workout.duration / 60.0  // Duration in minutes
                var pointsPerMinute = 0.0
                
                // Assign points based on workout type
                switch workout.workoutActivityType {
                case .traditionalStrengthTraining, .functionalStrengthTraining:
                    pointsPerMinute = 4.0
                case .running, .cycling, .rowing:
                    pointsPerMinute = 3.0
                default:
                    pointsPerMinute = 2.0
                }
                
                let load = pointsPerMinute * duration
                totalMuscularLoad += load
                
                print("Muscular load for workout on \(workout.startDate): \(load)")
            }
            
            DispatchQueue.main.async {
                self.muscularLoad = totalMuscularLoad
                print("Total muscular load: \(self.muscularLoad)")
            }
            
            completion()
        }
        
        self.healthStore.execute(query)
    }
    
    func calculateTotalLoad() {
        let rawLoad = cardiovascularLoad + muscularLoad
        
        print("Calculating total load:")
        print("Cardiovascular Load: \(cardiovascularLoad)")
        print("Muscular Load: \(muscularLoad)")
        print("Raw Load: \(rawLoad)")
        
        // **Adjust maxPossibleLoad to a realistic value for 7 days**
        let maxPossibleLoad = 1000.0  // Adjust this value based on your expectations
        
        let normalizedLoad = min(rawLoad / maxPossibleLoad, 1.0)
        
        print("Normalized Load: \(normalizedLoad)")
        
        // Optionally, apply non-linear scaling
        let loadScore = pow(normalizedLoad, 0.75)  // Adjust exponent as needed
        
        print("Load Score (after scaling): \(loadScore)")
        
        self.totalLoad = loadScore
    }
    
    func getAge(healthStore: HKHealthStore) -> Int {
        let calendar = Calendar.current
        let now = Date()
        do {
            let dobComponents = try healthStore.dateOfBirthComponents()
            if let birthDate = dobComponents.date {
                let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
                return ageComponents.year ?? 30  // Default to 30 if unknown
            }
        } catch {
            print("Failed to get date of birth: \(error)")
        }
        return 30
    }
    
    
    func requestHealthDataAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            healthDataManager.requestHealthDataAccess { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    func fetchAndProcessSleepData() async {
        self.isLoading = true
        print("Started fetching and processing sleep data.")

        let success = await requestHealthDataAccess()
        if success {
            let sleepData = await healthDataManager.fetchSleepData()
            processSleepData(sleepData: sleepData)
            fetchAdditionalHealthData()

            // Fetch Load Data and wait for completion
            await withCheckedContinuation { continuation in
                let group = DispatchGroup()

                group.enter()
                fetchCardiovascularLoad {
                    print("Completed fetchCardiovascularLoad.")
                    group.leave()
                }

                group.enter()
                fetchMuscularLoad {
                    print("Completed fetchMuscularLoad.")
                    group.leave()
                }

                group.notify(queue: .main) {
                    self.calculateTotalLoad()
                    print("Completed load calculations.")
                    continuation.resume()
                }
            }

            // After successful fetch, save to cache
            saveCache()
        } else {
            print("Failed to get HealthKit data access.")
        }

        self.isLoading = false
        print("Finished fetching and processing sleep data.")
    }
    
    func refreshData() async {
        await fetchAndProcessSleepData()
        await fetchWeeklyWorkouts()
    }
    
    func fetchReadinessSummary() {
        TextRecognition().findCommonalitiesInArray(keywords: getSleepMetricsAsKeywords()) { summary in
            Task { @MainActor in
                self.readinessSummary = summary
                await self.saveReadinessScore()
                // Save summary to cache
                UserDefaults.standard.set(summary, forKey: self.cacheReadinessSummaryKey)
            }
        }
    }
    
    // Fetch Readiness Scores from Supabase
    func fetchReadinessScores() async {
        do {
            print("Fetching readiness scores from Supabase...")
            let scores = try await SupabaseManager.shared.fetchReadinessScores()
            print("Fetched \(scores.count) readiness scores.")
            self.readinessScores = scores
            saveReadinessScoresToCache()
        } catch {
            print("Error fetching readiness scores: \(error)")
            // Optionally, attempt to load from cache if fetch fails
            loadReadinessScoresFromCache()
        }
    }
    
    func saveReadinessScore() async {
        guard let score = extractReadinessScore() else {
            print("Failed to extract readiness score")
            return
        }

        do {
            print("Saving readiness score at \(Date()): \(score)")
            try await SupabaseManager.shared.saveReadinessScore(date: Date(), score: score, load: totalLoad)
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
            Task { @MainActor in
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
            Task { @MainActor in
                self?.restingHeartRate = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }
        
        // Fetch Average Resting Heart Rate for Last Three Months
        healthDataManager.fetchAverageRestingHeartRateForLastThreeMonths { [weak self] rate in
            Task { @MainActor in
                self?.averageHeartRate = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }
        
        // Fetch Heart Rate Variability
        healthDataManager.fetchHeartRateVariability(for: Date()) { [weak self] rate in
            Task { @MainActor in
                self?.heartRateVariability = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }
        
        // Fetch HRV Data for Last 30 Days
        healthDataManager.fetchHeartRateVariabilityForLast30Days { [weak self] hrvData in
            Task { @MainActor in
                if let hrvValues = hrvData {
                    self?.processHRVData(hrvValues)
                    self?.checkAllHealthMetricsAvailable()
                }
            }
        }
        
        // Fetch Average Blood Oxygen Level
        healthDataManager.fetchAverageBloodOxygenLevel(for: Date()) { [weak self] rate in
            Task { @MainActor in
                self?.bloodOxygen = rate
                self?.checkAllHealthMetricsAvailable()
            }
        }
        
        // Fetch Body Temperature While Asleep
        healthDataManager.fetchBodyTemperatureWhileAtSleep(for: Date()) { [weak self] lastNightTemperature, comparisonResult in
            Task { @MainActor in
                self?.bodyTemperature = lastNightTemperature
                self?.bodyTemperatureComparison = comparisonResult
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
        self.AverageHeartRateVariability = baselineHRV
        
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
        var missing: [String] = []
        
        if maxHeartRate == nil {
            missing.append("Maximum Heart Rate")
        }
        if minHeartRate == nil {
            missing.append("Minimum Heart Rate")
        }
        if restingHeartRate == nil {
            missing.append("Resting Heart Rate")
        }
        if heartRateVariability == nil {
            missing.append("Heart Rate Variability")
        }
        if AverageHeartRateVariability == nil {
            missing.append("Average Heart Rate Variability")
        }
        if bodyTemperature == nil {
            missing.append("Body Temperature")
        }
        if bodyTemperatureComparison == nil {
            missing.append("Body Temperature Comparison")
        }
        if stressLevel == "Unknown" {
            missing.append("Stress Level")
        }
        if bloodOxygen == nil {
            missing.append("Blood Oxygen")
        }
        
        if missing.isEmpty {
            allHealthMetricsAvailable = true
            fetchReadinessSummary()
            missingMetrics = []
        } else {
            allHealthMetricsAvailable = false
            self.missingMetrics = missing
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
        
        self.totalSleep = self.formatDuration(seconds: totalSleepSeconds)
        self.deepSleep = self.formatDuration(seconds: deepSleepSeconds)
        self.remSleep = self.formatDuration(seconds: remSleepSeconds)
        self.coreSleep = self.formatDuration(seconds: coreSleepSeconds)
        self.unspecifiedSleep = self.formatDuration(seconds: unspecifiedSleepSeconds)
        self.awake = self.formatDuration(seconds: awakeSeconds)
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
            readinessScore = Int(numberString)
            return readinessScore
        }
        return nil
    }
    
    func fetchWeeklyWorkouts() async {
        let workoutType = HKObjectType.workoutType()
        
        let now = Date()
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: fourteenDaysAgo, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        print("Fetching workouts from \(fourteenDaysAgo) to \(now)")
        
        do {
            let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: predicate,
                    limit: 0,
                    sortDescriptors: [sortDescriptor]
                ) { query, samples, error in
                    if let error = error {
                        print("Error fetching workouts: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }
                    if let workouts = samples as? [HKWorkout] {
                        print("Fetched \(workouts.count) workouts")
                        continuation.resume(returning: workouts)
                    } else {
                        print("No workouts found")
                        continuation.resume(returning: [])
                    }
                }
                self.healthStore.execute(query)
            }
            
            print("Processing \(workouts.count) workouts")
            var entries: [WorkoutEntry] = []
            for workout in workouts {
                let type = workout.workoutActivityType.name
                let duration = workout.duration
                let date = workout.startDate
                print("Workout: Type=\(type), Duration=\(duration), Date=\(date)")
                // Fetch max heart rate during this workout
                let maxHR = await fetchMaxHeartRate(for: workout)
                if let maxHR = maxHR {
                    print("Max heart rate for workout: \(maxHR)")
                } else {
                    print("No heart rate data for this workout")
                }
                let entry = WorkoutEntry(type: type, duration: duration, date: date, maxHeartRate: maxHR)
                entries.append(entry)
            }
            self.weeklyWorkouts = entries
            print("Total entries added: \(entries.count)")
        } catch {
            print("Error fetching workouts: \(error)")
            self.weeklyWorkouts = []
        }
    }
    
    @MainActor
    func fetchMaxHeartRate(for workout: HKWorkout) async -> Double? {
        print("Fetching max heart rate for workout on \(workout.startDate)")
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                print("Heart Rate Quantity Type is unavailable.")
                continuation.resume(returning: nil)
                return
            }
            let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: [])
            
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteMax) { _, result, error in
                if let error = error {
                    print("Error fetching heart rate: \(error)")
                }
                if let maxQuantity = result?.maximumQuantity() {
                    let maxHR = maxQuantity.doubleValue(for: HKUnit(from: "count/min"))
                    print("Max heart rate: \(maxHR)")
                    continuation.resume(returning: maxHR)
                } else {
                    print("No max heart rate found.")
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
}

extension SleepViewModel {
    var totalSleepHours: Double {
        return parseHoursMinutesString(totalSleep)
    }

    var deepSleepHours: Double {
        return parseHoursMinutesString(deepSleep)
    }

    private func parseHoursMinutesString(_ timeString: String) -> Double {
        let components = timeString.components(separatedBy: " ")
        var hours = 0
        var minutes = 0
        for component in components {
            if component.hasSuffix("h") {
                if let h = Int(component.dropLast()) {
                    hours = h
                }
            } else if component.hasSuffix("m") {
                if let m = Int(component.dropLast()) {
                    minutes = m
                }
            }
        }
        return Double(hours) + Double(minutes) / 60.0
    }
}

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .yoga:
            return "Yoga"
        // Add other cases as needed
        default:
            return "Other"
        }
    }
}
