//
//  ProfileView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    @State private var userName: String = "Unknown"
    @State private var userEmail: String = "Unknown"
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // User Info
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Name:")
                        .font(.headline)
                    Spacer()
                    Text(userName)
                        .font(.body)
                }

                HStack {
                    Text("Email:")
                        .font(.headline)
                    Spacer()
                    Text(userEmail)
                        .font(.body)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding()

            // Logout Button
            Button(action: {
                Task {
                    await logout()
                }
            }) {
                Text("Logout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            // Loading Indicator or Error Message
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationBarTitle("Profile", displayMode: .inline)
        .onAppear {
            fetchUserInfo()
        }
    }

    // Function to fetch user info from Supabase
    func fetchUserInfo() {
        let user = SupabaseService.shared.client.auth.currentUser
        if let user = user {
            userEmail = user.email ?? "No Email"

            if let userMetadata = user.userMetadata as? [String: Any] {
                userName = userMetadata["name"] as? String ?? "No Name"
            } else {
                userName = "No Name"
            }
        } else {
            userEmail = "No Email"
            userName = "No Name"
        }
        isLoading = false
    }

    // Function to logout
    func logout() async {
        do {
            try await SupabaseService.shared.client.auth.signOut()
            DispatchQueue.main.async {
                isLoggedIn = false
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Error signing out: \(error.localizedDescription)"
            }
            print("Error signing out: \(error)")
        }
    }
}
