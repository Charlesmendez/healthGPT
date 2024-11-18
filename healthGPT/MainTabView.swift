//
//  MainTabView.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 11/16/24.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: SleepViewModel
    @Binding var isLoggedIn: Bool

    var body: some View {
        TabView {
            // Home Tab
            NavigationView {
                ContentView() // No parameters
                    .navigationBarTitle("Home", displayMode: .inline)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }

            // Readiness Tab
            NavigationView {
                ReadinessChartView()
                    .navigationBarTitle("Readiness", displayMode: .inline)
            }
            .tabItem {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                Text("Readiness")
            }

            // Friends Tab
            NavigationView {
                FriendsView()
            }
            .tabItem {
                Image(systemName: "person.2.fill")
                Text("Friends")
            }

            // Profile Tab
            NavigationView {
                ProfileView(isLoggedIn: $isLoggedIn)
            }
            .tabItem {
                Image(systemName: "person.crop.circle.fill")
                Text("Profile")
            }
        }
    }
}
