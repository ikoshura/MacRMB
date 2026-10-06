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
}
