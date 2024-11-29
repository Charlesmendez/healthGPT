//
//  ReadinessContentView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/29/24.
//

import SwiftUI


struct ReadinessContentView: View {
    @ObservedObject var viewModel: SleepViewModel
    let chartHeight: CGFloat
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                ChartContainer(
                    title: "Weekly Readiness",
                    data: weeklyScores,
                    height: chartHeight
                )
                ChartContainer(
                    title: "Monthly Readiness",
                    data: monthlyScores,
                    height: chartHeight
                )
            }
            .padding(.bottom)
        }
    }
    
    // Updated weeklyScores and monthlyScores
    private var weeklyScores: [ReadinessScoreEntry] {
        filterScoresForCurrentWeek()
    }
    
    private var monthlyScores: [ReadinessScoreEntry] {
        filterScoresForCurrentMonth()
    }
    
    private func filterScoresForCurrentWeek() -> [ReadinessScoreEntry] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return viewModel.readinessScores.filter {
            $0.date >= weekInterval.start && $0.date < weekInterval.end
        }
        .sorted(by: { $0.date < $1.date })
    }
    
    private func filterScoresForCurrentMonth() -> [ReadinessScoreEntry] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else {
            return []
        }
        return viewModel.readinessScores.filter {
            $0.date >= monthInterval.start && $0.date < monthInterval.end
        }
        .sorted(by: { $0.date < $1.date })
    }
}
