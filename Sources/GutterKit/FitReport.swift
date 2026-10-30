/// What a fitting shortcut did, for the popup under the menu bar icon.
public enum FitReport: Equatable, Sendable {
    /// ⌃⌥⌘F fitted the front app's window.
    case fitted(app: String)
    /// ⌃⌥⌘D fitted this many windows.
    case fittedAll(count: Int)
    /// The front app is in "Never resize".
    case excluded(app: String)
    /// The front app has no window to fit.
    case noWindow(app: String)
    /// The window can't be resized: full screen, minimized, fixed size, or too small a display.
    case cantFit
    case needsAccess

    public var title: String {
        switch self {
        case .fitted(let app): "Fitted \(app)"
        case .fittedAll(0): "No windows to fit"
        case .fittedAll(let count): "Fitted \(count) window\(count == 1 ? "" : "s")"
        case .excluded(let app): "\(app) is in Never resize"
        case .noWindow(let app): "\(app) has no window to fit"
        case .cantFit: "Can’t fit this window"
        case .needsAccess: "Gutter needs Accessibility access"
        }
    }

    /// Shown in the accent color; the rest are shown as a warning.
    public var succeeded: Bool {
        switch self {
        case .fitted: true
        case .fittedAll(let count): count > 0
        case .excluded, .noWindow, .cantFit, .needsAccess: false
        }
    }
}
