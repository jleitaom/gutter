import AppKit
import Carbon.HIToolbox
import Combine

// Gutter is a pure menu bar app: no SwiftUI App scenes, so macOS never opens an empty
// window when the app is launched again (e.g. from Spotlight).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?
    private var statusItem: StatusItemController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if Snapshot.runIfRequested() { return }
        #endif

        WindowManager.shared.start()
        statusItem = StatusItemController()

        Preferences.shared.$hotKeyEnabled
            .sink { [weak self] enabled in
                self?.hotKey = nil // unregister first, so re-enabling doesn't collide with ourselves
                self?.hotKey = enabled
                    ? HotKey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | optionKey | controlKey)) {
                        WindowManager.shared.fitFrontmostWindow()
                    }
                    : nil
                WindowManager.shared.hotKeyInUse = enabled && self?.hotKey == nil
            }
            .store(in: &cancellables)
    }

    /// Opening Gutter while it's already running (Spotlight, Finder, Dock) shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.openPanel()
        return false
    }
}
