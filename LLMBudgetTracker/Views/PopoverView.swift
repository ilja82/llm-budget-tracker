import SwiftUI

struct PopoverView: View {
    var closePopover: () -> Void = {}
    @Environment(BudgetViewModel.self) private var viewModel
    @Environment(\.openSettings) private var openSettings

    @State private var isRefreshing = false
    @State private var refreshError: String?
    @State private var refreshTask: Task<Void, Never>?
    @State private var autoStartEnabled = AutoStartService.isEnabled
    @State private var autoStartError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.appState == .notConfigured {
                notConfiguredView
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        StatsView()
                        if !viewModel.dailySpend.isEmpty {
                            UsageChartView(
                                data: viewModel.dailySpend,
                                safeLine: viewModel.safeSpendLine,
                                currentPeriodStart: viewModel.currentPeriodStart
                            )
                            .transition(.opacity)
                        }
                        if !viewModel.dailyActivity.isEmpty {
                            TokenChartView(
                                data: viewModel.dailyActivity,
                                currentPeriodStart: viewModel.currentPeriodStart
                            )
                            .transition(.opacity)
                            RequestsChartView(
                                data: viewModel.dailyActivity,
                                currentPeriodStart: viewModel.currentPeriodStart
                            )
                            .transition(.opacity)
                        }
                        secondaryControlsSection
                    }
                    .animation(.easeOut(duration: 0.25), value: viewModel.dailySpend.isEmpty)
                    .animation(.easeOut(duration: 0.25), value: viewModel.dailyActivity.isEmpty)
                    .padding(16)
                }
            }
            Divider()
            footer
        }
        .frame(width: 420)
        .environment(viewModel)
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.willShowNotification)) { _ in
            autoStartEnabled = AutoStartService.isEnabled
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text("LLM Budget Tracker")
                .font(.headline)
            if viewModel.devMode.isEnabled {
                Text("DEV")
                    .font(.caption2).bold()
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
            }
            Spacer()
            if viewModel.appState == .loading || viewModel.appState == .refreshing || isRefreshing {
                ProgressView().controlSize(.small)
            }
            Button {
                closePopover()
                NSApp.activate(ignoringOtherApps: true)
                Task { @MainActor in openSettings() }
            } label: {
                Label("Settings", systemImage: "gear")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the settings window")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var notConfiguredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("Connect LiteLLM to get started")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Open Settings and enter your Proxy URL and API Key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Open Settings") {
                closePopover()
                NSApp.activate(ignoringOtherApps: true)
                Task { @MainActor in openSettings() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var dailyActivityHint: some View {
        GroupBox {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(.secondary)
                Text("Daily activity stats are off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Enable") {
                    refreshTask?.cancel()
                    isRefreshing = true
                    refreshError = nil
                    refreshTask = Task {
                        await viewModel.setDailyActivityEnabled(true)
                        guard !Task.isCancelled else { return }
                        if let err = viewModel.errorMessage, !err.isEmpty {
                            refreshError = err
                        }
                        isRefreshing = false
                    }
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var secondaryControlsSection: some View {
        if !viewModel.dailyActivityEnabled || !autoStartEnabled {
            VStack(alignment: .leading, spacing: 8) {
                Text("More options")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)

                if !viewModel.dailyActivityEnabled {
                    dailyActivityHint
                }

                if !autoStartEnabled {
                    launchAtLoginHint
                }
            }
            .padding(.top, 2)
        }
    }

    private var launchAtLoginHint: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Launch at Login is off.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Enable") {
                        do {
                            try AutoStartService.setEnabled(true)
                            autoStartEnabled = true
                            autoStartError = nil
                        } catch {
                            autoStartError = error.localizedDescription
                        }
                    }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Enable Launch at Login")
                    .accessibilityHint("Starts LLM Budget Tracker automatically when you log in")
                    Spacer()
                }

                if let err = autoStartError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if let error = refreshError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
            if viewModel.lastUpdated != nil || viewModel.nextRefreshMinutes != nil {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    HStack {
                        if !viewModel.relativeLastUpdated.isEmpty {
                            Text("Updated:")
                                .foregroundStyle(.secondary)
                            Text(viewModel.relativeLastUpdated)
                        }
                        Spacer()
                        if let mins = viewModel.nextRefreshMinutes {
                            Text("Next refresh in:")
                                .foregroundStyle(.secondary)
                            Text("\(mins) min")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            HStack {
                Button {
                    refreshTask?.cancel()
                    isRefreshing = true
                    refreshError = nil
                    refreshTask = Task {
                        await viewModel.refresh()
                        guard !Task.isCancelled else { return }
                        if let err = viewModel.errorMessage, !err.isEmpty {
                            refreshError = err
                        }
                        isRefreshing = false
                    }
                } label: {
                    Label(isRefreshing ? "Refreshing..." : "Refresh now", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(isRefreshing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
