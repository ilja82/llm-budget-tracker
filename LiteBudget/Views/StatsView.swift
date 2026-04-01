import SwiftUI

struct StatsView: View {
    @Environment(BudgetViewModel.self) private var viewModel

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                if let info = viewModel.budgetInfo {
                    budgetRows(info: info)
                } else if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Configure Settings to start tracking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Label("Budget Overview", systemImage: "chart.pie")
                .font(.caption.weight(.semibold))
        }
    }

    @ViewBuilder
    private func budgetRows(info: BudgetInfo) -> some View {
        StatRow(label: "Used", value: String(format: "$%.2f", info.spend))

        if let max = info.maxBudget {
            StatRow(label: "Max Budget", value: String(format: "$%.2f", max))
            ProgressView(value: viewModel.budgetPercentage)
                .tint(progressTint)
        }

        if let resetAt = info.budgetResetAt {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: resetAt).day ?? 0
            StatRow(label: "Resets In", value: "\(max(0, days)) day\(days == 1 ? "" : "s")")
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