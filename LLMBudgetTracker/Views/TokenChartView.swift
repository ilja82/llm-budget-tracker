import Charts
import SwiftUI

struct TokenChartView: View {
    let data: [DailySpendData]
    let currentPeriodStart: Date?
    private let points: [TokenPoint]

    private struct TokenPoint: Identifiable {
        let id: String
        let date: Date
        let type: String
        let tokens: Int
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init(data: [DailySpendData], currentPeriodStart: Date? = nil) {
        self.data = data
        self.currentPeriodStart = currentPeriodStart
        let fmt = Self.dateFmt
        var result: [TokenPoint] = []
        for entry in data.sorted(by: { $0.date < $1.date }) {
            guard let date = fmt.date(from: entry.date) else { continue }
            let metrics = entry.metrics
            result.append(.init(
                id: "\(entry.date)-prompt", date: date, type: "Prompt", tokens: metrics.promptTokens))
            result.append(.init(
                id: "\(entry.date)-completion", date: date, type: "Completion", tokens: metrics.completionTokens))
            result.append(.init(
                id: "\(entry.date)-cache_read", date: date, type: "Cache Read", tokens: metrics.cacheReadInputTokens))
            result.append(.init(
                id: "\(entry.date)-cache_create",
                date: date, type: "Cache Write", tokens: metrics.cacheCreationInputTokens))
        }
        self.points = result
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
        Chart {
            if let start = currentPeriodStart,
               let last = points.map(\.date).max(),
               start <= last {
                RectangleMark(
                    xStart: .value("Period start", start),
                    xEnd: .value("Period end", last)
                )
                .foregroundStyle(Color.accentColor.opacity(0.10))
            }

            ForEach(points) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Tokens", point.tokens)
                )
                .foregroundStyle(by: .value("Type", point.type))
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
                    if let val = value.as(Int.self) {
                        Text(formatCount(val)).font(.caption2)
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 120)
        .accessibilityLabel(chartAccessibilityLabel)
        .accessibilityHint("Daily token usage stacked bar chart")
    }

    private var chartAccessibilityLabel: String {
        guard !data.isEmpty else { return "No token data available" }
        let totalPrompt = data.reduce(0) { $0 + $1.metrics.promptTokens }
        let totalCompletion = data.reduce(0) { $0 + $1.metrics.completionTokens }
        let totalCache = data.reduce(0) { $0 + $1.metrics.cacheReadInputTokens }
        let summary = "Token usage over \(data.count) days."
        let parts = "Prompt: \(formatCount(totalPrompt)), Completion: \(formatCount(totalCompletion))," +
            " Cache read: \(formatCount(totalCache))."
        return "\(summary) \(parts)"
    }

    private var strideCount: Int {
        guard let earliest = points.first?.date, let latest = points.last?.date else { return 1 }
        let spanDays = max(1, Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1)
        return max(1, spanDays / 5)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.0fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    let data: [DailySpendData] = (0..<14).map { i in
        let date = calendar.date(byAdding: .day, value: -13 + i, to: today) ?? today
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
