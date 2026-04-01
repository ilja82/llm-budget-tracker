import SwiftUI

struct StatsView: View {
    @Environment(BudgetViewModel.self) private var viewModel

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                switch viewModel.appState {
                case .notConfigured:
                    EmptyView()
                case .loading:
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                case .authError:
                    stateView(
                        title: "Authentication failed",
                        body: "Your API key was rejected. Check your API key in Settings."
                    )
                case .networkError:
                    stateView(
                        title: "Server unreachable",
                        body: "LiteBudget could not reach your LiteLLM proxy. Check the Proxy URL and your network connection."
                    )
                case .invalidData:
                    stateView(
                        title: "Invalid response data",
                        body: "LiteBudget received incomplete or malformed budget data."
                    )
                case .noBudget:
                    stateView(
                        title: "No budget found",
                        body: "Your LiteLLM account does not currently have budget data available."
                    )
                case .unknownError:
                    stateView(
                        title: "Something went wrong",
                        body: viewModel.errorMessage ?? "An unexpected error occurred."
                    )
                case .loaded, .refreshing:
                    if let info = viewModel.budgetInfo {
                        budgetRows(info: info)
                    }
                }
            }
        } label: {
            Label("Budget Overview", systemImage: "chart.pie")
                .font(.caption.weight(.semibold))
        }
    }

    private func stateView(title: String, body: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func budgetRows(info: BudgetInfo) -> some View {
        StatRow(label: "Used", value: String(format: "$%.2f", info.spend))

        if let max = info.maxBudget {
            StatRow(label: "Total Budget", value: String(format: "$%.2f", max))

            let remaining = Swift.max(max - info.spend, 0)
            StatRow(label: "Remaining", value: String(format: "$%.2f", remaining))

            ProgressView(value: viewModel.budgetPercentage)
                .tint(progressTint)
        }

        if let resetAt = info.budgetResetAt {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: resetAt).day ?? 0
            StatRow(label: "Reset in", value: "\(Swift.max(0, days)) day\(days == 1 ? "" : "s")")
        }

        if let pacing = viewModel.pacingInfo {
            Divider()
            HStack {
                Text("Safe daily spend")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "$%.2f/day", pacing.safeDailySpend))
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
            .font(.caption)
        }
    }

    private var progressTint: Color {
        viewModel.budgetPercentage > 0.9 ? .red : viewModel.budgetPercentage > 0.75 ? .orange : .accentColor
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.caption)
    }
}