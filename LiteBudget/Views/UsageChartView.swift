import SwiftUI
import Charts

struct UsageChartView: View {
    let data: [(date: Date, amount: Double)]

    var body: some View {
        GroupBox {
            Chart(data, id: \.date) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Spend ($)", point.amount)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(2)
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
        } label: {
            Label("Daily Spend", systemImage: "chart.bar.fill")
                .font(.caption.weight(.semibold))
        }
    }

    private var strideCount: Int {
        max(1, data.count / 6)
    }
}