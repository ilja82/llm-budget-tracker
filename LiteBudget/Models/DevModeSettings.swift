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

    var maxBudget: Double = {
        let v = UserDefaults.standard.double(forKey: "devMode.maxBudget")
        return v > 0 ? v : 100.00
    }() {
        didSet { UserDefaults.standard.set(maxBudget, forKey: "devMode.maxBudget") }
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