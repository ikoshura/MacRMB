import SwiftUI

/// Sidebar panes, NotProton-style. About is pinned at the bottom.
enum Pane: String, CaseIterable, Identifiable, Hashable {
    case status
    case panning
    case bindings
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .status: "Status"
        case .panning: "Panning"
        case .bindings: "Bindings"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .status: "checklist"
        case .panning: "cursorarrow.rays"
        case .bindings: "keyboard"
        case .about: "info.circle"
        }
    }
}

struct RootView: View {
    @Binding var pane: Pane

    private static let mainPanes: [Pane] = [.status, .panning, .bindings]

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $pane) {
                    ForEach(Self.mainPanes) { item in
                        Label(item.label, systemImage: item.symbol)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                aboutRow
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(pane == .about ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            switch pane {
            case .status: StatusView()
            case .panning: PanningView()
            case .bindings: BindingsView()
            case .about: AboutView()
            }
        }
    }

    private var aboutRow: some View {
        Button {
            pane = .about
        } label: {
            Label(Pane.about.label, systemImage: Pane.about.symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(pane == .about ? Color.accentColor : .primary)
    }
}
