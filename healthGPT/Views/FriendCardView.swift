////
////  FriendCardView.swift
////  healthGPT
////
////  Created by Carlos Fernando Mendez Solano on 11/18/24.
////
//
//import SwiftUI
//
//struct FriendCardView: View {
//    let friendScore: FriendReadinessScore
//
//    var readinessProgress: Double {
//        return Double(friendScore.score) / 100.0
//    }
//
//    var loadProgress: Double {
//        return friendScore.load ?? 0.0
//    }
//
//    var body: some View {
//        VStack(spacing: 12) {
//            Text(friendScore.displayName)
//                .font(.headline)
//                .foregroundColor(.primary)
//
//            ZStack {
//                // Outer Circle - Load
//                CircularProgressView(
//                    progress: loadProgress,
//                    color: .orange,
//                    lineWidth: 8,
//                    radius: 50
//                )
//
//                // Inner Circle - Readiness
//                CircularProgressView(
//                    progress: readinessProgress,
//                    color: .green,
//                    lineWidth: 8,
//                    radius: 35
//                )
//
//                // Center Icon
//                Image(systemName: "person.circle.fill")
//                    .resizable()
//                    .frame(width: 40, height: 40)
//                    .foregroundColor(.blue)
//            }
//            .padding(.bottom, 8)
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 15)
//                .fill(Color(.systemBackground))
//                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
//        )
//        .padding([.leading, .trailing], 4)
//    }
//}
