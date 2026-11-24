import Foundation

enum MenuBarLinePosition: String, CaseIterable, Identifiable {
    case below
    case above

    var id: String { rawValue }

    var label: String {
        switch self {
        case .below: return "Below"
        case .above: return "Above"
        }
    }

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? .below
    }

    static func load(from defaults: UserDefaults = .standard) -> Self {
        Self(storedValue: defaults.string(forKey: StorageKeys.App.linePosition))
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: StorageKeys.App.linePosition)
    }
}
