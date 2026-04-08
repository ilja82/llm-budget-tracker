import SwiftUI
import Charts

struct RequestsChartView: View {
    let data: [DailySpendData]
    private let points: [RequestPoint]

    private struct RequestPoint: Identifiable {
        let id: String
        let date: Date
        let type: String
        let count: Int
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init(data: [DailySpendData]) {
        self.data = data
        let fmt = RequestsChartView.dateFmt
        var result: [RequestPoint] = []
        for d in data.sorted(by: { $0.date < $1.date }) {
            guard let date = fmt.date(from: d.date) else { continue }
            let m = d.metrics
            result.append(.init(id: "\(d.date)-success", date: date, type: "Success", count: m.successfulRequests))
            result.append(.init(id: "\(d.date)-failed", date: date, type: "Failed", count: m.failedRequests))
        }
        self.points = result
    }

    var body: some View {
        GroupBox {
            chartBody
        } label: {
            Label("API Requests", systemImage: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
        }
    }

    private var chartBody: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Requests", point.count)
            )
            .foregroundStyle(by: .value("Type", point.type))
        }
        .chartForegroundStyleScale([
            "Success": Color.green,
            "Failed": Color.red
        ])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideCount)) { _ in
                AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)").font(.caption2)
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 100)
        .accessibilityLabel(chartAccessibilityLabel)
        .accessibilityHint("Daily API requests stacked bar chart")
    }

    private var chartAccessibilityLabel: String {
        guard !data.isEmpty else { return "No request data available" }
        let totalSuccess = data.reduce(0) { $0 + $1.metrics.successfulRequests }
        let totalFailed = data.reduce(0) { $0 + $1.metrics.failedRequests }
        return "API requests over \(data.count) days. \(totalSuccess) successful, \(totalFailed) failed."
    }

    private var strideCount: Int {
        guard let earliest = points.first?.date, let latest = points.last?.date else { return 1 }
        let spanDays = max(1, Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1)
        return max(1, spanDays / 5)
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
                successfulRequests: Int.random(in: 5...30),
                failedRequests: Int.random(in: 0...3)
            )
        )
    }
    return RequestsChartView(data: data)
        .padding()
        .frame(width: 320)
}