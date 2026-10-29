import AppKit
import GutterKit
import SwiftUI

/// The capsule that drops under the menu bar icon after ⌃⌥⌘F or ⌃⌥⌘D, saying what was fitted.
/// It never takes focus or clicks, and fades out on its own.
final class ShortcutPopup: NSPanel {
    /// How long the popup stays before fading out.
    private static let duration: TimeInterval = 1.6

    private let hosting = NSHostingView(rootView: ShortcutPopupView(report: .cantFit))
    private var hideWork: DispatchWorkItem?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // the capsule draws its own
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        contentView = hosting
    }

    /// Shows the report centered under `anchor` (the menu bar icon), or at the top right of the
    /// main display when the icon isn't on screen, e.g. hidden by a menu bar manager.
    func show(_ report: FitReport, below anchor: NSRect?) {
        hosting.rootView = ShortcutPopupView(report: report)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let screen = anchor.flatMap { anchor in NSScreen.screens.first { $0.frame.intersects(anchor) } } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        // The view has room around the capsule for its shadow; line the capsule itself up.
        let inset = ShortcutPopupView.shadowRoom
        let centerX = anchor?.midX ?? bounds.maxX - size.width / 2 - 8
        let x = min(max(centerX - size.width / 2, bounds.minX - inset), bounds.maxX - size.width + inset)
        let top = (anchor?.minY ?? bounds.maxY) - 6 + inset
        setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)

        // A second press while it's up replaces the text and restarts the timer.
        hideWork?.cancel()
        if !isVisible || alphaValue < 1 {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                animator().alphaValue = 1
            }
        }
        // It never takes focus, so VoiceOver wouldn't read it otherwise.
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: report.title, .priority: NSAccessibilityPriorityLevel.high.rawValue])

        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration, execute: work)
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // Skip if it was shown again while fading out.
                guard let self, self.alphaValue == 0 else { return }
                self.orderOut(nil)
            }
        })
    }
}

/// Fitted windows show in the accent capsule of "Fit all windows"; anything else in a plain
/// capsule with a warning sign.
struct ShortcutPopupView: View {
    /// Transparent room around the capsule so its shadow isn't clipped by the window.
    static let shadowRoom: CGFloat = 16

    let report: FitReport
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: report.succeeded ? "checkmark" : "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(report.succeeded ? Color.white : Color.orange)
            Text(report.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(report.succeeded ? Color.white : Color.primary)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 16)
        .background {
            if report.succeeded {
                AccentCapsule()
            } else {
                Capsule()
                    .fill(colorScheme == .dark ? Color(white: 0.2).opacity(0.96) : Color(white: 0.98).opacity(0.96))
                    .overlay(Capsule().strokeBorder(.white.opacity(colorScheme == .dark ? 0.15 : 0.7), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
            }
        }
        .fixedSize()
        .padding(Self.shadowRoom)
        .accessibilityElement(children: .combine)
    }
}
