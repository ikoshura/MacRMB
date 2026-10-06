import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import RMBKit

final class ConfigTests: XCTestCase {
    func testDefaultRoundTrip() throws {
        let original = Config.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCustomConfigRoundTrip() throws {
        var original = Config.default
        original.targetName = "yuzu — game"
        original.deadzone = 20.5
        original.sensitivity = 1.7
        original.offsetX = -40
        original.offsetY = 15
        original.invertY = true
        original.hideCursor = false
        original.directions = DirectionKeys(up: 13, down: 1, left: 0, right: 2)
        original.bindings = [0: 8, 1: 9, 2: 11, 3: 45, 4: 46]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.bindings[2], 11)
    }

    func testPartialJSONFallsBackToDefaults() throws {
        let json = #"{"targetName": "Ryujinx"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(decoded.targetName, "Ryujinx")
        XCTAssertEqual(decoded.deadzone, Config.default.deadzone)
        XCTAssertEqual(decoded.hideCursor, true)
        XCTAssertEqual(decoded.bindings, [:])
    }

    func testStoreSaveLoad() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RMBTests-\(UUID().uuidString)/config.json")
        let store = ConfigStore(url: url)

        var original = Config.default
        original.sensitivity = 2.5
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

    func testDefaultsUseIJKLRightStickKeys() {
        XCTAssertEqual(Config.default.directions, DirectionKeys.rightStick)
        XCTAssertEqual(DirectionKeys.rightStick.up, UInt16(kVK_ANSI_I))    // 34
        XCTAssertEqual(DirectionKeys.rightStick.down, UInt16(kVK_ANSI_K))  // 40
        XCTAssertEqual(DirectionKeys.rightStick.left, UInt16(kVK_ANSI_J))  // 38
        XCTAssertEqual(DirectionKeys.rightStick.right, UInt16(kVK_ANSI_L)) // 37
        XCTAssertEqual(Config.default.version, 1)
    }

    func testLegacyArrowConfigMigratesToIJKL() throws {
        let json = #"{"targetName":"Ryujinx","directions":{"up":126,"down":125,"left":123,"right":124}}"#
            .data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(decoded.version, 0, "files without a version are legacy")

        let migrated = ConfigStore.migrate(decoded)
        XCTAssertEqual(migrated.directions, .rightStick)
        XCTAssertEqual(migrated.version, 1)
        XCTAssertEqual(migrated.targetName, "Ryujinx")
    }

    func testLegacyCustomDirectionsArePreservedByMigration() {
        var legacy = Config.default
        legacy.version = 0
        legacy.directions = DirectionKeys(up: 13, down: 1, left: 0, right: 2) // W/S/A/D
        let migrated = ConfigStore.migrate(legacy)
        XCTAssertEqual(migrated.directions, legacy.directions)
        XCTAssertEqual(migrated.version, 1)
    }

    func testCurrentVersionConfigIsNotMigrated() {
        var config = Config.default
        config.directions = DirectionKeys(up: 13, down: 1, left: 0, right: 2)
        let migrated = ConfigStore.migrate(config)
        XCTAssertEqual(migrated.directions, config.directions)
        XCTAssertEqual(migrated.version, 1)
    }

    func testAnchorDefaultsToCenterWhenMissing() throws {
        let json = #"{"targetName":"X"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertEqual(decoded.anchor, .center)
    }

    func testAnchorRoundTrip() throws {
        var original = Config.default
        original.anchor = .bottomRight
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded.anchor, .bottomRight)
        XCTAssertEqual(decoded, original)
    }

    func testAnchorPoints() {
        func assertInside(_ point: CGPoint, _ rect: CGRect, _ label: String) {
            XCTAssertTrue(
                point.x >= rect.minX && point.x <= rect.maxX
                    && point.y >= rect.minY && point.y <= rect.maxY,
                "\(label): \(point) outside \(rect)"
            )
        }

        let frame = CGRect(x: 100, y: 50, width: 400, height: 300)
        XCTAssertEqual(AnchorPreset.center.point(in: frame), CGPoint(x: 300, y: 200))

        let big = CGRect(x: 0, y: 0, width: 1000, height: 800)
        XCTAssertEqual(AnchorPreset.topLeft.point(in: big), CGPoint(x: 80, y: 80))
        XCTAssertEqual(AnchorPreset.bottomRight.point(in: big), CGPoint(x: 920, y: 720))
        for preset in AnchorPreset.allCases {
            assertInside(preset.point(in: big), big, preset.rawValue)
        }

        // Tiny window: inset clamps to the bounds, never escapes the frame.
        let tiny = CGRect(x: 10, y: 10, width: 50, height: 40)
        for preset in AnchorPreset.allCases {
            assertInside(preset.point(in: tiny), tiny, "tiny \(preset.rawValue)")
        }
    }
}
