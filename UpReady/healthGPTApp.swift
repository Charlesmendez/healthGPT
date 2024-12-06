//
//  healthGPTApp.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//

import SwiftUI
import Supabase
import StoreKit

enum AppViewState {
  case auth
  case main
  case resetPassword(url: URL)
  case paywall
}

@main
struct healthGPTApp: App {
  @StateObject private var viewModel = SleepViewModel()
  @StateObject private var transactionListener = TransactionListener()
  @State private var isLoggedIn: Bool = false
  @State private var currentView: AppViewState = .auth
  @Environment(\.scenePhase) private var scenePhase

  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      Group {
        switch currentView {
        case .main:
          MainTabView(isLoggedIn: $isLoggedIn, onLogout: {
            Task {
              await handleLogout()
            }
          })
          .environmentObject(viewModel)
          .onAppear {
            appDelegate.viewModel = viewModel
            Task {
              await checkSession()
              await viewModel.initializeData()
            }
          }
          .onOpenURL { url in handleURL(url) }

        case .auth:
          AuthView(onLogin: {
            Task {
              await validateSubscription()
            }
          })
          .onAppear {
            appDelegate.viewModel = viewModel
          }
          .onOpenURL { url in handleURL(url) }

        case .resetPassword(let url):
          ResetPasswordView(url: url) {
            self.currentView = .auth
          }
          .onAppear {
            appDelegate.viewModel = viewModel
          }

        case .paywall:
          PaywallView(
            onRestore: {
              Task {
                await restorePurchase()
              }
            },
            onComplete: {
              self.currentView = .main
            },
            onBackToSignIn: {
              self.currentView = .auth
            }
          )
        }
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        Task {
          transactionListener.startListening() // Start listening for transaction updates
          await checkSession()
          await viewModel.initializeData()
        }
      }
    }
  }

  @MainActor
  private func checkSession() async {
    do {
      let session = try await SupabaseManager.shared.client.auth.session
      self.isLoggedIn = true
      await validateSubscription()
    } catch {
        print("Failed to restore session: \(error.localizedDescription)")
      self.isLoggedIn = false
      self.currentView = .auth
    }
  }

  @MainActor
  private func validateSubscription() async {
      print("Validating subscription...")
    let hasValidSubscription = await SubscriptionManager.shared.isSubscriptionValid()
    if hasValidSubscription {
        print("Subscription is valid.Redirecting to main.")
      self.currentView = .main
    } else {
        print("Subscription is invalid.Redirecting to paywall.")
      self.currentView = .paywall
    }
  }

  @MainActor
  private func restorePurchase() async {
    do {
      try await SubscriptionManager.shared.restorePurchase()
      await validateSubscription()
    } catch {
        print("Failed to restore purchases: \(error.localizedDescription)")
      // Optionally, present an alert to the user
    }
  }

  @MainActor
  private func handleLogout() async {
    isLoggedIn = false
    self.currentView = .auth
    await validateSubscription()
  }

  private func handleURL(_ url: URL) {
      if url.host == "reset-password" {
      self.currentView = .resetPassword(url: url)
    }
  }
}
