import AppKit
import SwiftUI

@MainActor
final class StatusBarController {
    let viewModel = BudgetViewModel()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private weak var hostingViewController: NSViewController?

    init() {
        setupPopover()
        setupButton()
        observeViewModel()
    }

    // MARK: - Setup

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 420)
        let controller = NSHostingController(
            rootView: PopoverView(closePopover: { [weak self] in
                self?.popover.performClose(nil)
            }).environment(viewModel)
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
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            updatePopoverSize()
            popover.contentViewController?.view.window?.makeKey()
            DispatchQueue.main.async { [weak self] in
                self?.popover.contentViewController?.view.window?.makeFirstResponder(nil)
                self?.updatePopoverSize()
            }
        }
    }

    // MARK: - Icon

    private func updateImage() {
        guard let button = statusItem.button else { return }
        let img = progressBarImage(
            progress: viewModel.budgetPercentage,
            color: viewModel.pacingBarNSColor,
            label: viewModel.menuBarText
        )
        img.isTemplate = false
        button.image = img
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = viewModel.menuBarTooltip
    }

    private func observeViewModel() {
        withObservationTracking {
            _ = viewModel.budgetPercentage
            _ = viewModel.menuBarText
            _ = viewModel.pacingBarNSColor
            _ = viewModel.menuBarTooltip
            _ = viewModel.appState
            _ = viewModel.dailySpend.count
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateImage()
                self?.updatePopoverSize()
                self?.observeViewModel()
            }
        }
    }

    private func updatePopoverSize() {
        guard let view = hostingViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        let fittedHeight = view.fittingSize.height
        let clampedHeight = min(max(fittedHeight, 320), 900)
        popover.contentSize = NSSize(width: 420, height: clampedHeight)
    }
}

// MARK: - Image Drawing

private func progressBarImage(progress: Double, color: NSColor, label: String) -> NSImage {
    let height: CGFloat = NSStatusBar.system.thickness
    let barH: CGFloat = height - 2        // 1pt padding top and bottom
    let fontSize: CGFloat = (barH * 0.62).rounded()
    let textWidth = NSAttributedString(
        string: label,
        attributes: [.font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)]
    ).size().width
    let width: CGFloat = max(textWidth + 16, 44)

    return NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
        let barY = (rect.height - barH) / 2
        let barRect = CGRect(x: 0.5, y: barY, width: rect.width - 1, height: barH)
        let r = barH / 4

        // Track
        NSColor.quaternaryLabelColor.setFill()
        NSBezierPath(roundedRect: barRect, xRadius: r, yRadius: r).fill()

        // Fill
        let fillW = barRect.width * CGFloat(min(1.0, max(0.0, progress)))
        if fillW > 0 {
            var fillRect = barRect
            fillRect.size.width = fillW
            color.withAlphaComponent(0.85).setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: r, yRadius: r).fill()
        }

        // Border
        let border = NSBezierPath(roundedRect: barRect.insetBy(dx: 0.5, dy: 0.5), xRadius: r, yRadius: r)
        border.lineWidth = 1
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
        border.stroke()

        // Label
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let str = NSAttributedString(string: label, attributes: attrs)
        let sz = str.size()
        str.draw(at: NSPoint(x: (width - sz.width) / 2, y: barY + (barH - sz.height) / 2))

        return true
    }
}
