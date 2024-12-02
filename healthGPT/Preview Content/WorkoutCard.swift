//
//  WorkoutCard.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/18/24.
//

import SwiftUI

struct WorkoutCard: View {
    let workout: WorkoutEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Workout Type
            Text(workout.type)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Workout Date
            Text(formatDate(workout.date))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Divider
            Divider()
            
            // Duration, Max Heart Rate, and Calories
            HStack {
                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(workout.duration))
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Max Heart Rate (optional)
                if let maxHR = workout.maxHeartRate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max Heart Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(maxHR)) bpm")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                
                // Calories (optional)
                if let calories = workout.calories {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(calories)) kcal")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
