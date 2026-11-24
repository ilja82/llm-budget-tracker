import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    let viewModel = BudgetViewModel()
    let updateViewModel = UpdateViewModel()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private weak var hostingViewController: NSViewController?
    private lazy var dashboardWindow = DashboardWindowController(viewModel: viewModel)

    init() {
        setupPopover()
        setupButton()
        observeViewModel()
        observeUpdateViewModel()
        updateViewModel.start()
    }

    // MARK: - Setup

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 470, height: 420)
        let controller = NSHostingController(
            rootView: PopoverView(
                closePopover: { [weak self] in self?.popover.performClose(nil) },
                openDashboard: { [weak self] in self?.dashboardWindow.show() }
            )
            .environment(viewModel)
            .environment(updateViewModel)
        )
        hostingViewController = controller
        popover.contentViewController = controller
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        updateImage()
    }

    // MARK: - Click

    @objc private func handleClick() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            updateViewModel.reevaluate()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updatePopoverSize()
            popover.contentViewController?.view.window?.makeKey()
            Task { @MainActor [weak self] in
                self?.popover.contentViewController?.view.window?.makeFirstResponder(nil)
                self?.updatePopoverSize()
            }
        }
    }

    // MARK: - Icon

    private func updateImage() {
        guard let button = statusItem.button else { return }
        let img = MenuBarIconRenderer.image(
            style: viewModel.iconStyle,
            progress: viewModel.budgetPercentage,
            color: viewModel.pacingBarNSColor,
            label: viewModel.menuBarText,
            linePosition: viewModel.linePosition
        )
        img.isTemplate = false
        button.image = img
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = viewModel.menuBarTooltip
        button.setAccessibilityLabel("LLM Budget Tracker")
        button.setAccessibilityValue(accessibilityValue)
        button.setAccessibilityHelp("Open budget overview and settings")
    }

    private func observeViewModel() {
        withObservationTracking {
            _ = viewModel.budgetPercentage
            _ = viewModel.menuBarText
            _ = viewModel.iconStyle
            _ = viewModel.linePosition
            _ = viewModel.pacingBarNSColor
            _ = viewModel.menuBarTooltip
            _ = viewModel.appState
            _ = viewModel.spendLogs
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateImage()
                self?.updatePopoverSize()
                self?.observeViewModel()
            }
        }
    }

    private func observeUpdateViewModel() {
        withObservationTracking {
            _ = updateViewModel.availableUpdate
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updatePopoverSize()
                self?.observeUpdateViewModel()
            }
        }
    }

    private func updatePopoverSize() {
        guard let view = hostingViewController?.view else { return }
        let fittedHeight = view.fittingSize.height
        let clampedHeight = min(max(fittedHeight, 320), 900)
        popover.contentSize = NSSize(width: 470, height: clampedHeight)
    }

    private var accessibilityValue: String {
        switch viewModel.appState {
        case .notConfigured:
            return "Not configured"
        case .authError:
            return "Authentication failed"
        case .rateLimited:
            return "Requests paused"
        case .networkError:
            return "Server unreachable"
        case .offline:
            return "Waiting for connection"
        case .invalidData:
            return "Invalid response data"
        case .noBudget:
            return "Used \(viewModel.menuBarText), no budget limit"
        case .unknownError:
            return "Unknown error"
        case .loading:
            return "Loading budget"
        case .refreshing:
            return "Refreshing budget"
        case .loaded:
            return "\(viewModel.usageLabel) \(viewModel.menuBarText), pacing \(viewModel.pacingStatus.label)"
        }
    }
}
