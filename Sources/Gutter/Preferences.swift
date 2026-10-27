import Foundation

/// Space to leave around a fitted window, in points.
struct Margins: Codable, Equatable {
    var left: Double
    var top: Double
    var right: Double
    var bottom: Double

    /// Quick choices for the left gap, shown in the panel and the right-click menu.
    static let gapPresets: [(name: String, value: Double)] = [("Snug", 160), ("Comfy", 200), ("Roomy", 280)]

    /// The largest left gap on any display.
    static let maxLeft: Double = 600

    /// Largest value each margin can have on a screen area this size, so the window stays at
    /// least half as wide and half as tall as the area. The left gap takes priority over the
    /// right one, and the top over the bottom.
    static func limits(left: Double, top: Double, in size: CGSize) -> (left: Double, right: Double, top: Double, bottom: Double) {
        let halfWidth = (size.width / 2 / 10).rounded(.down) * 10
        let halfHeight = (size.height / 2 / 10).rounded(.down) * 10
        let maxLeft = min(Self.maxLeft, halfWidth)
        let maxTop = halfHeight
        return (maxLeft, max(halfWidth - min(left, maxLeft), 0), maxTop, max(halfHeight - min(top, maxTop), 0))
    }

    /// These margins, reduced where needed to fit `limits(in:)`.
    func limited(to size: CGSize) -> Margins {
        let max = Self.limits(left: left, top: top, in: size)
        return Margins(left: min(left, max.left), top: min(top, max.top),
                       right: min(right, max.right), bottom: min(bottom, max.bottom))
    }
}

/// User settings, persisted in UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var autoFit: Bool { didSet { defaults.set(autoFit, forKey: "autoFit") } }
    @Published var onlyWithStageManager: Bool { didSet { defaults.set(onlyWithStageManager, forKey: "onlyWithStageManager") } }
    @Published var fullWidthWhenStripHidden: Bool { didSet { defaults.set(fullWidthWhenStripHidden, forKey: "fullWidthWhenStripHidden") } }
    @Published var refitOnDisplayChange: Bool { didSet { defaults.set(refitOnDisplayChange, forKey: "refitOnDisplayChange") } }
    @Published var hotKeyEnabled: Bool { didSet { defaults.set(hotKeyEnabled, forKey: "hotKeyEnabled") } }

    /// Margins for displays that haven't been customized yet: always the most recently edited ones.
    @Published var leftMargin: Double { didSet { defaults.set(leftMargin, forKey: "leftMargin") } }
    @Published var topMargin: Double { didSet { defaults.set(topMargin, forKey: "topMargin") } }
    @Published var rightMargin: Double { didSet { defaults.set(rightMargin, forKey: "rightMargin") } }
    @Published var bottomMargin: Double { didSet { defaults.set(bottomMargin, forKey: "bottomMargin") } }

    /// Per-display margins, keyed by `NSScreen.displayUUID`.
    @Published var displayMargins: [String: Margins] {
        didSet { defaults.set(try? JSONEncoder().encode(displayMargins), forKey: "displayMargins") }
    }

    /// Bundle IDs of apps whose windows are never auto-fitted.
    @Published var excludedBundleIDs: [String] { didSet { defaults.set(excludedBundleIDs, forKey: "excludedBundleIDs") } }

    private init() {
        defaults.register(defaults: [
            "autoFit": true,
            "onlyWithStageManager": true,
            "fullWidthWhenStripHidden": true,
            "refitOnDisplayChange": true,
            "hotKeyEnabled": true,
            "leftMargin": 200.0,
            "topMargin": 0.0,
            "rightMargin": 0.0,
            "bottomMargin": 0.0,
            "excludedBundleIDs": ["com.apple.calculator", "com.apple.systempreferences"],
        ])
        autoFit = defaults.bool(forKey: "autoFit")
        onlyWithStageManager = defaults.bool(forKey: "onlyWithStageManager")
        fullWidthWhenStripHidden = defaults.bool(forKey: "fullWidthWhenStripHidden")
        refitOnDisplayChange = defaults.bool(forKey: "refitOnDisplayChange")
        hotKeyEnabled = defaults.bool(forKey: "hotKeyEnabled")
        leftMargin = defaults.double(forKey: "leftMargin")
        topMargin = defaults.double(forKey: "topMargin")
        rightMargin = defaults.double(forKey: "rightMargin")
        bottomMargin = defaults.double(forKey: "bottomMargin")
        displayMargins = defaults.data(forKey: "displayMargins")
            .flatMap { try? JSONDecoder().decode([String: Margins].self, from: $0) } ?? [:]
        excludedBundleIDs = defaults.stringArray(forKey: "excludedBundleIDs") ?? []
    }

    func margins(for displayID: String) -> Margins {
        displayMargins[displayID] ?? Margins(left: leftMargin, top: topMargin, right: rightMargin, bottom: bottomMargin)
    }

    func setMargins(_ margins: Margins, for displayID: String) {
        displayMargins[displayID] = margins
        // New displays start from whatever was set up most recently.
        leftMargin = margins.left
        topMargin = margins.top
        rightMargin = margins.right
        bottomMargin = margins.bottom
    }
}
