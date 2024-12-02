//
//  MetricLabelWithInfo.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct MetricLabelWithInfo: View {
    let text: String
    let value: Double
    let color: Color
    @Binding var isTooltipVisible: Bool
    @Binding var tooltipText: String
    let tooltipContent: String // Tooltip content specific to this label

    var body: some View {
        VStack(spacing: 5) {
            // Info Icon at the Top
            Button(action: {
                withAnimation {
                    tooltipText = tooltipContent // Update the tooltip text
                    isTooltipVisible.toggle()
                }
            }) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(color)
                    .font(.headline)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: TooltipPositionPreferenceKey.self, value: proxy.frame(in: .global).center)
                        }
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Percentage Text
            Text("\(Int(value * 100))%")
                .font(.headline)
                .bold()
                .foregroundColor(color)

            // Label Text
            Text(text)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(width: 100) // Ensure consistent width
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
