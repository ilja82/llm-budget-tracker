import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case dollar = "dollar"
    case percentage = "percentage"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dollar: return "Amount"
        case .percentage: return "Percent"
        }
    }
}