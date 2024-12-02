//
//  CircularProgressView.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct CircularProgressView: View {
    var progress: Double // Value between 0 and 1
    var color: Color
    var lineWidth: CGFloat
    var radius: CGFloat

    var body: some View {
        Circle()
            .stroke(color.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: radius * 2, height: radius * 2)
            .overlay(
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.linear, value: progress)
                    .frame(width: radius * 2, height: radius * 2)
            )
    }
}
