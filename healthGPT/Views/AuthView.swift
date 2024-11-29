import SwiftUI
import AuthenticationServices
import Supabase
import Foundation

struct AuthView: View {
    @State private var showSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var infoMessage: String?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    var onLogin: () -> Void
    private let client = SupabaseManager.shared.client

    var body: some View {
            NavigationView {
                VStack(spacing: 25) {
                    Image("up")
                        .resizable()
                        .scaledToFit()
                        .frame(width: dynamicTypeSize.isAccessibilitySize ? 200 : 250,
                               height: dynamicTypeSize.isAccessibilitySize ? 200 : 250)
                        .padding(.top, 40)

                    Text(showSignUp ? "Create Account" : "Welcome Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? .white : .black)

                    VStack(spacing: 20) {
                        if showSignUp {
                            TextField("Name", text: $name)
                                .textFieldStyle(RoundedTextFieldStyle())
                        }

                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)

                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedTextFieldStyle())
                    }
                    .padding(.horizontal)

                    Button(action: {
                        if showSignUp {
                            guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
                                alertMessage = "Please fill out all fields."
                                showAlert = true
                                return
                            }
                            handleSignUp()
                        } else {
                            guard !email.isEmpty, !password.isEmpty else {
                                alertMessage = "Please enter both email and password."
                                showAlert = true
                                return
                            }
                            handleSignIn()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(showSignUp ? "Sign Up" : "Sign In")
                                .opacity(isLoading ? 0.5 : 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)

                    Button(action: {
                        handleForgotPassword()
                    }) {
                        Text("Forgot Password?")
                            .foregroundColor(.blue)
                            .font(.body)
                    }
                    .padding(.horizontal)

                    Text("Or continue with")
                        .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.6))

                    HStack(spacing: 20) {
                        SignInWithAppleButton(
                            onRequest: { request in
                                request.requestedScopes = [.email, .fullName]
                            },
                            onCompletion: handleAppleSignIn
                        )
                        .signInWithAppleButtonStyle(
                            colorScheme == .dark ? .white : .black
                        )
                        .frame(height: 50)
                        .cornerRadius(8)
                    }

                    Button(action: { showSignUp.toggle() }) {
                        Text(showSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                            .font(.body)
                    }
                }
                .onAppear {
                    // Reset to Sign In view whenever AuthView appears
                    showSignUp = false
                }
                .padding()
                .background(colorScheme == .dark ? Color.black : Color.white)
                .edgesIgnoringSafeArea(.all)
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Notification"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }

    private func handleSignIn() {
        Task {
            do {
                try await client.auth.signIn(email: email, password: password)
                print("Session Token:", client.auth.session.accessToken ?? "No token")
                onLogin()
            } catch {
                print("Sign In failed:", error.localizedDescription)
                if let message = parseError(error) {
                    alertMessage = message
                } else {
                    alertMessage = "Sign In failed: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
    
    private func handleSignUp() {
        Task {
            do {
                let response = try await SupabaseManager.shared.client.auth.signUp(
                    email: email,
                    password: password,
                    data: ["name": AnyJSON(name)] // Wrap the name as AnyJSON
                )
                if let session = response.session {
                    onLogin()
                } else {
                    alertMessage = "Sign-up successful. Please check your email to confirm your account."
                    showAlert = true
                }
            } catch {
                if let message = parseError(error) {
                    alertMessage = message
                } else {
                    alertMessage = "Sign Up failed: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
    
    private func parseError(_ error: Error) -> String? {
        // Attempt to parse JSON from the error description
        if let data = error.localizedDescription.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = json as? [String: Any],
           let message = dict["message"] as? String {
            return message // Return detailed error message from JSON
        }

        // Return nil if parsing fails
        return nil
    }
    
    private func handleForgotPassword() {
        let alert = UIAlertController(
            title: "Reset Password",
            message: "Enter your email to reset your password.",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Email"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
        }

        let sendAction = UIAlertAction(title: "Send", style: .default) { _ in
            if let email = alert.textFields?.first?.text, !email.isEmpty {
                Task {
                    do {
                        // Request a password reset email
                        try await SupabaseManager.shared.client.auth.resetPasswordForEmail(
                            email,
                            redirectTo: URL(string: "healthgpt://reset-password")! // Replace with your app's redirect URL
                        )
                        alertMessage = "Password reset email sent. Check your inbox!"
                        showAlert = true
                    } catch {
                        alertMessage = "Failed to send password reset email: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            } else {
                alertMessage = "Please enter a valid email address."
                showAlert = true
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(sendAction)
        alert.addAction(cancelAction)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = keyWindow.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

        private func sendPasswordReset(email: String) async {
            do {
                try await client.auth.resetPasswordForEmail(email)
                alertMessage = "Password reset email sent. Check your inbox!"
                showAlert = true
            } catch {
                alertMessage = "Failed to send password reset email: \(error.localizedDescription)"
                showAlert = true
            }
        }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        Task {
            do {
                guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential else {
                    return
                }

                guard let idToken = credential.identityToken
                    .flatMap({ String(data: $0, encoding: .utf8) })
                else {
                    return
                }

                // Sign in to Supabase with the ID token from Apple
                try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken
                    )
                )

                onLogin() // Trigger successful login action
            } catch {
                print("Apple Sign-In failed:", error)
            }
        }
    }

}


// Preview Provider for AuthView
//struct AuthView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            AuthView(onLogin: {})
//                .preferredColorScheme(.light)
//                .previewDisplayName("Light Mode")
//
//            AuthView(onLogin: {})
//                .preferredColorScheme(.dark)
//                .previewDisplayName("Dark Mode")
//        }
//    }
//}
