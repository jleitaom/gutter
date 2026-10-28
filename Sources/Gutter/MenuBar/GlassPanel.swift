import AppKit
import SwiftUI

/// A borderless floating panel with rounded corners and a Liquid Glass background
/// (frosted material before macOS 26). It hangs below an anchor rect, and its top edge
/// stays put while the content grows or shrinks.
final class GlassPanel: NSPanel {
    static let cornerRadius: CGFloat = 26

    var onCancel: (() -> Void)?
    private var anchorTop: CGFloat?
    private var dismissing = false

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }

    /// Escape closes the panel.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    func setContent(_ view: NSView) {
        // NSGlassEffectView needs the macOS 26 SDK (Swift 6.2+); older toolchains build the frosted fallback.
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = Self.cornerRadius
            glass.contentView = view
            contentView = glass
            return
        }
        #endif
        do {
            let material = NSVisualEffectView()
            material.material = .popover
            material.blendingMode = .behindWindow
            material.state = .active
            material.wantsLayer = true
            material.layer?.cornerRadius = Self.cornerRadius
            material.layer?.cornerCurve = .continuous
            material.layer?.masksToBounds = true
            view.frame = material.bounds
            view.autoresizingMask = [.width, .height]
            material.addSubview(view)
            contentView = material
        }
    }

    /// Resizes to fit the content, keeping the top edge pinned under the menu bar.
    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let top = anchorTop ?? frame.maxY
        setFrame(NSRect(x: frame.minX, y: top - size.height, width: size.width, height: size.height), display: true)
        invalidateShadow()
    }

    func show(below anchor: NSRect, on screen: NSScreen?, size: CGSize) {
        let bounds = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let x = min(max(anchor.midX - size.width / 2, bounds.minX + 8), bounds.maxX - size.width - 8)
        let top = anchor.minY - 6
        anchorTop = top
        setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)

        dismissing = false
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            animator().alphaValue = 1
        }
    }

    func dismiss() {
        dismissing = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // Skip if the panel was reopened while fading out.
                guard let self, self.dismissing else { return }
                self.orderOut(nil)
            }
        })
    }
}
