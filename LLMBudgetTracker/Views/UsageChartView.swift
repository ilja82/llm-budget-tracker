import SwiftUI
import Charts

struct UsageChartView: View {
    let data: [(date: Date, amount: Double)]
    var safeLine: [(date: Date, amount: Double)] = []

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                chartBody
                if let safe = currentSafeDailySpend {
                    safeSpendCallout(safe)
                }
            }
        } label: {
            Label("Daily Spend", systemImage: "chart.bar.fill")
                .font(.caption.weight(.semibold))
        }
    }

    private func safeSpendCallout(_ safe: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("Optimum daily spend: ")
                    .font(.caption2)
                Text(String(format: "$%.2f/day", safe))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .foregroundStyle(.green.opacity(0.85))
            Text("Stay at or under this amount per day to finish within budget.")
                .font(.caption2)
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
                        Text("Optimum")
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
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "$%.0f", v)).font(.caption2)
                    }
                }
            }
        }
        .frame(height: 120)
        .accessibilityLabel(chartAccessibilityLabel)
        .accessibilityHint("Daily spending bar chart")
    }

    // MARK: - Helpers

    private var chartAccessibilityLabel: String {
        guard !data.isEmpty else { return "No daily spend data available" }
        let total = data.reduce(0.0) { $0 + $1.amount }
        let peak = data.max(by: { $0.amount < $1.amount })
        return String(format: "Daily spend over %d days. Total: $%.2f. Peak day: $%.2f.",
            data.count, total, peak?.amount ?? 0)
    }

    private var currentSafeDailySpend: Double? {
        safeLine.first(where: { Calendar.current.isDateInToday($0.date) })?.amount ?? safeLine.last?.amount
    }

    private var strideCount: Int {
        let allDates = data.map(\.date) + safeLine.map(\.date)
        guard let earliest = allDates.min(), let latest = allDates.max() else { return 1 }
        let spanDays = max(1, Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1)
        return max(1, spanDays / 5)
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
