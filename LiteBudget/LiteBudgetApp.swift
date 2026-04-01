import SwiftUI

@main
struct LiteBudgetApp: App {
    private let statusBarController = StatusBarController()

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(statusBarController.viewModel)
        }
    }
}