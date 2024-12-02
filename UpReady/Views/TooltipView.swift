//
//  TooltipView.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct TooltipView: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(LocalizedStringKey(text))
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding()
                .frame(maxWidth: 250)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 5)

            // Triangle Pointer
            Triangle()
                .fill(Color(.systemBackground))
                .frame(width: 20, height: 10)
                .rotationEffect(.degrees(180))
                .offset(y: -1)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))      // Bottom center
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))   // Top left
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))   // Top right
        path.closeSubpath()
        return path
    }
}
