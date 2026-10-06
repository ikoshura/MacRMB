import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import RMBKit

final class BehaviorTests: XCTestCase {
    // MARK: - Focus matching (used by Detect and pin computation)

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

    // MARK: - Key catalog (binding pickers)

    func testKeyCatalogNamesKnownCodes() {
        XCTAssertEqual(KeyCodeCatalog.name(for: 49), "Space")
        XCTAssertEqual(KeyCodeCatalog.name(for: 126), "Up")
        XCTAssertEqual(KeyCodeCatalog.name(for: UInt16(kVK_ANSI_A)), "A")
        XCTAssertEqual(KeyCodeCatalog.name(for: UInt16(kVK_ANSI_J)), "J")
    }

    func testKeyCatalogHasNoDuplicateCodes() {
        let codes = KeyCodeCatalog.common.map(\.code)
        XCTAssertEqual(codes.count, Set(codes).count)
    }
}
