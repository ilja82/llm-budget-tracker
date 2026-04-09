import Foundation

enum StorageKeys {
    enum App {
        static let endpointURL           = "endpointURL"
        static let updateIntervalMinutes = "updateIntervalMinutes"
        static let displayMode           = "displayMode"
        static let chartDays             = "chartDays"
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

    /// All keys that resetToInitialState() must wipe. Add new keys here alongside their definition.
    static let allKeys: [String] = [
        App.endpointURL, App.updateIntervalMinutes, App.displayMode, App.chartDays,
        DevMode.isEnabled, DevMode.spend, DevMode.hasMaxBudget, DevMode.maxBudget,
        DevMode.hasReset, DevMode.daysRemaining, DevMode.totalDays, DevMode.unlocked,
        DevLog.requests,
    ]
}
