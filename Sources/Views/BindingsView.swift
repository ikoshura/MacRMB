import RMBKit
import SwiftUI

/// 'Bindings' pane: right-stick keys, mouse-button bindings, behavior flags.
struct BindingsView: View {
    @EnvironmentObject private var model: AppModel

    private static let buttonNames = ["Left", "Right", "Middle"]

    var body: some View {
        Form {
            Section("Right Stick keys") {
                KeyPicker(title: "Up", key: $model.config.directions.up)
                KeyPicker(title: "Down", key: $model.config.directions.down)
                KeyPicker(title: "Left", key: $model.config.directions.left)
                KeyPicker(title: "Right", key: $model.config.directions.right)
                Text("Held while panning — bind the same keys to the Right Stick in your emulator (default I/K/J/L, matching upstream RMB).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Mouse buttons") {
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

            Section("Behavior") {
                Toggle("Hide cursor while panning", isOn: $model.config.hideCursor)
                Toggle("Auto-focus emulator on start", isOn: $model.config.autoFocus)
                Toggle("Enable mouse button bindings", isOn: $model.config.bindMouseButtons)
                Toggle("Persistent key press", isOn: $model.config.persistentKeyPress)
                Text("The hidden cursor re-asserts every 2.5 s over the target (original RMB behavior) and is restored on stop or quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
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
