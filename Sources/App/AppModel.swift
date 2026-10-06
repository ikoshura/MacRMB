import AppKit
import Combine
import Foundation
import RMBKit

/// Orchestrates the whole app. Everything here runs on the main thread:
/// the Carbon hotkey handler, the focus timer, and the CGEventTap callback
/// are all scheduled on the main run loop.
final class AppModel: ObservableObject {
    enum Status: String, Equatable {
        case idle = "Off"
        case armed = "Waiting for target"
        case active = "Panning"
    }

    static let shared = AppModel()

    @Published var config: Config {
        didSet {
            try? store.save(config)
            applyConfig()
        }
    }

    @Published var isPanningEnabled = false {
        didSet {
            guard isPanningEnabled != oldValue else { return }
            panningStateChanged()
        }
    }

    @Published private(set) var status: Status = .idle
    @Published var error: RMBError?
    @Published private(set) var accessibilityTrusted: Bool
    @Published private(set) var lastExternalName: String?

    private let store = ConfigStore()
    private let keySim = KeySimulator()
    private let panning: PanningController
    private let tap = EventTap()
    private let hotkeys = HotkeyManager()
    private let focus = FocusMonitor()
    private var axPollTimer: Timer?
    private var started = false
    private var targetPID: pid_t?
    private var cursorHiddenByUs = false

    private init() {
        let loaded = store.load()
        config = loaded
        accessibilityTrusted = Permissions.isAccessibilityTrusted
        panning = PanningController(keys: keySim, config: loaded)

        keySim.onPostFailure = { [weak self] _ in
            self?.error = RMBError(code: .inputKeyPostFailed)
        }
        hotkeys.onToggle = { [weak self] _ in
            self?.isPanningEnabled.toggle()
        }
        tap.onMouseMoved = { [weak self] location in
            self?.panning.handleMouseMoved(location: location)
        }
        tap.onMouseButton = { [weak self] button, down in
            self?.handleMouseButton(button, down: down)
        }
        focus.onSnapshot = { [weak self] snapshot in
            self?.handleFocus(snapshot)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true

        accessibilityTrusted = Permissions.isAccessibilityTrusted
        if let registrationError = hotkeys.register() {
            error = registrationError
        }
        focus.start(target: config.targetName)
        ensureTap()

        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollAccessibility()
        }
        RunLoop.main.add(timer, forMode: .common)
        axPollTimer = timer
    }

    func shutdown() {
        guard started else { return }
        started = false
        panning.deactivate()
        CursorHider.show()
        cursorHiddenByUs = false
        tap.stop()
        focus.stop()
        hotkeys.unregister()
        axPollTimer?.invalidate()
        axPollTimer = nil
    }

    // MARK: - Permissions

    func requestAccessibility() {
        Permissions.requestAccessibilityPrompt()
        recheckPermissions()
    }

    func recheckPermissions() {
        accessibilityTrusted = Permissions.isAccessibilityTrusted
        if accessibilityTrusted {
            ensureTap()
        }
    }

    private func pollAccessibility() {
        let trusted = Permissions.isAccessibilityTrusted
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
        }
        if trusted && !tap.isRunning {
            ensureTap()
        }
    }

    private func ensureTap() {
        guard Permissions.isAccessibilityTrusted else { return }
        if !tap.start() {
            error = RMBError(code: .inputTapUnavailable)
        }
    }


    // MARK: - Panning state

    private func panningStateChanged() {
        if !isPanningEnabled {
            deactivatePanning()
        }
        // Turning on waits for the next focus snapshot (≤100 ms).
        recomputeStatus()
    }

    private func handleFocus(_ snapshot: FocusMonitor.Snapshot) {
        if let name = snapshot.lastExternalName {
            lastExternalName = name
        }
        targetPID = snapshot.targetPID

        let shouldActivate = isPanningEnabled && snapshot.targetFocused && !snapshot.isOwnAppFocused
        if shouldActivate != panning.isActive {
            if shouldActivate {
                activatePanning()
            } else {
                deactivatePanning()
            }
        } else if shouldActivate {
            // Keep the pin center in sync in case the window moved.
            panning.updateCenter(computedCenter())
        }
        recomputeStatus()
    }

    private func activatePanning() {
        panning.activate(at: computedCenter())
        applyCursorVisibility()
    }

    private func deactivatePanning() {
        panning.deactivate()
        if cursorHiddenByUs {
            CursorHider.show()
            cursorHiddenByUs = false
        }
    }

    private func computedCenter() -> CGPoint {
        let frame = targetPID.flatMap { WindowLocator.targetFrame(ownerPID: $0) }
            ?? WindowLocator.mainDisplayFrame
        return CGPoint(x: frame.midX + config.offsetX, y: frame.midY + config.offsetY)
    }

    private func applyCursorVisibility() {
        guard config.hideCursor else {
            if cursorHiddenByUs {
                CursorHider.show()
                cursorHiddenByUs = false
            }
            return
        }
        guard !cursorHiddenByUs, panning.isActive else { return }
        if let cursorError = CursorHider.hide() {
            error = cursorError
        } else {
            cursorHiddenByUs = true
        }
    }

    private func recomputeStatus() {
        let newStatus: Status
        if !isPanningEnabled {
            newStatus = .idle
        } else if panning.isActive {
            newStatus = .active
        } else {
            newStatus = .armed
        }
        if status != newStatus {
            status = newStatus
        }
    }

    private func handleMouseButton(_ button: Int, down: Bool) {
        guard panning.isActive, let key = config.bindings[button] else { return }
        keySim.setKey(key, down: down)
    }

    private func applyConfig() {
        panning.updateConfig(config)
        focus.retarget(config.targetName)
        if panning.isActive {
            panning.updateCenter(computedCenter())
            applyCursorVisibility()
        }
    }

    // MARK: - UI actions

    /// Pre-fills the target from the last app/window observed in front
    /// before RMB itself was focused.
    func detectTarget() {
        if let name = lastExternalName, !name.isEmpty {
            config.targetName = name
        } else {
            error = RMBError(
                code: .targetNotFound,
                detail: "Focus the emulator window first, then click Detect."
            )
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
