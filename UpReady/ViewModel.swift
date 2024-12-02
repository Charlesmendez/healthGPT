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
    
    // New numeric properties for durations in seconds
    private var totalSleepSeconds: Double = 0
    private var deepSleepSeconds: Double = 0
    private var remSleepSeconds: Double = 0
    private var coreSleepSeconds: Double = 0
    private var unspecifiedSleepSeconds: Double = 0
    private var awakeSeconds: Double = 0
    
    // New @Published properties for percentages
    @Published var deepSleepPercentage: Int = 0
    @Published var remSleepPercentage: Int = 0
    @Published var coreSleepPercentage: Int = 0
    @Published var unspecifiedSleepPercentage: Int = 0
    @Published var awakePercentage: Int = 0
    
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
    @Published var pressedReadinessScore: Bool = false
    @Published var pendingInvites: [FriendInvite] = []
    @Published var friends: [Friend] = []
    @Published var friendsReadinessScores: [FriendReadinessScore] = []
    @Published var refreshTrigger: Bool = false
    
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
    // New properties for tracking app usage
    @Published var lastLaunchDate: Date?
    @Published var hasOpenedToday: Bool = false
    
    private let userDefaultsLastLaunchKey = "lastLaunchDate"
    
    init() {
        loadCache()
        checkIfOpenedToday()
        loadLastLaunchDate()
        self.cardiovascularLoad = 0.0
        self.muscularLoad = 0.0
        self.totalLoad = 0.0
    }
    
    // MARK: - Tracking App Launch

        func loadLastLaunchDate() {
            if let date = UserDefaults.standard.object(forKey: userDefaultsLastLaunchKey) as? Date {
                self.lastLaunchDate = date
            }
        }

        func saveLastLaunchDate() {
            self.lastLaunchDate = Date()
            UserDefaults.standard.set(self.lastLaunchDate, forKey: userDefaultsLastLaunchKey)
        }

        func checkIfOpenedToday() {
            guard let lastLaunch = lastLaunchDate else {
                self.hasOpenedToday = false
                return
            }
            
            let calendar = Calendar.current
            let now = Date()
            if calendar.isDate(lastLaunch, inSameDayAs: now) {
                self.hasOpenedToday = true
            } else {
                self.hasOpenedToday = false
            }
        }

        // Call this method when the app becomes active
        func appDidBecomeActive() {
            saveLastLaunchDate()
            checkIfOpenedToday()
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
                
            } catch {
                print("Error decoding readinessScores: \(error)")
            }
        }
    }
    
    // Initialize data fetching
    @MainActor
    func initializeData() async {
        if await isNewDataAvailable() {
            isLoading = true
            await refreshData()
        } else {
            loadCache()
        }
        // Always fetch readiness scores
        await fetchReadinessScores()
    }
    
    // Determine whether to fetch new data by checking new sleep and workout data since lastFetchDate
    func isNewDataAvailable() async -> Bool {
        guard let lastFetch = lastFetchDate else {
            return true // No data fetched yet
        }

        let now = Date()
        let adjustedLastFetch = lastFetch // Use the exact last fetch date


        // Define sample types
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return false
        }
        let workoutType = HKObjectType.workoutType()

        // Create predicates without overlapping samples
        let sleepPredicate = HKQuery.predicateForSamples(withStart: adjustedLastFetch, end: now, options: .strictStartDate)
        let workoutPredicate = HKQuery.predicateForSamples(withStart: adjustedLastFetch, end: now, options: .strictStartDate)

        // Check for new data
        let sleepHasNewData = await hasNewData(sampleType: sleepType, predicate: sleepPredicate)
        let workoutHasNewData = await hasNewData(sampleType: workoutType, predicate: workoutPredicate)


        return sleepHasNewData || workoutHasNewData
    }
    
    private func hasNewData(sampleType: HKSampleType, predicate: NSPredicate) async -> Bool {
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(returning: false)
                    return
                }

                if let samples = samples, !samples.isEmpty {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }

            healthStore.execute(query)
        }
    }
    
    
    
    
    func fetchCardiovascularLoad(completion: @escaping () -> Void) {

        // Reset cardiovascularLoad to 0
        DispatchQueue.main.async {
            self.cardiovascularLoad = 0.0
        }

        let group = DispatchGroup()
        let workoutType = HKObjectType.workoutType()

        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion()
            return
        }

        let age = getAge(healthStore: healthStore)
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Set Monday as the first day of the week
        calendar.timeZone = TimeZone.current
        let now = Date()

        // Get the start of the current week
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            completion()
            return
        }

        // Log the date range

        // Create predicate to fetch workouts from startOfWeek to now
        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: [])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: 0,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] query, samples, error in
            guard let self = self else {
                completion()
                return
            }

            if let error = error {
                completion()
                return
            }

            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                completion()
                return
            }


            for workout in workouts {
                // Check if workout date is before startOfWeek
                if workout.startDate < startOfWeek {
                    continue
                }

                group.enter()
                let heartRatePredicate = HKQuery.predicateForSamples(
                    withStart: workout.startDate,
                    end: workout.endDate,
                    options: []
                )

                // Log each workout being processed

                let heartRateQuery = HKSampleQuery(
                    sampleType: heartRateType,
                    predicate: heartRatePredicate,
                    limit: 0,
                    sortDescriptors: nil
                ) { [weak self] query, hrSamples, error in
                    defer { group.leave() }
                    guard let self = self else { return }

                    if let error = error {
                        return
                    }

                    guard let hrSamples = hrSamples as? [HKQuantitySample], !hrSamples.isEmpty else {
                        return
                    }


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

                    DispatchQueue.main.async {
                        self.cardiovascularLoad += cardioLoad
                    }
                }
                self.healthStore.execute(heartRateQuery)
            }

            group.notify(queue: .main) {
                completion()
            }
        }

        self.healthStore.execute(query)

    }
    
    func fetchMuscularLoad(completion: @escaping () -> Void) {

        // Reset muscularLoad to 0
        DispatchQueue.main.async {
            self.muscularLoad = 0.0
        }

        let workoutType = HKObjectType.workoutType()
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        calendar.timeZone = TimeZone.current // Changed from UTC to current to match cardiovascularLoad
        let now = Date()

        // Get the start of the current week
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            completion()
            return
        }

        // Log the date range

        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: [])

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: 0,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] query, samples, error in
            guard let self = self else {
                completion()
                return
            }

            if let error = error {
                completion()
                return
            }

            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                completion()
                return
            }


            var totalMuscularLoad = 0.0

            for workout in workouts {
                // Skip workouts before startOfWeek
                if workout.startDate < startOfWeek {
                    continue
                }

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

               
            }

            DispatchQueue.main.async {
                self.muscularLoad = totalMuscularLoad
            }


            completion()
        }

        self.healthStore.execute(query)
    }
    
    func calculateTotalLoad() {
        let rawLoad = cardiovascularLoad + muscularLoad
        
        // **Adjust maxPossibleLoad to a realistic value for 7 days**
        let maxPossibleLoad = 1000.0  // Adjust this value based on your expectations
        
        let normalizedLoad = min(rawLoad / maxPossibleLoad, 1.0)
        
        // Optionally, apply non-linear scaling
        let loadScore = pow(normalizedLoad, 0.75)  // Adjust exponent as needed
        
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
        
        let success = await requestHealthDataAccess()
        if success {
            let sleepData = await healthDataManager.fetchSleepData()
            processSleepData(sleepData: sleepData)
            fetchAdditionalHealthData()

            // Wait for load calculations to complete
            await withCheckedContinuation { continuation in
                let group = DispatchGroup()

                group.enter()
                fetchCardiovascularLoad {
                    group.leave()
                }

                group.enter()
                fetchMuscularLoad {
                    group.leave()
                }

                group.notify(queue: .main) {
                    self.calculateTotalLoad()
                    continuation.resume()
                }
            }

            // Move saveCache() here, after all processing is done
            saveCache()
        } else {
            print("Carlos1: Failed to get HealthKit data access.")
        }
    }
    
    @MainActor
    func refreshData() async {
        isLoading = true
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        } catch {
            print("Carlos2: Sleep was interrupted: \(error)")
        }
        
        // Fetch and process sleep data
        await fetchAndProcessSleepData()
        
        // Fetch weekly workouts
        await fetchWeeklyWorkouts()
        
        
        isLoading = false
    }
    
    @MainActor
    func fetchReadinessSummary() async {
        // Directly await the async function
        if let summary = await TextRecognition().findCommonalitiesInArray(keywords: getSleepMetricsAsKeywords()) {
            // Update the readiness summary
            self.readinessSummary = summary
            
            // Save readiness score and cache
            await self.saveReadinessScore()
            UserDefaults.standard.set(summary, forKey: self.cacheReadinessSummaryKey)
        } else {
            self.readinessSummary = "Failed to load readiness summary."
        }
    }
    
    // Fetch Readiness Scores from Supabase
    func fetchReadinessScores() async {
        do {
            let scores = try await SupabaseManager.shared.fetchReadinessScores()
            DispatchQueue.main.async {
                self.readinessScores = scores
            }
            saveReadinessScoresToCache()
        } catch {
            print("Error fetching readiness scores: \(error)")
            // Optionally, attempt to load from cache if fetch fails
            loadReadinessScoresFromCache()
        }
    }
    
    func saveReadinessScore() async {
        guard let score = extractReadinessScore() else {
            print("Carlos Debug: Readiness score could not be extracted. Readiness summary is \(readinessSummary ?? "nil").")
            return
        }

        do {
            print("Carlos Debug: Saving readiness score \(score) with totalLoad \(totalLoad).")
            try await SupabaseManager.shared.saveReadinessScore(date: Date(), score: score, load: totalLoad)
            print("Carlos Debug: Successfully saved readiness score.")
        } catch {
            print("Carlos Debug: Error saving readiness score: \(error)")
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
        
        // Fetch Respiratory Rate While Asleep
        healthDataManager.fetchRespiratoryRate(for: Date()) { [weak self] rate in
            Task { @MainActor in
                self?.respiratoryRate = rate
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
        
        // Always required metrics
        let requiredMetrics: [String: Any?] = [
            "Maximum Heart Rate": maxHeartRate,
            "Minimum Heart Rate": minHeartRate,
            "Resting Heart Rate": restingHeartRate,
            "Heart Rate Variability": heartRateVariability,
            "Average Heart Rate Variability": AverageHeartRateVariability,
            "Respiratory Rate": respiratoryRate,
            "Body Temperature Comparison": bodyTemperatureComparison,
            "Stress Level": stressLevel == "Unknown" ? nil : "Known"
        ]
        
        // Conditionally required metrics based on device capabilities
        if isMetricSupported(.bloodOxygen) {
            if bloodOxygen == nil {
                missing.append("Blood Oxygen")
            }
        }
        
        if isMetricSupported(.bodyTemperature) {
            if bodyTemperature == nil {
                missing.append("Body Temperature")
            }
        }
        
        // Check always required metrics
        for (metric, value) in requiredMetrics {
            if value == nil {
                missing.append(metric)
            }
        }
        
        if missing.isEmpty {
            allHealthMetricsAvailable = true
            // Call fetchReadinessSummary asynchronously using Task
            Task {
                await fetchReadinessSummary()
            }
            missingMetrics = []
        } else {
            allHealthMetricsAvailable = false
            self.missingMetrics = missing
            isLoading = false
        }
    }
    
    
    private func isMetricSupported(_ metric: HealthMetric) -> Bool {
        switch metric {
        case .bloodOxygen:
            return HKObjectType.quantityType(forIdentifier: .oxygenSaturation) != nil
        case .bodyTemperature:
            return HKObjectType.quantityType(forIdentifier: .bodyTemperature) != nil
        // Add other metrics as needed
        default:
            return false
        }
    }

    enum HealthMetric {
        case bloodOxygen
        case bodyTemperature
        // Add other metrics as needed
    }
    
    func processSleepData(sleepData: [HKCategorySample]?) {
        var totalSeconds = 0.0
        var deepSeconds = 0.0
        var remSeconds = 0.0
        var coreSeconds = 0.0
        var unspecifiedSeconds = 0.0
        var awakeSec = 0.0
        
        guard let sleepData = sleepData else {
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
                unspecifiedSeconds += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeSec += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSeconds += duration
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSeconds += duration
            default:
                print("Unknown sleep stage: \(sample.value)")
            }
            
            totalSeconds += duration
        }
        
        // Update durations
        self.totalSleepSeconds = totalSeconds
        self.deepSleepSeconds = deepSeconds
        self.remSleepSeconds = remSeconds
        self.coreSleepSeconds = coreSeconds
        self.unspecifiedSleepSeconds = unspecifiedSeconds
        self.awakeSeconds = awakeSec
        
        // Format durations as strings for display
        self.totalSleep = self.formatDuration(seconds: totalSeconds)
        self.deepSleep = self.formatDuration(seconds: deepSeconds)
        self.remSleep = self.formatDuration(seconds: remSeconds)
        self.coreSleep = self.formatDuration(seconds: coreSeconds)
        self.unspecifiedSleep = self.formatDuration(seconds: unspecifiedSeconds)
        self.awake = self.formatDuration(seconds: awakeSec)
        
        // Calculate percentages
        calculateSleepStagePercentages()
    }
    
    private func calculateSleepStagePercentages() {
        guard totalSleepSeconds > 0 else {
            self.deepSleepPercentage = 0
            self.remSleepPercentage = 0
            self.coreSleepPercentage = 0
            self.unspecifiedSleepPercentage = 0
            self.awakePercentage = 0
            return
        }
        
        self.deepSleepPercentage = Int((deepSleepSeconds / totalSleepSeconds) * 100)
        self.remSleepPercentage = Int((remSleepSeconds / totalSleepSeconds) * 100)
        self.coreSleepPercentage = Int((coreSleepSeconds / totalSleepSeconds) * 100)
        self.unspecifiedSleepPercentage = Int((unspecifiedSleepSeconds / totalSleepSeconds) * 100)
        self.awakePercentage = Int((awakeSeconds / totalSleepSeconds) * 100)
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
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        calendar.timeZone = TimeZone.current
        
        guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfWeek, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
       
        
        do {
            let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                let query = HKSampleQuery(
                    sampleType: workoutType,
                    predicate: predicate,
                    limit: 0,
                    sortDescriptors: [sortDescriptor]
                ) { query, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let workouts = samples as? [HKWorkout] {
                        continuation.resume(returning: workouts)
                    } else {
                        continuation.resume(returning: [])
                    }
                }
                self.healthStore.execute(query)
            }
            
            var entries: [WorkoutEntry] = []
            for workout in workouts {
                let typeName = workout.workoutActivityType.name
                let typeRawValue = workout.workoutActivityType.rawValue
                let duration = workout.duration
                let date = workout.startDate
                
                // Fetch max heart rate during this workout
                let maxHR = await fetchMaxHeartRate(for: workout)
                
                // Fetch calories burned
                let calories: Double?
                if let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    calories = energy
                } else {
                    calories = nil
                }
                
                let entry = WorkoutEntry(
                    type: typeName,
                    duration: duration,
                    date: date,
                    maxHeartRate: maxHR,
                    calories: calories // Assign calories
                )
                entries.append(entry)
            }
            self.weeklyWorkouts = entries
        } catch {
            print("Error fetching workouts: \(error)")
            self.weeklyWorkouts = []
        }
    }
    
    @MainActor
    func fetchMaxHeartRate(for workout: HKWorkout) async -> Double? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
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
                    continuation.resume(returning: maxHR)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    func sendFriendInvite(email: String) async {
            do {
                try await SupabaseManager.shared.sendFriendInvite(email: email)
                // Optionally notify the user of success
            } catch {
                print("Error sending friend invite: \(error)")
                // Optionally handle error
            }
        }

        func fetchPendingInvites() async {
            do {
                let invites = try await SupabaseManager.shared.fetchPendingInvites()
                self.pendingInvites = invites
            } catch {
                print("Error fetching pending invites: \(error)")
            }
        }

        func acceptInvite(invite: FriendInvite) async {
            do {
                try await SupabaseManager.shared.acceptInvite(inviteId: invite.id)
                await fetchPendingInvites()
                await fetchFriends()
                await fetchFriendsReadinessScores()
            } catch {
                print("Error accepting invite: \(error)")
            }
        }

        func declineInvite(invite: FriendInvite) async {
            do {
                try await SupabaseManager.shared.declineInvite(inviteId: invite.id)
                await fetchPendingInvites()
            } catch {
                print("Error declining invite: \(error)")
            }
        }

        func fetchFriends() async {
            do {
                let friends = try await SupabaseManager.shared.fetchFriends()
                self.friends = friends
            } catch {
                print("Error fetching friends: \(error)")
            }
        }

        func fetchFriendsReadinessScores() async {
            do {
                let scores = try await SupabaseManager.shared.fetchFriendsReadinessScores()
                self.friendsReadinessScores = scores
            } catch {
                print("Error fetching friends' readiness scores: \(error)")
            }
        }
    
    func revokeFriend(friendId: UUID) async {
        do {
            try await SupabaseManager.shared.revokeFriend(friendId: friendId)
            // Refresh the data to update UI
            await fetchFriends()
            await fetchFriendsReadinessScores()
            DispatchQueue.main.async {
                self.refreshTrigger.toggle()
            }
        } catch {
            print("Error revoking friend: \(error)")
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

    var remSleepHours: Double {
        return parseHoursMinutesString(remSleep)
    }

    var coreSleepHours: Double {
        return parseHoursMinutesString(coreSleep)
    }

    var unspecifiedSleepHours: Double {
        return parseHoursMinutesString(unspecifiedSleep)
    }

    var awakeHours: Double {
        return parseHoursMinutesString(awake)
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

extension Date {
    func removingMilliseconds() -> Date {
        let timeInterval = floor(self.timeIntervalSinceReferenceDate)
        return Date(timeIntervalSinceReferenceDate: timeInterval)
    }
    
    func inTimeZone(_ timeZone: TimeZone) -> Date {
        let targetSeconds = TimeInterval(timeZone.secondsFromGMT(for: self))
        let localSeconds = TimeInterval(TimeZone.current.secondsFromGMT(for: self))
        return self.addingTimeInterval(targetSeconds - localSeconds)
    }
}


extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .americanFootball:             return "American Football"
        case .archery:                      return "Archery"
        case .australianFootball:           return "Australian Football"
        case .badminton:                    return "Badminton"
        case .baseball:                     return "Baseball"
        case .basketball:                   return "Basketball"
        case .bowling:                      return "Bowling"
        case .boxing:                       return "Boxing"
        case .climbing:                     return "Climbing"
        case .cricket:                      return "Cricket"
        case .crossTraining:                return "Cross Training"
        case .curling:                      return "Curling"
        case .cycling:                      return "Cycling"
        case .dance:                        return "Dance"
        case .danceInspiredTraining:        return "Dance Inspired Training"
        case .elliptical:                   return "Elliptical"
        case .equestrianSports:             return "Equestrian Sports"
        case .fencing:                      return "Fencing"
        case .fishing:                      return "Fishing"
        case .functionalStrengthTraining:   return "Functional Strength Training"
        case .golf:                         return "Golf"
        case .gymnastics:                   return "Gymnastics"
        case .handball:                     return "Handball"
        case .hiking:                       return "Hiking"
        case .hockey:                       return "Hockey"
        case .hunting:                      return "Hunting"
        case .lacrosse:                     return "Lacrosse"
        case .martialArts:                  return "Martial Arts"
        case .mindAndBody:                  return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
        case .paddleSports:                 return "Paddle Sports"
        case .play:                         return "Play"
        case .preparationAndRecovery:       return "Preparation and Recovery"
        case .racquetball:                  return "Racquetball"
        case .rowing:                       return "Rowing"
        case .rugby:                        return "Rugby"
        case .running:                      return "Running"
        case .sailing:                      return "Sailing"
        case .skatingSports:                return "Skating Sports"
        case .snowSports:                   return "Snow Sports"
        case .soccer:                       return "Soccer"
        case .softball:                     return "Softball"
        case .squash:                       return "Squash"
        case .stairClimbing:                return "Stair Climbing"
        case .surfingSports:                return "Surfing Sports"
        case .swimming:                     return "Swimming"
        case .tableTennis:                  return "Table Tennis"
        case .tennis:                       return "Tennis"
        case .trackAndField:                return "Track and Field"
        case .traditionalStrengthTraining:  return "Traditional Strength Training"
        case .volleyball:                   return "Volleyball"
        case .walking:                      return "Walking"
        case .waterFitness:                 return "Water Fitness"
        case .waterPolo:                    return "Water Polo"
        case .waterSports:                  return "Water Sports"
        case .wrestling:                    return "Wrestling"
        case .yoga:                         return "Yoga"
        
        // iOS 10+
        case .barre:                        return "Barre"
        case .coreTraining:                 return "Core Training"
        case .crossCountrySkiing:           return "Cross Country Skiing"
        case .downhillSkiing:               return "Downhill Skiing"
        case .flexibility:                  return "Flexibility"
        case .highIntensityIntervalTraining: return "High Intensity Interval Training"
        case .jumpRope:                     return "Jump Rope"
        case .kickboxing:                   return "Kickboxing"
        case .pilates:                      return "Pilates"
        case .snowboarding:                 return "Snowboarding"
        case .stairs:                       return "Stairs"
        case .stepTraining:                 return "Step Training"
        case .wheelchairWalkPace:           return "Wheelchair Walk Pace"
        case .wheelchairRunPace:            return "Wheelchair Run Pace"
        
        // iOS 11+
        case .taiChi:                       return "Tai Chi"
        case .mixedCardio:                  return "Mixed Cardio"
        case .handCycling:                  return "Hand Cycling"
        
        // iOS 13+
        case .discSports:                   return "Disc Sports"
        case .fitnessGaming:                return "Fitness Gaming"
        
        // iOS 14+
        case .cardioDance:                  return "Cardio Dance"
        case .socialDance:                  return "Social Dance"
        case .pickleball:                   return "Pickleball"
        case .cooldown:                     return "Cooldown"
        
        // iOS 15+
        case .barre:                        return "Barre"
        // Add any new types introduced in iOS 15+

        // iOS 16+ (Example additions; ensure to check the latest documentation)
        case .coreTraining:                 return "Core Training"
        // Add more as needed

        // Default case for any unknown types
        case .other:                        return "Other"
        @unknown default:                   return "Other"
        }
    }
}
