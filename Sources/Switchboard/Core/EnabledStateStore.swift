import Foundation

/// Persists each helper's enabled flag in `UserDefaults`, keyed by helper id.
/// Used only from the main actor; `UserDefaults` is injectable so tests can use
/// a throwaway suite.
struct EnabledStateStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(id: String) -> Bool {
        defaults.bool(forKey: Self.key(id))
    }

    func setEnabled(_ on: Bool, id: String) {
        defaults.set(on, forKey: Self.key(id))
    }

    static func key(_ id: String) -> String { "helper.enabled.\(id)" }
}
