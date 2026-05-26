import XCTest
@testable import Switchboard

final class AutoLightEvaluateTests: XCTestCase {
    private typealias Command = AutoLightDisplayHelper.AppearanceCommand

    func testConnectForcesLight() {
        XCTAssertEqual(AutoLightDisplayHelper.evaluate(connected: true, previouslyConnected: false, onDisconnect: .restore), .forceLight)
    }

    func testStillConnectedDoesNothing() {
        XCTAssertNil(AutoLightDisplayHelper.evaluate(connected: true, previouslyConnected: true, onDisconnect: .restore))
    }

    func testDisconnectRestores() {
        XCTAssertEqual(AutoLightDisplayHelper.evaluate(connected: false, previouslyConnected: true, onDisconnect: .restore), .restorePrevious)
    }

    func testDisconnectCanForceDark() {
        XCTAssertEqual(AutoLightDisplayHelper.evaluate(connected: false, previouslyConnected: true, onDisconnect: .dark), .forceDark)
    }

    func testDisconnectNoneDoesNothing() {
        XCTAssertNil(AutoLightDisplayHelper.evaluate(connected: false, previouslyConnected: true, onDisconnect: .none))
    }

    func testStillDisconnectedDoesNothing() {
        XCTAssertNil(AutoLightDisplayHelper.evaluate(connected: false, previouslyConnected: false, onDisconnect: .restore))
    }
}

@MainActor
final class AutoLightHelperBehaviorTests: XCTestCase {
    private func makeHelper(connected: Bool, currentDark: Bool, failure: AppearanceError? = nil)
        -> (AutoLightDisplayHelper, MockAppearance, MockDisplayWatcher)
    {
        let appearance = MockAppearance(currentDark: currentDark)
        appearance.failure = failure
        let watcher = MockDisplayWatcher()
        watcher.connected = connected
        let helper = AutoLightDisplayHelper(
            config: AutoLightDisplayConfig(match: "any-external", onDisconnect: .restore),
            appearance: appearance,
            watcher: watcher
        )
        return (helper, appearance, watcher)
    }

    func testEnablingWhileConnectedForcesLight() async {
        let (helper, appearance, _) = makeHelper(connected: true, currentDark: true)
        await helper.start()
        XCTAssertEqual(appearance.setCalls, [false])      // forced Light
        XCTAssertFalse(appearance.currentDark)
        XCTAssertEqual(helper.status, .running)
        await helper.stop()
    }

    func testEnablingWhileDisconnectedDoesNothing() async {
        let (helper, appearance, _) = makeHelper(connected: false, currentDark: true)
        await helper.start()
        XCTAssertTrue(appearance.setCalls.isEmpty)
        XCTAssertEqual(helper.status, .running)
        await helper.stop()
    }

    func testPermissionDenialSurfacesAsError() async {
        let (helper, _, _) = makeHelper(connected: true, currentDark: true, failure: .permissionDenied("denied"))
        await helper.start()
        guard case .error = helper.status else {
            return XCTFail("expected error status, got \(helper.status)")
        }
        await helper.stop()
    }
}
