import XCTest
@testable import Switchboard

final class LaunchctlClientArgvTests: XCTestCase {
    private let client = LaunchctlClient(
        runner: ScriptedRunner { _ in ProcessResult(exitCode: 0) }, uid: 501
    )

    func testBootstrapTargetsGUIDomain() {
        XCTAssertEqual(client.bootstrapArgs(plistPath: "/x.plist"), ["bootstrap", "gui/501", "/x.plist"])
    }

    func testServiceCommandsTargetLabelInGUIDomain() {
        XCTAssertEqual(client.bootoutArgs(label: "com.a"), ["bootout", "gui/501/com.a"])
        XCTAssertEqual(client.enableArgs(label: "com.a"), ["enable", "gui/501/com.a"])
        XCTAssertEqual(client.disableArgs(label: "com.a"), ["disable", "gui/501/com.a"])
        XCTAssertEqual(client.kickstartArgs(label: "com.a"), ["kickstart", "-k", "gui/501/com.a"])
        XCTAssertEqual(client.printArgs(label: "com.a"), ["print", "gui/501/com.a"])
    }

    func testNotLoadedDetection() {
        XCTAssertTrue(LaunchctlClient.indicatesNotLoaded(ProcessResult(exitCode: 3, stderr: "No such process")))
        XCTAssertTrue(LaunchctlClient.indicatesNotLoaded(ProcessResult(exitCode: 113, stderr: "Could not find service")))
        XCTAssertFalse(LaunchctlClient.indicatesNotLoaded(ProcessResult(exitCode: 1, stderr: "permission denied")))
    }
}

final class LaunchctlClientExecutionTests: XCTestCase {
    func testStartSucceedsWhenBootstrapSucceeds() async throws {
        let client = LaunchctlClient(runner: ScriptedRunner { _ in ProcessResult(exitCode: 0) }, uid: 501)
        try await client.start(label: "com.a", plistPath: "/x.plist")
    }

    func testStartTreatsAlreadyLoadedAsSuccess() async throws {
        // bootstrap fails, but `print` reports the job is loaded → success.
        let client = LaunchctlClient(runner: ScriptedRunner { args in
            switch args.first {
            case "print": return ProcessResult(exitCode: 0, stdout: "com.a = { ... }")
            case "bootstrap": return ProcessResult(exitCode: 5, stderr: "Bootstrap failed: 5: Input/output error")
            default: return ProcessResult(exitCode: 0)
            }
        }, uid: 501)
        try await client.start(label: "com.a", plistPath: "/x.plist")
    }

    func testStartThrowsWhenBootstrapFailsAndNotRunning() async {
        let client = LaunchctlClient(runner: ScriptedRunner { args in
            args.first == "bootstrap"
                ? ProcessResult(exitCode: 5, stderr: "Bootstrap failed")
                : ProcessResult(exitCode: 1)
        }, uid: 501)
        await assertThrowsAsync { try await client.start(label: "com.a", plistPath: "/x.plist") }
    }

    func testStopIsBenignWhenNotLoaded() async throws {
        let client = LaunchctlClient(runner: ScriptedRunner { _ in
            ProcessResult(exitCode: 3, stderr: "No such process")
        }, uid: 501)
        try await client.stop(label: "com.a") // should not throw
    }

    func testStopThrowsOnRealFailure() async {
        let client = LaunchctlClient(runner: ScriptedRunner { _ in
            ProcessResult(exitCode: 1, stderr: "permission denied")
        }, uid: 501)
        await assertThrowsAsync { try await client.stop(label: "com.a") }
    }
}

/// Async counterpart to `XCTAssertThrowsError`.
func assertThrowsAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath, line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected an error to be thrown", file: file, line: line)
    } catch {
        // expected
    }
}
