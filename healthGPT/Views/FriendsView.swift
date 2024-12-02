
//  FriendsView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var viewModel: SleepViewModel
    @State private var emailToInvite: String = ""
    @State private var statusMessage: String? = nil
    @State private var showAlert: Bool = false

    var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    // Invite a Friend Section
                    inviteFriendSection

                    // Pending Invites Section
                    if !viewModel.pendingInvites.isEmpty {
                        pendingInvitesSection
                    }

                    // Friends Section
                    if !viewModel.friendsReadinessScores.isEmpty {
                        friendsSection
                    } else {
                        Text("No friends yet.")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding()
                .navigationBarTitle("Friends", displayMode: .inline)
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Invite Status"),
                        message: Text(statusMessage ?? "Unknown error"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .onAppear {
                Task {
                    await viewModel.fetchPendingInvites()
                    await viewModel.fetchFriends()
                    await viewModel.fetchFriendsReadinessScores()
                }
            }
        }

    // MARK: - Invite Friend Section

    private var inviteFriendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite a Friend")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 8) {
                TextField("Friend's email", text: $emailToInvite)
                    .padding(.horizontal)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                Button(action: {
                    Task {
                        do {
                            try await viewModel.sendFriendInvite(email: emailToInvite)
                            statusMessage = "Invite sent successfully!"
                            emailToInvite = ""
                        } catch {
                            statusMessage = "Error sending invite: \(error.localizedDescription)"
                        }
                        showAlert = true
                    }
                }) {
                    Text("Send")
                        .fontWeight(.semibold)
                        .frame(width: 80, height: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(emailToInvite.isEmpty)
            }
        }
    }

    // MARK: - Pending Invites Section

    private var pendingInvitesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pending Invites")
                .font(.title2)
                .fontWeight(.semibold)

            ForEach(viewModel.pendingInvites) { invite in
                HStack {
                    VStack(alignment: .leading) {
                        Text(invite.senderEmail)
                            .font(.headline)
                        Text("Sent on \(formattedDate(invite.createdAt))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    HStack {
                        Button(action: {
                            Task {
                                await viewModel.acceptInvite(invite: invite)
                                // Remove the invite from the list
                                await viewModel.fetchPendingInvites()
                            }
                        }) {
                            Text("Accept")
                                .fontWeight(.semibold)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Button(action: {
                            Task {
                                await viewModel.declineInvite(invite: invite)
                                // Remove the invite from the list
                                await viewModel.fetchPendingInvites()
                            }
                        }) {
                            Text("Decline")
                                .fontWeight(.semibold)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friends")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.friendsReadinessScores) { friendScore in
                    VStack(spacing: 16) {
                        ZStack {
                            // Load - Outer ring
                            CircularProgressView(
                                progress: min(friendScore.loadScore, 1.0),
                                color: .orange,
                                lineWidth: 10,
                                radius: 50
                            )

                            // Readiness - Inner ring
                            CircularProgressView(
                                progress: Double(friendScore.readinessScore) / 100.0,
                                color: .green,
                                lineWidth: 10,
                                radius: 35
                            )
                        }
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text("\(friendScore.readinessScore)%")
                                .font(.headline)
                                .fontWeight(.bold)
                        )

                        Text(friendScore.friend.email)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        // Subtle revoke action as a link
                        Button(action: {
                            Task {
                                await viewModel.revokeFriend(friendId: friendScore.friend.id)
                            }
                        }) {
                            Text("Revoke")
                                .font(.footnote)
                                .foregroundColor(.red)
                                .padding(.top, 2)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
