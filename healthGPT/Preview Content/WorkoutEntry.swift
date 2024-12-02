//
//  WorkoutEntry.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/18/24.
//

import Foundation

struct WorkoutEntry: Identifiable, Codable {
    var id = UUID()
    let type: String
    let duration: TimeInterval // Duration in seconds
    let date: Date
    let maxHeartRate: Double?
    let calories: Double?
}
