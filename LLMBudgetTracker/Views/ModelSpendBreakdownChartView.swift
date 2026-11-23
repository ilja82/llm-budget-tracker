import SwiftUI

struct ModelSpendBreakdownChartView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @AppStorage(StorageKeys.ChartUI.modelSpendRange) private var rangeRaw: String = ModelRange.thisMonth.rawValue

    private enum Layout {
        static let compactThreshold = 5
        static let compactHeight: CGFloat = 180
        static let rowSpacing: CGFloat = 8
        static let barHeight: CGFloat = 6
    }

    private var range: ModelRange {
        ModelRange(rawValue: rangeRaw) ?? .thisMonth
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                rangePicker
                chartBody
            }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: Binding(
            get: { range },
            set: { rangeRaw = $0.rawValue }
        )) {
            ForEach(ModelRange.allCases) { opt in
                Text(opt.label).tag(opt)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .labelsHidden()
        .opacity(0.85)
    }

    @ViewBuilder
    private var chartBody: some View {
        let totals = viewModel.modelGroupSpendTotals(range: range)
        if totals.isEmpty {
            emptyState
        } else if totals.count <= Layout.compactThreshold {
            rows(for: totals)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(totals: totals))
        } else {
            ScrollView(.vertical) {
                rows(for: totals)
                    .padding(.trailing, 12)
            }
            .frame(height: Layout.compactHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(totals: totals))
        }
    }

    private func rows(for totals: [(model: String, spend: Double)]) -> some View {
        let largest = totals.map(\.spend).max() ?? 0
        return VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            ForEach(totals, id: \.model) { entry in
                row(
                    model: entry.model,
                    spend: entry.spend,
                    fraction: ModelSpendScale.fraction(of: entry.spend, max: largest)
                )
            }
        }
    }

    private func row(model: String, spend: Double, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Text(String(format: "$%.2f", spend))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: Layout.barHeight)
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                Text("No per-model data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(height: Layout.compactHeight)
    }

    private func accessibilityLabel(totals: [(model: String, spend: Double)]) -> String {
        let top = totals.prefix(3)
            .map { String(format: "%@ $%.2f", $0.model, $0.spend) }
            .joined(separator: ", ")
        return "Spend by model for \(range.label). Top: \(top)."
    }
}
