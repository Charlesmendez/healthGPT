import SwiftUI
import Charts

struct ReadinessChartView: View {
    @EnvironmentObject var viewModel: SleepViewModel
    private let chartHeight: CGFloat = 250

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Existing Charts
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

                // Workout Cards
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
            .padding()
        }
    }

    private var weeklyScores: [ReadinessScoreEntry] {
        filterScores(byDays: 7)
    }

    private var monthlyScores: [ReadinessScoreEntry] {
        filterScores(byDays: 30)
    }

    private func filterScores(byDays days: Int) -> [ReadinessScoreEntry] {
        let now = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }
        return viewModel.readinessScores.filter {
            let scoreDay = calendar.startOfDay(for: $0.date)
            return scoreDay >= startDate && scoreDay <= now
        }
        .sorted(by: { $0.date < $1.date })
    }

    private var calendar: Calendar {
        Calendar.current
    }
}

struct ChartContainer: View {
    let title: String
    let data: [ReadinessScoreEntry]
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if data.isEmpty {
                Text("No data available for this period.")
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.top, 50)
            } else {
                Chart {
                    ForEach(data) { item in
                        LineMark(
                            x: .value("Date", calendar.startOfDay(for: item.date)),
                            y: .value("Score", item.score)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 4))
                        .foregroundStyle(.white)

                        PointMark(
                            x: .value("Date", calendar.startOfDay(for: item.date)),
                            y: .value("Score", item.score)
                        )
                        .symbolSize(8)
                        .foregroundStyle(.white)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(shortDateFormatter.string(from: date))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .chartXScale(domain: xAxisDomain(data: data))
                .chartYAxis {
                    AxisMarks { value in
                        AxisTick()
                        AxisValueLabel {
                            if let score = value.as(Double.self) {
                                Text("\(Int(score))")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(.clear)
                }
                .frame(height: height)
            }
        }
        .padding()
        .background(Color.black)
        .cornerRadius(8)
    }

    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    private func xAxisDomain(data: [ReadinessScoreEntry]) -> ClosedRange<Date> {
        guard let firstDate = data.first?.date,
              let lastDate = data.last?.date else {
            return Date()...Date()
        }
        let lowerBound = calendar.startOfDay(for: firstDate)
        let upperBound = calendar.startOfDay(for: lastDate).addingTimeInterval(24 * 60 * 60)
        return lowerBound...upperBound
    }

    private var calendar: Calendar {
        Calendar.current
    }
}
