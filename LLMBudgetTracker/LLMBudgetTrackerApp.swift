import SwiftUI

@main
struct LLMBudgetTrackerApp: App {
    private let statusBarController = StatusBarController()

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(statusBarController.viewModel)
        }
        .windowResizability(.contentMinSize)
    }
}
