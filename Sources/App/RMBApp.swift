import AppKit
import RMBKit
import SwiftUI

@main
struct RMBApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(minWidth: 540, idealWidth: 580, minHeight: 480, idealHeight: 620)
        }
        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.status == .active ? "cursorarrow.rays" : "cursorarrow")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Developer/self-test mode: verifies the (undocumented) background
        // cursor-hide path once and exits with a machine-readable result.
        if CommandLine.arguments.contains("--check-cursor") {
            Self.runCursorCheck()
        }
        AppModel.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppModel.shared.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func runCursorCheck() -> Never {
        if let hideError = CursorHider.hide() {
            print("cursor-hide: FAIL \(hideError.fullDescription)")
            exit(1)
        }
        print("cursor-hide: OK (hidden)")
        usleep(400_000)
        CursorHider.show()
        print("cursor-show: OK (restored)")
        exit(0)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button(model.isPanningEnabled ? "Disable Panning" : "Enable Panning (⌥⌘P)") {
            model.isPanningEnabled.toggle()
        }
        Button("Status: \(model.status.rawValue)") {}
            .disabled(true)
        Button("Settings…") {
            model.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
        Divider()
        Button("Quit RMB") {
            NSApp.terminate(nil)
        }
    }
}
