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

    func testApplyRenamesInPlace() {
        let helper = LaunchAgentHelper(
            config: config,
            launchctl: LaunchctlClient(runner: RecordingRunner())
        )
        helper.apply(LaunchAgentConfig(id: "job", name: "Renamed", label: "com.a", plistPath: "/x.plist"))
        XCTAssertEqual(helper.name, "Renamed")
        XCTAssertNil(helper.notice)
    }

    func testApplyWhileOffUsesTheNewJobOnNextStart() async {
        let runner = RecordingRunner()
        let helper = LaunchAgentHelper(config: config, launchctl: LaunchctlClient(runner: runner))
        helper.apply(LaunchAgentConfig(id: "job", name: "Job", label: "com.b", plistPath: "/y.plist"))
        XCTAssertNil(helper.notice)

        await helper.start()
        XCTAssertTrue(runner.calls.contains { $0.first == "bootstrap" && $0.last == "/y.plist" })
    }

    func testApplyWhileOnWaitsForTheNextSwitchOff() async {
        let runner = RecordingRunner()
        let helper = LaunchAgentHelper(config: config, launchctl: LaunchctlClient(runner: runner))
        await helper.start()
        let callsBeforeApply = runner.calls.count

        helper.apply(LaunchAgentConfig(id: "job", name: "Job", label: "com.b", plistPath: "/y.plist"))
        XCTAssertEqual(runner.calls.count, callsBeforeApply, "a reload must not touch the running job")
        XCTAssertNotNil(helper.notice)

        await helper.stop()
        let bootout = runner.calls.last { $0.first == "bootout" }
        XCTAssertEqual(bootout?.last?.hasSuffix("/com.a"), true, "the old job is the one booted out")
        XCTAssertNil(helper.notice)

        await helper.start()
        XCTAssertEqual(runner.calls.last { $0.first == "bootstrap" }?.last, "/y.plist")
    }

    func testRevertingAPendingEditClearsTheNotice() async {
        let helper = LaunchAgentHelper(
            config: config,
            launchctl: LaunchctlClient(runner: RecordingRunner())
        )
        await helper.start()
        helper.apply(LaunchAgentConfig(id: "job", name: "Job", label: "com.b", plistPath: "/y.plist"))
        helper.apply(config)
        XCTAssertNil(helper.notice)
    }
}
