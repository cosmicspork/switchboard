import XCTest
@testable import Switchboard

@MainActor
final class HelperStoreTests: XCTestCase {
    private var configURL: URL!
    private var suiteName: String!

    override func setUp() async throws {
        configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("switchboard-store-\(UUID().uuidString).json")
        suiteName = "switchboard-store-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: configURL)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func writeConfig(name: String) throws {
        try """
        { "launchAgents": [ { "id": "job", "name": "\(name)", "label": "com.a", "plistPath": "/x.plist" } ] }
        """.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func makeStore() -> HelperStore {
        HelperStore(
            states: EnabledStateStore(defaults: UserDefaults(suiteName: suiteName)!),
            launchctl: LaunchctlClient(runner: RecordingRunner()),
            appearance: MockAppearance(),
            watcher: MockDisplayWatcher(),
            configURL: configURL
        )
    }

    func testReloadAppliesAnEditedNameToTheSameHelper() throws {
        try writeConfig(name: "Before")
        let store = makeStore()
        store.reloadConfig()
        let before = try XCTUnwrap(store.helpers.first { $0.id == "job" })

        try writeConfig(name: "After")
        store.reloadConfig()
        let after = try XCTUnwrap(store.helpers.first { $0.id == "job" })

        XCTAssertTrue(before === after, "a reload keeps the existing helper")
        XCTAssertEqual(after.name, "After")
    }
}
