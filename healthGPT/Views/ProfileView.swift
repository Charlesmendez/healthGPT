//
//  ProfileView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    let onLogout: () -> Void
    @State private var userName: String = "Unknown"
    @State private var userEmail: String = "Unknown"
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    // State variable for presenting the delete confirmation alert
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(spacing: 20) {
            // User Info Section
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

            // Delete Account Button
            Button(action: {
                showingDeleteAlert = true
            }) {
                Text("Delete Account")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.7))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Account"),
                    message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        Task {
                            await deleteAccount()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }

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

    /// Handles the logout process
    func logout() async {
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            DispatchQueue.main.async {
                isLoggedIn = false
                onLogout() // Transition to auth view
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Error signing out: \(error.localizedDescription)"
            }
        }
    }

    /// Handles the account deletion process
    func deleteAccount() async {
        do {
            // Start loading
            DispatchQueue.main.async {
                isLoading = true
                errorMessage = nil
            }

            // Call the deleteUser function from SupabaseManager
            try await SupabaseManager.shared.deleteUser()
            
            // Sign out the user after successful deletion
            try await SupabaseManager.shared.client.auth.signOut()
            
            // Update UI on the main thread
            DispatchQueue.main.async {
                isLoggedIn = false
                onLogout()
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Error deleting account: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    /// Fetches user information from Supabase
    func fetchUserInfo() {
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.refreshSession()
                let user = session.user

                DispatchQueue.main.async {
                    userEmail = user.email ?? "No Email"
                    let userMetadata = user.userMetadata
                    if let name = userMetadata["name"]?.value as? String {
                        userName = name
                    } else {
                        userName = "No Name"
                    }
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error fetching user info: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
