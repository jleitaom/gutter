import AppKit
import SwiftUI

/// The Settings window (⌘,). Gutter has no SwiftUI App scenes (so relaunching never opens an
/// empty window), so this is an AppKit window around the same glass groups as the panel.
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = "Gutter Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let content = SettingsView(chooseApps: { [weak self] in self?.chooseAppsToExclude() })
            .environmentObject(Preferences.shared)
            .environmentObject(WindowManager.shared)
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in
                self?.resize(to: size)
            }
        let hosting = NSHostingView(rootView: content)
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        guard let window else { return }
        if !window.isVisible { window.center() }
        NSApp.activate()
        showWindow(nil)
        // Open calm: no focus ring on the first control.
        window.makeFirstResponder(nil)
    }

    /// Grows or shrinks with the content (e.g. opening "Never resize"), keeping the title bar in place.
    private func resize(to size: CGSize) {
        guard let window, size.width > 0, size.height > 0 else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = CGPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: false)
    }

    /// Lets the user pick any installed app to add to "Never resize".
    private func chooseAppsToExclude() {
        guard let window else { return }
        let picker = NSOpenPanel()
        picker.title = "Never resize these apps"
        picker.prompt = "Add"
        picker.allowedContentTypes = [.application]
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        picker.directoryURL = URL(fileURLWithPath: "/Applications")

        picker.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            let prefs = Preferences.shared
            for bundleID in picker.urls.compactMap({ Bundle(url: $0)?.bundleIdentifier })
            where !prefs.excludedBundleIDs.contains(bundleID) {
                prefs.excludedBundleIDs.append(bundleID)
            }
        }
    }
}

/// The options people set once: moved out of the panel, drawn with the same rows.
struct SettingsView: View {
    /// Shows a file picker for apps to exclude; provided by the window's owner.
    var chooseApps: () -> Void = {}

    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var manager: WindowManager
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var showExclusions = false

    var body: some View {
        VStack(spacing: 12) {
            stageManager
            general
            exclusions
        }
        .padding(16)
        .frame(width: 340)
        // The right-click menu can change this too, so re-read it whenever the window comes forward.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    // MARK: - Sections

    private var stageManager: some View {
        GlassGroup {
            Row(icon: "sidebar.left", title: "Only with Stage Manager") {
                SmallSwitch(title: "Only with Stage Manager", isOn: $prefs.onlyWithStageManager)
            }
            Divider()
            Row(icon: "arrow.left.and.right", title: "Full width when strip is hidden") {
                SmallSwitch(title: "Full width when strip is hidden", isOn: $prefs.fullWidthWhenStripHidden)
            }
            .help("If “Show recent apps” is off in Stage Manager settings, windows skip the left gap.")
        }
    }

    private var general: some View {
        GlassGroup {
            Row(icon: "display.2", title: "Refit on display change") {
                SmallSwitch(title: "Refit on display change", isOn: $prefs.refitOnDisplayChange)
            }
            .help("Fit windows again when you move them to another display, or when displays are connected or disconnected.")
            Divider()
            Row(icon: "keyboard", title: "Shortcut") {
                if manager.hotKeyInUse {
                    Label("In use", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Another app is using ⌃⌥⌘F. Quit it or change its shortcut, then turn this off and on.")
                } else {
                    KeyCap("⌃⌥⌘F")
                }
                SmallSwitch(title: "Shortcut", isOn: $prefs.hotKeyEnabled)
            }
            Divider()
            Row(icon: "power", title: "Open at login") {
                SmallSwitch(title: "Open at login", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
            }
        }
    }

    private var exclusions: some View {
        GlassGroup {
            DisclosureRow(icon: "nosign", title: "Never resize", isExpanded: $showExclusions) {
                HStack(spacing: -6) {
                    ForEach(prefs.excludedBundleIDs.prefix(3), id: \.self) { bundleID in
                        if let icon = appIcon(bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                        }
                    }
                }
                if prefs.excludedBundleIDs.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                }
            }
            if showExclusions {
                ForEach(prefs.excludedBundleIDs, id: \.self) { bundleID in
                    Divider()
                    HStack(spacing: 10) {
                        if let icon = appIcon(bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                        }
                        Text(appName(bundleID))
                        Spacer()
                        Button {
                            withAnimation(.snappy) { prefs.excludedBundleIDs.removeAll { $0 == bundleID } }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                        .help("Stop excluding \(appName(bundleID))")
                    }
                    .frame(minHeight: 32)
                }
                Divider()
                Menu {
                    Button("Choose from Applications…", action: chooseApps)
                    if !excludableApps.isEmpty {
                        Divider()
                        Section("Running") {
                            ForEach(excludableApps, id: \.self) { bundleID in
                                Button(appName(bundleID)) {
                                    withAnimation(.snappy) { prefs.excludedBundleIDs.append(bundleID) }
                                }
                            }
                        }
                    }
                } label: {
                    Label("Add App", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    /// Running regular apps that aren't excluded yet, sorted by name.
    private var excludableApps: [String] {
        let ids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() }
            .compactMap(\.bundleIdentifier)
            .filter { !prefs.excludedBundleIDs.contains($0) }
        return Array(Set(ids)).sorted { appName($0).localizedCaseInsensitiveCompare(appName($1)) == .orderedAscending }
    }

    private func appName(_ bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?
            .deletingPathExtension().lastPathComponent ?? bundleID
    }

    private func appIcon(_ bundleID: String) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.set(enabled)
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
