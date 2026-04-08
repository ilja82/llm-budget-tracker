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
                message: "LLM Budget Tracker could not reach your LiteLLM proxy. Check the Proxy URL and your network connection."
            )
        case .invalidData:
            errorCard(
                title: "Invalid response data",
                message: "LLM Budget Tracker received incomplete or malformed budget data."
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
                BudgetCard(info: info, pacing: viewModel.pacingInfo, displayMode: viewModel.displayMode)
            }
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

// MARK: - Budget Card

struct BudgetCard: View {
    let info: BudgetInfo
    let pacing: PacingInfo?
    let displayMode: MenuBarDisplayMode

    private var statusColor: Color {
        guard let p = pacing else {
            let pct = info.maxBudget.map { info.spend / $0 } ?? 0
            return pct > 0.9 ? .red : pct > 0.75 ? .orange : .green
        }
        switch p.status {
        case .underPace: return .green
        case .onTrack: return .green
        case .nearLimit: return .orange
        case .overPace: return .red
        case .unknown: return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Hero: remaining amount + percentage + reset
            VStack(spacing: 3) {
                Text("Remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let max = info.maxBudget {
                    let remaining = Swift.max(max - info.spend, 0)
                    let percentage = max > 0 ? (remaining / max) * 100 : 0
                    let heroText = displayMode == .dollar
                        ? String(format: "$%.2f", remaining)
                        : String(format: "%.0f%%", percentage)
                    Text(heroText)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                    if let resetAt = info.budgetResetAt {
                        let days = Calendar.current.dateComponents([.day], from: Date(), to: resetAt).day ?? 0
                        Text("Resets in \(Swift.max(0, days))d")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("—")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Unified budget bar
            if let p = pacing {
                BudgetBar(pacing: p, statusColor: statusColor)
            }

            // Status badge
            if let p = pacing {
                StatusBadge(pacing: p, color: statusColor)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(statusColor.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// MARK: - Budget Bar

struct BudgetBar: View {
    let pacing: PacingInfo
    let statusColor: Color

    private var scale: Double {
        pacing.maxBudget * 1.06
    }

    var body: some View {
        VStack(spacing: 6) {
            let scale = scale
            Canvas { context, size in
                let w = size.width
                let barH: CGFloat = 12
                let barY: CGFloat = (size.height - barH) / 2

                func xPos(_ value: Double) -> CGFloat {
                    guard scale > 0 else { return 0 }
                    return CGFloat(min(value / scale, 1.0)) * w
                }

                // Track
                context.fill(
                    Path(roundedRect: CGRect(x: 0, y: barY, width: w, height: barH), cornerRadius: 5),
                    with: .color(.secondary.opacity(0.15))
                )

                // Spent fill
                let spendW = max(6, xPos(pacing.spend))
                context.fill(
                    Path(roundedRect: CGRect(x: 0, y: barY, width: spendW, height: barH), cornerRadius: 5),
                    with: .color(statusColor)
                )

                // Max budget marker (solid vertical line)
                let maxX = xPos(pacing.maxBudget)
                var maxPath = Path()
                maxPath.move(to: CGPoint(x: maxX, y: barY - 4))
                maxPath.addLine(to: CGPoint(x: maxX, y: barY + barH + 4))
                context.stroke(maxPath, with: .color(.primary.opacity(0.55)), lineWidth: 2)

                // Optimum marker (dashed vertical line)
                let optX = xPos(pacing.expectedUse)
                var dashY = barY - 4
                let dashEnd = barY + barH + 4
                while dashY < dashEnd {
                    var dp = Path()
                    dp.move(to: CGPoint(x: optX, y: dashY))
                    dp.addLine(to: CGPoint(x: optX, y: min(dashY + 3, dashEnd)))
                    context.stroke(dp, with: .color(.primary.opacity(0.4)), lineWidth: 1.5)
                    dashY += 5
                }

                // Projected total marker (upward triangle below bar)
                if !pacing.isOverBudget {
                    let projX = xPos(pacing.predictedTotal)
                    let triTip = barY + barH + 3
                    let triBase = triTip + 5
                    let triHalfW: CGFloat = 4
                    var projPath = Path()
                    projPath.move(to: CGPoint(x: projX, y: triTip))
                    projPath.addLine(to: CGPoint(x: projX - triHalfW, y: triBase))
                    projPath.addLine(to: CGPoint(x: projX + triHalfW, y: triBase))
                    projPath.closeSubpath()
                    context.fill(projPath, with: .color(.secondary.opacity(0.6)))
                }
            }
            .frame(height: 26)

            // Legend
            HStack(spacing: 0) {
                legendItem(indicator: .dot(statusColor), label: String(format: "$%.2f spent", pacing.spend))
                Spacer()
                legendItem(indicator: .dashed, label: String(format: "$%.2f optimum", pacing.expectedUse))
                Spacer()
                if pacing.isOverBudget {
                    if let exhaustDate = pacing.projectedBudgetExhaustDate {
                        Text("full by \(exhaustDate.formatted(.dateTime.month(.abbreviated).day())) · ")
                            .font(.system(size: 9))
                            .foregroundStyle(.red)
                    }
                } else {
                    legendItem(indicator: .triangle, label: String(format: "$%.2f projected", pacing.predictedTotal))
                    Spacer()
                }
                legendItem(indicator: .solid, label: String(format: "$%.2f max", pacing.maxBudget))
            }
        }
    }

    private enum Indicator {
        case dot(Color), dashed, solid, triangle
    }

    @ViewBuilder
    private func legendItem(indicator: Indicator, label: String) -> some View {
        HStack(spacing: 4) {
            switch indicator {
            case .dot(let color):
                Circle().fill(color).frame(width: 6, height: 6)
            case .dashed:
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 3, height: 1.5)
                    }
                }
            case .solid:
                Rectangle()
                    .fill(Color.primary.opacity(0.55))
                    .frame(width: 2, height: 10)
            case .triangle:
                Canvas { ctx, sz in
                    var p = Path()
                    p.move(to: CGPoint(x: sz.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: sz.height))
                    p.addLine(to: CGPoint(x: sz.width, y: sz.height))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(.secondary.opacity(0.6)))
                }
                .frame(width: 8, height: 6)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let pacing: PacingInfo
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: pacing.status.icon)
                .font(.caption.weight(.semibold))
            Text(statusText)
                .font(.caption)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundStyle(color)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.1)))
    }

    private var statusText: String {
        switch pacing.status {
        case .underPace:
            return String(
                format: "Under pace · projected total: $%.2f, below your $%.2f budget",
                pacing.predictedTotal,
                pacing.maxBudget
            )
        case .onTrack:
            return String(
                format: "On pace · projected total: $%.2f, within your $%.2f budget",
                pacing.predictedTotal,
                pacing.maxBudget
            )
        case .nearLimit:
            return String(
                format: "Near limit · projected total: $%.2f, close to your $%.2f budget",
                pacing.predictedTotal,
                pacing.maxBudget
            )
        case .overPace:
            if let exhaustDate = pacing.projectedBudgetExhaustDate {
                return "Over pace · budget exhausted by \(exhaustDate.formatted(.dateTime.month(.abbreviated).day()))"
            }
            return String(
                format: "Over pace · projected total: $%.2f, above your $%.2f budget",
                pacing.predictedTotal,
                pacing.maxBudget
            )
        case .unknown:
            return "Status unavailable"
        }
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
    var detail: String? = nil
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

            if let detail {
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
