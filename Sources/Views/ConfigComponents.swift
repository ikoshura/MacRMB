import RMBKit
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
            .frame(width: 150)
        }
    }
}
