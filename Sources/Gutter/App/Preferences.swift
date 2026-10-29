import Foundation
import GutterKit

/// User settings, persisted in UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var autoFit: Bool { didSet { defaults.set(autoFit, forKey: "autoFit") } }
    @Published var onlyWithStageManager: Bool { didSet { defaults.set(onlyWithStageManager, forKey: "onlyWithStageManager") } }
    @Published var fullWidthWhenStripHidden: Bool { didSet { defaults.set(fullWidthWhenStripHidden, forKey: "fullWidthWhenStripHidden") } }
    @Published var refitOnDisplayChange: Bool { didSet { defaults.set(refitOnDisplayChange, forKey: "refitOnDisplayChange") } }
    @Published var hotKeyEnabled: Bool { didSet { defaults.set(hotKeyEnabled, forKey: "hotKeyEnabled") } }
    @Published var fitAllHotKeyEnabled: Bool { didSet { defaults.set(fitAllHotKeyEnabled, forKey: "fitAllHotKeyEnabled") } }
    /// Show what a shortcut fitted in a popup under the menu bar icon.
    @Published var shortcutPopup: Bool { didSet { defaults.set(shortcutPopup, forKey: "shortcutPopup") } }

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
            "fitAllHotKeyEnabled": true,
            "shortcutPopup": true,
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
        fitAllHotKeyEnabled = defaults.bool(forKey: "fitAllHotKeyEnabled")
        shortcutPopup = defaults.bool(forKey: "shortcutPopup")
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
