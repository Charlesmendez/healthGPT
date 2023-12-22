//
//  healthGPTApp.swift
//  healthGPT
//
//  Created by Carlos Fernando Mendez Solano on 12/20/23.
//

import SwiftUI

@main
struct healthGPTApp: App {
    // Create an instance of SleepViewModel
    @StateObject private var viewModel = SleepViewModel()

    var body: some Scene {
        WindowGroup {
            // Pass the viewModel to ContentView
            ContentView(viewModel: viewModel)
        }
    }
}
