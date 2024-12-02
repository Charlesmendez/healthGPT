//
//  WorkoutsView.swift
//  UpReady
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

