import Foundation

enum AppearanceError: Error, Sendable, Equatable, CustomStringConvertible {
    /// macOS denied (or has not yet granted) permission to control System Events.
    case permissionDenied(String)
    case scriptFailed(String)

    var description: String {
        switch self {
        case .permissionDenied:
            return "Automation permission needed — allow Switchboard to control "
                + "System Events in System Settings → Privacy & Security → Automation."
        case .scriptFailed(let message):
            return "Appearance change failed: \(message)"
        }
    }
}

/// Reads and sets the system Light/Dark appearance.
protocol AppearanceControlling: Sendable {
    func isDarkMode() async throws -> Bool
    func setDarkMode(_ on: Bool) async throws
}

/// Drives appearance through `osascript` → System Events. `osascript` (rather
/// than `NSAppleScript`) keeps the call off the main thread and behind the same
/// `ProcessRunning` seam the rest of the app uses, so it is testable.
///
/// Note: this toggles the binary Dark/Light flag. macOS scheduled "Auto"
/// appearance has no public AppleScript setter, so callers can capture and
/// restore the Dark/Light value exactly, but cannot restore "Auto".
struct AppearanceController: AppearanceControlling {
    private let runner: ProcessRunning
    private let osascript = URL(fileURLWithPath: "/usr/bin/osascript")

    init(runner: ProcessRunning) {
        self.runner = runner
    }

    func isDarkMode() async throws -> Bool {
        let result = try await runner.run(osascript, [
            "-e", "tell application \"System Events\" to tell appearance preferences to get dark mode",
        ])
        try Self.throwIfFailed(result)
        return result.trimmedStdout == "true"
    }

    func setDarkMode(_ on: Bool) async throws {
        let result = try await runner.run(osascript, [
            "-e", "tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)",
        ])
        try Self.throwIfFailed(result)
    }

    static func throwIfFailed(_ result: ProcessResult) throws {
        guard result.exitCode != 0 else { return }
        let stderr = result.stderr.lowercased()
        if stderr.contains("-1743") || stderr.contains("not authorized") || stderr.contains("not allowed") {
            throw AppearanceError.permissionDenied(result.stderr)
        }
        throw AppearanceError.scriptFailed(result.stderr)
    }
}
