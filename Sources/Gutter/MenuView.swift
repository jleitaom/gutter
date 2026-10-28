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
            .help("Fit every window on every display to that display's gap")

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
            .disabled(manager.lastActiveApp == nil)
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

    private enum Status {
        case active, paused, waiting, needsAccess

        var color: Color {
            switch self {
            case .active: .green
            case .paused: .secondary
            case .waiting: .yellow
            case .needsAccess: .orange
            }
        }
    }

    private var status: Status {
        if !manager.accessibilityGranted { return .needsAccess }
        if !prefs.autoFit { return .paused }
        if prefs.onlyWithStageManager && !manager.stageManagerOn { return .waiting }
        return .active
    }

    private var statusText: String {
        switch status {
        case .active: manager.stageManagerOn ? "Active · Stage Manager on" : "Active"
        case .paused: "Paused"
        case .waiting: "Waiting for Stage Manager"
        case .needsAccess: "Needs access"
        }
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

// MARK: - Components

/// An inset, frosted group of rows, like the grouped lists in System Settings.
struct GlassGroup<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    var body: some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 14)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(colorScheme == .dark ? 0.06 : 0.5), lineWidth: 0.5))
    }

    private var fill: Color {
        if let tint { return tint.opacity(0.14) }
        return colorScheme == .dark ? .white.opacity(0.06) : .white.opacity(0.45)
    }
}

struct Row<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
            Spacer(minLength: 8)
            trailing()
        }
        .frame(minHeight: 38)
    }
}

struct DisclosureRow<Trailing: View>: View {
    let icon: String
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button {
            withAnimation(.snappy) { isExpanded.toggle() }
        } label: {
            Row(icon: icon, title: title) {
                trailing()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SmallSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
    }
}

struct KeyCap: View {
    let keys: String
    var onAccent = false

    init(_ keys: String, onAccent: Bool = false) {
        self.keys = keys
        self.onAccent = onAccent
    }

