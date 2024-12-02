//
//  AppDelegate.swift
//  UpReady
//
//  Created by Carlos Fernando Mendez Solano on 12/1/24.
//

import SwiftUI
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    var viewModel: SleepViewModel?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.app.UpReady.refresh", using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefreshIfNeeded()
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleAppRefreshIfNeeded()

        // Create an operation that performs the background fetch
        let operation = FetchDataOperation(viewModel: viewModel)

        // Provide an expiration handler for the task
        task.expirationHandler = {
            operation.cancel()
        }

        // Inform the system when the task is complete
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
            if !operation.isCancelled {
                print("Background refresh succeeded.")
            } else {
                print("Background refresh failed or was cancelled.")
            }
        }

        // Start the operation
        OperationQueue().addOperation(operation)
    }

    func scheduleAppRefreshIfNeeded() {
        guard let viewModel = viewModel else { return }
        let calendar = Calendar.current
        let now = Date()

        // Define the "day" period as 5 AM to 8 PM
        let startOfDay = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: now)!
        let endOfDay = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now)!

        // Check if the user has opened the app today
        if !viewModel.hasOpenedToday {
            // Schedule background task to run after 8 PM
            let earliestBeginDate = endOfDay.addingTimeInterval(60 * 60) // 12 AM

            let request = BGAppRefreshTaskRequest(identifier: "com.app.UpReady.refresh")
            request.earliestBeginDate = earliestBeginDate

            do {
                try BGTaskScheduler.shared.submit(request)
                print("Background refresh scheduled at or after \(earliestBeginDate)")
            } catch {
                print("Could not schedule app refresh: \(error)")
            }
        } else {
            print("User has opened the app today. No background refresh scheduled.")
        }
    }
}

class FetchDataOperation: Operation, @unchecked Sendable {
    var viewModel: SleepViewModel?

    init(viewModel: SleepViewModel?) {
        self.viewModel = viewModel
    }

    override func main() {
        if self.isCancelled { return }

        let calendar = Calendar.current
        let now = Date()

        // Define the night period (e.g., 8 PM to 7 AM)
        let hour = calendar.component(.hour, from: now)
        if hour < 20 && hour >= 7 {
            // Outside the night period; do not perform fetch
            print("Current time is outside the background fetch window.")
            return
        }

        let semaphore = DispatchSemaphore(value: 0)

        Task {
            await viewModel?.refreshData()
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .distantFuture)
    }
}
