import SwiftUI

struct PopoverView: View {
    var closePopover: (() -> Void)? = nil
    @Environment(BudgetViewModel.self) private var viewModel
    @Environment(\.openSettings) private var openSettings

    @State private var isRefreshing = false
    @State private var refreshError: String?

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
                        if let pacing = viewModel.pacingInfo,
                           viewModel.appState == .loaded || viewModel.appState == .refreshing {
                            PacingView(pacing: pacing)
                        }
                        if !viewModel.dailySpend.isEmpty {
                            UsageChartView(data: viewModel.dailySpend)
                        }
                    }
                    .padding(14)
                }
            }
            Divider()
            footer
        }
        .frame(width: 320, height: 550)
        .environment(viewModel)
    }

    private var header: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text("LiteBudget")
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
                ProgressView().scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var notConfiguredView: some View {
        VStack(spacing: 16) {
            Spacer()
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
                closePopover?()
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.async { openSettings() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            HStack {
                Button {
                    guard !isRefreshing else { return }
                    isRefreshing = true
                    refreshError = nil
                    Task {
                        await viewModel.refresh()
                        if let err = viewModel.errorMessage, !err.isEmpty {
                            refreshError = err
                        }
                        isRefreshing = false
                    }
                } label: {
                    Label(isRefreshing ? "Refreshing..." : "Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(isRefreshing)

                Spacer()

                Button {
                    closePopover?()
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.async {
                        openSettings()
                    }
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}