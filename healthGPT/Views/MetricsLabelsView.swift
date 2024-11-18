//
//  MetricsLabelsView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct MetricsLabelsView: View {
    let readiness: Double
    let sleep: Double
    let hrv: Double
    let load: Double

    @State private var isLoadTooltipVisible = false

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                let radius: CGFloat = 140 // Adjust as needed

                ZStack {
                    // Readiness Label
                    MetricLabel(
                        text: "Readiness",
                        value: readiness,
                        color: .green
                    )
                    .position(x: centerX, y: centerY - radius)

                    // Sleep Label
                    MetricLabel(
                        text: "Sleep",
                        value: sleep,
                        color: .purple
                    )
                    .position(x: centerX + radius, y: centerY)

                    // HRV Label
                    MetricLabel(
                        text: "HRV",
                        value: hrv,
                        color: .blue
                    )
                    .position(x: centerX, y: centerY + radius)

                    // Load Label with Info Icon and Tooltip
                    MetricLabelWithInfo(
                        text: "Load",
                        value: load,
                        color: .orange,
                        isTooltipVisible: $isLoadTooltipVisible
                    )
                    .position(x: centerX - radius, y: centerY)
                }
                .frame(height: 300)
            }
            // Overlay the Tooltip using the PreferenceKey
            .overlayPreferenceValue(TooltipPositionPreferenceKey.self) { position in
                GeometryReader { proxy in
                    if isLoadTooltipVisible, let position = position {
                        TooltipView(text: """
                        **Load** is a comprehensive measure of your total training effort over the past week, combining both cardiovascular and muscular activities. It reflects the cumulative stress you've placed on your body through workouts, helping you understand your exercise intensity and volume. By tracking your Load, you can ensure you're training at an optimal level—not too little and not too much—to improve fitness, enhance performance, and reduce the risk of overtraining or injury. This metric empowers you to balance your exercise and recovery periods effectively for better overall health.
                        """)
                        .frame(maxWidth: 250)
                        .fixedSize()
                        .position(x: position.x, y: position.y - 20) // Adjust y-offset as needed
                        .onTapGesture {
                            withAnimation {
                                isLoadTooltipVisible = false
                            }
                        }
                        .zIndex(1) // Bring the tooltip to the front
                    }
                }
            }
        }
        .frame(height: 300) // Adjust the frame height as needed
    }
}
