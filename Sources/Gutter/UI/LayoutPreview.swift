import AppKit
import GutterKit
import SwiftUI

/// A miniature of a display (with its real wallpaper) showing where new windows land.
/// Drag the window's left edge to change the gap.
struct LayoutPreview: View {
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
