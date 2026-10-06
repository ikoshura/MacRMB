import MacRMBKit
import SwiftUI

/// 'Status' pane: engine state, panning control, target, permissions.
struct StatusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            if !model.accessibilityTrusted {
                Section {
                    PermissionBanner()
                }
            }

            Section("Engine") {
                StatusRow(
                    title: "Engine",
                    value: model.engineStarted ? "Running — original RMB core" : "Not started",
                    tone: model.engineStarted ? .ok : .bad
                )
                StatusRow(
                    title: "Panning",
                    value: model.isPanning ? "Active — mouse drives the camera" : "Stopped",
                    tone: model.isPanning ? .ok : .neutral,
                    action: StatusAction(
                        label: model.isPanning ? "Stop" : "Start",
                        isProminent: true,
                        help: "Toggle mouse panning (⌥⌘P)."
                    ) {
                        model.togglePanning()
                    }
                )
                StatusRow(
                    title: "Emulator in front",
                    value: model.targetActive ? "Matched: \(model.config.targetName)" : "No match",
                    tone: model.targetActive ? .ok : .info
                )
                HStack {
                    Text("Toggle hotkey")
                        .font(.headline)
                    Spacer()
                    HotkeyRecorder()
                }
                Text("Click, then press the new combo. Needs a modifier (⌃⌥⇧⌘); Esc cancels. Conflicts fall back to the previous hotkey.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Target") {
                HStack {
                    TextField("Window or app name", text: $model.config.targetName)
                        .textFieldStyle(.roundedBorder)
                    Button("Detect") {
                        model.detectTarget()
                    }
                }
                Text("Matches the emulator's window title or app name. Focus the emulator, then click Detect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                StatusRow(
                    title: "Accessibility",
                    value: model.accessibilityTrusted ? "Granted" : "Missing — panning won't work",
                    tone: model.accessibilityTrusted ? .ok : .warning,
                    detail: model.accessibilityTrusted
                        ? nil
                        : "The engine also asks for Input Monitoring and Allow Events at first launch.",
                    secondaryAction: StatusAction(label: "Settings") {
                        Permissions.openAccessibilitySettings()
                    },
                    action: StatusAction(label: "Check") {
                        model.recheckPermissions()
                    }
                )
            }
        }
        .formStyle(.grouped)
        .alert(item: $model.error) { error in
            Alert(
                title: Text(error.code.rawValue),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
