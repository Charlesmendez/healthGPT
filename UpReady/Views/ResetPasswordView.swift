//
//  ResetPasswordView.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/18/24.
//
import SwiftUI
import Supabase

struct ResetPasswordView: View {
    let url: URL
    let onComplete: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 25) {
            Text("Reset Your Password")
                .font(.largeTitle)
                .fontWeight(.bold)

            SecureField("New Password", text: $newPassword)
                .textFieldStyle(RoundedTextFieldStyle())
                .padding(.horizontal)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(RoundedTextFieldStyle())
                .padding(.horizontal)

            Button(action: resetPassword) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Reset Password")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(isLoading || newPassword.isEmpty || confirmPassword.isEmpty)
            .padding(.horizontal)

            // Back to Sign In button
            Button(action: {
                onComplete() // Navigate back to sign-in screen
            }) {
                Text("Back to Sign In")
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding()
            }

            Spacer()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Notification"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertMessage == "Password reset successful!" {
                        onComplete()
                    }
                }
            )
        }
        .onAppear {
            authenticateUser()
        }
    }

    private func authenticateUser() {
            isLoading = true
            Task {
                do {
                    // Establish a session using the recovery URL
                    try await SupabaseManager.shared.client.auth.session(from: url)
                } catch {
                    alertMessage = "Failed to verify reset token. Please try again."
                    showAlert = true
                }
                isLoading = false
            }
        }

    private func resetPassword() {
        guard newPassword == confirmPassword else {
            alertMessage = "Passwords do not match."
            showAlert = true
            return
        }

        isLoading = true
        Task {
            do {
                // Update the user's password
                try await SupabaseManager.shared.client.auth.update(user: UserAttributes(password: newPassword))
                alertMessage = "Password reset successful!"
                showAlert = true
            } catch {
                alertMessage = "Password reset failed: \(error.localizedDescription)"
                showAlert = true
            }
            isLoading = false
        }
    }
}
