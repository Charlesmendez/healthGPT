import SwiftUI
import Charts

struct ReadinessChartView: View {
    @State private var readinessScores: [ReadinessScoreEntry] = []
    @State private var selectedFilter: FilterType = .week

    enum FilterType: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var id: String { self.rawValue }
    }

    var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone(secondsFromGMT: 0)! // Use UTC
        return cal
    }

    var body: some View {
        VStack {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(FilterType.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            if #available(iOS 16.0, *) {
                if filteredScores.isEmpty {
                    Text("No data available for the selected period.")
                        .padding()
                } else {
                    Chart {
                        ForEach(filteredScores) { score in
                            let scoreDay = calendar.startOfDay(for: score.date)
                            BarMark(
                                x: .value("Date", scoreDay),
                                y: .value("Score", score.score)
                            )
                            .foregroundStyle(.blue)
                            .symbol(by: .value("Date", scoreDay)) // Ensures date grouping works
                            .annotation(position: .top) { // Optional annotation to label each bar
                                Text("\(score.score)")
                                    .font(.caption)
                            }

                            PointMark(
                                x: .value("Date", scoreDay),
                                y: .value("Score", score.score)
                            )
                            .foregroundStyle(.red)
                            .symbolSize(100)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisValueLabel(format: .dateTime.day().month())
                        }
                    }
                    .chartXAxisLabel("Date")
                    .chartYAxisLabel("Readiness Score")
                    .chartYScale(domain: 0...100) // Ensure Y scale covers possible scores
                    .chartXScale(domain: xAxisDomain()) // Ensure X scale covers the date range
                    .padding()
                }
            } else {
                Text("Charts are only available on iOS 16 and above.")
            }
        }
        .onAppear {
            Task {
                await fetchReadinessScores()
            }
        }
    }

    func xAxisDomain() -> ClosedRange<Date> {
        guard let firstDate = filteredScores.first?.date,
              let lastDate = filteredScores.last?.date else {
            return Date()...Date()
        }
        let lowerBound = calendar.startOfDay(for: firstDate)
        let upperBound = calendar.startOfDay(for: lastDate).addingTimeInterval(24 * 60 * 60) // Add one day
        return lowerBound...upperBound
    }

    var filteredScores: [ReadinessScoreEntry] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)! // Use UTC
        let now = Date()
        let today = calendar.startOfDay(for: now)

        switch selectedFilter {
        case .day:
            return readinessScores.filter {
                let scoreDay = calendar.startOfDay(for: $0.date)
                return scoreDay == today
            }
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }
            return readinessScores.filter {
                let scoreDay = calendar.startOfDay(for: $0.date)
                return scoreDay >= weekAgo && scoreDay <= today
            }
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: today) else { return [] }
            return readinessScores.filter {
                let scoreDay = calendar.startOfDay(for: $0.date)
                return scoreDay >= monthAgo && scoreDay <= today
            }
        }
    }

    func fetchReadinessScores() async {
        do {
            let scores = try await SupabaseManager.shared.fetchReadinessScores()
            DispatchQueue.main.async {
                self.readinessScores = scores
                print("Fetched scores:")
                for score in scores {
                    print("ID: \(score.id ?? UUID()), Date: \(score.date), Score: \(score.score)")
                }
            }
        } catch {
            print("Error fetching readiness scores: \(error)")
        }
    }
}
