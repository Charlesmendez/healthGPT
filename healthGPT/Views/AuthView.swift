import SwiftUI
import AuthenticationServices
import GoogleSignIn
import Supabase

struct AuthView: View {
    @State private var showSignUp = false
    @State private var email = ""
    @State private var password = ""
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize // Adapts to accessibility text size
    var onLogin: () -> Void // Callback for successful login
    private let client = SupabaseService.shared.client // Access the shared Supabase client

    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                // Adaptive image size based on text size and color scheme
                Image("up")
                    .resizable()
                    .scaledToFit()
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 200 : 250, // Increased sizes
                           height: dynamicTypeSize.isAccessibilitySize ? 200 : 250)
                    .padding(.top, 40)
                
                Text(showSignUp ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black) // Adjust for Dark Mode

                VStack(spacing: 20) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                .padding(.horizontal)

                Button(action: {
                    showSignUp ? handleSignUp() : handleSignIn()
                }) {
                    Text(showSignUp ? "Sign Up" : "Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Text("Or continue with")
                    .foregroundColor(colorScheme == .dark ? .gray : .black.opacity(0.6)) // Adjust for Dark Mode

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
                    .cornerRadius(8) // Ensures consistent corner rounding

                    SocialButton(image: "google.logo", text: "Google") {
                        handleGoogleSignIn()
                    }
                }

                Button(action: { showSignUp.toggle() }) {
                    Text(showSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                        .font(.body)
                }
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white) // Background color for Dark Mode
            .edgesIgnoringSafeArea(.all) // Extends the background to edges
        }
    }

    private func handleSignIn() {
        Task {
            do {
                try await client.auth.signIn(email: email, password: password)
                onLogin() // Notify successful login
            } catch {
                print("Sign In failed:", error)
            }
        }
    }

    private func handleSignUp() {
        Task {
            do {
                try await client.auth.signUp(email: email, password: password)
                onLogin() // Notify successful signup
            } catch {
                print("Sign Up failed:", error)
            }
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

    private func handleGoogleSignIn() {
        // Implement Google sign-in logic
        print("Google sign-in logic goes here")
        onLogin()
    }
}


// Preview Provider for AuthView
struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthView(onLogin: {})
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            AuthView(onLogin: {})
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
