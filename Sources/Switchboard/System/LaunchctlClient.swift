import Foundation

/// Builds and runs `launchctl` commands against the current GUI domain.
///
/// The argv builders are pure (no I/O) so command construction can be unit
/// tested without spawning anything. The `start`/`stop`/`isRunning` methods are
/// thin wrappers that translate exit codes and stderr into success, a benign
/// no-op, or a `HelperError`.
struct LaunchctlClient: Sendable {
    private let runner: ProcessRunning
    private let uid: uid_t
    private let executable = URL(fileURLWithPath: "/bin/launchctl")

    init(runner: ProcessRunning, uid: uid_t = getuid()) {
        self.runner = runner
        self.uid = uid
    }

    /// The per-user Aqua (GUI login) domain. GUI LaunchAgents must be addressed
    /// here — not `user/<uid>` or `system` — to be controllable from a
    /// foreground app.
    var domainTarget: String { "gui/\(uid)" }
    func serviceTarget(_ label: String) -> String { "gui/\(uid)/\(label)" }

    // MARK: Pure argv builders

    func bootstrapArgs(plistPath: String) -> [String] { ["bootstrap", domainTarget, plistPath] }
    func bootoutArgs(label: String) -> [String] { ["bootout", serviceTarget(label)] }
    func enableArgs(label: String) -> [String] { ["enable", serviceTarget(label)] }
    func disableArgs(label: String) -> [String] { ["disable", serviceTarget(label)] }
    func kickstartArgs(label: String) -> [String] { ["kickstart", "-k", serviceTarget(label)] }
    func printArgs(label: String) -> [String] { ["print", serviceTarget(label)] }

    // MARK: Execution

    /// Enables and bootstraps the agent. If `bootstrap` fails we re-check with
    /// `print`: a job that is already loaded reports a bootstrap failure that is
    /// indistinguishable, by exit code alone, from a real error — so a
    /// successful `print` is treated as "already running, fine".
    func start(label: String, plistPath: String) async throws {
        _ = try? await runner.run(executable, enableArgs(label: label))
        let result = try await runner.run(executable, bootstrapArgs(plistPath: plistPath))
        guard result.exitCode != 0 else { return }

        if await isRunning(label: label) { return }
        throw HelperError.processFailed(
            exitCode: result.exitCode,
            message: result.stderr.isEmpty ? result.stdout : result.stderr
        )
    }

    /// Boots the agent out of the domain. "Not loaded" is treated as success —
    /// the desired end state (stopped) already holds.
    func stop(label: String) async throws {
        let result = try await runner.run(executable, bootoutArgs(label: label))
        guard result.exitCode != 0, !Self.indicatesNotLoaded(result) else { return }
        throw HelperError.processFailed(
            exitCode: result.exitCode,
            message: result.stderr.isEmpty ? result.stdout : result.stderr
        )
    }

    func isRunning(label: String) async -> Bool {
        guard let result = try? await runner.run(executable, printArgs(label: label)) else {
            return false
        }
        return result.exitCode == 0
    }

    static func indicatesNotLoaded(_ result: ProcessResult) -> Bool {
        let text = (result.stderr + result.stdout).lowercased()
        return text.contains("no such process")
            || text.contains("could not find")
            || text.contains("not loaded")
    }
}
