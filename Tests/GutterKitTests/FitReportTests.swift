import GutterKit
import Testing

@Suite("Shortcut popup")
struct FitReportTests {
    @Test("Wording and color", arguments: [
        (FitReport.fitted(app: "Safari"), "Fitted Safari", true),
        (.fittedAll(count: 7), "Fitted 7 windows", true),
        (.fittedAll(count: 1), "Fitted 1 window", true),
        // Nothing fitted is a warning, not a success.
        (.fittedAll(count: 0), "No windows to fit", false),
        (.excluded(app: "Calculator"), "Calculator is in Never resize", false),
        (.noWindow(app: "Finder"), "Finder has no window to fit", false),
        (.cantFit, "Can’t fit this window", false),
        (.needsAccess, "Gutter needs Accessibility access", false),
    ])
    func report(_ report: FitReport, title: String, succeeded: Bool) {
        #expect(report.title == title)
        #expect(report.succeeded == succeeded)
    }
}
