import Charts
import SwiftUI

struct ModelSpendBreakdownChartView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @AppStorage(StorageKeys.ChartUI.modelSpendRange) private var rangeRaw: String = ModelRange.thisMonth.rawValue

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
        } else {
            Chart(totals, id: \.model) { entry in
                BarMark(
                    x: .value("Spend", entry.spend),
                    y: .value("Model", entry.model)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(2)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(String(format: "$%.2f", entry.spend))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(String(format: "$%.0f", val)).font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartPlotStyle { plot in
                plot.padding(.trailing, 48)
            }
            .frame(height: 180)
            .accessibilityLabel(accessibilityLabel(totals: totals))
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
        .frame(height: 180)
    }

    private func accessibilityLabel(totals: [(model: String, spend: Double)]) -> String {
        let top = totals.prefix(3)
            .map { String(format: "%@ $%.2f", $0.model, $0.spend) }
            .joined(separator: ", ")
        return "Spend by model for \(range.label). Top: \(top)."
    }
}
