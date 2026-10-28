import AppKit

/// Gutter is a menu bar app, so this menu is never shown. Its key equivalents are what make
/// ⌘, ⌘W, ⌘Z, ⌘C, ⌘V and ⌘Q work while the Settings window is in front.
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        add("Gutter", to: main, items: [
            NSMenuItem(title: "Settings…", action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ","),
            .separator(),
            NSMenuItem(title: "Quit Gutter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ])

        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        add("Edit", to: main, items: [
            NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"),
            redo,
            .separator(),
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
        ])

        add("Window", to: main, items: [
            NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"),
        ])
        return main
    }

    private static func add(_ title: String, to main: NSMenu, items: [NSMenuItem]) {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
    }
}
