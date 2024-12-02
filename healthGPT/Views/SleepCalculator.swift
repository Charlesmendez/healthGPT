//
//  SleepCalculator.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

struct SleepCalculator {
    // MARK: - Configuration for Ideal Sleep Metrics
    struct IdealSleepConfig {
        static let idealTotalSleep: Double = 8.0 // hours
        static let idealDeepSleepPercentage: Double = 0.20 // 20%
        static let idealRemSleepPercentage: Double = 0.25 // 25%
        static let idealCoreSleepPercentage: Double = 0.30 // 30%
        static let idealUnspecifiedSleepPercentage: Double = 0.15 // 15%
        static let idealAwakePercentage: Double = 0.10 // 10%
    }
    
    // MARK: - Scoring Weights
    private struct Weights {
        static let durationWeight: Double = 30.0
        static let deepSleepWeight: Double = 15.0
        static let remSleepWeight: Double = 15.0
        static let coreSleepWeight: Double = 15.0
        static let unspecifiedSleepWeight: Double = 10.0
        static let awakeWeight: Double = 15.0
    }
    
    // MARK: - Main Calculation Function
    static func calculateSleepPerformance(
        totalSleepHours: Double,
        deepSleepHours: Double,
        remSleepHours: Double,
        coreSleepHours: Double,
        unspecifiedSleepHours: Double,
        awakeHours: Double
    ) -> Double {
        // Data Consistency Check
        let sumOfStages = deepSleepHours + remSleepHours + coreSleepHours + unspecifiedSleepHours + awakeHours
        let isDataConsistent = abs(sumOfStages - totalSleepHours) < 0.1 // Allowing a margin of 6 minutes
        
        guard isDataConsistent else {
            // Handle inconsistent data, possibly return a specific value or notify the user
            print("ERROR: Data is inconsistent. Returning 0.0")
            return 0.0
        }
        
        // Calculate actual percentages
        let deepSleepPercentage = totalSleepHours > 0 ? deepSleepHours / totalSleepHours : 0.0
        let remSleepPercentage = totalSleepHours > 0 ? remSleepHours / totalSleepHours : 0.0
        let coreSleepPercentage = totalSleepHours > 0 ? coreSleepHours / totalSleepHours : 0.0
        let unspecifiedSleepPercentage = totalSleepHours > 0 ? unspecifiedSleepHours / totalSleepHours : 0.0
        let awakePercentage = totalSleepHours > 0 ? awakeHours / totalSleepHours : 0.0
        
        // Calculate individual scores
        let durationScore = calculateDurationScore(totalSleepHours: totalSleepHours)
        let deepSleepScore = calculateStageScore(actual: deepSleepPercentage, ideal: IdealSleepConfig.idealDeepSleepPercentage, maxScore: Weights.deepSleepWeight)
        let remSleepScore = calculateStageScore(actual: remSleepPercentage, ideal: IdealSleepConfig.idealRemSleepPercentage, maxScore: Weights.remSleepWeight)
        let coreSleepScore = calculateStageScore(actual: coreSleepPercentage, ideal: IdealSleepConfig.idealCoreSleepPercentage, maxScore: Weights.coreSleepWeight)
        let unspecifiedSleepScore = calculateStageScore(actual: unspecifiedSleepPercentage, ideal: IdealSleepConfig.idealUnspecifiedSleepPercentage, maxScore: Weights.unspecifiedSleepWeight)
        let awakeScore = calculateStageScore(actual: awakePercentage, ideal: IdealSleepConfig.idealAwakePercentage, maxScore: Weights.awakeWeight, inverse: true) // Less awake time is better
        
        
        // Sum all scores
        let totalScore = durationScore + deepSleepScore + remSleepScore + coreSleepScore + unspecifiedSleepScore + awakeScore
        
        // Define the maximum possible score
        let maxScore = Weights.durationWeight + Weights.deepSleepWeight + Weights.remSleepWeight + Weights.coreSleepWeight + Weights.unspecifiedSleepWeight + Weights.awakeWeight
        
        // Calculate percentage
        let performancePercentage = (totalScore / maxScore)
        
        return performancePercentage
    }
    
    // MARK: - Helper Functions
    private static func calculateDurationScore(totalSleepHours: Double) -> Double {
        let ideal = IdealSleepConfig.idealTotalSleep
        let difference = abs(totalSleepHours - ideal)
        let maxDifference = 3.0 // Maximum difference considered for scoring (e.g., 3 hours)
        let score = max(0.0, Weights.durationWeight - (difference / maxDifference) * Weights.durationWeight)
        return score
    }
    
    private static func calculateStageScore(
        actual: Double,
        ideal: Double,
        maxScore: Double,
        inverse: Bool = false
    ) -> Double {
        let difference: Double
        if inverse {
            difference = actual > ideal ? actual - ideal : 0.0
        } else {
            difference = abs(actual - ideal)
        }
        let maxDifference = 0.5
        let normalizedDifference = min(difference / maxDifference, 1.0)
        let score = max(0.0, maxScore - (normalizedDifference * maxScore))
        return score
    }
}
