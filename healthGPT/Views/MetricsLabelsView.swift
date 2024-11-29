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

    @State private var isTooltipVisible = false
    @State private var tooltipText = ""

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                let radius: CGFloat = 140 // Adjust as needed

                ZStack {
                    // Readiness Label
                    MetricLabelWithInfo(
                        text: "Readiness",
                        value: readiness,
                        color: .green,
                        isTooltipVisible: $isTooltipVisible,
                        tooltipText: $tooltipText,
                        tooltipContent: """
                        We pass all your health metrics to our AI model, which analyzes your health comprehensively and provides a Readiness score ranging from 1 to 10.
                        """
                    )
                    .position(x: centerX, y: centerY - radius)
                    .padding(.top, -10)

                    // Sleep Label
                    MetricLabelWithInfo(
                        text: "Sleep",
                        value: sleep,
                        color: .purple,
                        isTooltipVisible: $isTooltipVisible,
                        tooltipText: $tooltipText,
                        tooltipContent: """
                         Measures your rest quality and duration (Sleep and Deep Sleep) essential for recovery and performance.
                        """
                    )
                    .position(x: centerX + radius, y: centerY)

                    // HRV Label
                    MetricLabelWithInfo(
                        text: "HRV",
                        value: hrv,
                        color: .blue,
                        isTooltipVisible: $isTooltipVisible,
                        tooltipText: $tooltipText,
                        tooltipContent: """
                        **HRV** (Heart Rate Variability) is an indicator of your recovery and readiness for activity. A low indicator might indicate Stress or a less resilient body.
                        """
                    )
                    .position(x: centerX, y: centerY + radius)
                    .padding(.top, 10)

                    // Load Label
                    MetricLabelWithInfo(
                        text: "Load",
                        value: load,
                        color: .orange,
                        isTooltipVisible: $isTooltipVisible,
                        tooltipText: $tooltipText,
                        tooltipContent: """
                        Represents your total training effort over the past week, combining cardiovascular and muscular activities. It shows the stress your workouts place on your body, helping you gauge exercise intensity and volume. 
                        """
                    )
                    .position(x: centerX - radius, y: centerY)
                    
                }
                .frame(height: 300)
            }
            // Overlay the Tooltip
            .overlayPreferenceValue(TooltipPositionPreferenceKey.self) { position in
                GeometryReader { proxy in
                    if isTooltipVisible, let position = position {
                        TooltipView(text: tooltipText)
                            .frame(maxWidth: 250)
                            .fixedSize()
                            .position(x: position.x, y: position.y - 20) // Adjust y-offset as needed
                            .onTapGesture {
                                withAnimation {
                                    isTooltipVisible = false
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
