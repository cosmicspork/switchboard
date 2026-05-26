import Foundation
import Observation

/// In-process helper that forces Light mode while a matching external display is
/// attached, and restores the prior appearance when it disconnects. Motivation:
/// some external panels flicker under dark content; Light mode avoids it.
///
/// The app must be running for this helper to work (it has no separate process
/// to supervise). The connect/disconnect decision is the pure, testable
/// `evaluate(...)`; everything else is wiring.
@MainActor
@Observable
final class AutoLightDisplayHelper: Helper {
    static let helperID = "auto-light-display"
    let id = AutoLightDisplayHelper.helperID
    let name = "Auto Light on External Display"

    private let match: DisplayMatch
    private let onDisconnect: DisconnectBehavior
    private let appearance: AppearanceControlling
    private let watcher: any DisplayWatching

    private(set) var isEnabled = false
    private(set) var status: HelperStatus = .idle

    private var watchTask: Task<Void, Never>?
    private var previouslyConnected = false
    /// Appearance captured before we first forced Light, restored on disconnect.
    private var capturedDarkMode: Bool?

    init(config: AutoLightDisplayConfig, appearance: AppearanceControlling, watcher: any DisplayWatching) {
        self.match = config.displayMatch
        self.onDisconnect = config.onDisconnect
        self.appearance = appearance
        self.watcher = watcher
    }

    func start() async {
        guard watchTask == nil else { return }
        isEnabled = true
        status = .running

        // Treat current connectivity as a fresh "change" so an already-attached
        // display forces Light immediately on enable.
        previouslyConnected = false
        await handleChange(connected: watcher.isConnected(matching: match))

        let stream = watcher.events()
        watchTask = Task { [weak self] in
            for await _ in stream {
                guard let self else { break }
                await self.handleChange(connected: self.watcher.isConnected(matching: self.match))
            }
        }
    }

    func stop() async {
        watchTask?.cancel()
        watchTask = nil
        isEnabled = false
        status = .stopped
    }

    private func handleChange(connected: Bool) async {
        defer { previouslyConnected = connected }
        guard let command = Self.evaluate(
            connected: connected,
            previouslyConnected: previouslyConnected,
            onDisconnect: onDisconnect
        ) else { return }
        await apply(command)
    }

    private func apply(_ command: AppearanceCommand) async {
        do {
            switch command {
            case .forceLight:
                if capturedDarkMode == nil {
                    capturedDarkMode = try await appearance.isDarkMode()
                }
                try await appearance.setDarkMode(false)
            case .restorePrevious:
                if let previous = capturedDarkMode {
                    try await appearance.setDarkMode(previous)
                }
                capturedDarkMode = nil
            case .forceDark:
                try await appearance.setDarkMode(true)
                capturedDarkMode = nil
            }
            status = .running
        } catch {
            status = .error(String(describing: error))
            Log.appearance.error("Appearance change failed: \(String(describing: error), privacy: .public)")
        }
    }

    enum AppearanceCommand: Sendable, Equatable {
        case forceLight
        case restorePrevious
        case forceDark
    }

    /// Pure decision logic: given the new and previous connectivity, what (if
    /// anything) should happen to the system appearance. `nonisolated` because
    /// it touches no actor state — this keeps it callable (and unit-testable)
    /// from any context.
    nonisolated static func evaluate(
        connected: Bool,
        previouslyConnected: Bool,
        onDisconnect: DisconnectBehavior
    ) -> AppearanceCommand? {
        switch (connected, previouslyConnected) {
        case (true, false):
            return .forceLight
        case (false, true):
            switch onDisconnect {
            case .restore: return .restorePrevious
            case .dark: return .forceDark
            case .light: return .forceLight
            case .none: return nil
            }
        default:
            return nil
        }
    }
}
