import MacRMBKit
import SwiftUI

/// 'Behavior' pane: cursor, focus, and key-press behavior flags.
struct BehaviorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Hide cursor while panning", isOn: $model.config.hideCursor)
                Toggle("Auto-focus emulator on start", isOn: $model.config.autoFocus)
                Toggle("Enable mouse button bindings", isOn: $model.config.bindMouseButtons)
                Toggle("Persistent key press", isOn: $model.config.persistentKeyPress)
                Text("The hidden cursor re-asserts every 2.5 s over the target and is restored on stop or quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
