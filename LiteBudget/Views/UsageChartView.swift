import SwiftUI
import Charts

struct UsageChartView: View {
    let data: [(date: Date, amount: Double)]
    var safeLine: [(date: Date, amount: Double)] = []

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                chartSummaryRow
                chartBody
                if let safe = currentSafeDailySpend {
                    safeSpendCallout(safe)
                }
            }
        } label: {
            Label("Daily Spending", systemImage: "chart.bar.fill")
                .font(.caption.weight(.semibold))
        }
    }

    // MARK: - Chart Summary

    private var chartSummaryRow: some View {
        HStack(spacing: 12) {
            summaryItem(label: "7-day avg", value: String(format: "$%.2f", sevenDayAverage))
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

    private func safeSpendCallout(_ safe: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                Text("Safe daily limit")
                    .font(.system(size: 9))
            }
            .foregroundStyle(.green.opacity(0.85))
            Text(String(format: "$%.2f/day", safe))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
            Text("Stay at or under this amount per day to finish within budget.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.08))
        )
    }

    // MARK: - Chart

    private var chartBody: some View {
        Chart {
            ForEach(data, id: \.date) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Spend ($)", point.amount)
                )
                .foregroundStyle(barColor(for: point))
                .cornerRadius(2)
            }

            if !safeLine.isEmpty {
                ForEach(safeLine, id: \.date) { point in
                    LineMark(
                        x: .value("Safe Date", point.date, unit: .day),
                        y: .value("Safe daily", point.amount)
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.green.opacity(0.75))
                }

                if let lastSafePoint = safeLine.last {
                    PointMark(
                        x: .value("Safe Label Date", lastSafePoint.date, unit: .day),
                        y: .value("Safe Label Amount", lastSafePoint.amount)
                    )
                    .opacity(0.001)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Safe")
                            .font(.system(size: 8))
                            .foregroundStyle(.green.opacity(0.85))
                            .padding(.trailing, 2)
                    }
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
                        Text(String(format: "$%.0f", v)).font(.system(size: 9))
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

    private var currentSafeDailySpend: Double? {
        safeLine.first(where: { Calendar.current.isDateInToday($0.date) })?.amount ?? safeLine.last?.amount
    }

    private var strideCount: Int {
        max(1, max(data.count, safeLine.count) / 6)
    }

    private func barColor(for point: (date: Date, amount: Double)) -> Color {
        guard let safe = safeLimit(for: point.date), safe > 0 else {
            return Color.accentColor
        }
        if point.amount > safe * 1.2 { return .red }
        if point.amount > safe { return .orange }
        return Color.accentColor
    }

    private func safeLimit(for date: Date?) -> Double? {
        guard let date else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        return safeLine.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })?.amount
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
    let safeLine = data.map { (date: $0.date, amount: 0.007) }
    return UsageChartView(data: data, safeLine: safeLine)
        .padding()
        .frame(width: 320)
}
