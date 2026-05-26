import Foundation

/// Top-level shape of `helpers.json`. Helper *types* live in code; this file
/// describes which *instances* exist on a given machine. Nothing here is
/// committed to the repo — see `helpers.example.json` for the documented shape.
struct AppConfig: Codable, Sendable, Equatable {
    var launchAgents: [LaunchAgentConfig]
    var autoLightDisplay: AutoLightDisplayConfig?

    static let empty = AppConfig(launchAgents: [], autoLightDisplay: nil)

    init(launchAgents: [LaunchAgentConfig] = [], autoLightDisplay: AutoLightDisplayConfig? = nil) {
        self.launchAgents = launchAgents
        self.autoLightDisplay = autoLightDisplay
    }
}

/// A launchd user agent the app can switch on/off.
struct LaunchAgentConfig: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let label: String
    let plistPath: String
}

/// Configuration for the built-in auto-light helper. Both fields default so a
/// present-but-sparse object still decodes.
struct AutoLightDisplayConfig: Codable, Sendable, Equatable {
    /// `"any-external"` or a specific display name.
    var match: String
    var onDisconnect: DisconnectBehavior

    init(match: String = "any-external", onDisconnect: DisconnectBehavior = .restore) {
        self.match = match
        self.onDisconnect = onDisconnect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        match = try container.decodeIfPresent(String.self, forKey: .match) ?? "any-external"
        onDisconnect = try container.decodeIfPresent(DisconnectBehavior.self, forKey: .onDisconnect) ?? .restore
    }

    var displayMatch: DisplayMatch {
        match == "any-external" ? .anyExternal : .named(match)
    }
}

/// What to do when the trigger display disconnects.
enum DisconnectBehavior: String, Codable, Sendable, Equatable {
    /// Restore the Light/Dark value that was active before we forced Light.
    case restore
    case dark
    case light
    /// Leave the appearance untouched.
    case none
}
