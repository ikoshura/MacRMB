import AppKit
import RMBKit
import SwiftUI

@main
struct RMBApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared
    @State private var pane: Pane = .status

    var body: some Scene {
        Window("RMB", id: "main") {
            RootView(pane: $pane)
                .environmentObject(model)
                .frame(minWidth: 700, minHeight: 480)
        }
        .defaultSize(width: 880, height: 640)
        .commands { menus }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.isPanning ? "cursorarrow.rays" : "cursorarrow")
        }
    }

    @CommandsBuilder
    private var menus: some Commands {
        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .sidebar) {
            Button("Status") { pane = .status }
                .keyboardShortcut("1", modifiers: .command)
            Button("Panning") { pane = .panning }
                .keyboardShortcut("2", modifiers: .command)
            Button("Bindings") { pane = .bindings }
                .keyboardShortcut("3", modifiers: .command)

            Divider()

            Button(model.isPanning ? "Stop Panning" : "Start Panning") {
                model.togglePanning()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Developer/self-test mode: exercise the engine's Native cursor
        // hide/show path once and exit with a machine-readable result.
        if CommandLine.arguments.contains("--check-cursor") {
            rmb_engine_cursor_self_test()
            print("cursor-hide/show: OK (engine Native path)")
            exit(0)
        }
        AppModel.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button(model.isPanning ? "Stop Panning" : "Start Panning (⌥⌘P)") {
            model.togglePanning()
        }
        Button("Show RMB") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit RMB") {
            NSApp.terminate(nil)
        }
    }
}
