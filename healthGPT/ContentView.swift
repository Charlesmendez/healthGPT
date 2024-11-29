import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: SleepViewModel
    @State private var readinessSummary: String?
    
    // Computed property for readiness score
    var readinessScoreDouble: Double {
        if let score = viewModel.readinessScore {
            return Double(score) / 100.0
        } else {
            return 0.0
        }
    }
    
    // Computed property for load score
    var loadScore: Double {
        return viewModel.totalLoad
    }
    
    // Computed property for sleep performance
    var sleepPerformance: Double {
        let totalSleepHours = viewModel.totalSleepHours
        let deepSleepHours = viewModel.deepSleepHours
        return SleepCalculator.calculateSleepPerformance(totalSleepHours: totalSleepHours, deepSleepHours: deepSleepHours)
    }
    
    // Computed property for HRV score
    var hrvScore: Double {
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
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        // HRV - Outer ring
                        CircularProgressView(
                            progress: hrvScore,
                            color: .blue,
                            lineWidth: 12,
                            radius: 100
                        )
                        
                        // Sleep Performance
                        CircularProgressView(
                            progress: sleepPerformance,
                            color: .purple,
                            lineWidth: 12,
                            radius: 85
                        )
                        
                        // Load
                        CircularProgressView(
                            progress: loadScore,
                            color: .orange,
                            lineWidth: 12,
                            radius: 70
                        )
                        
                        // Readiness - Inner ring
                        CircularProgressView(
                            progress: readinessScoreDouble,
                            color: .green,
                            lineWidth: 12,
                            radius: 55
                        )
                        
                        // Center image
                        Image("up")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                        
                        // Metrics Labels
                        MetricsLabelsView(
                            readiness: readinessScoreDouble,
                            sleep: sleepPerformance,
                            hrv: hrvScore,
                            load: loadScore
                        )
                        .padding()
                    }
                    .padding(40)
                    .frame(height: 400)
                    
                    // Readiness Summary Section
                    VStack(alignment: .leading, spacing: 20) {
                        if viewModel.allHealthMetricsAvailable {
                            if let readinessSummary = viewModel.readinessSummary {
                                Text("Readiness Summary:")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.top)
                                
                                Text(readinessSummary)
                                    .font(.body)
                                    .padding(.horizontal)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Loading readiness summary...")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                        } else if !viewModel.missingMetrics.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Cannot Show Readiness Score")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                
                                Text("\(viewModel.missingMetrics.joined(separator: ", ")) metric(s) are missing. I can't show you the readiness score. Come back later and refresh your data.")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        } else {
                            Text("No data to display. Please refresh your data...")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        // Always show the "Refresh Data" button
                        Button(action: {
                            Task {
                                await viewModel.refreshData()
                                viewModel.pressedReadinessScore.toggle()
                            }
                        }) {
                            Text("Refresh Data")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top)
                    }
                    .padding()
                }
                .padding(.horizontal)
                .padding(.vertical, 30)
            }
            .background(Color(.systemBackground))
            
            // Overlay LoadingView when isLoading is true
            if viewModel.isLoading {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                LoadingView()
                    .transition(.opacity)
            }
        }
        .onAppear {
//            if viewModel.readinessSummary == nil && !viewModel.isLoading {
//                Task {
//                    await viewModel.initializeData()
//                }
//            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            // Semi-transparent background that covers the entire screen
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            // Centered loading indicator
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            // Ensure the loading indicator is centered
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(10)
        }
    }
}
