import Foundation

enum StorageKeys {
    enum App {
        static let endpointURL           = "endpointURL"
        static let updateIntervalMinutes = "updateIntervalMinutes"
        static let displayMode           = "displayMode"
        static let iconStyle             = "iconStyle"
        static let dailyActivityEnabled  = "dailyActivityEnabled"
        static let dailyActivityCache    = "dailyActivity.cache"
        static let showRemaining         = "showRemaining"
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

    enum Update {
        static let lastCheck         = "update.lastCheck"
        static let latestVersion     = "update.latestVersion"
        static let latestPublishedAt = "update.latestPublishedAt"
        static let dismissedVersion  = "update.dismissedVersion"
        static let checkEnabled      = "update.checkEnabled"
    }

    /// All keys that resetToInitialState() must wipe. Add new keys here alongside their definition.
    static let allKeys: [String] = [
<<<<<<< 9764b8266f5678d2968b02f1209979f16df44a34
        App.endpointURL, App.updateIntervalMinutes, App.displayMode,
        App.dailyActivityEnabled, App.dailyActivityCache, App.showRemaining,
=======
        App.endpointURL, App.updateIntervalMinutes, App.displayMode, App.iconStyle,
        App.dailyActivityEnabled, App.dailyActivityCache,
>>>>>>> c6d744a184bade792f5dd8203ff7584ffdad2aee
        DevMode.isEnabled, DevMode.spend, DevMode.hasMaxBudget, DevMode.maxBudget,
        DevMode.hasReset, DevMode.daysRemaining, DevMode.totalDays, DevMode.unlocked,
        DevLog.requests,
        ChartUI.unifiedChartMetric, ChartUI.unifiedChartModel, ChartUI.modelSpendRange,
        Update.lastCheck, Update.latestVersion, Update.latestPublishedAt, Update.dismissedVersion,
        Update.checkEnabled
    ]

    static func loadShowRemaining(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: App.showRemaining)
    }

    static func saveShowRemaining(_ value: Bool, to defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: App.showRemaining)
    }
}
