import Foundation
import Observation

/// A helper backed by a launchd user agent. Enabling bootstraps the job (launchd
/// then supervises it, including `KeepAlive` restarts); disabling boots it out.
/// The job keeps running even if Switchboard quits — launchd owns its lifecycle.
@MainActor
@Observable
final class LaunchAgentHelper: Helper {
    let id: String
    let name: String

    private let label: String
    private let plistPath: String
    private let launchctl: LaunchctlClient

    private(set) var isEnabled = false
    private(set) var status: HelperStatus = .idle

    init(config: LaunchAgentConfig, launchctl: LaunchctlClient) {
        self.id = config.id
        self.name = config.name
        self.label = config.label
        self.plistPath = config.plistPath
        self.launchctl = launchctl
    }

    func start() async {
        isEnabled = true
        do {
            try await launchctl.start(label: label, plistPath: plistPath)
            status = .running
            Log.launchctl.info("Started \(self.label, privacy: .public)")
        } catch {
            status = .error(Self.message(error))
            Log.launchctl.error("Start failed for \(self.label, privacy: .public): \(Self.message(error), privacy: .public)")
        }
    }

    func stop() async {
        isEnabled = false
        do {
            try await launchctl.stop(label: label)
            status = .stopped
            Log.launchctl.info("Stopped \(self.label, privacy: .public)")
        } catch {
            status = .error(Self.message(error))
            Log.launchctl.error("Stop failed for \(self.label, privacy: .public): \(Self.message(error), privacy: .public)")
        }
    }

    private static func message(_ error: Error) -> String {
        String(describing: error)
    }
}
