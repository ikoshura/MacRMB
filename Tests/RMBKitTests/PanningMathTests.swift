import XCTest
@testable import RMBKit

final class PanningMathTests: XCTestCase {
    func testDeadzoneSuppressesSmallMotion() {
        XCTAssertEqual(PanningMath.axisState(delta: 10, deadzone: 12, sensitivity: 1), 0)
        XCTAssertEqual(PanningMath.axisState(delta: -10, deadzone: 12, sensitivity: 1), 0)
        XCTAssertEqual(PanningMath.axisState(delta: 0, deadzone: 0, sensitivity: 1), 0)
    }

    func testDirectionBeyondDeadzone() {
        XCTAssertEqual(PanningMath.axisState(delta: 20, deadzone: 12, sensitivity: 1), 1)
        XCTAssertEqual(PanningMath.axisState(delta: -20, deadzone: 12, sensitivity: 1), -1)
    }

    func testSensitivityScalesDelta() {
        // 7 px × 2.0 = 14 > 12 deadzone → active
        XCTAssertEqual(PanningMath.axisState(delta: 7, deadzone: 12, sensitivity: 2), 1)
        // 7 px × 1.0 = 7 < 12 deadzone → inactive
        XCTAssertEqual(PanningMath.axisState(delta: 7, deadzone: 12, sensitivity: 1), 0)
    }

    func testInvertYFlipsVerticalDirection() {
        let normal = PanningMath.direction(dx: 0, dy: 20, deadzone: 12, sensitivity: 1, invertY: false)
        XCTAssertEqual(normal.y, 1)
        let inverted = PanningMath.direction(dx: 0, dy: 20, deadzone: 12, sensitivity: 1, invertY: true)
        XCTAssertEqual(inverted.y, -1)
    }

    func testAxesAreIndependent() {
        let direction = PanningMath.direction(dx: 30, dy: 0, deadzone: 12, sensitivity: 1, invertY: false)
        XCTAssertEqual(direction.x, 1)
        XCTAssertEqual(direction.y, 0)
    }

    func testNegativeDeadzoneIsTreatedAsZero() {
        XCTAssertEqual(PanningMath.axisState(delta: 1, deadzone: -5, sensitivity: 1), 1)
    }
}
