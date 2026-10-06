import SwiftUI

/// Status-row building blocks adapted from NotProton's Status view design
/// (tone dot + headline/value + trailing actions inside grouped forms).
enum StatusTone {
    case ok, info, warning, bad, neutral

    var symbol: String {
        switch self {
        case .ok: "circle.fill"
        case .info: "circle"
        case .warning: "circle.fill"
        case .bad: "circle.fill"
        case .neutral: "circle"
        }
    }

    var color: Color {
        switch self {
        case .ok: .green
        case .info: .secondary
        case .warning: .orange
        case .bad: .red
        case .neutral: .secondary
        }
    }
}

struct StatusAction {
    let label: String
    var isProminent = false
    var help: String?
    var isEnabled = true
    let perform: () -> Void
}

struct StatusRow: View {
    let title: String
    var value: String?
    var tone: StatusTone?
    var detail: String?
    var secondaryAction: StatusAction?
    var action: StatusAction?

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let tone {
                    Image(systemName: tone.symbol)
                        .font(.system(size: 8))
                        .foregroundStyle(tone.color)
                        .frame(width: 10)
                        .accessibilityHidden(true)
                } else {
                    Color.clear.frame(width: 10, height: 1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let value {
                        Text(value)
                            .foregroundStyle(.secondary)
                    }
                    if let detail {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }
            }

            if secondaryAction != nil || action != nil {
                Spacer(minLength: 12)
            }
            if let secondaryAction {
                button(secondaryAction)
                    .padding(.trailing, 8)
            }
            if let action {
                button(action)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func button(_ action: StatusAction) -> some View {
        Group {
            if action.isProminent {
                Button(action.label, action: action.perform)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Button(action.label, action: action.perform)
                    .controlSize(.small)
            }
        }
        .disabled(!action.isEnabled)
        .help(action.help ?? "")
    }
}
