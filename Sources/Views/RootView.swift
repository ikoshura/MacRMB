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
            // Single List = single selection container: arrow keys flow
            // through every row including About, and the highlight color
            // is always consistent.
            List(selection: $pane) {
                Section {
                    ForEach(Self.mainPanes) { item in
                        Label(item.label, systemImage: item.symbol)
                            .tag(item)
                    }
                }
                Section {
                    Label(Pane.about.label, systemImage: Pane.about.symbol)
                        .tag(Pane.about)
                }
            }
            .listStyle(.sidebar)
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
