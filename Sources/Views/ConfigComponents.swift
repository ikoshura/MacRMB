import AppKit
import Carbon.HIToolbox
import MacRMBKit
import SwiftUI

/// Titled slider row with a live value readout.
struct LabeledSlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var unit: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(value, specifier: "%.1f")\(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

/// One mouse-button → key binding row.
struct BindingRow: View {
    let buttonIndex: Int
    let buttonName: String
    @Binding var key: UInt16?

    var body: some View {
        HStack {
            Image(systemName: "\(buttonIndex + 1).circle")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(buttonName)
            Spacer()
            Picker("", selection: $key) {
                Text("None").tag(UInt16?.none)
                ForEach(KeyCodeCatalog.common, id: \.code) { item in
                    Text(item.name).tag(Optional(item.code))
                }
            }
            .labelsHidden()
            .frame(width: 160, alignment: .trailing)
        }
    }
}

/// Picker for a non-optional direction key (Up/Down/Left/Right).
struct KeyPicker: View {
    let title: String
    @Binding var key: UInt16

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $key) {
                ForEach(KeyCodeCatalog.common, id: \.code) { item in
                    Text(item.name).tag(item.code)
                }
            }
            .labelsHidden()
            .frame(width: 160, alignment: .trailing)
        }
    }
}

/// Click to record a new global hotkey combo. Requires at least one
/// modifier (⌃⌥⇧⌘); Escape cancels recording.
struct HotkeyRecorder: View {
    @EnvironmentObject private var model: AppModel
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(label)
                .monospaced()
                .frame(minWidth: 110)
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if isRecording {
            return "Type shortcut…"
        }
        return HotkeyManager.displayString(
            key: model.config.hotkeyKey,
            modifiers: model.config.hotkeyModifiers
        )
    }

    private func toggle() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels.
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Bare key presses are rejected — a shortcut needs a modifier.
            guard flags.contains(.control) || flags.contains(.option)
                || flags.contains(.shift) || flags.contains(.command)
            else {
                NSSound.beep()
                return nil
            }
            let carbon = Self.carbonModifiers(flags)
            let key = UInt16(event.keyCode)
            stopRecording()
            _ = model.setHotkey(key: key, modifiers: carbon)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var mask = 0
        if flags.contains(.control) { mask |= controlKey }
        if flags.contains(.option) { mask |= optionKey }
        if flags.contains(.shift) { mask |= shiftKey }
        if flags.contains(.command) { mask |= cmdKey }
        return mask
    }
}