    var body: some View {
        Text(keys)
            .font(.caption.weight(.medium))
            .foregroundStyle(onAccent ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(onAccent ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct MarginSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    /// Snaps to 10 pt without `Slider(step:)`, which draws a tick mark for every step.
    private var snapped: Binding<Double> {
        Binding(get: { value }, set: { value = ($0 / 10).rounded() * 10 })
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Slider(value: snapped, in: range)
                .controlSize(.small)
            Text("\(Int(value))")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .font(.callout)
    }
}

/// Capsule segmented control with a sliding selection. Used for displays and gap presets;
/// nothing is highlighted when the selection matches no option.
private struct CapsulePicker<Value: Hashable>: View {
    /// What VoiceOver calls the group, e.g. "Display".
    let title: String
    let options: [(label: String, value: Value)]
    @Binding var selection: Value
    @Namespace private var highlight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = selection == option.value
                Button {
                    withAnimation(.snappy) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(selected ? .primary : .secondary)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(.white.opacity(colorScheme == .dark ? 0.18 : 0.9))
                                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "highlight", in: highlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.primary.opacity(0.06), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// A full-width accent capsule with a soft top highlight, like the glass buttons in macOS 26.
private struct CapsuleProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background {
                Capsule()
                    .fill(Color.accentColor)
                    .overlay(Capsule().fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom)))
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
            .shadow(color: .accentColor.opacity(isEnabled ? 0.35 : 0), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// A quieter capsule for secondary actions next to the prominent one.
private struct CapsuleSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.primary.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// A miniature of a display (with its real wallpaper) showing where new windows land.
/// Drag the window's left edge to change the gap.
private struct LayoutPreview: View {
    @Binding var margins: Margins
    let screen: NSScreen?
    /// Fades the window while auto-fit is paused.
    let dimmed: Bool

    /// Panel width minus its padding; the menu bar window sizes to content, so this must be explicit.
    private static let width: CGFloat = 308
    /// How close (in points) to the edge a drag must start, or the pointer must be, to grab it.
    private static let grabDistance: CGFloat = 16

    @State private var wallpaper: CGImage?
    @State private var draggingEdge: Bool?
    @State private var hoveringEdge = false
    @Environment(\.colorScheme) private var colorScheme

    private var screenFrame: CGRect { screen?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982) }
    private var visibleFrame: CGRect { screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1512, height: 944) }

    /// The visible area in top-left-origin coordinates relative to the screen.
    private var visible: CGRect {
        CGRect(x: visibleFrame.minX - screenFrame.minX,
               y: screenFrame.maxY - visibleFrame.maxY,
               width: visibleFrame.width,
               height: visibleFrame.height)
    }

    private var windowRect: CGRect {
        CGRect(x: visible.minX + margins.left,
               y: visible.minY + margins.top,
               width: max(visible.width - margins.left - margins.right, 0),
               height: max(visible.height - margins.top - margins.bottom, 0))
    }

    /// Keeps the window at least half the screen wide.
    private var maxGap: Double { Margins.limits(left: 0, top: 0, in: visible.size).left }

    private func setGap(_ value: Double) {
        margins.left = min(max((value / 10).rounded() * 10, 0), maxGap)
    }

    private func setResizeCursor(_ on: Bool) {
        guard on != hoveringEdge else { return }
        hoveringEdge = on
        if on { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
    }

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / screenFrame.width
            let win = CGRect(x: windowRect.minX * scale, y: windowRect.minY * scale,
                             width: windowRect.width * scale, height: windowRect.height * scale)
            let thumbWidth = min(win.minX * 0.62, 40)

            ZStack(alignment: .topLeading) {
                wallpaperView
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                Rectangle()
                    .fill(.black.opacity(0.15))
                    .frame(height: max(visible.minY * scale, 3))

                if thumbWidth > 6 {
                    VStack(spacing: thumbWidth * 0.28) {
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.white.opacity(i == 1 ? 0.9 : 0.5))
                                .frame(width: thumbWidth, height: thumbWidth * 0.75)
                        }
                    }
                    .frame(width: win.minX, height: geo.size.height)
                }

                MiniWindow(dark: colorScheme == .dark)
                    .frame(width: max(win.width - 4, 0), height: max(win.height - 4, 0))
                    .offset(x: win.minX + 2, y: win.minY + 2)
                    .opacity(dimmed ? 0.6 : 1)

                Capsule()
                    .fill(.white)
                    .frame(width: 5, height: win.height * 0.38)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .position(x: win.minX + 2, y: win.midY)

                Text("\(Int(margins.left)) pt")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.55), in: Capsule())
                    .fixedSize()
                    // Just right of the handle, so it never covers the traffic lights.
                    .position(x: min(win.minX + 32, geo.size.width - 28), y: win.midY)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): setResizeCursor(abs(point.x - win.minX) < Self.grabDistance)
                case .ended: setResizeCursor(false)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        // Only drags that start on the edge move it, so stray clicks change nothing.
                        if draggingEdge == nil {
                            draggingEdge = abs(drag.startLocation.x - win.minX) < Self.grabDistance
                        }
                        guard draggingEdge == true else { return }
                        setGap(drag.location.x / scale - visible.minX)
                    }
                    .onEnded { _ in draggingEdge = nil }
            )
        }
        .frame(width: Self.width, height: Self.width * screenFrame.height / screenFrame.width)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
        .onDisappear { setResizeCursor(false) }
        .accessibilityElement()
        .accessibilityLabel("Left gap")
        .accessibilityValue("\(Int(margins.left)) points")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setGap(margins.left + 10)
            case .decrement: setGap(margins.left - 10)
            @unknown default: break
            }
        }
        .task(id: screen?.displayUUID) {
            guard let screen, let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return }
            wallpaper = await Task.detached { Self.thumbnail(of: url) }.value
        }
    }

    @ViewBuilder
    private var wallpaperView: some View {
        if let wallpaper {
            Image(decorative: wallpaper, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(colors: [Color(red: 0.95, green: 0.72, blue: 0.52), Color(red: 0.25, green: 0.38, blue: 0.59)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Decodes a small version of the wallpaper so opening the panel stays instant.
    nonisolated private static func thumbnail(of url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 800,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

private struct MiniWindow: View {
    let dark: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(dark ? Color(white: 0.17) : .white)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                        Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                        Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                    }
                    .frame(width: 26, height: 6)
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(.primary.opacity(0.14)).frame(width: 90, height: 5)
                        Capsule().fill(.primary.opacity(0.08)).frame(width: 130, height: 5)
                        Capsule().fill(.primary.opacity(0.08)).frame(width: 70, height: 5)
                    }
                    .padding(.top, 10)
                    .padding(.leading, 6)
                }
                .padding(7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
