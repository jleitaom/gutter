import CoreGraphics
import GutterKit
import Testing

// A built-in display with the menu bar (33 pt) and the Dock (57 pt), and three external displays
// around it, in AppKit coordinates (origin at the bottom left of the built-in display).
private let builtIn = CGRect(x: 0, y: 0, width: 1512, height: 982)
private let builtInVisible = CGRect(x: 0, y: 57, width: 1512, height: 892)
private let above = CGRect(x: -539, y: 982, width: 2560, height: 1440)
private let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
private let right = CGRect(x: 1512, y: -98, width: 1920, height: 1080)
private let primaryHeight = builtIn.height

private func ax(_ rect: CGRect) -> CGRect {
    WindowGeometry.axRect(rect, primaryHeight: primaryHeight)
}

@Suite("Coordinates")
struct CoordinateTests {
    @Test("AppKit to Accessibility", arguments: [
        (builtIn, CGRect(x: 0, y: 0, width: 1512, height: 982)),
        // The visible area starts below the 33 pt menu bar.
        (builtInVisible, CGRect(x: 0, y: 33, width: 1512, height: 892)),
        // A display above the primary one has negative y in Accessibility coordinates.
        (above, CGRect(x: -539, y: -1440, width: 2560, height: 1440)),
        (left, CGRect(x: -1920, y: -98, width: 1920, height: 1080)),
        (right, CGRect(x: 1512, y: 0, width: 1920, height: 1080)),
    ])
    func axRect(appKit: CGRect, expected: CGRect) {
        #expect(ax(appKit) == expected)
    }

    @Test("Converting twice gives the original rect back", arguments: [builtIn, builtInVisible, above, left, right])
    func roundTrip(rect: CGRect) {
        #expect(ax(ax(rect)) == rect)
    }
}

@Suite("Which display a window is on")
struct DisplayTests {
    private let displays = [builtIn, above, left, right].map(ax)

    @Test("By the window's center, else its top-left corner", arguments: [
        (CGRect(x: 200, y: 100, width: 800, height: 600), 0 as Int?),
        (CGRect(x: 0, y: -1200, width: 1000, height: 800), 1),
        (CGRect(x: -1500, y: 100, width: 800, height: 600), 2),
        // Straddles the built-in and right displays; the center is on the right one.
        (CGRect(x: 1300, y: 100, width: 800, height: 600), 3),
        // The center is off every display, so the top-left corner decides.
        (CGRect(x: 1400, y: 900, width: 400, height: 400), 0),
        (CGRect(x: 5000, y: 5000, width: 400, height: 400), nil),
    ])
    func display(window: CGRect, expected: Int?) {
        #expect(WindowGeometry.displayIndex(containing: window, axDisplays: displays) == expected)
    }
}

@Suite("Margins")
struct MarginTests {
    @Test("Limited to half of the display", arguments: [
        // Margins that fit are kept.
        (Margins(left: 200, top: 0, right: 0, bottom: 0), CGSize(width: 1512, height: 892),
         Margins(left: 200, top: 0, right: 0, bottom: 0)),
        (Margins(left: 280, top: 100, right: 300, bottom: 100), CGSize(width: 2560, height: 1415),
         Margins(left: 280, top: 100, right: 300, bottom: 100)),
        // The left gap takes priority over the right, and the top over the bottom.
        (Margins(left: 600, top: 500, right: 800, bottom: 500), CGSize(width: 1280, height: 775),
         Margins(left: 600, top: 380, right: 40, bottom: 0)),
        // The left gap is capped at half the width on a small display.
        (Margins(left: 600, top: 0, right: 200, bottom: 0), CGSize(width: 1024, height: 700),
         Margins(left: 510, top: 0, right: 0, bottom: 0)),
    ])
    func limited(margins: Margins, size: CGSize, expected: Margins) {
        #expect(margins.limited(to: size) == expected)
    }

    @Test("Limiting twice changes nothing more")
    func limitedIsStable() {
        let size = CGSize(width: 1280, height: 775)
        let once = Margins(left: 600, top: 500, right: 800, bottom: 500).limited(to: size)
        #expect(once.limited(to: size) == once)
    }

    @Test("Every preset fits the largest left gap")
    func presets() {
        #expect(Margins.gapPresets.allSatisfy { $0.value > 0 && $0.value <= Margins.maxLeft })
    }

    @Test("No left gap when the strip is hidden, and only then")
    func stripHidden() {
        let margins = Margins(left: 200, top: 10, right: 20, bottom: 30)
        let size = builtInVisible.size
        #expect(WindowGeometry.effectiveMargins(margins, visibleSize: size, stripHidden: false) == margins)
        #expect(WindowGeometry.effectiveMargins(margins, visibleSize: size, stripHidden: true)
                == Margins(left: 0, top: 10, right: 20, bottom: 30))
    }
}

@Suite("Where a fitted window goes")
struct TargetFrameTests {
    @Test("The visible area minus the margins", arguments: [
        (ax(builtInVisible), Margins(left: 200, top: 0, right: 0, bottom: 0),
         CGRect(x: 200, y: 33, width: 1312, height: 892) as CGRect?),
        (ax(builtInVisible), Margins(left: 200, top: 10, right: 20, bottom: 30),
         CGRect(x: 200, y: 43, width: 1292, height: 852)),
        // On the display above, in negative Accessibility coordinates.
        (ax(above), Margins(left: 200, top: 0, right: 0, bottom: 0),
         CGRect(x: -339, y: -1440, width: 2360, height: 1440)),
        // Exactly the minimum size is still fitted...
        (CGRect(x: 0, y: 0, width: 600, height: 400), Margins(left: 200, top: 0, right: 200, bottom: 200),
         CGRect(x: 200, y: 0, width: 200, height: 200)),
        // ...one point less is not.
        (CGRect(x: 0, y: 0, width: 599, height: 400), Margins(left: 200, top: 0, right: 200, bottom: 0), nil),
        (CGRect(x: 0, y: 0, width: 800, height: 399), Margins(left: 0, top: 100, right: 0, bottom: 100), nil),
    ])
    func target(axVisible: CGRect, margins: Margins, expected: CGRect?) {
        #expect(WindowGeometry.targetFrame(axVisible: axVisible, margins: margins) == expected)
    }

    @Test("Limited margins always leave a window to fit", arguments: [
        CGSize(width: 1024, height: 640), CGSize(width: 1280, height: 775), CGSize(width: 1512, height: 892),
        CGSize(width: 2560, height: 1415), CGSize(width: 3840, height: 2135),
    ])
    func limitedMarginsAlwaysFit(size: CGSize) {
        let largest = Margins(left: 10_000, top: 10_000, right: 10_000, bottom: 10_000).limited(to: size)
        let target = WindowGeometry.targetFrame(axVisible: CGRect(origin: .zero, size: size), margins: largest)
        #expect(target != nil)
    }
}
