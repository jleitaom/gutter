import AppKit
import Combine
import Sparkle

/// Update checks through Sparkle, against the appcast attached to the latest GitHub release.
/// Sparkle asks people before it checks on its own, and only runs in a bundled app with a
/// feed in Info.plist, so `swift run` builds and snapshots never touch the network.
final class Updater: ObservableObject {
    static let shared = Updater()

    /// False while a check is running, or when updates aren't available in this build.
    @Published private(set) var canCheck = false
    private let controller: SPUStandardUpdaterController?

    private init() {
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
    }

    var isAvailable: Bool { controller != nil }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set {
            objectWillChange.send()
            controller?.updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() {
        // A menu bar app isn't active, so bring Sparkle's window to the front.
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }
}
