import SwiftUI

struct StatsView: View {
    @Environment(BudgetViewModel.self) private var viewModel

    var body: some View {
        switch viewModel.appState {
        case .notConfigured:
            EmptyView()
        case .loading:
            GroupBox {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        case .authError:
            errorCard(
                title: "Authentication failed",
                message: "Your API key was rejected. Check your API key in Settings."
            )
        case .networkError:
            errorCard(
                title: "Server unreachable",
                message: "LiteBudget could not reach your LiteLLM proxy. Check the Proxy URL and your network connection."
            )
        case .invalidData:
            errorCard(
                title: "Invalid response data",
                message: "LiteBudget received incomplete or malformed budget data."
            )
        case .noBudget:
            errorCard(
                title: "No budget found",
                message: "Your LiteLLM account does not currently have budget data available."
            )
        case .unknownError:
            errorCard(
                title: "Something went wrong",
                message: viewModel.errorMessage ?? "An unexpected error occurred."
            )
        case .loaded, .refreshing:
            if let info = viewModel.budgetInfo {
                VStack(spacing: 8) {
                    BudgetHeroCard(
                        info: info,
                        pacing: viewModel.pacingInfo,
                        budgetPercentage: viewModel.budgetPercentage
                    )
                    if let pacing = viewModel.pacingInfo {
                        statChipsRow(info: info, pacing: pacing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func statChipsRow(info: BudgetInfo, pacing: PacingInfo) -> some View {
        HStack(spacing: 6) {
            if let resetAt = info.budgetResetAt {
                let days = Swift.max(0, Calendar.current.dateComponents([.day], from: Date(), to: resetAt).day ?? 0)
                StatChip(
                    icon: "calendar",
                    label: "Days left",
                    value: "\(days)",
                    color: daysColor(days: days, total: pacing.totalDays)
                )
            }
            StatChip(
                icon: "dollarsign.circle",
                label: "Safe daily",
                value: String(format: "$%.2f", pacing.safeDailySpend),
                color: .green
            )
            StatChip(
                icon: pacing.status.icon,
                label: "Pacing",
                value: pacing.status.label,
                color: pacingChipColor(pacing.status)
            )
        }
    }

    private func daysColor(days: Int, total: Int) -> Color {
        guard total > 0 else { return .secondary }
        let frac = Double(days) / Double(total)
        return frac < 0.15 ? .red : frac < 0.30 ? .orange : .secondary
    }

    private func pacingChipColor(_ status: PacingStatus) -> Color {
        switch status {
        case .underPace: return .green
        case .onTrack: return Color.accentColor
        case .nearLimit: return .orange
        case .overPace: return .red
        case .unknown: return .secondary
        }
    }

    private func errorCard(title: String, message: String) -> some View {
        GroupBox {
            VStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Budget Hero Card

struct BudgetHeroCard: View {
    let info: BudgetInfo
    let pacing: PacingInfo?
    let budgetPercentage: Double

    private var remaining: Double {
        guard let max = info.maxBudget else { return 0 }
        return Swift.max(max - info.spend, 0)
    }

    private var heroColor: Color {
        budgetPercentage > 0.9 ? .red : budgetPercentage > 0.75 ? .orange : .green
    }

    private var progressTint: Color {
        budgetPercentage > 0.9 ? .red : budgetPercentage > 0.75 ? .orange : Color.accentColor
    }

    var body: some View {
        VStack(spacing: 10) {
            // Hero stat
            VStack(spacing: 3) {
                Text("Remaining Budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let max = info.maxBudget {
                    Text(String(format: "$%.2f", Swift.max(max - info.spend, 0)))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(heroColor)
                } else {
                    Text("—")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Progress bar
            if info.maxBudget != nil {
                ProgressView(value: min(budgetPercentage, 1.0))
                    .tint(progressTint)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)
            }

            // Supporting metrics
            HStack {
                if let max = info.maxBudget {
                    SupportingMetric(
                        label: "Used",
                        value: String(format: "$%.2f / $%.2f", info.spend, max)
                    )
                    Spacer()
                }
                if let pacing {
                    SupportingMetric(
                        label: "% used",
                        value: String(format: "%.0f%%", pacing.percentageUsed * 100)
                    )
                    Spacer()
                }
                if let resetAt = info.budgetResetAt {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: resetAt).day ?? 0
                    SupportingMetric(
                        label: "Resets in",
                        value: "\(Swift.max(0, days)) day\(days == 1 ? "" : "s")"
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(heroColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(heroColor.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// MARK: - Reusable Sub-components

struct SupportingMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

struct StatChip: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(color.opacity(0.8))

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    let vm = BudgetViewModel()
    return StatsView()
        .environment(vm)
        .padding()
        .frame(width: 320)
}