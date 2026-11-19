import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case bar
    case ring
    case dot
    case textOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bar: return "Bar"
        case .ring: return "Ring"
        case .dot: return "Dot"
        case .textOnly: return "Text only"
        }
    }

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? .bar
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(storedValue: defaults.string(forKey: StorageKeys.App.iconStyle))
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: StorageKeys.App.iconStyle)
    }
}
