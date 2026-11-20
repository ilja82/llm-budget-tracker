import SwiftUI

@main
struct LLMBudgetTrackerApp: App {
    private let statusBarController = StatusBarController()

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(statusBarController.viewModel)
                .environment(statusBarController.updateViewModel)
        }
        .windowResizability(.contentSize)

        Window("Dashboard", id: DailyCostDetailView.windowID) {
            DailyCostDetailView()
                .environment(statusBarController.viewModel)
        }
        .defaultSize(width: 720, height: 560)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .windowResizability(.contentMinSize)
    }
}
