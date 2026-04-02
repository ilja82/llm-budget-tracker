import SwiftUI
import Charts

struct RequestsChartView: View {
    let data: [DailySpendData]

    private struct RequestPoint: Identifiable {
        let id: String
        let date: Date
        let type: String
        let count: Int
    }

    private var points: [RequestPoint] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        var result: [RequestPoint] = []
        for d in data.sorted(by: { $0.date < $1.date }) {
            guard let date = fmt.date(from: d.date) else { continue }
            let m = d.metrics
            result.append(.init(id: "\(d.date)-success", date: date, type: "Success", count: m.successfulRequests))
            result.append(.init(id: "\(d.date)-failed", date: date, type: "Failed", count: m.failedRequests))
        }
        return result
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
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)").font(.system(size: 9))
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 100)
    }

    private var strideCount: Int {
        max(1, data.count / 6)
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