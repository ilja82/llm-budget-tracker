import Foundation

enum StorageKeys {
    enum App {
        static let endpointURL           = "endpointURL"
        static let updateIntervalMinutes = "updateIntervalMinutes"
        static let displayMode           = "displayMode"
        static let dailyActivityEnabled  = "dailyActivityEnabled"
        static let dailyActivityCache    = "dailyActivity.cache"
    }

    enum DevMode {
        static let isEnabled     = "devMode.isEnabled"
        static let spend         = "devMode.spend"
        static let hasMaxBudget  = "devMode.hasMaxBudget"
        static let maxBudget     = "devMode.maxBudget"
        static let hasReset      = "devMode.hasReset"
        static let daysRemaining = "devMode.daysRemaining"
        static let totalDays     = "devMode.totalDays"
        static let unlocked      = "devMode.unlocked"
    }

    enum DevLog {
        static let requests = "devLog.requests"
    }

    enum ChartUI {
        static let unifiedChartMetric = "ui.unifiedChart.metric"
        static let unifiedChartModel  = "ui.unifiedChart.model"
        static let modelSpendRange    = "ui.modelSpend.range"
    }

    /// All keys that resetToInitialState() must wipe. Add new keys here alongside their definition.
    static let allKeys: [String] = [
        App.endpointURL, App.updateIntervalMinutes, App.displayMode,
        App.dailyActivityEnabled, App.dailyActivityCache,
        DevMode.isEnabled, DevMode.spend, DevMode.hasMaxBudget, DevMode.maxBudget,
        DevMode.hasReset, DevMode.daysRemaining, DevMode.totalDays, DevMode.unlocked,
        DevLog.requests,
        ChartUI.unifiedChartMetric, ChartUI.unifiedChartModel, ChartUI.modelSpendRange
    ]
}
