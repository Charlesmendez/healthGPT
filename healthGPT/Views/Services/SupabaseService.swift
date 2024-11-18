import Supabase
import Foundation


import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    let client: SupabaseClient

    private init() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
              let supabaseURLString = dict["supabaseURL"] as? String,
              let supabaseKey = dict["Supabase"] as? String,
              let supabaseURL = URL(string: supabaseURLString) else {
            fatalError("Supabase configuration is missing or invalid.")
        }

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }

    
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }
    
    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password
        )
    }
    
    func signInWithApple(idToken: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken
            )
        )
    }
    
    func signInWithGoogle(idToken: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken
            )
        )
    }
}
