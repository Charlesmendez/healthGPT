//
//  ChartContainer.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/29/24.
//

// ChartContainer.swift

import SwiftUI
import Charts

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
                        // LineMark to draw the line
                        LineMark(
                            x: .value("Date", calendar.startOfDay(for: item.date)),
                            y: .value("Score", item.score)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 4))
                        .foregroundStyle(.green)

                        // PointMark for each data point
                        PointMark(
                            x: .value("Date", calendar.startOfDay(for: item.date)),
                            y: .value("Score", item.score)
                        )
                        .symbolSize(8)
                        .foregroundStyle(.white)
                        // Adding annotation (data label) to each PointMark
                        .annotation(position: .top, alignment: .center) {
                            Text("\(Int(item.score))")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
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
                    plot.background(Color.black) // Changed to black for contrast
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
        formatter.dateFormat = "d" // Only display the day of the month
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
