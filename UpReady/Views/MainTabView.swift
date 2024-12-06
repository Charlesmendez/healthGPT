//
//  MainTabView.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct MainTabView: View {
  @EnvironmentObject var viewModel: SleepViewModel
  @Binding var isLoggedIn: Bool
  let onLogout: () -> Void // Callback for handling logout

  var body: some View {
    TabView {
      // Home Tab
      NavigationView {
        ContentView()
              .navigationBarTitle("Home", displayMode: .inline)
          .onAppear {
            Task {
              await validateSubscription()
            }
          }
      }
      .tabItem {
          Image(systemName: "house.fill")
          Text("Home")
      }

      // Readiness Tab
      NavigationView {
        ReadinessChartView()
              .navigationBarTitle("Readiness", displayMode: .inline)
          .onAppear {
            Task {
              await validateSubscription()
            }
          }
      }
      .tabItem {
          Image(systemName: "chart.bar.doc.horizontal.fill")
          Text("Readiness")
      }

      // Friends Tab
      NavigationView {
        FriendsView()
          .onAppear {
            Task {
              await validateSubscription()
            }
          }
      }
      .tabItem {
          Image(systemName: "person.2.fill")
          Text("Friends")
      }

      // Profile Tab
      NavigationView {
        ProfileView(isLoggedIn: $isLoggedIn, onLogout: onLogout)
          .onAppear {
            Task {
              await validateSubscription()
            }
          }
      }
      .tabItem {
          Image(systemName: "person.crop.circle.fill")
          Text("Profile")
      }
    }
  }

  @MainActor
  private func validateSubscription() async {
    let hasValidSubscription = await SubscriptionManager.shared.isSubscriptionValid()
    if !hasValidSubscription {
      // Trigger logout to redirect to Paywall
      onLogout()
    }
  }
}
