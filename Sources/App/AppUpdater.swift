import Combine
import Foundation
import Sparkle

/// Sparkle update bridge. Owns the standard updater controller, surfaces
/// check status for the About page, and applies the persisted
/// "check automatically" setting. The EdDSA public key and feed URL live
/// in Info.plist (SUPublicEDKey / SUFeedURL).
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()

    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckResult: String?

    let updaterController: SPUStandardUpdaterController
    private let bridge: DelegateBridge

    private override init() {
        let bridge = DelegateBridge()
        self.bridge = bridge // before super.init; the controller holds it weakly
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: bridge,
            userDriverDelegate: nil
        )
        super.init()
        bridge.owner = self
    }

    func applyAutomaticChecks(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        isChecking = true
        lastCheckResult = nil
        updaterController.checkForUpdates(nil)
    }

    fileprivate func finishCheck(with message: String?) {
        DispatchQueue.main.async {
            self.isChecking = false
            self.lastCheckResult = message
        }
    }
}

/// Thin SPUUpdaterDelegate forwarder — the delegate is needed at
/// controller-construction time, i.e. before `self` exists.
private final class DelegateBridge: NSObject, SPUUpdaterDelegate {
    weak var owner: AppUpdater?

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        owner?.finishCheck(with: "You're up to date.")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let code = (error as NSError).code
        if code == 1001 { // SUNoUpdateError
            owner?.finishCheck(with: "You're up to date.")
        } else {
            owner?.finishCheck(with: "Couldn't check for updates: \(error.localizedDescription)")
        }
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        // An update was found — Sparkle's standard UI takes over from here.
        owner?.finishCheck(with: nil)
    }
}
