import SwiftUI

struct StatsView: View {
    @Environment(BudgetViewModel.self) private var viewModel

    var body: some View {
        Group {
            switch viewModel.appState {
            case .notConfigured:
                EmptyView()
            case .loading:
                GroupBox {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.mini)
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
                    message: "LLM Budget Tracker could not reach your LiteLLM proxy." +
                        " Check the Proxy URL and your network connection."
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
                    BudgetCard(info: info, pacing: viewModel.pacingInfo)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.appState)
    }

    private func errorCard(title: String, message: String) -> some View {
        GroupBox {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
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

    private var statusColor: Color {
        pacing?.status.color ?? fallbackStatusColor
    }

    private var fallbackStatusColor: Color {
        let pct = info.maxBudget.map { info.spend / $0 } ?? 0
        return pct > 0.9 ? .red : pct > 0.75 ? .orange : .green
    }

    private var remainingBudget: Double? {
        guard let maxBudget = info.maxBudget else { return nil }
        return Swift.max(maxBudget - info.spend, 0)
    }

    private var remainingPercentage: Double? {
        guard let max = info.maxBudget, max > 0, let remainingBudget else { return nil }
        return (remainingBudget / max) * 100
    }

    private var resetText: String? {
        guard let resetAt = info.budgetResetAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: resetAt).day ?? 0
        return "Resets in \(Swift.max(0, days))d"
    }

    private var fallbackForecastText: String? {
        guard let maxBudget = info.maxBudget else { return nil }
        let remaining = Swift.max(maxBudget - info.spend, 0)
        if remaining <= 0 {
            return "You have reached your budget cap."
        }
        return String(format: "$%.2f still available before reset.", remaining)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remaining")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let remaining = remainingBudget {
                            Text(currency(remaining))
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(statusColor)
                                .accessibilityLabel(heroAccessibilityLabel(remaining: remaining))
                        } else {
                            Text("—")
                                .font(.system(size: 42, weight: .heavy, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        if let resetText {
                            Text(resetText)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: 0)

                    if let pacing {
                        VStack(alignment: .trailing, spacing: 4) {
                            StatusPill(
                                icon: pacing.status.icon,
                                text: pacing.status.label,
                                color: statusColor
                            )
                        }
                    } else if let resetText {
                        Text(resetText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let pacing {
                BudgetBar(pacing: pacing, statusColor: statusColor)

                ActionInsightCard(pacing: pacing, color: statusColor)
            } else if let forecastText = fallbackForecastText {
                Text(forecastText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(statusColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(statusColor.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func heroAccessibilityLabel(remaining: Double) -> String {
        guard let percentage = remainingPercentage, let maxBudget = info.maxBudget else {
            return String(format: "Remaining budget: $%.2f", remaining)
        }
        return String(
            format: "Remaining budget: $%.2f, %.0f percent of your $%.2f budget",
            remaining,
            percentage,
            maxBudget
        )
    }

    private func currency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

// MARK: - Budget Bar

struct BudgetBar: View {
    let pacing: PacingInfo
    let statusColor: Color

    private var scale: Double {
        max(pacing.maxBudget, pacing.predictedTotal)
    }

    private var budgetBarAccessibilityLabel: String {
        [
            String(format: "Spent so far: $%.2f.", pacing.spend),
            String(format: "On-track by today: $%.2f.", pacing.expectedUse),
            String(format: "Projected total: $%.2f.", pacing.predictedTotal),
            String(format: "Budget cap: $%.2f.", pacing.maxBudget)
        ].joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                let width = size.width
                let barHeight: CGFloat = 14
                let barY = (size.height - barHeight) / 2
                let capWidth: CGFloat = 3

                func xPosition(_ value: Double) -> CGFloat {
                    guard scale > 0 else { return 0 }
                    let clamped = min(max(value, 0), scale)
                    return CGFloat(clamped / scale) * max(width - capWidth, 0)
                }

                let trackRect = CGRect(x: 0, y: barY, width: max(width - capWidth, 0), height: barHeight)
                context.fill(
                    Path(roundedRect: trackRect, cornerRadius: 7),
                    with: .color(.secondary.opacity(0.14))
                )

                let spendWidth = max(8, xPosition(pacing.spend))
                context.fill(
                    Path(roundedRect: CGRect(x: 0, y: barY, width: spendWidth, height: barHeight), cornerRadius: 7),
                    with: .color(statusColor)
                )

                let projectionStart = xPosition(pacing.spend)
                let projectionEnd = xPosition(pacing.predictedTotal)
                if projectionEnd > projectionStart {
                    context.fill(
                        Path(
                            roundedRect: CGRect(
                                x: projectionStart,
                                y: barY,
                                width: projectionEnd - projectionStart,
                                height: barHeight
                            ),
                            cornerRadius: 7
                        ),
                        with: .color(statusColor.opacity(0.22))
                    )
                }

                let paceX = xPosition(pacing.expectedUse)
                var pacePath = Path()
                pacePath.move(to: CGPoint(x: paceX, y: barY - 5))
                pacePath.addLine(to: CGPoint(x: paceX, y: barY + barHeight + 5))
                context.stroke(
                    pacePath,
                    with: .color(.white.opacity(0.75)),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )

                let projectionX = xPosition(pacing.predictedTotal)
                var projectionPath = Path()
                projectionPath.move(to: CGPoint(x: projectionX, y: barY - 4))
                projectionPath.addLine(to: CGPoint(x: projectionX, y: barY + barHeight + 4))
                context.stroke(
                    projectionPath,
                    with: .color(Color.blue.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 2)
                )

                let capX = xPosition(pacing.maxBudget)
                context.fill(
                    Path(
                        roundedRect: CGRect(x: capX, y: barY - 4, width: capWidth, height: barHeight + 8),
                        cornerRadius: 2
                    ),
                    with: .color(.primary.opacity(0.7))
                )
            }
            .frame(height: 28)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(budgetBarAccessibilityLabel)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    barKey(
                        color: statusColor,
                        text: "Spent: \(legendCurrency(pacing.spend))"
                    )
                    barKey(
                        color: .white.opacity(0.75),
                        text: "Optimum: \(legendCurrency(pacing.expectedUse))",
                        dashed: true
                    )
                    barKey(
                        color: .primary.opacity(0.7),
                        text: "Max: \(legendCurrency(pacing.maxBudget))"
                    )
                }

                HStack(spacing: 10) {
                    barKey(
                        color: Color.blue.opacity(0.85),
                        text: pacing.forecastSentence
                    )
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func barKey(color: Color, text: String, dashed: Bool = false) -> some View {
        HStack(spacing: 5) {
            Group {
                if dashed {
                    Rectangle()
                        .fill(color)
                        .frame(width: 12, height: 1.5)
                        .overlay(
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                                .foregroundStyle(color)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 12, height: 4)
                }
            }
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    private func legendCurrency(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "$%.0f", value)
        }
        return String(format: "$%.2f", value)
    }
}

// MARK: - Supporting Views

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.14)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

struct ActionInsightCard: View {
    let pacing: PacingInfo
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(String(format: "Optimum daily spend: $%.2f/day", pacing.safeDailySpend))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(pacing.warningSentence)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.18))
        )
    }
}

// MARK: - Presentation Helpers

private extension PacingInfo {
    var forecastSentence: String {
        switch status {
        case .underPace:
            return String(format: "At this pace, you'll finish around: $%.2f.", predictedTotal)
        case .onTrack:
            return String(format: "You're projected to finish around: $%.2f.", predictedTotal)
        case .nearLimit:
            return String(format: "At this pace, you'll finish around: $%.2f.", predictedTotal)
        case .overPace:
            return "At this pace, you may exceed your budget before reset."
        case .unknown:
            return "Projected outcome is not available."
        }
    }

    var warningSentence: String {
        switch status {
        case .underPace:
            return String(
                format: "You still have about $%.2f of cushion at your current pace.",
                maxBudget - predictedTotal
            )
        case .onTrack:
            return "You're close to your ideal pace, so keep heavier usage days in check."
        case .nearLimit:
            return String(
                format: "Only $%.2f of cushion remains at your current pace.",
                max(maxBudget - predictedTotal, 0)
            )
        case .overPace:
            if let exhaustDate = projectedBudgetExhaustDate {
                let day = exhaustDate.formatted(.dateTime.month(.abbreviated).day())
                return "You're trending above your ideal pace and could run out by \(day)."
            }
            return "A few heavier usage days could push you over budget."
        case .unknown:
            return "More budget data is needed for pacing guidance."
        }
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
