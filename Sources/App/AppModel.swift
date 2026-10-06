import AppKit
import Combine
import CoreGraphics
import Foundation
import MacRMBKit

/// Conductor for the Swift UI ⇄ C++ engine bridge. Everything here runs on
/// the main thread (Carbon hotkey handler, timers, engine status polls).
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var config: Config {
        didSet {
            try? store.save(config)
            applyConfig()
        }
    }
    @Published private(set) var isPanning = false
    @Published private(set) var targetActive = false
    @Published private(set) var engineStarted = false
    @Published private(set) var accessibilityTrusted: Bool
    @Published var error: RMBError?
    @Published private(set) var lastExternalName: String?

    private let store = ConfigStore()
    private let hotkeys = HotkeyManager()
    private var statusTimer: Timer?
    private var axTimer: Timer?
    private var started = false

    private init() {
        let loaded = store.load()
        config = loaded
        accessibilityTrusted = Permissions.isAccessibilityTrusted
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true

        engineStarted = rmb_engine_start() == 0
        if !engineStarted {
            error = RMBError(code: .inputTapUnavailable, detail: "rmb_engine_start failed")
        }
        applyConfig()

        hotkeys.onToggle = { [weak self] _ in
            self?.togglePanning()
        }
        if let registrationError = hotkeys.register() {
            error = registrationError
        }

        pollStatus()
        let status = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollStatus()
        }
        RunLoop.main.add(status, forMode: .common)
        statusTimer = status

        let ax = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollAccessibility()
        }
        RunLoop.main.add(ax, forMode: .common)
        axTimer = ax
    }

    func shutdown() {
        guard started else { return }
        started = false
        rmb_engine_stop()
        hotkeys.unregister()
        statusTimer?.invalidate()
        axTimer?.invalidate()
        statusTimer = nil
        axTimer = nil
    }

    // MARK: - Permissions

    func requestAccessibility() {
        Permissions.requestAccessibilityPrompt()
        recheckPermissions()
    }

    func recheckPermissions() {
        accessibilityTrusted = Permissions.isAccessibilityTrusted
    }

    private func pollAccessibility() {
        let trusted = Permissions.isAccessibilityTrusted
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
        }
    }

    // MARK: - Panning

    /// Entry point for ⌥⌘P, the menu command, the menu bar, and the
    /// status-row button. The engine pins the cursor at the screen center
    /// (upstream behavior); rmb_engine_set_pin() remains available in the
    /// C API for custom points but is no longer exposed in the UI.
    func togglePanning() {
        guard engineStarted else { return }
        rmb_engine_toggle_panning()
        pollStatus()
    }

    private func pollStatus() {
        let panning = rmb_engine_is_panning() != 0
        if panning != isPanning {
            isPanning = panning
        }
        let active = rmb_engine_is_target_active() != 0
        if active != targetActive {
            targetActive = active
        }
        captureExternalIfAny()
    }

    /// Remembers the last non-self frontmost window/app name for Detect.
    private func captureExternalIfAny() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != getpid()
        else { return }
        let titles = FocusMonitor.windowTitles(of: front.processIdentifier)
        if let name = titles.first ?? front.localizedName, !name.isEmpty, name != lastExternalName {
            lastExternalName = name
        }
    }

    // MARK: - Config → engine

    func applyConfig() {
        var c = RmbEngineConfig()
        let d = config.directions
        c.stick_keys = (Int32(d.left), Int32(d.right), Int32(d.up), Int32(d.down))
        c.left_mouse_key = config.bindings[0].map { Int32($0) } ?? -1
        c.right_mouse_key = config.bindings[1].map { Int32($0) } ?? -1
        c.middle_mouse_key = config.bindings[2].map { Int32($0) } ?? -1
        c.sensitivity = Float(config.sensitivity)
        c.deadzone = Float(config.deadzone)
        c.range = Float(config.range)
        c.threshold = Float(config.threshold)
        c.x_offset = Float(config.stickOffsetX)
        c.y_offset = Float(config.stickOffsetY)
        c.hide_mouse = config.hideCursor ? 1 : 0
        c.auto_focus = config.autoFocus ? 1 : 0
        c.bind_mouse_button = config.bindMouseButtons ? 1 : 0
        c.persistent_key_press = config.persistentKeyPress ? 1 : 0
        config.targetName.withCString { name in
            c.target_name = name
            rmb_engine_reconfig(&c)
        }
    }

    // MARK: - UI actions

    /// Pre-fills the target from the frontmost (or last frontmost) window.
    func detectTarget() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != getpid()
        {
            let titles = FocusMonitor.windowTitles(of: front.processIdentifier)
            if let name = titles.first ?? front.localizedName, !name.isEmpty {
                lastExternalName = name
                config.targetName = name
                return
            }
        }
        if let name = lastExternalName {
            config.targetName = name
        } else {
            error = RMBError(
                code: .targetNotFound,
                detail: "Focus the emulator window first, then click Detect."
            )
        }
    }
}
