import AppKit

/// How the auto-light helper decides whether the "trigger" display is present.
enum DisplayMatch: Sendable, Equatable {
    /// Any display that is not the built-in panel.
    case anyExternal
    /// A display whose `localizedName` equals this string (e.g. "DELL U3223QE").
    case named(String)
}

/// Observes display configuration changes and reports whether a matching
/// external display is currently attached. A protocol so the auto-light helper
/// can be tested without real hardware.
@MainActor
protocol DisplayWatching {
    func isConnected(matching match: DisplayMatch) -> Bool
    /// Emits once per display reconfiguration (connect, disconnect, rearrange).
    func events() -> AsyncStream<Void>
}

@MainActor
struct ScreenObserver: DisplayWatching {
    func isConnected(matching match: DisplayMatch) -> Bool {
        let screens = NSScreen.screens
        switch match {
        case .anyExternal:
            return screens.contains { !$0.isBuiltin }
        case .named(let name):
            return screens.contains { $0.localizedName == name }
        }
    }

    func events() -> AsyncStream<Void> {
        AsyncStream { continuation in
            // The token is only ever touched by NotificationCenter, which is
            // thread-safe; the explicit annotation lets it cross into the
            // @Sendable termination closure.
            nonisolated(unsafe) let token = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { _ in
                continuation.yield(())
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(token)
            }
        }
    }
}

extension NSScreen {
    /// True when this screen is the built-in (laptop) display.
    var isBuiltin: Bool {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
    }
}
