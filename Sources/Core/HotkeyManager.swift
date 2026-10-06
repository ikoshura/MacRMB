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

    /// Registers the global toggle hotkey. Returns `nil` on success or an
    /// `RMBError` (`RMB-UI-001`) if registration fails — typically because
    /// another app already owns that combo.
    @discardableResult
    public func register(key: UInt32, modifier: UInt32) -> RMBError? {
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
            key,
            modifier,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            let detail = registerStatus == eventHotKeyExistsErr
                ? "\(Self.displayString(key: UInt16(key), modifiers: Int(modifier))) is already taken by another app"
                : "RegisterEventHotKey failed (\(registerStatus))"
            return RMBError(code: .uiHotkeyTaken, detail: detail)
        }
        return nil
    }

    /// Human-readable combo, e.g. "⌥⌘P" (order: ⌃ ⌥ ⇧ ⌘).
    public static func displayString(key: UInt16, modifiers: Int) -> String {
        var text = ""
        if modifiers & controlKey != 0 { text += "⌃" }
        if modifiers & optionKey != 0 { text += "⌥" }
        if modifiers & shiftKey != 0 { text += "⇧" }
        if modifiers & cmdKey != 0 { text += "⌘" }
        text += KeyCodeCatalog.name(for: key)
        return text
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
