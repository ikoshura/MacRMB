import RMBKit
import SwiftUI

/// 'Panning' pane: upstream RMB analog parameters + pin position.
struct PanningView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Stick response") {
                LabeledSlider(
                    title: "Sensitivity", icon: "speedometer",
                    value: $model.config.sensitivity, range: 1...30, step: 0.5
                )
                LabeledSlider(
                    title: "Deadzone", icon: "scope",
                    value: $model.config.deadzone, range: 0...0.9, step: 0.01
                )
                LabeledSlider(
                    title: "Range", icon: "arrow.left.and.right.circle",
                    value: $model.config.range, range: 0.5...1.5, step: 0.05
                )
                LabeledSlider(
                    title: "Threshold", icon: "arrow.up.and.down.circle",
                    value: $model.config.threshold, range: 0...1, step: 0.05
                )
                LabeledSlider(
                    title: "Axis offset X", icon: "arrow.left.and.right",
                    value: $model.config.stickOffsetX, range: -0.75...0.75, step: 0.05
                )
                LabeledSlider(
                    title: "Axis offset Y", icon: "arrow.up.and.down",
                    value: $model.config.stickOffsetY, range: -0.75...0.75, step: 0.05
                )
                Text("Original RMB analog parameters: a radial deadzone around the pin point — movement beyond it holds the Right Stick keys, just like upstream.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Pin position") {
                Picker("Pin position", selection: $model.config.anchor) {
                    ForEach(AnchorPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                LabeledSlider(
                    title: "Pin offset X", icon: "move",
                    value: $model.config.pinOffsetX, range: -300...300, unit: " px"
                )
                LabeledSlider(
                    title: "Pin offset Y", icon: "move",
                    value: $model.config.pinOffsetY, range: -300...300, unit: " px"
                )
                Text("“Screen center” is the original behavior. Window corners are inset 80 px so the cursor never rests on titlebar/pause hover zones.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }
}
