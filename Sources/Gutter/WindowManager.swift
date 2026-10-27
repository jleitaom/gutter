import AppKit
import ApplicationServices

/// Watches every app for new windows and windows moving between displays (via the
/// Accessibility API) and resizes them to fill the screen minus that display's margins.
final class WindowManager: ObservableObject {
    static let shared = WindowManager()

    @Published private(set) var accessibilityGranted = false
    @Published private(set) var stageManagerOn = false
    /// True when "Show recent apps in Stage Manager" is off, so the strip only appears on hover.
    @Published private(set) var stripHidden = false
    /// The last app that was frontmost, other than Gutter itself.
    @Published private(set) var lastActiveApp: NSRunningApplication?
    /// True when the shortcut is on but couldn't be registered because another app holds it.
    @Published var hotKeyInUse = false

    private let prefs = Preferences.shared
    private var observers: [pid_t: AXObserver] = [:]
    private var observing = false
    private var statusTimer: Timer?
    /// The display each known window was last seen on, per app.
    private var windowDisplays: [pid_t: [AXUIElement: String]] = [:]
    /// Pending display checks for windows being dragged, so each drag is handled once it settles.
    private var pendingMoveChecks: [AXUIElement: DispatchWorkItem] = [:]

    func start() {
        // AX calls run on the main thread; a hung app shouldn't freeze Gutter for the default
        // timeout of several seconds per call, so give up after half a second.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.observe(app, justLaunched: true)
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.stopObserving(app.processIdentifier)
        }
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != getpid() else { return }
            self?.lastActiveApp = app
        }
        lastActiveApp = NSWorkspace.shared.frontmostApplication

        // When displays are connected or disconnected, macOS moves windows around; refit the ones that changed display.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, prefs.refitOnDisplayChange else { return }
                for pid in observers.keys {
                    windows(of: pid).forEach(checkDisplayChange)
                }
            }
        }

        // Accessibility permission and Stage Manager can change at any time, so poll them.
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshStatus() }
        refreshStatus()
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Status

    private func refreshStatus() {
        let trusted = AXIsProcessTrusted()
        if accessibilityGranted != trusted { accessibilityGranted = trusted }

        let stageManager = Self.isStageManagerOn()
        if stageManagerOn != stageManager { stageManagerOn = stageManager }

        let hidden = Self.isStripHidden()
        if stripHidden != hidden { stripHidden = hidden }

        if trusted && !observing {
            observing = true
            NSWorkspace.shared.runningApplications.forEach { observe($0, justLaunched: false) }
        } else if !trusted && observing {
            observing = false
            observers.keys.forEach(stopObserving)
        }
    }

    static func isStageManagerOn() -> Bool {
        windowManagerSetting("GloballyEnabled")
    }

    static func isStripHidden() -> Bool {
        windowManagerSetting("AutoHide")
    }

    /// Reads a Stage Manager setting from the `com.apple.WindowManager` preferences.
    private static func windowManagerSetting(_ key: String) -> Bool {
        let domain = "com.apple.WindowManager" as CFString
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key as CFString, domain) as? Bool ?? false
    }

    // MARK: - Observing apps

    private func observe(_ app: NSRunningApplication, justLaunched: Bool, attempt: Int = 0) {
        let pid = app.processIdentifier
        guard observing, app.activationPolicy == .regular, pid != getpid(), observers[pid] == nil else { return }

        var created: AXObserver?
        guard AXObserverCreate(pid, axCallback, &created) == .success, let observer = created else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let result = AXObserverAddNotification(observer, AXUIElementCreateApplication(pid), kAXWindowCreatedNotification as CFString, refcon)
        guard result == .success else {
            // Freshly launched apps often aren't ready to be observed yet; retry for a few seconds.
            if attempt < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.observe(app, justLaunched: justLaunched, attempt: attempt + 1)
                }
            }
            return
        }
        AXObserverAddNotification(observer, AXUIElementCreateApplication(pid), kAXWindowMovedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer

        if justLaunched {
            // The first window of a new app may have appeared before the observer was attached.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                windows(of: pid).forEach(windowCreated)
            }
        } else {
            // Remember where existing windows are, so moving one to another display can be detected.
            windows(of: pid).forEach(checkDisplayChange)
        }
    }

    private func stopObserving(_ pid: pid_t) {
        windowDisplays[pid] = nil
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    fileprivate func handle(_ notification: String, for window: AXUIElement) {
        switch notification {
        case kAXWindowCreatedNotification:
            windowCreated(window)
        case kAXWindowMovedNotification:
            windowMoved(window)
        default:
            break
        }
    }

    private func windowMoved(_ window: AXUIElement) {
        guard prefs.refitOnDisplayChange else { return }
        // Moves arrive continuously during a drag; check once the window has settled.
        pendingMoveChecks[window]?.cancel()
        let check = DispatchWorkItem { [weak self] in
            self?.pendingMoveChecks[window] = nil
            self?.checkDisplayChange(window)
        }
        pendingMoveChecks[window] = check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: check)
    }

    /// Records which display the window is on, and fits it if that changed since it was last seen.
    private func checkDisplayChange(_ window: AXUIElement) {
        guard let frame = frame(of: window), let screen = screen(containing: frame) else { return }
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let display = screen.displayUUID
        let previous = windowDisplays[pid]?[window]
        windowDisplays[pid, default: [:]][window] = display

        if let previous, previous != display, prefs.refitOnDisplayChange, shouldAutoFit(window) {
            fit(window)
        }
    }

    fileprivate func windowCreated(_ window: AXUIElement) {
        guard shouldAutoFit(window) else { return }
        // Apps often set their own saved frame right after creating a window, so apply twice.
        for delay in [0.05, 0.4] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.fit(window) }
        }
    }

    private func shouldAutoFit(_ window: AXUIElement) -> Bool {
        guard prefs.autoFit else { return false }
        if prefs.onlyWithStageManager && !Self.isStageManagerOn() { return false }
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        if let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
           prefs.excludedBundleIDs.contains(bundleID) {
            return false
        }
        return true
    }

    // MARK: - Fitting

    /// Fits the focused window of whatever app is frontmost (used by the hotkey).
    func fitFrontmostWindow() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
        fitFocusedWindow(of: pid)
    }

    /// Fits the focused window of the app that was active before the menu was opened.
    func fitLastActiveWindow() {
        guard let pid = lastActiveApp?.processIdentifier else { return }
        fitFocusedWindow(of: pid)
    }

    /// Fits every window of every visible app, each to its own display's margins.
    /// Skips excluded apps, hidden apps and minimized windows. Returns how many windows were fitted.
    @discardableResult
    func fitAllWindows() -> Int {
        guard accessibilityGranted else { return 0 }
        var fitted = 0
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != getpid() {
            if let bundleID = app.bundleIdentifier, prefs.excludedBundleIDs.contains(bundleID) { continue }
            for window in windows(of: app.processIdentifier) where fit(window) {
                fitted += 1
            }
        }
        return fitted
    }

    private func fitFocusedWindow(of pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        if let window = element(app, kAXFocusedWindowAttribute) ?? element(app, kAXMainWindowAttribute) {
            fit(window)
        }
    }

    @discardableResult
    func fit(_ window: AXUIElement) -> Bool {
        guard string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole,
              bool(window, "AXFullScreen") != true,
              bool(window, kAXMinimizedAttribute) != true,
              isSettable(window, kAXPositionAttribute),
              isSettable(window, kAXSizeAttribute),
              let current = frame(of: window),
              let screen = screen(containing: current) else { return false }

        let margins = effectiveMargins(for: screen)
        let visible = axRect(screen.visibleFrame)
        let target = CGRect(
            x: visible.minX + margins.left,
            y: visible.minY + margins.top,
            width: visible.width - margins.left - margins.right,
            height: visible.height - margins.top - margins.bottom
        )
        guard target.width >= 200, target.height >= 200 else { return false }

        // Position, size, position: avoids the window being clamped when it grows past the screen edge.
        setPosition(window, target.origin)
        setSize(window, target.size)
        setPosition(window, target.origin)

        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        windowDisplays[pid, default: [:]][window] = screen.displayUUID
        return true
    }

    /// The display's margins (limited to its size), minus the left gap when the Stage Manager strip is hidden.
    func effectiveMargins(for screen: NSScreen) -> Margins {
        var margins = prefs.margins(for: screen.displayUUID).limited(to: screen.visibleFrame.size)
        if prefs.fullWidthWhenStripHidden && stageManagerOn && stripHidden {
            margins.left = 0
        }
        return margins
    }

    // MARK: - Geometry

    /// Converts an AppKit rect (bottom-left origin) to Accessibility coordinates (top-left origin of the primary screen).
    private func axRect(_ rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { axRect($0.frame).contains(center) }
            ?? NSScreen.screens.first { axRect($0.frame).contains(frame.origin) }
            ?? NSScreen.main
    }

    // MARK: - Accessibility helpers

    private func windows(of pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func element(_ el: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func string(_ el: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func bool(_ el: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }

    private func isSettable(_ el: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(el, attribute as CFString, &settable) == .success && settable.boolValue
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &origin)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: origin, size: extent)
    }

    private func setPosition(_ window: AXUIElement, _ point: CGPoint) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    private func setSize(_ window: AXUIElement, _ size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }
}

private func axCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    Unmanaged<WindowManager>.fromOpaque(refcon).takeUnretainedValue().handle(notification as String, for: element)
}
