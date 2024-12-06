import Supabase
import Foundation


class SupabaseService {
    
    func signIn(email: String, password: String) async throws {
        try await SupabaseManager.shared.client.auth.signIn(
            email: email,
            password: password
        )
    }
    
    func signUp(email: String, password: String) async throws {
        try await SupabaseManager.shared.client.auth.signUp(
            email: email,
            password: password
        )
    }
    
    func signInWithApple(idToken: String) async throws {
        try await SupabaseManager.shared.client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken
            )
        )
    }
    

}
