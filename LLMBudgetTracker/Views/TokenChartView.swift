import SwiftUI
import Charts

struct TokenChartView: View {
    let data: [DailySpendData]

    private struct TokenPoint: Identifiable {
        let id: String
        let date: Date
        let type: String
        let tokens: Int
    }

    private var points: [TokenPoint] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        var result: [TokenPoint] = []
        for d in data.sorted(by: { $0.date < $1.date }) {
            guard let date = fmt.date(from: d.date) else { continue }
            let m = d.metrics
            result.append(.init(id: "\(d.date)-prompt", date: date, type: "Prompt", tokens: m.promptTokens))
            result.append(.init(id: "\(d.date)-completion", date: date, type: "Completion", tokens: m.completionTokens))
            result.append(.init(id: "\(d.date)-cache_read", date: date, type: "Cache Read", tokens: m.cacheReadInputTokens))
            result.append(.init(id: "\(d.date)-cache_create", date: date, type: "Cache Write", tokens: m.cacheCreationInputTokens))
        }
        return result
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                chartBody
            }
        } label: {
            Label("Tokens", systemImage: "text.page.fill")
                .font(.caption.weight(.semibold))
        }
    }

    private var chartBody: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Tokens", point.tokens)
            )
            .foregroundStyle(by: .value("Type", point.type))
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
                    if let v = value.as(Int.self) {
                        Text(formatCount(v)).font(.system(size: 9))
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 120)
    }

    private var strideCount: Int {
        let dates = points.map(\.date)
        guard let earliest = dates.min(), let latest = dates.max() else { return 1 }
        let spanDays = max(1, Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1)
        return max(1, spanDays / 5)
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    let data: [DailySpendData] = (0..<14).map { i in
        let date = calendar.date(byAdding: .day, value: -13 + i, to: today)!
        return DailySpendData(
            date: fmt.string(from: date),
            metrics: SpendMetrics(
                promptTokens: Int.random(in: 1000...5000),
                completionTokens: Int.random(in: 200...1000),
                cacheReadInputTokens: Int.random(in: 0...2000),
                cacheCreationInputTokens: Int.random(in: 0...500)
            )
        )
    }
    return TokenChartView(data: data)
        .padding()
        .frame(width: 320)
}