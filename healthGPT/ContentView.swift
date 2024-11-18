import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: SleepViewModel
    @State private var readinessSummary: String?

//    init(viewModel: SleepViewModel) {
//        self.viewModel = viewModel
//    }

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

                    Button("Refresh Data") {
                        Task {
                            await viewModel.refreshData()
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
            .padding(.horizontal)
            .padding(.vertical, 30)
        }
        .background(Color(.systemBackground))
//        .onAppear {
//            Task {
//                await viewModel.fetchAndProcessSleepData()
//            }
//        }
    }
}
