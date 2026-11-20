import SwiftUI

struct DailyCostDetailView: View {
    static let windowID = "daily-cost-details"

    enum Page: String, CaseIterable, Identifiable {
        case dailyCosts
        case statistics

        var id: String { rawValue }

        var label: String {
            switch self {
            case .dailyCosts: return "Daily costs"
            case .statistics: return "Statistics"
            }
        }
    }

    @Environment(BudgetViewModel.self) private var viewModel
    @AppStorage(StorageKeys.ChartUI.modelSpendRange) private var rangeRaw: String = ModelRange.thisMonth.rawValue
    @State private var page: Page = .dailyCosts

    private var range: ModelRange {
        ModelRange(rawValue: rangeRaw) ?? .thisMonth
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()
            let now = Date()
            switch page {
            case .dailyCosts:
                DailyCostListView(rows: DailyCostBreakdown.rows(from: viewModel.dailyActivity, range: range, now: now))
            case .statistics:
                DashboardStatsView(
                    days: DashboardStats.days(viewModel.dailyActivity, range: range, now: now),
                    summary: DashboardStats.summary(from: viewModel.dailyActivity, range: range, now: now)
                )
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer()
            Picker("Range", selection: Binding(
                get: { range },
                set: { rangeRaw = $0.rawValue }
            )) {
                ForEach(ModelRange.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }
}

struct DailyCostListView: View {
    let rows: [DailyCostRow]

    var body: some View {
        if rows.isEmpty {
            DashboardEmptyState(text: "No daily spend data for this range")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                rangeHeader
                Divider()
                List {
                    ForEach(rows) { row in
                        DailyCostRowView(row: row)
                    }
                }
            }
        }
    }

    private var rangeHeader: some View {
        HStack {
            Text("Total for range")
                .foregroundStyle(.secondary)
            Spacer()
            Text(DashboardFormat.dollars(DailyCostBreakdown.rangeTotal(rows)))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct DailyCostRowView: View {
    let row: DailyCostRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DashboardFormat.displayDate(row.date))
                    .font(.headline)
                if row.partsExceedTotal {
                    Text("parts ≠ total")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.orange.opacity(0.15), in: Capsule())
                        .help("The per-model amounts add up to more than the day total reported by LiteLLM.")
                }
                Spacer()
                Text(DashboardFormat.dollars(row.total))
                    .font(.headline)
                    .monospacedDigit()
            }
            ForEach(row.parts) { part in
                HStack {
                    Text(part.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(DashboardFormat.dollars(part.spend))
                        .monospacedDigit()
                    Text(DashboardFormat.share(part.spend, of: row.total))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                }
                .font(.callout)
                .padding(.leading, 12)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let parts = row.parts
            .map { "\($0.name) \(DashboardFormat.dollars($0.spend))" }
            .joined(separator: ", ")
        var label = "\(DashboardFormat.displayDate(row.date)): total \(DashboardFormat.dollars(row.total))"
        if !parts.isEmpty {
            label += "; \(parts)"
        }
        if row.partsExceedTotal {
            label += ". Parts exceed the total"
        }
        return label
    }
}

struct DashboardEmptyState: View {
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

enum DashboardFormat {
    static func dollars(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    static func share(_ value: Double, of total: Double) -> String {
        guard total > 0 else { return "–" }
        return String(format: "%.1f%%", value / total * 100)
    }

    static func localDate(_ value: String) -> Date? {
        DashboardStats.date(from: value, calendar: .current)
    }

    static func displayDate(_ value: String) -> String {
        guard let date = localDate(value) else { return value }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
    }
}
