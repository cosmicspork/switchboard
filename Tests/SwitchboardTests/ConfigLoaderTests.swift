import XCTest
@testable import Switchboard

final class ConfigLoaderTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("switchboard-test-\(UUID().uuidString).json")
    }

    func testMissingFileReturnsNil() throws {
        XCTAssertNil(try ConfigLoader.load(from: tempURL()))
    }

    func testValidFileDecodes() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let json = """
        {
          "launchAgents": [
            { "id": "nb", "name": "Notebook", "label": "dev.notebook.server",
              "plistPath": "~/Library/LaunchAgents/dev.notebook.server.plist" }
          ],
          "autoLightDisplay": { "match": "DELL U3223QE", "onDisconnect": "dark" }
        }
        """
        try json.write(to: url, atomically: true, encoding: .utf8)

        let config = try XCTUnwrap(try ConfigLoader.load(from: url))
        XCTAssertEqual(config.launchAgents.count, 1)
        XCTAssertEqual(config.launchAgents[0].label, "dev.notebook.server")
        XCTAssertEqual(config.autoLightDisplay?.displayMatch, .named("DELL U3223QE"))
        XCTAssertEqual(config.autoLightDisplay?.onDisconnect, .dark)
    }

    func testTildePathIsExpanded() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try #"{ "launchAgents": [ { "id": "a", "name": "A", "label": "a", "plistPath": "~/a.plist" } ] }"#
            .write(to: url, atomically: true, encoding: .utf8)

        let config = try XCTUnwrap(try ConfigLoader.load(from: url))
        XCTAssertFalse(config.launchAgents[0].plistPath.hasPrefix("~"))
        XCTAssertTrue(config.launchAgents[0].plistPath.hasSuffix("/a.plist"))
    }

    func testMalformedFileThrows() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try "{ not json".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ConfigLoader.load(from: url))
    }

    func testSparseAutoLightUsesDefaults() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try #"{ "launchAgents": [], "autoLightDisplay": {} }"#
            .write(to: url, atomically: true, encoding: .utf8)

        let config = try XCTUnwrap(try ConfigLoader.load(from: url))
        XCTAssertEqual(config.autoLightDisplay?.displayMatch, .anyExternal)
        XCTAssertEqual(config.autoLightDisplay?.onDisconnect, .restore)
    }
}

final class EnabledStateStoreTests: XCTestCase {
    func testRoundTrips() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "switchboard-test-\(UUID().uuidString)"))
        let store = EnabledStateStore(defaults: suite)

        XCTAssertFalse(store.isEnabled(id: "x"))
        store.setEnabled(true, id: "x")
        XCTAssertTrue(store.isEnabled(id: "x"))
        store.setEnabled(false, id: "x")
        XCTAssertFalse(store.isEnabled(id: "x"))
    }
}
