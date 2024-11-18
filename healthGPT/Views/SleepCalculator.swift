//
//  SleepCalculator.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//
struct SleepCalculator {
    static func calculateSleepPerformance(totalSleepHours: Double, deepSleepHours: Double) -> Double {
        // Ideal sleep duration is 7-9 hours
        let idealSleepDuration = 8.0
        let idealDeepSleepPercentage = 0.25 // 25% of total sleep should be deep sleep
        
        // Calculate sleep duration score (max 50 points)
        let durationScore = min(50.0, (totalSleepHours / idealSleepDuration) * 50.0)
        
        // Calculate deep sleep score (max 50 points)
        let actualDeepSleepPercentage = deepSleepHours / totalSleepHours
        let deepSleepScore = min(50.0, (actualDeepSleepPercentage / idealDeepSleepPercentage) * 50.0)
        
        // Total score out of 100
        let totalScore = durationScore + deepSleepScore
        
        return totalScore / 100.0 // Return as percentage
    }
} 
