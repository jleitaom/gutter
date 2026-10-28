#if DEBUG
import AppKit
import SwiftUI

/// Development helper: `swift run Gutter --snapshot out.png [--dark]` renders the menu panel
/// to a PNG and exits, so design changes can be checked without opening the menu bar.
enum Snapshot {
    /// `swift run Gutter --panel-test` opens the real panel and prints its frame, to catch sizing bugs.
    static var panelTestController: StatusItemController?

    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        if args.contains("--menu-test") {
            // Prints the right-click menu as an outline.
            func dump(_ menu: NSMenu, indent: String = "") {
                for item in menu.items {
                    let check = item.state == .on ? "✓ " : "  "
                    let title = item.isSeparatorItem ? "──────" : item.title
                    let key = item.keyEquivalent.isEmpty ? "" : "  [\(item.keyEquivalent)]"
                    print(indent + check + title + key + (item.isEnabled ? "" : "  (disabled)"))
                    if let submenu = item.submenu { dump(submenu, indent: indent + "    ") }
                }
            }
            dump(StatusItemController().buildContextMenu())
            exit(0)
        }
        if args.contains("--panel-test") {
            let controller = StatusItemController()
            panelTestController = controller
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let opened = controller.debugOpenPanel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let settled = controller.debugOpenPanel()
                    print("panel opened at \(opened), settled at \(settled)")
                    exit(opened.width > 100 && opened.height > 100 ? 0 : 1)
                }
            }
            return true
        }

        guard let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count else { return false }
        let output = URL(fileURLWithPath: args[index + 1])
        let dark = args.contains("--dark")

        // `--settings` renders the Settings window's content on a plain window background.
        if args.contains("--settings") {
            let view = SettingsView()
                .environmentObject(Preferences.shared)
                .environmentObject(WindowManager.shared)
                .background(Color(nsColor: .windowBackgroundColor))
            return render(view, to: output, dark: dark)
        }

        // Approximates the glass panel (which can't be captured offscreen) floating over a desktop.
        let shape = RoundedRectangle(cornerRadius: GlassPanel.cornerRadius, style: .continuous)
        let view = MenuView()
            .environmentObject(Preferences.shared)
            .environmentObject(WindowManager.shared)
            .background(dark ? Color(white: 0.16).opacity(0.92) : Color(white: 0.96).opacity(0.9), in: shape)
            .overlay(shape.strokeBorder(.white.opacity(dark ? 0.15 : 0.7), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(36)
            .background(LinearGradient(colors: [Color(red: 0.95, green: 0.72, blue: 0.52), Color(red: 0.25, green: 0.38, blue: 0.59)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
        return render(view, to: output, dark: dark)
    }

    private static func render(_ view: some View, to output: URL, dark: Bool) -> Bool {
        let hosting = NSHostingView(rootView: view)
        hosting.frame.size = hosting.fittingSize

        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -10_000, y: -10_000), size: hosting.frame.size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.orderFrontRegardless()

        // Give SwiftUI a moment to lay out and load the wallpaper.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            hosting.frame.size = hosting.fittingSize
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { exit(1) }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: output)
            exit(0)
        }
        return true
    }
}
#endif
