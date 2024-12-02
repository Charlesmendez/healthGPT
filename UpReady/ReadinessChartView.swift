// ReadinessChartView.swift

import SwiftUI
import Charts

enum DashboardTab: String, CaseIterable, Identifiable {
    case readiness = "Readiness"
    case workouts = "Workouts"
    case hrv = "HRV"
    case sleep = "Sleep"
    
    var id: String { self.rawValue }
}

struct ReadinessChartView: View {
    @EnvironmentObject var viewModel: SleepViewModel
    @State private var selectedTab: DashboardTab = .readiness
    private let chartHeight: CGFloat = 250

    var body: some View {
        VStack {
            // Menu
            HStack {
                ForEach(DashboardTab.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack {
                            Text(tab.rawValue)
                                .font(.footnote) 
                                .fontWeight(selectedTab == tab ? .bold : .regular)
                                .foregroundColor(selectedTab == tab ? .primary : .gray)
                            
                            // Underline for the selected tab
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedTab == tab ? .blue : .clear)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
            
            Divider()
            
            // Content based on selected tab
            switch selectedTab {
            case .readiness:
                ReadinessContentView(viewModel: viewModel, chartHeight: chartHeight)
            case .workouts:
                WorkoutsView(viewModel: viewModel)
            case .hrv:
                HRVView(viewModel: viewModel)
            case .sleep:
                SleepView(viewModel: viewModel)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            Task {
                await viewModel.fetchReadinessScores()
                if viewModel.pressedReadinessScore {
                    await viewModel.initializeData()
                    viewModel.pressedReadinessScore = false
                } else {
                    await viewModel.initializeData()
                }
            }
        }
    }
}
