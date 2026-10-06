import Carbon.HIToolbox
import Foundation

/// Registers a global hotkey (⌥⌘P) with the Carbon Event Manager — the same
/// mechanism MetalGoose uses for its global shortcuts. Hotkeys fire as raw
/// events, so toggling never steals focus from the emulator.
public final class HotkeyManager {
    public enum Hotkey: UInt32 {
        case togglePanning = 1
    }

    private static let signature: OSType = 0x524D4248 // 'RMBH'

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    public var onToggle: ((Hotkey) -> Void)?

    public init() {}

    /// Registers the hotkey. Returns `nil` on success or an `RMBError`
    /// (`RMB-UI-001`) if registration fails — typically because another
    /// app already owns ⌥⌘P.
    @discardableResult
    public func register() -> RMBError? {
        guard eventHandlerRef == nil else { return nil }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                if let hotkey = Hotkey(rawValue: hotKeyID.id) {
                    manager.onToggle?(hotkey)
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            return RMBError(code: .uiHotkeyTaken, detail: "InstallEventHandler failed (\(installStatus))")
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Hotkey.togglePanning.rawValue)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            let detail = registerStatus == eventHotKeyExistsErr
                ? "⌥⌘P is already taken by another app"
                : "RegisterEventHotKey failed (\(registerStatus))"
            return RMBError(code: .uiHotkeyTaken, detail: detail)
        }
        return nil
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
