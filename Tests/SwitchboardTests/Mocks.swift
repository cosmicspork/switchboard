import Foundation
@testable import Switchboard

/// A `ProcessRunning` that returns a scripted result based on the argv. Stateless
/// (decides purely from arguments) so it is safe to call from any executor.
struct ScriptedRunner: ProcessRunning {
    let handler: @Sendable ([String]) -> ProcessResult

    init(_ handler: @escaping @Sendable ([String]) -> ProcessResult) {
        self.handler = handler
    }

    func run(_ executable: URL, _ arguments: [String]) async throws -> ProcessResult {
        handler(arguments)
    }
}

/// Records the appearance calls made against it; used to assert what the
/// auto-light helper did.
@MainActor
final class MockAppearance: AppearanceControlling {
    var currentDark: Bool
    var failure: AppearanceError?
    private(set) var setCalls: [Bool] = []

    init(currentDark: Bool = true) {
        self.currentDark = currentDark
    }

    nonisolated func isDarkMode() async throws -> Bool {
        try await MainActor.run {
            if let failure { throw failure }
            return currentDark
        }
    }

    nonisolated func setDarkMode(_ on: Bool) async throws {
        try await MainActor.run {
            if let failure { throw failure }
            setCalls.append(on)
            currentDark = on
        }
    }
}

/// A `DisplayWatching` whose connectivity is set directly by the test.
@MainActor
final class MockDisplayWatcher: DisplayWatching {
    var connected = false

    func isConnected(matching match: DisplayMatch) -> Bool { connected }

    func events() -> AsyncStream<Void> {
        // Never emits — tests drive behavior through `start()` and direct
        // connectivity changes, not the live stream.
        AsyncStream { _ in }
    }
}
