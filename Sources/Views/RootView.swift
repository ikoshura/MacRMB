import AppKit
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

/// Which of the two sidebar lists currently owns keyboard focus.
private enum SidebarFocus: Hashable {
    case main
    case about
}

struct RootView: View {
    @Binding var pane: Pane

    private static let mainPanes: [Pane] = [.status, .panning, .bindings, .behavior]

    @FocusState private var sidebarFocus: SidebarFocus?
    @State private var keyMonitor: Any?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Main rows (top).
                List(selection: $pane) {
                    ForEach(Self.mainPanes) { item in
                        Label(item.label, systemImage: item.symbol)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)
                .focused($sidebarFocus, equals: .main)

                // Same sidebar List component, one row, pinned at the bottom —
                // shares the selection binding so look matches exactly.
                List(selection: $pane) {
                    Label(Pane.about.label, systemImage: Pane.about.symbol)
                        .tag(Pane.about)
                }
                .listStyle(.sidebar)
                .focused($sidebarFocus, equals: .about)
                .scrollDisabled(true)
                .frame(minHeight: 32, maxHeight: 40)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
            .onAppear(perform: installKeyMonitor)
            .onDisappear(perform: removeKeyMonitor)
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

    // MARK: - Arrow-key bridge between the two lists

    /// Routes Up/Down across the main↔About boundary and moves real focus
    /// with it, so the highlight color never disagrees between the lists.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard sidebarFocus != nil,
                  let chars = event.charactersIgnoringModifiers,
                  let scalar = chars.unicodeScalars.first
            else { return event }

            switch Int(scalar.value) {
            case NSDownArrowFunctionKey where sidebarFocus == .main && pane == .behavior:
                pane = .about
                sidebarFocus = .about
                return nil
            case NSUpArrowFunctionKey where sidebarFocus == .about:
                pane = .behavior
                sidebarFocus = .main
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
