import Foundation
import Observation

@Observable
final class DevModeSettings {

    var isEnabled: Bool = UserDefaults.standard.bool(forKey: StorageKeys.DevMode.isEnabled) {
        didSet { UserDefaults.standard.set(isEnabled, forKey: StorageKeys.DevMode.isEnabled) }
    }

    var spend: Double = {
        let v = UserDefaults.standard.double(forKey: StorageKeys.DevMode.spend)
        return v > 0 ? v : 45.50
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
        let v = UserDefaults.standard.double(forKey: StorageKeys.DevMode.maxBudget)
        return v > 0 ? v : 100.00
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
        let v = UserDefaults.standard.integer(forKey: StorageKeys.DevMode.daysRemaining)
        return v > 0 ? v : 12
    }() {
        didSet { UserDefaults.standard.set(daysRemaining, forKey: StorageKeys.DevMode.daysRemaining) }
    }

    var totalDays: Int = {
        let v = UserDefaults.standard.integer(forKey: StorageKeys.DevMode.totalDays)
        return v > 0 ? v : 30
    }() {
        didSet { UserDefaults.standard.set(totalDays, forKey: StorageKeys.DevMode.totalDays) }
    }
}