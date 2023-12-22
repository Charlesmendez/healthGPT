//
//  ContentView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: SleepViewModel
    @State private var readinessSummary: String?
    
    var body: some View {
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
                        SleepDataView(title: "In Bed", value: viewModel.inBed)
                        
                        Divider()
                        HealthMetricView(title: "Heart Rate Range", stringValue: viewModel.heartRateRangeString, unit: "bpm")
                        HealthMetricView(title: "Resting Heart Rate", value: viewModel.restingHeartRate, unit: "bpm")
                        HealthMetricView(title: "Heart Variability", value: viewModel.heartRateVariability, unit: "ms")
                        HealthMetricView(title: "Oxygen in Blood", value: viewModel.bloodOxygen.map { $0 * 100 }, unit: "%")
                        HealthMetricView(title: "Respiratory Rate", value: viewModel.respiratoryRate, unit: "brpm")
                        
                        if let bodyTemperatureComparison = viewModel.bodyTemperatureComparison {
                            Text("Bodytemp baseline: \(bodyTemperatureComparison)")
                                .font(.headline)
                                .foregroundColor(bodyTemperatureComparison.contains("above") ? .white : .blue)
                                .padding(.vertical)
                        }
                        
                        
                        Text("Stress Level: \(viewModel.stressLevel)")
                            .font(.title3) // Bigger font size
                            .fontWeight(.bold) // Bold text for emphasis
                            .foregroundColor(.red) // A color that stands out, you can choose a different one
                            .padding(.vertical) // Add padding to give it more space
                        
                      
                        if let readinessSummary = viewModel.readinessSummary {
                            Text("Readiness Summary: \(readinessSummary)")
                                .font(.title2)
                                .padding(.top)
                        }
                        
                        Button("Refresh Data") {
                            viewModel.fetchSleepData()
                        }
                        
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep Analysis")
            .navigationBarItems(trailing: Button(action: {
                // Add action for settings or refresh
            }) {
                Image(systemName: "gear")
                    .imageScale(.large)
            })
        }
        .onAppear {
            viewModel.fetchSleepData()
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
