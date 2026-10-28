import GutterKit
import Testing

@Suite("Status")
struct GutterStatusTests {
    @Test("Every combination", arguments: [
        // access, auto-fit, only with Stage Manager, Stage Manager on -> status
        (false, true, true, true, GutterStatus.needsAccess),
        // Missing access wins over a paused auto-fit.
        (false, false, false, false, .needsAccess),
        (true, false, true, false, .paused),
        (true, false, false, true, .paused),
        (true, true, true, false, .waiting),
        (true, true, true, true, .active),
        // Without the Stage Manager option, Gutter works either way.
        (true, true, false, false, .active),
        (true, true, false, true, .active),
    ])
    func status(access: Bool, autoFit: Bool, onlyWithStageManager: Bool, stageManagerOn: Bool, expected: GutterStatus) {
        let status = GutterStatus(accessGranted: access, autoFit: autoFit,
                                  onlyWithStageManager: onlyWithStageManager, stageManagerOn: stageManagerOn)
        #expect(status == expected)
    }

    @Test("Titles")
    func titles() {
        #expect(GutterStatus.active.title == "Active")
        #expect(GutterStatus.paused.title == "Paused")
        #expect(GutterStatus.waiting.title == "Waiting for Stage Manager")
        #expect(GutterStatus.needsAccess.title == "Needs access")
    }
}
