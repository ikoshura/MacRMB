import Foundation

/// Pure mouse-delta → direction math, kept free of CoreGraphics so it can
/// be unit tested.
public enum PanningMath {
    /// Signed axis state for one axis: -1, 0, or +1.
    /// `sensitivity` scales the delta; `deadzone` (in scaled px) must be
    /// exceeded before any input registers.
    public static func axisState(delta: Double, deadzone: Double, sensitivity: Double) -> Int {
        let scaled = delta * sensitivity
        guard abs(scaled) > max(deadzone, 0) else { return 0 }
        return scaled > 0 ? 1 : -1
    }

    /// Both axes at once. Note: CG coordinates grow downward, so a positive
    /// y means "cursor below center" → the Down key. `invertY` flips that.
    public static func direction(
        dx: Double,
        dy: Double,
        deadzone: Double,
        sensitivity: Double,
        invertY: Bool
    ) -> (x: Int, y: Int) {
        let y = axisState(delta: dy, deadzone: deadzone, sensitivity: sensitivity)
        let x = axisState(delta: dx, deadzone: deadzone, sensitivity: sensitivity)
        return (x: x, y: invertY ? -y : y)
    }
}
