import CoreGraphics
import Foundation

/// Posts synthetic keyboard events (press/release) to the focused app —
/// the macOS counterpart of RMB's Windows `SendInput` / X11 `XTestFakeKeyEvent`.
public final class KeySimulator {
    public private(set) var pressedKeys: Set<UInt16> = []

    /// Called when a key event could not be created (surfaces as RMB-IN-002).
    public var onPostFailure: ((UInt16) -> Void)?

    private let source = CGEventSource(stateID: .hidSystemState)

    public init() {}

    public func setKey(_ key: UInt16, down: Bool) {
        guard down != pressedKeys.contains(key) else { return }
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(key),
            keyDown: down
        ) else {
            onPostFailure?(key)
            return
        }
        event.post(tap: .cghidEventTap)
        if down {
            pressedKeys.insert(key)
        } else {
            pressedKeys.remove(key)
        }
    }

    /// Updates all four direction keys to match the computed axis states.
    public func applyDirections(x: Int, y: Int, keys: DirectionKeys) {
        setKey(keys.right, down: x > 0)
        setKey(keys.left, down: x < 0)
        setKey(keys.down, down: y > 0)
        setKey(keys.up, down: y < 0)
    }

    public func releaseAll() {
        for key in Array(pressedKeys) {
            setKey(key, down: false)
        }
    }
}
