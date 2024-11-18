//
//  healthGPTApp.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//

import SwiftUI


@main
struct healthGPTApp: App {
    @StateObject private var viewModel = SleepViewModel()
    @State private var isLoggedIn = false // Tracks login state
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                MainTabView(isLoggedIn: $isLoggedIn)
                    .environmentObject(viewModel) // Inject the environment object here
                    .onAppear {
                        Task {
                            await viewModel.initializeData()
                        }
                    }
            } else {
                AuthView(onLogin: {
                    isLoggedIn = true
                })
            }
        }
        .onChange(of: scenePhase) { newPhase, _ in
            if newPhase == .active {
                Task {
                    await viewModel.initializeData()
                }
            }
        }
    }
}
