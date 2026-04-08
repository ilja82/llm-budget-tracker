import SwiftUI

struct MenuBarLabel: View {
    @Environment(BudgetViewModel.self) private var viewModel

    var body: some View {
        BudgetProgressBarIcon(
            progress: viewModel.budgetPercentage,
            color: viewModel.pacingBarColor,
            label: viewModel.menuBarText
        )
        .accessibilityLabel("LLM Budget: \(viewModel.menuBarText)")
        .accessibilityHint("Click to open budget overview")
    }
}

struct BudgetProgressBarIcon: View {
    let progress: Double
    let color: Color
    let label: String

    private let barWidth: CGFloat = 56
    private let barHeight: CGFloat = 14

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(width: barWidth, height: barHeight)
            .background(alignment: .leading) {
                color.opacity(0.75)
                    .frame(width: barWidth * min(1, max(0, progress)))
            }
            .background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.primary.opacity(0.4), lineWidth: 1)
            }
    }
}
