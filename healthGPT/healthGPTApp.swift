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
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            switch currentView {
            case .main:
                MainTabView(isLoggedIn: $isLoggedIn, onLogout: {
                    self.currentView = .auth
                })
                .environmentObject(viewModel)
                .onAppear {
                    appDelegate.viewModel = viewModel // Assign ViewModel to AppDelegate
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
                .onAppear {
                    appDelegate.viewModel = viewModel // Assign ViewModel to AppDelegate
                }
                .onOpenURL { url in
                    handleURL(url)
                }

            case .resetPassword(let url):
                ResetPasswordView(url: url) {
                    self.currentView = .auth // Redirect to the login screen after password reset
                }
                .onAppear {
                    appDelegate.viewModel = viewModel // Assign ViewModel to AppDelegate
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await checkSession()
                    await viewModel.initializeData()
                }
            }
        }
    }

    private func checkSession() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            self.isLoggedIn = true
        } catch {
            self.isLoggedIn = false
        }
    }

    private func handleURL(_ url: URL) {
        if url.host == "reset-password" {
            self.currentView = .resetPassword(url: url)
        }
    }
}
