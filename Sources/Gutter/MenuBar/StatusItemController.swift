import AppKit
import GutterKit
import Combine
import SwiftUI

/// Owns the menu bar icon and the glass panel it opens.
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = GlassPanel()
    private let shortcutPopup = ShortcutPopup()
    private var hostingView: NSHostingView<AnyView>?
    private var outsideClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        let content = MenuView(openSettings: { [weak self] in self?.openSettings() })
            .environmentObject(Preferences.shared)
            .environmentObject(WindowManager.shared)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
                self?.panel.resize(to: size)
            }
        let hosting = NSHostingView(rootView: AnyView(content))
        hostingView = hosting
        panel.setContent(hosting)
        panel.onCancel = { [weak self] in self?.closePanel() }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Gutter")
        }

        Preferences.shared.$autoFit
            .sink { [weak self] active in self?.statusItem.button?.image = AppInfo.menuBarIcon(active: active) }
            .store(in: &cancellables)
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else if panel.isVisible && panel.alphaValue > 0 {
            closePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Right-click menu

    private func showContextMenu() {
        closePanel()
        // Attach the menu just for this click so left-clicks keep opening the panel.
        statusItem.menu = buildContextMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func buildContextMenu() -> NSMenu {
        let prefs = Preferences.shared
        let manager = WindowManager.shared
        let menu = NSMenu()

        // Status
        menu.addItem(.sectionHeader(title: statusText))
        if !manager.accessibilityGranted {
            menu.addItem(ActionItem("Grant Accessibility Access…") { manager.requestAccessibility() })
        }
        menu.addItem(ActionItem("Open Gutter") { [weak self] in self?.showPanel() })
        menu.addItem(.separator())

        // Fitting
        let fitAll = ActionItem("Fit All Windows") { manager.fitAllWindows() }
        fitAll.isEnabled = manager.accessibilityGranted
        if prefs.fitAllHotKeyEnabled && !manager.fitAllHotKeyInUse {
            fitAll.keyEquivalent = "d"
            fitAll.keyEquivalentModifierMask = [.control, .option, .command]
        }
        menu.addItem(fitAll)
        if let app = manager.lastActiveApp, let name = app.localizedName {
            let fitOne = ActionItem("Fit \(name) Window") { manager.fitLastActiveWindow() }
            fitOne.isEnabled = manager.accessibilityGranted && !manager.isExcluded(app)
            if prefs.hotKeyEnabled && !manager.hotKeyInUse {
                // Shown for reference; the global shortcut works everywhere.
                fitOne.keyEquivalent = "f"
                fitOne.keyEquivalentModifierMask = [.control, .option, .command]
            }
            menu.addItem(fitOne)
        }
        menu.addItem(.separator())

        // Gap and exclusions
        let gapItem = NSMenuItem(title: "Left Gap", action: nil, keyEquivalent: "")
        gapItem.submenu = gapMenu()
        menu.addItem(gapItem)
        if let app = manager.lastActiveApp, let name = app.localizedName, let bundleID = app.bundleIdentifier {
            let excluded = prefs.excludedBundleIDs.contains(bundleID)
            menu.addItem(ActionItem("Never Resize \(name)", checked: excluded) {
                if excluded {
                    prefs.excludedBundleIDs.removeAll { $0 == bundleID }
                } else {
                    prefs.excludedBundleIDs.append(bundleID)
                }
            })
        }
        menu.addItem(.separator())

        // Options
        menu.addItem(ActionItem("Auto-fit New Windows", checked: prefs.autoFit) { prefs.autoFit.toggle() })
        menu.addItem(ActionItem("Only with Stage Manager", checked: prefs.onlyWithStageManager) { prefs.onlyWithStageManager.toggle() })
        menu.addItem(ActionItem("Full Width When Strip Is Hidden", checked: prefs.fullWidthWhenStripHidden) { prefs.fullWidthWhenStripHidden.toggle() })
        menu.addItem(ActionItem("Refit on Display Change", checked: prefs.refitOnDisplayChange) { prefs.refitOnDisplayChange.toggle() })
        menu.addItem(ActionItem("Open at Login", checked: LaunchAtLogin.isEnabled) { LaunchAtLogin.set(!LaunchAtLogin.isEnabled) })
        menu.addItem(.separator())

        // App
        let settings = ActionItem("Settings…") { [weak self] in self?.openSettings() }
        settings.keyEquivalent = ","
        menu.addItem(settings)
        let updates = ActionItem("Check for Updates…") { Updater.shared.checkForUpdates() }
        updates.isEnabled = Updater.shared.canCheck
        menu.addItem(updates)
        menu.addItem(ActionItem("About Gutter") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(ActionItem("Gutter on GitHub") { NSWorkspace.shared.open(AppInfo.repositoryURL) })
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Gutter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    /// Gap presets for every display, with the current one checked.
    private func gapMenu() -> NSMenu {
        let prefs = Preferences.shared
        let menu = NSMenu()
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            if screens.count > 1 {
                if index > 0 { menu.addItem(.separator()) }
                menu.addItem(.sectionHeader(title: screen.localizedName))
            }
            let displayID = screen.displayUUID
            let current = prefs.margins(for: displayID).left
            for preset in Margins.gapPresets {
                menu.addItem(ActionItem("\(preset.name) · \(Int(preset.value)) pt", checked: current == preset.value) {
                    var margins = prefs.margins(for: displayID)
                    margins.left = preset.value
                    prefs.setMargins(margins, for: displayID)
                })
            }
            if !Margins.gapPresets.contains(where: { $0.value == current }) {
                let custom = NSMenuItem(title: "Custom · \(Int(current)) pt", action: nil, keyEquivalent: "")
                custom.state = .on
                custom.isEnabled = false
                menu.addItem(custom)
            }
        }
        return menu
    }

    private var statusText: String {
        "Gutter · \(WindowManager.shared.status.title)"
    }

    /// Says what a shortcut did, under the menu bar icon, unless the popup is turned off or the
    /// panel is open (it covers the same spot).
    func showShortcutReport(_ report: FitReport) {
        guard Preferences.shared.shortcutPopup, !(panel.isVisible && panel.alphaValue > 0) else { return }
        var anchor: NSRect?
        if let button = statusItem.button, let window = button.window {
            anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        shortcutPopup.show(report, below: anchor)
    }

    func openPanel() {
        showPanel()
    }

    func openSettings() {
        // The glass panel floats above everything, so step aside for the window.
        closePanel()
        SettingsWindowController.shared.show()
    }

    // MARK: - Panel

    /// The SwiftUI content's natural size, measured fresh each time.
    private var contentSize: CGSize {
        guard let hostingView else { return .zero }
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        panel.show(below: anchor, on: buttonWindow.screen, size: contentSize)
        button.highlight(true)

        // Clicks in other apps close the panel. The panel can be shown while already open
        // (reopening Gutter from Spotlight), so replace any monitor instead of adding a second.
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    #if DEBUG
    /// Shows the shortcut popup and returns the icon's and the popup's frames, for `--popup-test`.
    func debugShowShortcutReport(_ report: FitReport) -> (icon: NSRect, popup: NSRect) {
        showShortcutReport(report)
        guard let button = statusItem.button, let window = button.window else { return (.zero, shortcutPopup.frame) }
        return (window.convertToScreen(button.convert(button.bounds, to: nil)), shortcutPopup.frame)
    }

    /// Opens the panel and returns its frame, for `--panel-test`.
    func debugOpenPanel() -> NSRect {
        showPanel()
        return panel.frame
    }
    #endif

    private func closePanel() {
        guard panel.isVisible else { return }
        panel.dismiss()
        statusItem.button?.highlight(false)
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}

/// A menu item that runs a closure, optionally shown with a checkmark.
/// `nonisolated` because NSMenuItem's initializers are; menus only run the handler on the main thread.
nonisolated private final class ActionItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, checked: Bool? = nil, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        if let checked { state = checked ? .on : .off }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        let handler = handler
        MainActor.assumeIsolated { handler() }
    }
}
