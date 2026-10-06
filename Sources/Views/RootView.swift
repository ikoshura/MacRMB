import SwiftUI

/// Sidebar panes, NotProton-style. About is pinned at the bottom.
enum Pane: String, CaseIterable, Identifiable, Hashable {
    case status
    case panning
    case bindings
    case behavior
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .status: "Status"
        case .panning: "Panning"
        case .bindings: "Bindings"
        case .behavior: "Behavior"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .status: "checklist"
        case .panning: "cursorarrow.rays"
        case .bindings: "keyboard"
        case .behavior: "switch.2"
        case .about: "info.circle"
        }
    }
}

struct RootView: View {
    @Binding var pane: Pane

    private static let mainPanes: [Pane] = [.status, .panning, .bindings, .behavior]

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
                .tint(.secondary)
                .focusable(false)

                // Same sidebar List component, one row, pinned at the bottom —
                // shares the selection binding so look & behavior match exactly.
                List(selection: $pane) {
                    Label(Pane.about.label, systemImage: Pane.about.symbol)
                        .tag(Pane.about)
                }
                .listStyle(.sidebar)
                .tint(.secondary)
                .focusable(false)
                .scrollDisabled(true)
                .frame(minHeight: 32, maxHeight: 40)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            switch pane {
            case .status: StatusView()
            case .panning: PanningView()
            case .bindings: BindingsView()
            case .behavior: BehaviorView()
            case .about: AboutView()
            }
        }
    }
}
