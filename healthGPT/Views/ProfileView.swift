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

    func logout() async {
        do {
            let session = SupabaseManager.shared.client.auth.session

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
    // Function to fetch user info from Supabase
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
    
 

