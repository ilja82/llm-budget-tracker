import SwiftUI

struct PopoverView: View {
    var closePopover: (() -> Void)? = nil
    @Environment(BudgetViewModel.self) private var viewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 10) {
                    StatsView()
                    if let pacing = viewModel.pacingInfo {
                        PacingView(pacing: pacing)
                    }
                    if !viewModel.dailySpend.isEmpty {
                        UsageChartView(data: viewModel.dailySpend)
                    }
                }
                .padding(14)
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
            if viewModel.isLoading {
                ProgressView().scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            if let last = viewModel.lastUpdated {
                HStack {
                    Text("Updated:")
                        .foregroundStyle(.secondary)
                    Text(last, style: .time)
                    Spacer()
                    if let next = viewModel.nextRefresh {
                        Text("Next Update:")
                            .foregroundStyle(.secondary)
                        Text(next, style: .time)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            HStack {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(viewModel.isLoading)

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