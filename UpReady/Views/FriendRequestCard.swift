////
////  FriendRequestCard.swift
////  UpReady
////
////  Created by Carlos Fernando Mendez Solano on 11/18/24.
////
//
//import SwiftUI
//
//@MainActor // Add this line
//struct FriendRequestCard: View {
//    @EnvironmentObject var viewModel: SleepViewModel
//    let request: FriendRequest
//
//    var body: some View {
//        HStack {
//            Text("Friend Request from \(request.requesterDisplayName)")
//                .font(.subheadline)
//                .foregroundColor(.primary)
//
//            Spacer()
//
//            Button(action: {
//                Task {
//                    await viewModel.respondToFriendRequest(requestID: request.id!, accept: true)
//                }
//            }) {
//                Text("Accept")
//                    .foregroundColor(.green)
//            }
//            .buttonStyle(BorderlessButtonStyle())
//
//            Button(action: {
//                Task {
//                    await viewModel.respondToFriendRequest(requestID: request.id!, accept: false)
//                }
//            }) {
//                Text("Reject")
//                    .foregroundColor(.red)
//            }
//            .buttonStyle(BorderlessButtonStyle())
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 15)
//                .fill(Color(.secondarySystemBackground))
//        )
//    }
//}
