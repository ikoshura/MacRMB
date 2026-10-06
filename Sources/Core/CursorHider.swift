import CoreGraphics
import Foundation

@_silgen_name("_CGSDefaultConnection")
private func rmbCGSDefaultConnection() -> UInt32

@_silgen_name("CGSSetConnectionProperty")
private func rmbCGSSetConnectionProperty(
    _ cid: UInt32,
    _ target: UInt32,
    _ key: CFString,
    _ value: CFTypeRef
) -> CGError

/// Hides/shows the system cursor globally — including while another app
/// (the emulator) is frontmost and RMB itself is in the background.
///
/// Background cursor hiding is not exposed through a public macOS API.
/// `SetsCursorInBackground` is the same undocumented WindowServer connection
/// property the MIT-licensed Raycast "Mouse Cursor Toggle" extension uses,
/// applied before calling the documented `CGDisplayHideCursor`.
///
/// The hide state is tied to this process' WindowServer connection: if RMB
/// dies, macOS restores the cursor on its own. `show()` is still called on
/// shutdown as a belt-and-suspenders measure.
public enum CursorHider {
    public private(set) static var isHidden = false
    private static var backgroundControlEnabled = false

    /// Hides the cursor. Returns `nil` on success or an `RMBError`
    /// (`RMB-CUR-001`/`RMB-CUR-002`) describing the failure.
    @discardableResult
    public static func hide() -> RMBError? {
        if !backgroundControlEnabled {
            let connection = rmbCGSDefaultConnection()
            let result = rmbCGSSetConnectionProperty(
                connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue
            )
            guard result == .success else {
                return RMBError(code: .cursorBackgroundDenied, detail: "CGError \(result.rawValue)")
            }
            backgroundControlEnabled = true
        }

        let error = CGDisplayHideCursor(CGMainDisplayID())
        guard error == .success else {
            return RMBError(code: .cursorHideFailed, detail: "CGError \(error.rawValue)")
        }
        isHidden = true
        return nil
    }

    public static func show() {
        guard isHidden else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        isHidden = false
    }
}
