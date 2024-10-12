import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: SleepViewModel
    @State private var readinessSummary: String?

    var body: some View {
        TabView {
            // Sleep Analysis Tab
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView("Loading sleep data...")
                        } else {
                            SleepDataView(title: "Total Sleep", value: viewModel.totalSleep)
                            SleepDataView(title: "Deep Sleep", value: viewModel.deepSleep)
                            SleepDataView(title: "REM Sleep", value: viewModel.remSleep)
                            SleepDataView(title: "Core Sleep", value: viewModel.coreSleep)

                            Divider()
                            HealthMetricView(title: "Heart Rate Range", stringValue: viewModel.heartRateRangeString, unit: "bpm")
                            HealthMetricView(title: "Resting Heart Rate", value: viewModel.restingHeartRate, unit: "bpm")
                            HealthMetricView(title: "Average Resting Heart Rate", value: viewModel.averageHeartRate, unit: "bpm")
                            HealthMetricView(title: "Heart Rate Variability", value: viewModel.heartRateVariability, unit: "ms")
                            HealthMetricView(title: "Average Heart Rate Variability", value: viewModel.AverageHeartRateVariability, unit: "ms")
                            HealthMetricView(title: "Oxygen in Blood", value: viewModel.bloodOxygen.map { $0 * 100 }, unit: "%")
                            HealthMetricView(title: "Respiratory Rate", value: viewModel.respiratoryRate, unit: "brpm")

                            // New View for Average Respiratory Rate for Last Week
                            HealthMetricView(title: "Avg Respiratory Rate Last Week", value: viewModel.averageRespiratoryRateForLastWeek, unit: "brpm")

                            if let bodyTemperatureComparison = viewModel.bodyTemperatureComparison {
                                Text("Body Temperature Baseline: \(bodyTemperatureComparison)")
                                    .font(.headline)
                                    .foregroundColor(bodyTemperatureComparison.contains("above") ? .red : .blue)
                                    .padding(.vertical)
                            }

                            Text("Balance Disruption Causes: \(viewModel.stressLevel)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .padding(.vertical)

                            if let readinessSummary = viewModel.readinessSummary {
                                Text("Readiness Summary: \(readinessSummary)")
                                    .font(.title2)
                                    .padding(.top)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil) // Ensure no limit on the number of lines
                                    .fixedSize(horizontal: false, vertical: true) // Allows vertical growth
                            }

                            Button("Refresh Data") {
                                Task {
                                    await viewModel.fetchAndProcessSleepData()
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Sleep Analysis")
                .navigationBarItems(trailing: Button(action: {
                    // Settings action
                }) {
                    Image(systemName: "gear")
                        .imageScale(.large)
                })
            }
            .tabItem {
                Label("Sleep", systemImage: "bed.double.fill")
            }

            // Readiness Chart Tab
            ReadinessChartView()
                .tabItem {
                    Label("Readiness", systemImage: "chart.bar")
                }
        }
        .onAppear {
            Task {
                await viewModel.fetchAndProcessSleepData()
            }
        }
    }
}

struct SleepDataView: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title + ":")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.title)
                .foregroundColor(.blue)
        }
    }
}

struct HealthMetricView: View {
    var title: String
    var value: Double?
    var stringValue: String?
    var unit: String

    init(title: String, value: Double?, unit: String) {
        self.title = title
        self.value = value
        self.stringValue = nil
        self.unit = unit
    }

    init(title: String, stringValue: String?, unit: String) {
        self.title = title
        self.value = nil
        self.stringValue = stringValue
        self.unit = unit
    }

    var body: some View {
        HStack {
            Text(title + ":")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            if let value = value {
                Text(String(format: "%.1f", value) + " \(unit)")
                    .font(.title)
                    .foregroundColor(.green)
            } else if let stringValue = stringValue {
                Text(stringValue + " \(unit)")
                    .font(.title)
                    .foregroundColor(.green)
            } else {
                Text("N/A")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}
