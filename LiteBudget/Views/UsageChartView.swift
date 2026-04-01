import SwiftUI
import Charts

struct UsageChartView: View {
    let data: [(date: Date, amount: Double)]
    var safeDailySpend: Double? = nil

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                chartSummaryRow
                chartBody
            }
        } label: {
            Label("Daily Spend", systemImage: "chart.bar.fill")
                .font(.caption.weight(.semibold))
        }
    }

    // MARK: - Chart Summary

    private var chartSummaryRow: some View {
        HStack(spacing: 12) {
            summaryItem(label: "7-day avg", value: String(format: "$%.3f", sevenDayAverage))
            if let safe = safeDailySpend {
                summaryItem(label: "Safe daily", value: String(format: "$%.3f", safe))
            }
            Spacer()
            trendIndicator
        }
    }

    @ViewBuilder
    private var trendIndicator: some View {
        if data.count >= 3 {
            let recent = data.suffix(3).map(\.amount)
            let delta = (recent.last ?? 0) - (recent.first ?? 0)
            HStack(spacing: 3) {
                Image(systemName: delta > 0.001 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .semibold))
                Text(delta > 0.001 ? "Rising" : "Falling")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(delta > 0.001 ? .orange : .green)
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Chart

    private var chartBody: some View {
        Chart {
            ForEach(data, id: \.date) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Spend ($)", point.amount)
                )
                .foregroundStyle(barColor(for: point.amount))
                .cornerRadius(2)
            }

            if let safe = safeDailySpend, safe > 0 {
                RuleMark(y: .value("Safe daily", safe))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.green.opacity(0.7))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Safe")
                            .font(.system(size: 8))
                            .foregroundStyle(.green.opacity(0.85))
                            .padding(.trailing, 2)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideCount)) { _ in
                AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "$%.3f", v)).font(.system(size: 9))
                    }
                }
            }
        }
        .frame(height: 120)
    }

    // MARK: - Helpers

    private var sevenDayAverage: Double {
        let recent = Array(data.suffix(7))
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.amount).reduce(0, +) / Double(recent.count)
    }

    private var strideCount: Int {
        max(1, data.count / 6)
    }

    private func barColor(for amount: Double) -> Color {
        guard let safe = safeDailySpend, safe > 0 else { return Color.accentColor }
        if amount > safe * 1.2 { return .red }
        if amount > safe { return .orange }
        return Color.accentColor
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let data: [(date: Date, amount: Double)] = (0..<14).map { i in
        let date = calendar.date(byAdding: .day, value: -13 + i, to: today)!
        let amount = Double.random(in: 0.001...0.012)
        return (date: date, amount: amount)
    }
    return UsageChartView(data: data, safeDailySpend: 0.007)
        .padding()
        .frame(width: 320)
}