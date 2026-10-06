import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Polls (10 Hz) which app is frontmost and whether it matches the
/// configured emulator target, using the app's name/bundle ID first and
/// window titles (via the Accessibility API — no Screen Recording needed)
/// as a fallback.
public final class FocusMonitor {
    public struct Snapshot: Equatable {
        public let isOwnAppFocused: Bool
        public let frontmostName: String?
        public let targetFocused: Bool
        public let targetPID: pid_t?
        /// Window title (or app name) of the last app other than RMB that
        /// was frontmost — used by the "Detect" button.
        public let lastExternalName: String?
    }

    public var onSnapshot: ((Snapshot) -> Void)?

    private var timer: Timer?
    private var target = ""
    private var lastExternalName: String?
    private var ownPID: pid_t { ProcessInfo.processInfo.processIdentifier }

    public init() {}

    public func start(target: String) {
        retarget(target)
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    public func retarget(_ target: String) {
        self.target = target.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let front = NSWorkspace.shared.frontmostApplication
        let isOwn = front?.processIdentifier == ownPID

        var targetFocused = false
        var targetPID: pid_t?

        if let front, !isOwn {
            let titles = Self.windowTitles(of: front.processIdentifier)
            if let first = titles.first, !first.isEmpty {
                lastExternalName = first
            } else {
                lastExternalName = front.localizedName
            }
            if Self.matches(
                frontName: front.localizedName,
                bundleID: front.bundleIdentifier,
                titles: titles,
                target: target
            ) {
                targetFocused = true
                targetPID = front.processIdentifier
            }
        }

        onSnapshot?(Snapshot(
            isOwnAppFocused: isOwn,
            frontmostName: front?.localizedName,
            targetFocused: targetFocused,
            targetPID: targetPID,
            lastExternalName: lastExternalName
        ))
    }

    /// Window titles of another app's on-screen windows via AX.
    static func windowTitles(of pid: pid_t) -> [String] {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }

        var names: [String] = []
        for window in windows {
            var title: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title) == .success,
               let name = title as? String, !name.isEmpty
            {
                names.append(name)
            }
        }
        return names
    }

    /// True when the frontmost app's name, bundle ID, or any of its window
    /// titles contains the target (case-insensitive). An empty target never matches.
    static func matches(frontName: String?, bundleID: String?, titles: [String], target: String) -> Bool {
        let needle = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        if let frontName, frontName.localizedCaseInsensitiveContains(needle) { return true }
        if let bundleID, bundleID.localizedCaseInsensitiveContains(needle) { return true }
        return titles.contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}
