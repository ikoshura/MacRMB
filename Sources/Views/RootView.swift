import SwiftUI

/// Sidebar panes, NotProton-style.
enum Pane: String, CaseIterable, Identifiable, Hashable {
    case status
    case panning
    case bindings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .status: "Status"
        case .panning: "Panning"
        case .bindings: "Bindings"
        }
    }

    var symbol: String {
        switch self {
        case .status: "checklist"
        case .panning: "cursorarrow.rays"
        case .bindings: "keyboard"
        }
    }
}

struct RootView: View {
    @Binding var pane: Pane

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                ForEach(Pane.allCases) { item in
                    Label(item.label, systemImage: item.symbol)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            switch pane {
            case .status: StatusView()
            case .panning: PanningView()
            case .bindings: BindingsView()
            }
        }
    }
}
