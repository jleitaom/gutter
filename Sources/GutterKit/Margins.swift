import CoreGraphics

/// Space to leave around a fitted window, in points.
public struct Margins: Codable, Equatable, Sendable {
    public var left: Double
    public var top: Double
    public var right: Double
    public var bottom: Double

    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    /// Quick choices for the left gap, shown in the panel and the right-click menu.
    public static let gapPresets: [(name: String, value: Double)] = [("Snug", 160), ("Comfy", 200), ("Roomy", 280)]

    /// The largest left gap on any display.
    public static let maxLeft: Double = 600

    /// Largest value each margin can have on a screen area this size, so the window stays at
    /// least half as wide and half as tall as the area. The left gap takes priority over the
    /// right one, and the top over the bottom.
    public static func limits(left: Double, top: Double, in size: CGSize) -> (left: Double, right: Double, top: Double, bottom: Double) {
        let halfWidth = (size.width / 2 / 10).rounded(.down) * 10
        let halfHeight = (size.height / 2 / 10).rounded(.down) * 10
        let maxLeft = min(Self.maxLeft, halfWidth)
        let maxTop = halfHeight
        return (maxLeft, max(halfWidth - min(left, maxLeft), 0), maxTop, max(halfHeight - min(top, maxTop), 0))
    }

    /// These margins, reduced where needed to fit `limits(in:)`.
    public func limited(to size: CGSize) -> Margins {
        let max = Self.limits(left: left, top: top, in: size)
        return Margins(left: min(left, max.left), top: min(top, max.top),
                       right: min(right, max.right), bottom: min(bottom, max.bottom))
    }
}
