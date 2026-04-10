import Foundation
import Observation

@Observable
final class DevModeSettings {
    var isEnabled: Bool = UserDefaults.standard.bool(forKey: StorageKeys.DevMode.isEnabled) {
        didSet { UserDefaults.standard.set(isEnabled, forKey: StorageKeys.DevMode.isEnabled) }
    }

    var spend: Double = {
        let stored = UserDefaults.standard.double(forKey: StorageKeys.DevMode.spend)
        return stored > 0 ? stored : 45.50
    }() {
        didSet { UserDefaults.standard.set(spend, forKey: StorageKeys.DevMode.spend) }
    }

    var hasMaxBudget: Bool = {
        guard UserDefaults.standard.object(forKey: StorageKeys.DevMode.hasMaxBudget) != nil else { return true }
        return UserDefaults.standard.bool(forKey: StorageKeys.DevMode.hasMaxBudget)
    }() {
        didSet { UserDefaults.standard.set(hasMaxBudget, forKey: StorageKeys.DevMode.hasMaxBudget) }
    }

    var maxBudget: Double = {
        let stored = UserDefaults.standard.double(forKey: StorageKeys.DevMode.maxBudget)
        return stored > 0 ? stored : 100.00
    }() {
        didSet { UserDefaults.standard.set(maxBudget, forKey: StorageKeys.DevMode.maxBudget) }
    }

    var hasReset: Bool = {
        guard UserDefaults.standard.object(forKey: StorageKeys.DevMode.hasReset) != nil else { return true }
        return UserDefaults.standard.bool(forKey: StorageKeys.DevMode.hasReset)
    }() {
        didSet { UserDefaults.standard.set(hasReset, forKey: StorageKeys.DevMode.hasReset) }
    }

    var daysRemaining: Int = {
        let stored = UserDefaults.standard.integer(forKey: StorageKeys.DevMode.daysRemaining)
        return stored > 0 ? stored : 12
    }() {
        didSet { UserDefaults.standard.set(daysRemaining, forKey: StorageKeys.DevMode.daysRemaining) }
    }

    var totalDays: Int = {
        let stored = UserDefaults.standard.integer(forKey: StorageKeys.DevMode.totalDays)
        return stored > 0 ? stored : 30
    }() {
        didSet { UserDefaults.standard.set(totalDays, forKey: StorageKeys.DevMode.totalDays) }
    }
}
