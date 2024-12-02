//
//  MetricsLabel.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct MetricLabel: View {
    let text: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text("\(Int(value * 100))%")
                .font(.headline)
                .bold()
                .foregroundColor(color)

            Text(text)
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(width: 100) // Ensure consistent width
    }
}
