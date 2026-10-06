import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// TCC permission helpers. The engine's own `requestPermissions()` asks for
/// Accessibility + Input Monitoring + Post-Event access at startup (needed
/// for its HID-level event tap); these helpers back the settings banner.
public enum Permissions {
    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompts (subject to TCC rules) and returns whether
    /// Accessibility access is already granted.
    @discardableResult
    public static func requestAccessibilityPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        CGRequestListenEventAccess()
        CGRequestPostEventAccess()
        return trusted
    }

    public static let accessibilitySettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    public static func openAccessibilitySettings() {
        NSWorkspace.shared.open(accessibilitySettingsURL)
    }
}

