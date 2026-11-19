import Charts
import SwiftUI

struct DashboardStatsView: View {
    let days: [DailySpendData]
    let summary: DashboardSummary

    private enum Layout {
        static let chartHeight: CGFloat = 180
        static let topModels = 6
    }

    var body: some View {
        if days.isEmpty {
            DashboardEmptyState(text: "No daily spend data for this range")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    kpiGrid
                    chartSection("Daily tokens") { tokensChart }
                    chartSection("Daily requests") { requestsChart }
                    chartSection("Spend share by model") { modelShareChart }
                    chartSection("Spend by weekday") { weekdayChart }
                }
                .padding(16)
            }
        }
    }

    // MARK: - KPI tiles

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            KPITile(title: "Total spend", value: DashboardFormat.dollars(summary.totalSpend))
            KPITile(
                title: "Avg per active day",
                value: DashboardFormat.dollars(summary.avgPerActiveDay),
                detail: "\(summary.activeDays) active days"
            )
            KPITile(
                title: "Most expensive day",
                value: summary.topDay.map { DashboardFormat.dollars($0.spend) } ?? "–",
                detail: summary.topDay.map { DashboardFormat.displayDate($0.date) }
            )
            KPITile(
                title: "Requests",
                value: summary.requests.formatted(),
                detail: "\(summary.failed.formatted()) failed"
            )
            KPITile(title: "Failure rate", value: String(format: "%.1f%%", summary.failureRate))
            KPITile(
                title: "Tokens",
                value: summary.tokens.formatted(.number.notation(.compactName)),
                detail: tokenDetail
            )
            KPITile(
                title: "Cost per 1K tokens",
                value: summary.costPer1kTokens.map { String(format: "$%.4f", $0) } ?? "–"
            )
            KPITile(title: "Top model", value: summary.topModel ?? "–")
        }
    }

    private var tokenDetail: String {
        let compact = IntegerFormatStyle<Int>().notation(.compactName)
        return "Prompt \(summary.prompt.formatted(compact)), completion \(summary.completion.formatted(compact)), "
            + "cache read \(summary.cacheRead.formatted(compact))"
    }

    private func chartSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                content()
                    .frame(height: Layout.chartHeight)
            }
        }
    }

    // MARK: - Charts

    @ViewBuilder
    private var tokensChart: some View {
        let points = DashboardStats.dailyTokens(days)
        if points.allSatisfy({ $0.value == 0 }) {
            DashboardEmptyState(text: "No token data for this range")
                .frame(maxWidth: .infinity)
        } else {
            Chart(points) { point in
                BarMark(
                    x: .value("Day", DashboardFormat.localDate(point.date) ?? Date.distantPast, unit: .day),
                    y: .value("Tokens", point.value)
                )
                .foregroundStyle(by: .value("Kind", point.kind))
            }
            .chartForegroundStyleScale(domain: [
                DailyTokenPoint.promptKind, DailyTokenPoint.completionKind, DailyTokenPoint.cacheReadKind,
            ])
            .accessibilityLabel(
                "Daily tokens. Total \(summary.tokens.formatted()): \(tokenDetail)"
            )
        }
    }

    @ViewBuilder
    private var requestsChart: some View {
        let points = DashboardStats.dailyRequests(days)
        if points.allSatisfy({ $0.ok == 0 && $0.failed == 0 }) {
            DashboardEmptyState(text: "No request data for this range")
                .frame(maxWidth: .infinity)
        } else {
            Chart {
                ForEach(points) { point in
                    let day = DashboardFormat.localDate(point.date) ?? Date.distantPast
                    BarMark(x: .value("Day", day, unit: .day), y: .value("Requests", point.ok))
                        .foregroundStyle(by: .value("Status", "Successful"))
                    BarMark(x: .value("Day", day, unit: .day), y: .value("Requests", point.failed))
                        .foregroundStyle(by: .value("Status", "Failed"))
                }
            }
            .chartForegroundStyleScale(["Successful": Color.green, "Failed": Color.red])
            .accessibilityLabel(
                "Daily requests. \(summary.requests.formatted()) total, \(summary.failed.formatted()) failed, "
                    + String(format: "failure rate %.1f%%", summary.failureRate)
            )
        }
    }

    @ViewBuilder
    private var modelShareChart: some View {
        let share = DashboardStats.modelShare(days, top: Layout.topModels)
        let total = share.reduce(0) { $0 + $1.spend }
        if share.isEmpty || total <= 0 {
            DashboardEmptyState(text: "No per-model data for this range")
                .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .center, spacing: 16) {
                Chart(share) { part in
                    SectorMark(angle: .value("Spend", part.spend), innerRadius: .ratio(0.55), angularInset: 1)
                        .foregroundStyle(by: .value("Model", part.name))
                }
                .chartLegend(.hidden)
                .frame(width: Layout.chartHeight)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(share) { part in
                        HStack {
                            Text(part.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(DashboardFormat.dollars(part.spend))
                                .monospacedDigit()
                            Text(DashboardFormat.share(part.spend, of: total))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 56, alignment: .trailing)
                        }
                        .font(.caption)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Spend share by model. "
                    + share.map { "\($0.name) \(DashboardFormat.share($0.spend, of: total))" }.joined(separator: ", ")
            )
        }
    }

    @ViewBuilder
    private var weekdayChart: some View {
        let weekdays = DashboardStats.weekdaySpend(days, calendar: .current)
        if weekdays.allSatisfy({ $0.spend == 0 }) {
            DashboardEmptyState(text: "No spend data for this range")
                .frame(maxWidth: .infinity)
        } else {
            Chart(weekdays) { entry in
                BarMark(x: .value("Weekday", entry.label), y: .value("Spend", entry.spend))
                    .foregroundStyle(Color.accentColor)
                    .cornerRadius(2)
            }
            .chartXScale(domain: WeekdaySpend.labels)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(String(format: "$%.0f", val))
                        }
                    }
                }
            }
            .accessibilityLabel(
                "Spend by weekday. "
                    + weekdays.map { "\($0.label) \(DashboardFormat.dollars($0.spend))" }.joined(separator: ", ")
            )
        }
    }
}

struct KPITile: View {
    let title: String
    let value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}
