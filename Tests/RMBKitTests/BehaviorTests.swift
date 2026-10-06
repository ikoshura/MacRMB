import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import RMBKit

final class BehaviorTests: XCTestCase {
    // MARK: - Focus matching

    func testTargetMatchesAppName() {
        XCTAssertTrue(
            FocusMonitor.matches(frontName: "Ryujinx", bundleID: nil, titles: [], target: "Ryujinx")
        )
    }

    func testTargetMatchesWindowTitleCaseInsensitively() {
        XCTAssertTrue(
            FocusMonitor.matches(
                frontName: "Finder",
                bundleID: nil,
                titles: ["Some Game — Ryujinx"],
                target: "ryujinx"
            )
        )
    }

    func testTargetDoesNotMatchUnrelatedApp() {
        XCTAssertFalse(
            FocusMonitor.matches(frontName: "Safari", bundleID: nil, titles: [], target: "Ryujinx")
        )
    }

    func testEmptyTargetNeverMatches() {
        XCTAssertFalse(
            FocusMonitor.matches(frontName: "Ryujinx", bundleID: nil, titles: [], target: "  ")
        )
    }

    // MARK: - Key catalog

    func testKeyCatalogNamesKnownCodes() {
        XCTAssertEqual(KeyCodeCatalog.name(for: 49), "Space")
        XCTAssertEqual(KeyCodeCatalog.name(for: 126), "Up")
        XCTAssertEqual(KeyCodeCatalog.name(for: UInt16(kVK_ANSI_A)), "A")
    }

    func testKeyCatalogHasNoDuplicateCodes() {
        let codes = KeyCodeCatalog.common.map(\.code)
        XCTAssertEqual(codes.count, Set(codes).count)
    }

    // MARK: - Key simulator bookkeeping (no events posted for empty sets)

    func testReleaseAllOnIdleSimulatorIsSafe() {
        let simulator = KeySimulator()
        let controller = PanningController(keys: simulator, config: .default)
        XCTAssertFalse(controller.isActive)
        controller.deactivate()
        controller.handleMouseMoved(location: CGPoint(x: 100, y: 100))
        XCTAssertTrue(simulator.pressedKeys.isEmpty)
    }

    func testInactiveControllerIgnoresMouseMovement() {
        let simulator = KeySimulator()
        let controller = PanningController(keys: simulator, config: .default)
        controller.handleMouseMoved(location: CGPoint(x: 500, y: 500))
        XCTAssertTrue(simulator.pressedKeys.isEmpty)
        XCTAssertNil(controller.center)
    }
}
