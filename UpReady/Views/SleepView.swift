//
//  SleepView.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/29/24.
//

import SwiftUI

struct SleepView: View {
    @ObservedObject var viewModel: SleepViewModel

    var body: some View {
        VStack(spacing: 30) {
            // Total Sleep Time
            VStack {
                Text("Total Sleep Time")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(viewModel.totalSleep)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Divider()
            
            // Sleep Stages
            VStack(alignment: .leading, spacing: 15) {
                Text("Sleep Stages")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 10) {
                    SleepStageBar(stage: "Awake", value: viewModel.awakePercentage, color: .gray)
                    SleepStageBar(stage: "Core Sleep", value: viewModel.coreSleepPercentage, color: .blue)
                    SleepStageBar(stage: "Deep Sleep", value: viewModel.deepSleepPercentage, color: .purple)
                    SleepStageBar(stage: "REM", value: viewModel.remSleepPercentage, color: .pink)
                    SleepStageBar(stage: "Unspecified", value: viewModel.unspecifiedSleepPercentage, color: .orange)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 3)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground).edgesIgnoringSafeArea(.all))
    }
}

struct SleepStageBar: View {
    let stage: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(stage)
                    .font(.subheadline)
                Spacer()
                Text("\(value)%")
                    .font(.subheadline)
            }
            ProgressView(value: Double(value) / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
}
