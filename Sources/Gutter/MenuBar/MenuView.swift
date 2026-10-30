import AppKit
import GutterKit
import SwiftUI

struct MenuView: View {
    /// Opens the Settings window; provided by the panel's owner.
    var openSettings: () -> Void = {}

    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var manager: WindowManager
    @State private var showMargins = false
    @State private var selectedDisplay = NSScreen.main?.displayUUID ?? ""
    /// Briefly shows how many windows "Fit all windows" fitted.
    @State private var fittedCount: Int?

    var body: some View {
        VStack(spacing: 12) {
            header

            if !manager.accessibilityGranted {
                permissionNotice
            }

            if NSScreen.screens.count > 1 {
                CapsulePicker(title: "Display",
                              options: NSScreen.screens.map { ($0.localizedName, $0.displayUUID) },
                              selection: $selectedDisplay)
            }

            VStack(spacing: 6) {
                LayoutPreview(margins: margins, screen: selectedScreen, dimmed: status == .paused)
                Text(previewHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CapsulePicker(title: "Gap preset", options: Margins.gapPresets.map { ($0.name, $0.value) }, selection: margins.left)

            otherMargins
            fitButton
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Gutter").font(.system(size: 14, weight: .semibold))
                HStack(spacing: 6) {
                    Circle().fill(status.color).frame(width: 7, height: 7)
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Auto-fit", isOn: $prefs.autoFit)
                .labelsHidden()
                .toggleStyle(.switch)
                .help(prefs.autoFit ? "Pause auto-fit" : "Resume auto-fit")
        }
        .padding(.horizontal, 2)
    }

    private var permissionNotice: some View {
        GlassGroup(tint: .orange) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Accessibility access needed").font(.callout.weight(.semibold))
                    Text("Gutter uses it to move and resize windows. Nothing else.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Grant Access…") { manager.requestAccessibility() }
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                    }
                    .controlSize(.small)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
        }
    }

    private var otherMargins: some View {
        GlassGroup {
            DisclosureRow(icon: "square.dashed", title: "Top, right, bottom", isExpanded: $showMargins) {
                let current = margins.wrappedValue
                Text("\(Int(current.top)) · \(Int(current.right)) · \(Int(current.bottom))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if showMargins {
                let current = margins.wrappedValue
                let limits = Margins.limits(left: current.left, top: current.top, in: visibleSize)
                VStack(spacing: 8) {
                    MarginSlider(label: "Top", value: margins.top, range: 0...Swift.max(limits.top, 10))
                    MarginSlider(label: "Right", value: margins.right, range: 0...Swift.max(limits.right, 10))
                    MarginSlider(label: "Bottom", value: margins.bottom, range: 0...Swift.max(limits.bottom, 10))
                }
                .padding(.bottom, 10)
            }
        }
    }

    private var fitButton: some View {
        HStack(spacing: 8) {
            Button {
                let count = manager.fitAllWindows()
                withAnimation(.snappy) { fittedCount = count }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.snappy) { fittedCount = nil }
                }
            } label: {
                Text(fittedCount.map { "Fitted \($0) window\($0 == 1 ? "" : "s")" } ?? "Fit all windows")
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(CapsuleProminentButtonStyle())
            .help(prefs.fitAllHotKeyEnabled && !manager.fitAllHotKeyInUse
                  ? "Fit every window on every display to that display's gap (⌃⌥⌘D)"
                  : "Fit every window on every display to that display's gap")

            Button {
                manager.fitLastActiveWindow()
            } label: {
                Text("Fit \(manager.lastActiveApp?.localizedName ?? "window")")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120)
            }
            .buttonStyle(CapsuleSecondaryButtonStyle())
            .fixedSize()
            .help(prefs.hotKeyEnabled && !manager.hotKeyInUse ? "Fit only this window (⌃⌥⌘F)" : "Fit only this window")
            .disabled(manager.lastActiveApp == nil || manager.isExcluded(manager.lastActiveApp))
        }
        .disabled(!manager.accessibilityGranted)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(",")
                .help("Open Gutter Settings (⌘,)")

                Button { NSApp.terminate(nil) } label: {
                    Label("Quit", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("q")
                .help("Quit Gutter (⌘Q)")
            }
            .buttonStyle(CapsuleSecondaryButtonStyle())

            HStack(spacing: 4) {
                Text("Gutter \(AppInfo.version) ·")
                Link(destination: AppInfo.repositoryURL) {
                    HStack(spacing: 2) {
                        Text("GitHub")
                        Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .semibold))
                    }
                }
                .help("View the source on GitHub")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .tint(.secondary)
        }
    }

    // MARK: - Status

    private var status: GutterStatus { manager.status }

    private var statusText: String {
        status == .active && manager.stageManagerOn ? "\(status.title) · Stage Manager on" : status.title
    }

    // MARK: - Displays

    private var selectedScreen: NSScreen? {
        NSScreen.screens.first { $0.displayUUID == selectedDisplay } ?? NSScreen.main
    }

    /// The visible area of the display picked in the tabs.
    private var visibleSize: CGSize {
        selectedScreen?.visibleFrame.size ?? CGSize(width: 1512, height: 944)
    }

    /// The margins of the display picked in the tabs (the main display with only one),
    /// limited to that display's size so the panel shows what fitting will do.
    private var margins: Binding<Margins> {
        let id = selectedScreen?.displayUUID ?? selectedDisplay
        let size = visibleSize
        return Binding(get: { prefs.margins(for: id).limited(to: size) },
                       set: { prefs.setMargins($0.limited(to: size), for: id) })
    }

    private var previewHint: String {
        if prefs.fullWidthWhenStripHidden && manager.stageManagerOn && manager.stripHidden {
            return "Recent apps are hidden, so windows use the full width"
        }
        return "Drag the edge to set the gap"
    }
}

private extension GutterStatus {
    /// The dot next to the status in the panel header.
    var color: Color {
        switch self {
        case .active: .green
        case .paused: .secondary
        case .waiting: .yellow
        case .needsAccess: .orange
        }
    }
}
