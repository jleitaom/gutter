import CoreGraphics

/// The math behind fitting a window, kept free of AppKit and Accessibility state so it can be
/// unit tested. Rects named `ax…` use Accessibility coordinates: origin at the top left of the
/// primary display, y growing down. AppKit rects have their origin at the bottom left.
public enum WindowGeometry {
    /// Windows are never made smaller than this, in either direction.
    public static let minimumSize: CGFloat = 200

    /// Converts an AppKit rect to Accessibility coordinates. `primaryHeight` is the height of the
    /// primary display (the one with the menu bar in System Settings, `NSScreen.screens[0]`).
    public static func axRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// The display a window is on: the one holding its center, else its top-left corner.
    /// Both the window and the displays are in Accessibility coordinates.
    public static func displayIndex(containing axWindow: CGRect, axDisplays: [CGRect]) -> Int? {
        let center = CGPoint(x: axWindow.midX, y: axWindow.midY)
        return axDisplays.firstIndex { $0.contains(center) }
            ?? axDisplays.firstIndex { $0.contains(axWindow.origin) }
    }

    /// The margins used on a display: limited to its visible size, and with no left gap when
    /// Stage Manager's strip of recent apps is hidden and the full width is wanted.
    public static func effectiveMargins(_ margins: Margins, visibleSize: CGSize, stripHidden: Bool) -> Margins {
        var margins = margins.limited(to: visibleSize)
        if stripHidden { margins.left = 0 }
        return margins
    }

    /// Where a fitted window goes: the display's visible area minus the margins, or nil when that
    /// would be smaller than `minimumSize`.
    public static func targetFrame(axVisible: CGRect, margins: Margins) -> CGRect? {
        let target = CGRect(x: axVisible.minX + margins.left,
                            y: axVisible.minY + margins.top,
                            width: axVisible.width - margins.left - margins.right,
                            height: axVisible.height - margins.top - margins.bottom)
        guard target.width >= minimumSize, target.height >= minimumSize else { return nil }
        return target
    }
}
