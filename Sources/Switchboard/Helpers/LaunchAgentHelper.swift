import Foundation
import Observation

/// A helper backed by a launchd user agent. Enabling bootstraps the job (launchd
/// then supervises it, including `KeepAlive` restarts); disabling boots it out.
/// The job keeps running even if Switchboard quits — launchd owns its lifecycle.
@MainActor
@Observable
final class LaunchAgentHelper: Helper {
    let id: String
    private(set) var name: String

    private var label: String
    private var plistPath: String
    /// A label or plist edit that arrived while the job was on. launchd still
    /// knows the running job by its old label, so the edit waits until the job
    /// is next booted out.
    private var pendingJob: (label: String, plistPath: String)?
    private let launchctl: LaunchctlClient

    private(set) var isEnabled = false
    private(set) var status: HelperStatus = .idle

    var notice: String? {
        pendingJob == nil ? nil : "Config changed. Switch off and on to apply."
    }

    init(config: LaunchAgentConfig, launchctl: LaunchctlClient) {
        self.id = config.id
        self.name = config.name
        self.label = config.label
        self.plistPath = config.plistPath
        self.launchctl = launchctl
    }

    /// Takes a reloaded config entry with this helper's id. The name always
    /// applies; a new label or plist applies now if the job is off, or on the
    /// next switch-off if it is on, so a reload never boots out a running job.
    func apply(_ config: LaunchAgentConfig) {
        name = config.name
        if config.label == label, config.plistPath == plistPath {
            pendingJob = nil
        } else if isEnabled {
            pendingJob = (config.label, config.plistPath)
        } else {
            label = config.label
            plistPath = config.plistPath
            pendingJob = nil
        }
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
            if let pendingJob {
                label = pendingJob.label
                plistPath = pendingJob.plistPath
                self.pendingJob = nil
            }
        } catch {
            status = .error(Self.message(error))
            Log.launchctl.error("Stop failed for \(self.label, privacy: .public): \(Self.message(error), privacy: .public)")
        }
    }

    private static func message(_ error: Error) -> String {
        String(describing: error)
    }
}
