# Architecture review, 28 Oct 2026

Phase 5 of `IMPROVEMENT-PLAN.md`, after the Settings window (PR #8). Gutter is small
(about 1,900 lines in the app target), so this review only covers the items the plan names.

## Shared panel parts in `UI/`  [Done]

Files: `Sources/Gutter/MenuView.swift` (637 lines, now 241), `Sources/Gutter/UI/*`
Signal: a file near 600 lines, and parts now used by two screens (panel and Settings).
Proof of same behavior: panel and Settings snapshots (light and dark) and `--menu-test` output
are byte-identical before and after. Commit `a9c317a`.

## One status for the panel and the menu  [Done]

Files: `MenuView.swift` (`Status`, `statusText`), `StatusItemController.swift` (`statusText`)
Signal: the same rule written twice. The panel and the right-click menu each work out
"Needs access / Paused / Waiting for Stage Manager / Active" on their own, so a new state
(for example "Shortcut in use") has to be added in both places, and the two can disagree.
Proposal:

```swift
enum GutterStatus: Equatable {
    case active(stageManagerOn: Bool), paused, waiting, needsAccess

    init(accessGranted: Bool, autoFit: Bool, onlyWithStageManager: Bool, stageManagerOn: Bool)
    var title: String   // "Active · Stage Manager on", "Paused", ...
}
```

A plain type that takes plain values goes in `GutterKit`, so it can be unit tested. The panel
keeps the dot color as a small view-side extension, and the menu shows `"Gutter · " + title`.
Benefits: one place to change the wording or add a state; the rule gets unit tests.
Proof of same behavior: new unit tests for each combination; snapshots and `--menu-test`
unchanged.
Plan: 1) add the type and its tests, 2) move both callers to it and delete the copies.

## Swift 6 language mode  [Done]

Files: `Package.swift`, `WindowManager.swift`, `Preferences.swift`, `HotKey.swift`,
`StatusItemController.swift`
Signal: Swift 5 mode lets main-thread assumptions go unchecked. The AX observer and Carbon hot
key callbacks run on the main run loop, but nothing in the code proves it.
Proposal: `@MainActor` on the four classes; C callbacks hop in with
`MainActor.assumeIsolated`; tools version 6.0. `@Observable` can follow in its own step.
Proof of same behavior: no warnings in Swift 6 mode, all checks above, and a session on the
installed build (new windows fit, ⌃⌥⌘F works, display changes refit).
Plan: 1) tools version 6.0 with Swift 5 mode and fix warnings, 2) annotate and switch to
Swift 6 mode, 3) optionally `@Observable`.
Result: tools version 6.2 with `.defaultIsolation(MainActor.self)` on the app target, instead of
annotating each class, since everything in it is UI. Seven callbacks enter the main actor with
`MainActor.assumeIsolated`; `ActionItem` is `nonisolated` because NSMenuItem's initializers are.
No warnings in debug or release; snapshots and `--menu-test` are byte-identical. `@Observable`
is left for later: it changes how every view observes state, so it gets its own step.

## Top recommendation

The shared status next: it is small, it removes a real duplicate, and it adds tests. Then
Swift 6, because it touches the window code and needs a session on the installed build.

## Considered, not recommended

- Splitting `WindowManager.swift` (365 lines): it is under the threshold, and its geometry
  already lives in `GutterKit`.
- A protocol around Accessibility calls for tests: there would be one conformer, and the
  window math is already tested where it lives.
