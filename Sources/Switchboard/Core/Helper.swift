import Foundation

/// Runtime state of a helper, shown in the menu.
enum HelperStatus: Sendable, Equatable {
    case idle
    case running
    case stopped
    case error(String)
}

enum HelperError: Error, Sendable, Equatable, CustomStringConvertible {
    case processFailed(exitCode: Int32, message: String)
    case notConfigured

    var description: String {
        switch self {
        case .processFailed(let code, let message):
            return "Command failed (exit \(code)): \(message)"
        case .notConfigured:
            return "Not configured."
        }
    }
}

/// One toggleable background helper. The whole surface is `@MainActor`-isolated
/// so concrete helpers can hold AppKit/`@Observable` state without `Sendable`
/// gymnastics; the work they delegate to (process/AppleScript execution) is
/// what crosses threads, behind `Sendable` value seams.
@MainActor
protocol Helper: AnyObject, Identifiable {
    /// Stable identifier — also the persistence key for the enabled flag.
    var id: String { get }
    var name: String { get }
    var isEnabled: Bool { get }
    var status: HelperStatus { get }
    func start() async
    func stop() async
}

extension HelperStatus {
    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}
