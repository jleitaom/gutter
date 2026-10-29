import AppKit
import Carbon.HIToolbox
import Combine
import GutterKit

// Gutter is a pure menu bar app: no SwiftUI App scenes, so macOS never opens an empty
// window when the app is launched again (e.g. from Spotlight).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeys: [UInt32: HotKey] = [:]
    private var statusItem: StatusItemController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if Snapshot.runIfRequested() { return }
        #endif

        NSApp.mainMenu = MainMenu.make()
        WindowManager.shared.start()
        statusItem = StatusItemController()
        _ = Updater.shared // starts Sparkle's scheduled checks

        // ⌃⌥⌘F fits the front window, ⌃⌥⌘D every window; a popup says what was fitted.
        bindHotKey(id: 1, keyCode: kVK_ANSI_F, enabled: Preferences.shared.$hotKeyEnabled, inUse: \.hotKeyInUse) { [weak self] in
            self?.statusItem?.showShortcutReport(WindowManager.shared.fitFrontmostWindow())
        }
        bindHotKey(id: 2, keyCode: kVK_ANSI_D, enabled: Preferences.shared.$fitAllHotKeyEnabled, inUse: \.fitAllHotKeyInUse) { [weak self] in
            let manager = WindowManager.shared
            self?.statusItem?.showShortcutReport(manager.accessibilityGranted ? .fittedAll(count: manager.fitAllWindows()) : .needsAccess)
        }
    }

    /// Registers the shortcut whenever its switch is on, and reports when another app holds it.
    private func bindHotKey(id: UInt32, keyCode: Int, enabled: Published<Bool>.Publisher,
                            inUse: ReferenceWritableKeyPath<WindowManager, Bool>, action: @escaping () -> Void) {
        enabled
            .sink { [weak self] enabled in
                self?.hotKeys[id] = nil // unregister first, so re-enabling doesn't collide with ourselves
                self?.hotKeys[id] = enabled
                    ? HotKey(id: id, keyCode: UInt32(keyCode), modifiers: UInt32(cmdKey | optionKey | controlKey), action: action)
                    : nil
                WindowManager.shared[keyPath: inUse] = enabled && self?.hotKeys[id] == nil
            }
            .store(in: &cancellables)
    }

    /// Opening Gutter while it's already running (Spotlight, Finder, Dock) shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.openPanel()
        return false
    }

    /// ⌘, from the main menu, while the Settings window is in front.
    @objc func showSettings(_ sender: Any?) {
        statusItem?.openSettings()
    }
}
