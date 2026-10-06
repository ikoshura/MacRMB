import MacRMBKit
import SwiftUI

/// Orange banner shown while Accessibility access is missing —
/// modeled on MetalGoose's PermissionBanner.
struct PermissionBanner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility access required", systemImage: "exclamationmark.shield.fill")
                .font(.headline)

            Text("MacRMB needs Accessibility access to read mouse movement and send key presses to your emulator window. No Screen Recording needed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Grant Access") {
                    model.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Again") {
                    model.recheckPermissions()
                }

                Button("Open Settings") {
                    Permissions.openAccessibilitySettings()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.35))
        )
    }
}
