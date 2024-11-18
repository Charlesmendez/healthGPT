//
//  CircularProgressView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let radius: CGFloat
    
    var body: some View {
        Circle()
            .stroke(color.opacity(0.2), lineWidth: lineWidth)
            .overlay(
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(color, style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    ))
                    .rotationEffect(.degrees(-90))
            )
            .frame(width: radius * 2, height: radius * 2)
    }
} 
