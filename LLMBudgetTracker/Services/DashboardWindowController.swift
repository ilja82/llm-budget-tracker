import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController {
    private let viewModel: BudgetViewModel
    private var window: NSWindow?

    init(viewModel: BudgetViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: DailyCostDetailView().environment(viewModel))
        controller.sizingOptions = []
        let window = NSWindow(contentViewController: controller)
        window.title = "Dashboard"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 720, height: 560))
        window.contentMinSize = NSSize(width: 560, height: 420)
        window.center()
        return window
    }
}
