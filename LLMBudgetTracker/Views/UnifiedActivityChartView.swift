import Charts
import SwiftUI

struct UnifiedActivityChartView: View {
    @Environment(BudgetViewModel.self) private var viewModel
    @AppStorage(StorageKeys.ChartUI.unifiedChartMetric) private var metricRaw: String = MetricKind.spend.rawValue
    @AppStorage(StorageKeys.ChartUI.unifiedChartModel) private var selectedModel: String = ""

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Convert a UTC "yyyy-MM-dd" day key into local midnight so chart bars align
    /// with `Calendar.current` .day buckets and with `currentPeriodStart` / safe lines.
    private static func localMidnight(from ymd: String) -> Date? {
        guard let utc = dateFmt.date(from: ymd) else { return nil }
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let comps = utcCal.dateComponents([.year, .month, .day], from: utc)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = .current
        return localCal.date(from: comps)
    }

    private var metric: MetricKind {
        MetricKind(rawValue: metricRaw) ?? .spend
    }

    private var modelFilter: String? {
        selectedModel.isEmpty ? nil : selectedModel
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                controlsRow
                chartBody
            }
        }
    }

    // MARK: - Controls

    private var controlsRow: some View {
        HStack(spacing: 8) {
            Picker("Metric", selection: Binding(
                get: { metric },
                set: { metricRaw = $0.rawValue }
            )) {
                ForEach(MetricKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .labelsHidden()
            .opacity(0.85)

            Spacer(minLength: 8)

            modelMenu
        }
    }

    @ViewBuilder
    private var modelMenu: some View {
        let models = viewModel.availableModelGroups
        if models.isEmpty {
            EmptyView()
        } else {
            Menu {
                Button {
                    selectedModel = ""
                } label: {
                    if selectedModel.isEmpty {
                        Label("All Models", systemImage: "checkmark")
                    } else {
                        Text("All Models")
                    }
                }
                Divider()
                ForEach(models, id: \.self) { name in
                    Button {
                        selectedModel = name
                    } label: {
                        if selectedModel == name {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedModel.isEmpty ? "All Models" : selectedModel)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartBody: some View {
        switch metric {
        case .spend:
            spendChart
        case .tokens:
            tokensChart
        case .requests:
            requestsChart
        }
    }

    // MARK: Spend

    private struct SpendPoint: Identifiable {
        let id: String
        let date: Date
        let amount: Double
    }

    private var spendPoints: [SpendPoint] {
        viewModel.dailyActivity
            .sorted { $0.date < $1.date }
            .compactMap { entry in
                guard let date = Self.localMidnight(from: entry.date) else { return nil }
                let amount = viewModel.metrics(for: entry, model: modelFilter).spend
                return SpendPoint(id: entry.date, date: date, amount: amount)
            }
    }

    // MARK: - Shared scale & highlight

    /// Max daily spend across all models — keeps y-scale fixed when filtering.
    private var allModelsSpendMax: Double {
        viewModel.dailyActivity
            .map { viewModel.metrics(for: $0, model: nil).spend }
            .max() ?? 0
    }

    /// Max daily stacked token total across all models.
    private var allModelsTokenMax: Int {
        viewModel.dailyActivity.map { entry in
            let metrics = viewModel.metrics(for: entry, model: nil)
            return metrics.promptTokens + metrics.completionTokens
                + metrics.cacheReadInputTokens + metrics.cacheCreationInputTokens
        }.max() ?? 0
    }

    /// Max daily stacked request total across all models.
    private var allModelsRequestMax: Int {
        viewModel.dailyActivity.map { entry in
            let metrics = viewModel.metrics(for: entry, model: nil)
            return metrics.successfulRequests + metrics.failedRequests
        }.max() ?? 0
    }

    /// Billing-period highlight. Ends at start-of-tomorrow so today's bar is fully covered.
    @ChartContentBuilder
    private var periodHighlight: some ChartContent {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        if let start = viewModel.currentPeriodStart, start < end {
            RectangleMark(
                xStart: .value("Period start", start),
                xEnd: .value("Period end", end)
            )
            .foregroundStyle(Color.accentColor.opacity(0.10))
        }
    }

    private var spendChart: some View {
        let points = spendPoints
        let safeLine = viewModel.safeSpendLine
        let safeLimitByDay: [Date: Double] = {
            var dict: [Date: Double] = [:]
            let cal = Calendar.current
            for point in safeLine { dict[cal.startOfDay(for: point.date)] = point.amount }
            return dict
        }()
        let safeMax = safeLine.map(\.amount).max() ?? 0
        let spendYMax = max(max(allModelsSpendMax, safeMax) * 1.05, 0.01)
        let minBarAmount = spendYMax * 0.005
        return Chart {
            periodHighlight

            ForEach(points) { point in
                // Floor non-zero bars to a visible minimum so activity is never rendered as empty.
                let displayAmount = point.amount > 0 ? max(point.amount, minBarAmount) : 0
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Spend ($)", displayAmount)
                )
                .foregroundStyle(barColor(for: point, safeLimitByDay: safeLimitByDay))
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
        .chartXAxis { dayAxis(points: points.map(\.date) + safeLine.map(\.date)) }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text(String(format: "$%.0f", val)).font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: 0 ... spendYMax)
        .frame(height: 180)
        .accessibilityLabel(spendAccessibilityLabel(points: points))
    }

    private func barColor(for point: SpendPoint, safeLimitByDay: [Date: Double]) -> Color {
        let overspendThreshold = 1.2
        let key = Calendar.current.startOfDay(for: point.date)
        guard let safe = safeLimitByDay[key], safe > 0 else {
            return Color.accentColor
        }
        if point.amount > safe * overspendThreshold { return .red }
        if point.amount > safe { return .orange }
        return Color.accentColor
    }

    private func spendAccessibilityLabel(points: [SpendPoint]) -> String {
        guard !points.isEmpty else { return "No daily spend data available" }
        let total = points.reduce(0.0) { $0 + $1.amount }
        let peak = points.max(by: { $0.amount < $1.amount })
        return String(format: "Daily spend over %d days. Total: $%.2f. Peak day: $%.2f.",
                      points.count, total, peak?.amount ?? 0)
    }

    // MARK: Tokens

    private struct TokenPoint: Identifiable {
        let id: String
        let date: Date
        let type: String
        let tokens: Int
    }

    private var tokenPoints: [TokenPoint] {
        var result: [TokenPoint] = []
        for entry in viewModel.dailyActivity.sorted(by: { $0.date < $1.date }) {
            guard let date = Self.localMidnight(from: entry.date) else { continue }
            let metrics = viewModel.metrics(for: entry, model: modelFilter)
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
        return result
    }

    private var tokensChart: some View {
        let points = tokenPoints
        let tokenYMax = max(allModelsTokenMax, 1)
        let minTokenBar = max(Int((Double(tokenYMax) * 0.005).rounded(.up)), 1)
        return Chart {
            periodHighlight
            ForEach(points) { point in
                let displayTokens = point.tokens > 0 ? max(point.tokens, minTokenBar) : 0
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Tokens", displayTokens)
                )
                .foregroundStyle(by: .value("Type", point.type))
            }
        }
        .chartXAxis { dayAxis(points: points.map(\.date)) }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let val = value.as(Int.self) {
                        Text(formatCount(val)).font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: 0 ... tokenYMax)
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 180)
        .accessibilityLabel(tokenAccessibilityLabel(points: points))
    }

    private func tokenAccessibilityLabel(points: [TokenPoint]) -> String {
        guard !points.isEmpty else { return "No token data available" }
        let days = Set(points.map { Calendar.current.startOfDay(for: $0.date) }).count
        let total = points.reduce(0) { $0 + $1.tokens }
        return "Token usage over \(days) days. Total: \(formatCount(total))."
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.0fK", Double(count) / 1_000) }
        return "\(count)"
    }

    // MARK: Requests

    private struct RequestPoint: Identifiable {
        let id: String
        let date: Date
        let type: String
        let count: Int
    }

    private var requestPoints: [RequestPoint] {
        var result: [RequestPoint] = []
        for entry in viewModel.dailyActivity.sorted(by: { $0.date < $1.date }) {
            guard let date = Self.localMidnight(from: entry.date) else { continue }
            let metrics = viewModel.metrics(for: entry, model: modelFilter)
            result.append(.init(
                id: "\(entry.date)-success", date: date, type: "Success", count: metrics.successfulRequests))
            result.append(.init(
                id: "\(entry.date)-failed", date: date, type: "Failed", count: metrics.failedRequests))
        }
        return result
    }

    private var requestsChart: some View {
        let points = requestPoints
        let requestYMax = max(allModelsRequestMax, 1)
        let minRequestBar = max(Int((Double(requestYMax) * 0.005).rounded(.up)), 1)
        return Chart {
            periodHighlight
            ForEach(points) { point in
                // swiftlint:disable:next empty_count
                let displayCount = point.count > 0 ? max(point.count, minRequestBar) : 0
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Requests", displayCount)
                )
                .foregroundStyle(by: .value("Type", point.type))
            }
        }
        .chartForegroundStyleScale([
            "Success": Color.green,
            "Failed": Color.red
        ])
        .chartXAxis { dayAxis(points: points.map(\.date)) }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let val = value.as(Int.self) {
                        Text("\(val)").font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: 0 ... requestYMax)
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 180)
        .accessibilityLabel(requestAccessibilityLabel(points: points))
    }

    private func requestAccessibilityLabel(points: [RequestPoint]) -> String {
        guard !points.isEmpty else { return "No request data available" }
        let success = points.filter { $0.type == "Success" }.reduce(0) { $0 + $1.count }
        let failed = points.filter { $0.type == "Failed" }.reduce(0) { $0 + $1.count }
        let days = Set(points.map { Calendar.current.startOfDay(for: $0.date) }).count
        return "API requests over \(days) days. \(success) successful, \(failed) failed."
    }

    // MARK: - Axis helper

    private func dayAxis(points: [Date]) -> some AxisContent {
        let stride = strideCount(for: points)
        return AxisMarks(values: .stride(by: .day, count: stride)) { _ in
            AxisValueLabel(format: .dateTime.month().day(), centered: true)
                .font(.caption2)
        }
    }

    private func strideCount(for dates: [Date]) -> Int {
        guard let earliest = dates.min(), let latest = dates.max() else { return 1 }
        let spanDays = max(1, Calendar.current.dateComponents([.day], from: earliest, to: latest).day ?? 1)
        return max(1, spanDays / 5)
    }
}
