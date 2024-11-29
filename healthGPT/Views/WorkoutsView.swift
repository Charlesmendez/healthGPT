//
//  WorkoutsView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/29/24.
//

import SwiftUI

struct WorkoutsView: View {
    @ObservedObject var viewModel: SleepViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !viewModel.weeklyWorkouts.isEmpty {
                    Text("Weekly Workouts")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.top)
                    
                    ForEach(viewModel.weeklyWorkouts) { workout in
                        WorkoutCard(workout: workout)
                    }
                } else {
                    Text("No workouts available for this period.")
                        .foregroundColor(.gray)
                        .italic()
                }
            }
            .padding(.bottom)
        }
    }
}

//struct WorkoutCard: View {
//    let workout: WorkoutEntry
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            Text(workout.type)
//                .font(.headline)
//                .foregroundColor(.primary)
//            
//            HStack {
//                Text("Duration: \(formatDuration(workout.duration))")
//                Spacer()
//                if let maxHR = workout.maxHeartRate {
//                    Text("Max HR: \(Int(maxHR)) bpm")
//                }
//            }
//            .font(.subheadline)
//            .foregroundColor(.secondary)
//        }
//        .padding()
//        .background(Color(UIColor.systemBackground))
//        .cornerRadius(8)
//        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
//    }
//    
//    private func formatDuration(_ duration: TimeInterval) -> String {
//        let minutes = Int(duration / 60)
//        let hours = minutes / 60
//        let remainingMinutes = minutes % 60
//        return hours > 0 ? "\(hours)h \(remainingMinutes)m" : "\(remainingMinutes)m"
//    }
//}
