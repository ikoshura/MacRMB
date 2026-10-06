import RMBKit
import SwiftUI

/// Main settings window, styled after MetalGoose's grouped configuration UI:
/// permission banner on top, status + toggles, grouped sections, and errors
/// surfaced as coded alerts.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    private static let buttonNames = ["Left", "Right", "Middle", "Back", "Forward"]

    var body: some View {
        Form {
            if !model.accessibilityTrusted {
                Section {
                    PermissionBanner()
                }
            }

            Section("Status") {
                statusRow
                Toggle("Panning enabled (⌥⌘P)", isOn: $model.isPanningEnabled)
            }

            Section("Target") {
                HStack {
                    TextField("Window or app name", text: $model.config.targetName)
                        .textFieldStyle(.roundedBorder)
                    Button("Detect") {
                        model.detectTarget()
                    }
                }
                Text("Matches the emulator's window title or app name (e.g. “Ryujinx”). Focus the emulator, then click Detect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Mouse panning") {
                LabeledSlider(
                    title: "Deadzone", icon: "scope",
                    value: $model.config.deadzone, range: 0...60, unit: " px"
                )
                LabeledSlider(
                    title: "Sensitivity", icon: "speedometer",
                    value: $model.config.sensitivity, range: 0.1...3, step: 0.1, unit: "×"
                )
                LabeledSlider(
                    title: "Center offset X", icon: "arrow.left.and.right",
                    value: $model.config.offsetX, range: -300...300, unit: " px"
                )
                LabeledSlider(
                    title: "Center offset Y", icon: "arrow.up.and.down",
                    value: $model.config.offsetY, range: -300...300, unit: " px"
                )
                Toggle("Invert vertical axis", isOn: $model.config.invertY)
                Text("While panning, the cursor is pinned at the window center. Movement past the deadzone holds the arrow keys — bind them to the Right Stick in your emulator's input config.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Cursor") {
                Toggle("Hide cursor while panning", isOn: $model.config.hideCursor)
                Text("Keeps the pinned cursor out of sight. Restored automatically when panning stops — or if RMB quits or crashes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Mouse button bindings") {
                ForEach(0..<Self.buttonNames.count, id: \.self) { index in
                    BindingRow(
                        buttonIndex: index,
                        buttonName: Self.buttonNames[index],
                        key: binding(for: index)
                    )
                }
                Text("Bind ZL/ZR/A/B… to keys in the emulator's input config, then pick the same key here to fire it with a mouse button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var statusRow: some View {
        HStack {
            Image(systemName: model.status == .active ? "cursorarrow.rays" : "cursorarrow")
                .foregroundStyle(model.status == .active ? Color.green : Color.secondary)
            Text(model.status.rawValue)
                .font(.headline)
            Spacer()
            Text("⌥⌘P")
                .font(.caption.monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: Capsule())
        }
    }

    private func binding(for button: Int) -> Binding<UInt16?> {
        Binding(
            get: { model.config.bindings[button] },
            set: { newValue in
                if let newValue {
                    model.config.bindings[button] = newValue
                } else {
                    model.config.bindings.removeValue(forKey: button)
                }
            }
        )
    }
}
