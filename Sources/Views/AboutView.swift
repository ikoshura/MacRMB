import MacRMBKit
import SwiftUI

/// 'About' pane: version, Sparkle update check, auto-update preference.
struct AboutView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updater: AppUpdater

    var body: some View {
        Form {
            Section("MacRMB") {
                Text("Version")
                    .font(.headline)
                Text(appVersion)
                    .foregroundStyle(.secondary)
                StatusRow(
                    title: "Updates",
                    value: updater.lastCheckResult ?? "Never checked",
                    action: StatusAction(
                        label: updater.isChecking ? "Checking…" : "Check for Updates",
                        isProminent: true,
                        isEnabled: !updater.isChecking
                    ) {
                        updater.checkForUpdates()
                    }
                )
            }

            Section("Settings") {
                Toggle(
                    "Check for updates automatically",
                    isOn: $model.config.checkForUpdatesAutomatically
                )
                Text("Uses Sparkle. The feed URL and EdDSA public key are configured in the app's Info.plist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
