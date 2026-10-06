import Foundation

/// Error identifiers in the MetalGoose style: stable codes that are never
/// renumbered. Gaps are intentional and reserved for future errors.
public enum RMBErrorCode: String, CaseIterable, Sendable {
    // UI (RMB-UI)
    case uiHotkeyTaken = "RMB-UI-001"
    case uiSelfFocused = "RMB-UI-002"

    // Permissions (RMB-PERM)
    case permissionAccessibility = "RMB-PERM-001"

    // Input (RMB-IN)
    case inputTapUnavailable = "RMB-IN-001"
    case inputKeyPostFailed = "RMB-IN-002"

    // Cursor (RMB-CUR)
    case cursorBackgroundDenied = "RMB-CUR-001"
    case cursorHideFailed = "RMB-CUR-002"

    // Target (RMB-TGT)
    case targetNotFound = "RMB-TGT-001"

    public var summary: String {
        switch self {
        case .uiHotkeyTaken:
            return "The global shortcut ⌥⌘P is already registered by another app."
        case .uiSelfFocused:
            return "RMB is frontmost — switch to the emulator window."
        case .permissionAccessibility:
            return "Accessibility access is required to read the mouse and send keys."
        case .inputTapUnavailable:
            return "Could not create the event tap. Grant Accessibility access, then reopen RMB."
        case .inputKeyPostFailed:
            return "A keyboard event could not be posted."
        case .cursorBackgroundDenied:
            return "WindowServer refused background cursor control."
        case .cursorHideFailed:
            return "CoreGraphics refused to hide the cursor."
        case .targetNotFound:
            return "No window matched the target name."
        }
    }
}

/// An error surfaced to the UI, shown as an in-app alert with its stable code.
public struct RMBError: Identifiable, Equatable, LocalizedError {
    public let code: RMBErrorCode
    public var detail: String?

    public init(code: RMBErrorCode, detail: String? = nil) {
        self.code = code
        self.detail = detail
    }

    public var id: String { code.rawValue }

    public var message: String {
        [code.summary, detail].compactMap { $0 }.joined(separator: " ")
    }

    public var fullDescription: String { "\(code.rawValue): \(message)" }

    public var errorDescription: String? { fullDescription }
}
