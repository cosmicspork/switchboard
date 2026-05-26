import Foundation

enum ConfigError: Error, CustomStringConvertible {
    case decode(String)
    var description: String {
        switch self {
        case .decode(let message): return "Could not read helpers.json: \(message)"
        }
    }
}

/// Locates and decodes `helpers.json`.
///
/// A missing file is *not* an error — it returns `nil` so the app runs with no
/// configured LaunchAgent helpers. A present-but-malformed file throws, so the
/// problem can be surfaced in the menu rather than silently swallowed.
enum ConfigLoader {
    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("com.cosmicspork.switchboard", isDirectory: true)
            .appendingPathComponent("helpers.json", isDirectory: false)
    }

    static func load(from url: URL = defaultURL, fileManager: FileManager = .default) throws -> AppConfig? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ConfigError.decode(error.localizedDescription)
        }

        do {
            var config = try JSONDecoder().decode(AppConfig.self, from: data)
            config.launchAgents = config.launchAgents.map {
                LaunchAgentConfig(id: $0.id, name: $0.name, label: $0.label,
                                  plistPath: expandingTilde($0.plistPath))
            }
            return config
        } catch let error as DecodingError {
            throw ConfigError.decode(Self.describe(error))
        }
    }

    static func expandingTilde(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _): return "missing key '\(key.stringValue)'"
        case .typeMismatch(_, let ctx), .valueNotFound(_, let ctx): return ctx.debugDescription
        case .dataCorrupted(let ctx): return ctx.debugDescription
        @unknown default: return String(describing: error)
        }
    }
}
