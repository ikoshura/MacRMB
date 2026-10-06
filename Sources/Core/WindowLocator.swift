import CoreGraphics
import Foundation

/// Finds the on-screen window frame of the emulator so the cursor can be
/// pinned at the window's center.
public enum WindowLocator {
    /// Frame of the topmost on-screen, layer-0 window owned by `ownerPID`,
    /// in CG global coordinates (origin at the top-left of the main display).
    /// Returns `nil` when no such window exists.
    public static func targetFrame(ownerPID: pid_t) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for window in list {
            guard let ownerPIDFound = window[kCGWindowOwnerPID as String] as? Int,
                  ownerPIDFound == Int(ownerPID),
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = (bounds["X"] as? NSNumber)?.doubleValue,
                  let y = (bounds["Y"] as? NSNumber)?.doubleValue,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue
            else { continue }
            return CGRect(x: x, y: y, width: width, height: height)
        }
        return nil
    }

    /// Full bounds of the main display (CG global coordinates).
    public static var mainDisplayFrame: CGRect {
        CGDisplayBounds(CGMainDisplayID())
    }
}
