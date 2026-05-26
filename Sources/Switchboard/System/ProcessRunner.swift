import Foundation

/// Result of running an external command.
struct ProcessResult: Sendable, Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    var trimmedStdout: String {
        stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Seam for running external processes. Real callers use `ProcessRunner`;
/// tests inject a stub so helper logic can be exercised without spawning
/// `launchctl` or `osascript`.
protocol ProcessRunning: Sendable {
    func run(_ executable: URL, _ arguments: [String]) async throws -> ProcessResult
}

/// Runs a process to completion on a background queue and returns its captured
/// output. All non-`Sendable` objects (`Process`, `Pipe`, `FileHandle`) are
/// created and consumed inside the work closure, so nothing crosses an actor
/// boundary.
///
/// Output is read fully *before* `waitUntilExit`. This is safe for the small,
/// stdout-only output the commands here produce; it is not a general-purpose
/// runner for commands that emit megabytes or flood stderr.
struct ProcessRunner: ProcessRunning {
    func run(_ executable: URL, _ arguments: [String]) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                process.waitUntilExit()

                continuation.resume(returning: ProcessResult(
                    exitCode: process.terminationStatus,
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self)
                ))
            }
        }
    }
}
