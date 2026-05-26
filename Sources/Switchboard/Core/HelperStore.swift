import Foundation
import Observation

/// Owns the set of helpers: builds them from config at launch, restores the
/// previously-enabled ones, and applies menu toggles. One instance, created and
/// held by the app delegate.
@MainActor
@Observable
final class HelperStore {
    private(set) var helpers: [any Helper] = []
    /// Non-fatal config problem (e.g. malformed helpers.json), surfaced in the menu.
    private(set) var loadError: String?

    private let states: EnabledStateStore
    private let launchctl: LaunchctlClient
    private let appearance: any AppearanceControlling
    private let watcher: any DisplayWatching
    private var didBootstrap = false

    init(
        states: EnabledStateStore = EnabledStateStore(),
        launchctl: LaunchctlClient = LaunchctlClient(runner: ProcessRunner()),
        appearance: any AppearanceControlling = AppearanceController(runner: ProcessRunner()),
        watcher: any DisplayWatching = ScreenObserver()
    ) {
        self.states = states
        self.launchctl = launchctl
        self.appearance = appearance
        self.watcher = watcher
    }

    /// Loads config and starts previously-enabled helpers. Idempotent.
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        reloadConfig()
    }

    /// Re-reads `helpers.json` and reconciles the helper list with it.
    ///
    /// Existing helpers are preserved by id so a reload never disturbs a running
    /// in-process helper (e.g. auto-light loses no captured state) and never
    /// boots out a launchd job. New entries are added and started if they were
    /// previously enabled; entries dropped from the config disappear from the
    /// menu but their launchd jobs are left running.
    func reloadConfig() {
        let config: AppConfig
        do {
            config = try ConfigLoader.load() ?? .empty
            loadError = nil
        } catch {
            config = .empty
            loadError = String(describing: error)
            Log.config.error("\(self.loadError ?? "", privacy: .public)")
        }

        var existing: [String: any Helper] = [:]
        for helper in helpers { existing[helper.id] = helper }

        var rebuilt: [any Helper] = []
        for agentConfig in config.launchAgents {
            rebuilt.append(existing[agentConfig.id] ?? register(
                LaunchAgentHelper(config: agentConfig, launchctl: launchctl)
            ))
        }
        rebuilt.append(existing[AutoLightDisplayHelper.helperID] ?? register(
            AutoLightDisplayHelper(
                config: config.autoLightDisplay ?? AutoLightDisplayConfig(),
                appearance: appearance,
                watcher: watcher
            )
        ))
        helpers = rebuilt
    }

    /// Starts a freshly built helper if its enabled flag was persisted.
    private func register(_ helper: any Helper) -> any Helper {
        if states.isEnabled(id: helper.id) {
            Task { await helper.start() }
        }
        return helper
    }

    func isEnabled(_ helper: any Helper) -> Bool {
        helper.isEnabled
    }

    func setEnabled(_ on: Bool, for helper: any Helper) {
        states.setEnabled(on, id: helper.id)
        Task {
            if on { await helper.start() } else { await helper.stop() }
        }
    }
}
