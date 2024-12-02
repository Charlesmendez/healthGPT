//
//  HRView.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/29/24.
//

import SwiftUI

struct HRVView: View {
    @ObservedObject var viewModel: SleepViewModel
    
    // Computed property for HRV percentage score
    private var hrvPercentage: Double {
        if let currentHRV = viewModel.heartRateVariability,
           let averageHRV = viewModel.AverageHeartRateVariability {
            let percentage = currentHRV / averageHRV
            // Clamp the value between 0 and 1
            return min(max(percentage, 0.0), 1.0)
        } else {
            return 0.0
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Circular Progress - HRV
            ZStack {
                CircularProgressView(
                    progress: hrvPercentage,
                    color: .blue,
                    lineWidth: 15,
                    radius: 100
                )
                .frame(width: 220, height: 220)
                
                VStack {
                    Text("\(Int(hrvPercentage * 100))%")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("HRV")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 20)
            
            Divider()
            
            // Recovery Statistics Section
            VStack(alignment: .leading, spacing: 20) {
                Text("Recovery Statistics")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Cards with Trend Indicator
                VStack(spacing: 15) {
                    RecoveryStatisticCardWithTrend(
                        title: "HRV vs Average",
                        current: Int(viewModel.heartRateVariability ?? 0),
                        average: Int(viewModel.AverageHeartRateVariability ?? 0),
                        color: .blue,
                        isHigherBetter: true // Higher HRV is good
                    )
                    
                    RecoveryStatisticCardWithTrend(
                        title: "Resting HR vs Average",
                        current: Int(viewModel.restingHeartRate ?? 0),
                        average: Int(viewModel.averageHeartRate ?? 0),
                        color: .red,
                        isHigherBetter: false // Lower Resting HR is good
                    )
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

struct RecoveryStatisticCardWithTrend: View {
    let title: String
    let current: Int
    let average: Int
    let color: Color
    let isHigherBetter: Bool // Determines if a higher value is better
    
    // Determine trend direction
    private var trend: TrendDirection {
        if isHigherBetter {
            return current >= average ? .up : .down
        } else {
            return current <= average ? .down : .up
        }
    }
    
    // Determine color for the arrow and the font
    private var trendColor: Color {
        if isHigherBetter {
            return trend == .up ? .green : .red
        } else {
            return trend == .down ? .green : .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("\(current)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(trendColor) // Updated font color
                        Image(systemName: trend == .up ? "arrow.up" : "arrow.down")
                            .foregroundColor(trendColor) // Updated arrow color
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Average:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(average)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

enum TrendDirection {
    case up
    case down
}
