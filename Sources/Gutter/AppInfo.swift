import AppKit
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Gutter: launch at login failed: \(error)")
        }
    }
}

enum AppInfo {
    static let repositoryURL = URL(string: "https://github.com/jleitaom/gutter")!

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    /// Template image for the menu bar, matching the "Glass" app icon: a Stage Manager tile
    /// behind a translucent window. Drawn dimmed when auto-fit is paused.
    static func menuBarIcon(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: true) { _ in
            let alpha: CGFloat = active ? 1 : 0.45

            NSColor.black.withAlphaComponent(0.45 * alpha).setFill()
            NSBezierPath(roundedRect: NSRect(x: 1.2, y: 4.2, width: 5.4, height: 7.6), xRadius: 1.4, yRadius: 1.4).fill()

            let window = NSBezierPath(roundedRect: NSRect(x: 5.4, y: 1.8, width: 12.8, height: 12.4), xRadius: 2.6, yRadius: 2.6)
            NSColor.black.withAlphaComponent(0.22 * alpha).setFill()
            window.fill()
            NSColor.black.withAlphaComponent(alpha).setStroke()
            window.lineWidth = 1.5
            window.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
