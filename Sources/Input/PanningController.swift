import CoreGraphics
import Foundation

/// Drives camera panning: while active, the cursor is pinned to a center
/// point (the emulator window's center + configured offsets), every mouse
/// delta beyond the deadzone holds the bound direction keys, and the cursor
/// is warped back so panning can continue indefinitely.
///
/// This is the macOS translation of RMB's approach: it never injects into
/// the emulator directly — it holds keyboard keys the emulator's own input
/// configuration maps to the right stick.
public final class PanningController {
    private let keys: KeySimulator
    private var config: Config

    /// Effective pin center in CG global coordinates.
    public private(set) var center: CGPoint?
    public private(set) var isActive = false

    public init(keys: KeySimulator, config: Config) {
        self.keys = keys
        self.config = config
    }

    public func updateConfig(_ config: Config) {
        // Direction keys changed while some were held → release the old
        // codes first so no key gets stuck down.
        if config.directions != self.config.directions {
            keys.releaseAll()
        }
        self.config = config
    }

    public func activate(at center: CGPoint) {
        self.center = center
        isActive = true
    }

    public func updateCenter(_ center: CGPoint) {
        guard isActive else { return }
        self.center = center
    }

    public func deactivate() {
        isActive = false
        center = nil
        keys.releaseAll()
    }

    public func handleMouseMoved(location: CGPoint) {
        guard isActive, let center else { return }
        // Ignore the echo of our own warp (or a cursor that did not move).
        guard location != center else { return }

        let direction = PanningMath.direction(
            dx: location.x - center.x,
            dy: location.y - center.y,
            deadzone: config.deadzone,
            sensitivity: config.sensitivity,
            invertY: config.invertY
        )
        keys.applyDirections(x: direction.x, y: direction.y, keys: config.directions)
        CGWarpMouseCursorPosition(center)
    }
}
