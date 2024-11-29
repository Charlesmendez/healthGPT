//
//  healthGPTApp.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//

import SwiftUI
import Supabase

enum AppViewState {
    case auth
    case main
    case resetPassword(url: URL)
}

@main
struct healthGPTApp: App {
    @StateObject private var viewModel = SleepViewModel()
    @State private var isLoggedIn: Bool = false
    @State private var currentView: AppViewState = .auth
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            switch currentView {
            case .main:
                MainTabView(isLoggedIn: $isLoggedIn, onLogout: {
                    self.currentView = .auth
                })
                .environmentObject(viewModel)
                .onAppear {
                    Task {
                        await checkSession()
                        await viewModel.initializeData()
                    }
                }
                .onOpenURL { url in
                    handleURL(url)
                }

            case .auth:
                AuthView(onLogin: {
                    self.currentView = .main
                })
                .onOpenURL { url in
                    handleURL(url)
                }

            case .resetPassword(let url):
                ResetPasswordView(url: url) {
                    print("Carlos3: Navigating to AuthView after password reset.")
                    self.currentView = .auth // Redirect to the login screen after password reset
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.initializeData()
                }
            }
        }
    }

    private func checkSession() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            self.isLoggedIn = true
            print("Carlos3: User is logged in: \(session.user.email ?? "No email")")
        } catch {
            self.isLoggedIn = false
            print("Carlos3: Error checking session: \(error.localizedDescription)")
        }
    }

    private func handleURL(_ url: URL) {
        print("Carlos3: Opened via URL: \(url)")
        if url.host == "reset-password" {
            print("Carlos3: Navigating to ResetPasswordView with URL: \(url).")
            self.currentView = .resetPassword(url: url)
        }
    }
}
