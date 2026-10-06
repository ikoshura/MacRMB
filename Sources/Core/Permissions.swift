import AppKit
import ApplicationServices
import Foundation

/// TCC permission helpers. RMB only needs Accessibility access:
/// it reads mouse movement through an event tap and posts key presses
/// into the focused emulator window. No Screen Recording required.
public enum Permissions {
    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt (subject to TCC rules) and returns whether
    /// access is already granted.
    @discardableResult
    public static func requestAccessibilityPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    public static func openAccessibilitySettings() {
        NSWorkspace.shared.open(accessibilitySettingsURL)
    }
}
