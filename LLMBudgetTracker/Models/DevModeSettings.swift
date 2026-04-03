import Foundation
import Observation

@Observable
final class DevModeSettings {

    var isEnabled: Bool = UserDefaults.standard.bool(forKey: "devMode.isEnabled") {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "devMode.isEnabled") }
    }

    var spend: Double = {
        let v = UserDefaults.standard.double(forKey: "devMode.spend")
        return v > 0 ? v : 45.50
    }() {
        didSet { UserDefaults.standard.set(spend, forKey: "devMode.spend") }
    }

    var hasMaxBudget: Bool = {
        guard UserDefaults.standard.object(forKey: "devMode.hasMaxBudget") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "devMode.hasMaxBudget")
    }() {
        didSet { UserDefaults.standard.set(hasMaxBudget, forKey: "devMode.hasMaxBudget") }
    }

    var maxBudget: Double = {
        let v = UserDefaults.standard.double(forKey: "devMode.maxBudget")
        return v > 0 ? v : 100.00
    }() {
        didSet { UserDefaults.standard.set(maxBudget, forKey: "devMode.maxBudget") }
    }

    var hasReset: Bool = {
        guard UserDefaults.standard.object(forKey: "devMode.hasReset") != nil else { return true }
        return UserDefaults.standard.bool(forKey: "devMode.hasReset")
    }() {
        didSet { UserDefaults.standard.set(hasReset, forKey: "devMode.hasReset") }
    }

    var daysRemaining: Int = {
        let v = UserDefaults.standard.integer(forKey: "devMode.daysRemaining")
        return v > 0 ? v : 12
    }() {
        didSet { UserDefaults.standard.set(daysRemaining, forKey: "devMode.daysRemaining") }
    }

    var totalDays: Int = {
        let v = UserDefaults.standard.integer(forKey: "devMode.totalDays")
        return v > 0 ? v : 30
    }() {
        didSet { UserDefaults.standard.set(totalDays, forKey: "devMode.totalDays") }
    }
}