import XCTest
@testable import Switchboard

@MainActor
final class LaunchAgentHelperTests: XCTestCase {
    private let config = LaunchAgentConfig(
        id: "job", name: "Job", label: "com.a", plistPath: "/x.plist"
    )

    func testStartMarksRunningOnSuccess() async {
        let helper = LaunchAgentHelper(
            config: config,
            launchctl: LaunchctlClient(runner: ScriptedRunner { _ in ProcessResult(exitCode: 0) })
        )
        await helper.start()
        XCTAssertTrue(helper.isEnabled)
        XCTAssertEqual(helper.status, .running)
    }

    func testStartMarksErrorOnFailure() async {
        let helper = LaunchAgentHelper(
            config: config,
            launchctl: LaunchctlClient(runner: ScriptedRunner { args in
                args.first == "bootstrap"
                    ? ProcessResult(exitCode: 5, stderr: "boom")
                    : ProcessResult(exitCode: 1)
            })
        )
        await helper.start()
        XCTAssertTrue(helper.isEnabled) // user intent is on, even though it errored
        guard case .error = helper.status else {
            return XCTFail("expected error status, got \(helper.status)")
        }
    }

    func testStopMarksStopped() async {
        let helper = LaunchAgentHelper(
            config: config,
            launchctl: LaunchctlClient(runner: ScriptedRunner { _ in ProcessResult(exitCode: 0) })
        )
        await helper.stop()
        XCTAssertFalse(helper.isEnabled)
        XCTAssertEqual(helper.status, .stopped)
    }
}
