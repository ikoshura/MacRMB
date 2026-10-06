import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import MacRMBKit

final class ConfigTests: XCTestCase {
    func testDefaultsMatchUpstreamEngine() {
        let config = Config.default
        XCTAssertEqual(config.version, 2)
        XCTAssertEqual(config.targetName, "Ryujinx")
        XCTAssertEqual(config.sensitivity, 10, accuracy: 0.0001)
        XCTAssertEqual(config.deadzone, 0.15, accuracy: 0.0001)
        XCTAssertEqual(config.range, 0.95, accuracy: 0.0001)
        XCTAssertEqual(config.threshold, 0.5, accuracy: 0.0001)
        XCTAssertTrue(config.hideCursor)
        XCTAssertTrue(config.autoFocus)
        XCTAssertTrue(config.bindMouseButtons)
        XCTAssertFalse(config.persistentKeyPress)
        XCTAssertEqual(config.directions, .ijkl)
        XCTAssertEqual(config.bindings, [:])
    }

    func testDefaultDirectionsAreJLIK() {
        let d = DirectionKeys.ijkl
        XCTAssertEqual(d.left, UInt16(kVK_ANSI_J))   // 38
        XCTAssertEqual(d.right, UInt16(kVK_ANSI_L))  // 37
        XCTAssertEqual(d.up, UInt16(kVK_ANSI_I))     // 34
        XCTAssertEqual(d.down, UInt16(kVK_ANSI_K))   // 40
        XCTAssertEqual(d.engineArray, [38, 37, 34, 40])
    }

    func testRoundTrip() throws {
        var original = Config.default
        original.targetName = "Odyssey"
        original.deadzone = 0.25
        original.sensitivity = 17.5
        original.bindings = [0: 8, 1: 9, 2: 11]
        original.directions = DirectionKeys(up: 13, down: 1, left: 0, right: 2)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.bindings[2], 11)
    }

    func testPartialJSONFallsBackToDefaults() throws {
        let json = #"{"targetName":"Ryujinx"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(decoded.targetName, "Ryujinx")
        XCTAssertEqual(decoded.deadzone, 0.15, accuracy: 0.0001)
        XCTAssertEqual(decoded.version, 0, "files without a version are legacy")
    }

    func testV1ConfigMigratesToV2() throws {
        let json = """
        {"version":1,"targetName":"SUPER MARIO ODYSSEY","deadzone":12,"sensitivity":3.0,\
        "offsetX":-40,"offsetY":15,"hideCursor":true,\
        "directions":{"up":34,"down":40,"left":38,"right":37},"bindings":{"2":49}}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(decoded.version, 1)

        let migrated = ConfigStore.migrate(decoded)
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.targetName, "SUPER MARIO ODYSSEY")
        // Analog params adopt upstream semantics/defaults.
        XCTAssertEqual(migrated.deadzone, 0.15, accuracy: 0.0001)
        XCTAssertEqual(migrated.sensitivity, 10, accuracy: 0.0001)
        // User-facing choices carry over (legacy pin offsets are ignored).
        XCTAssertEqual(migrated.directions, .ijkl)
        XCTAssertEqual(migrated.bindings[2], 49)
        XCTAssertTrue(migrated.hideCursor)
    }

    func testStoreSaveLoad() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RMBTests-\(UUID().uuidString)/config.json")
        let store = ConfigStore(url: url)

        var original = Config.default
        original.sensitivity = 14
        original.hideCursor = false
        original.bindings = [1: 49]
        try store.save(original)

        XCTAssertEqual(store.load(), original)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testLoadMissingFileReturnsDefault() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RMBMissing-\(UUID().uuidString)/config.json")
        let store = ConfigStore(url: url)
        XCTAssertEqual(store.load(), Config.default)
    }
}
