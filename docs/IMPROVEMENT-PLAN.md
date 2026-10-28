# Gutter improvement plan

Plan to apply the review of Gutter 0.1.0 (27 Oct 2026) before going public.
Work on a branch (`improvements`), one item per commit, and add a line to
`CHANGELOG.md` under **Unreleased** for every user-visible change.

Each item has: why, what to change, and a "Done when" check.

| Phase | Items | Size |
|---|---|---|
| 1. Quick fixes | 1.1 – 1.8 | Small, about one sitting |
| 2. Stable signing | 2.1 – 2.2 | Medium, needs a certificate and a GitHub secret |
| 3. Panel and Settings window | Redo before Phase 5, keeping the original design | Medium |
| 4. Tests and CI | 4.1 – 4.4 | Medium |
| 5. Code cleanup | 5.1 – 5.3 | Medium |
| 6. Going public | 6.1 – 6.5 | Medium |

---

## Phase 1: Quick fixes

### 1.1 Pin release actions to commit SHAs

**Why:** the release job can write to the repo and mint OIDC tokens.
`softprops/action-gh-release@v3` is pinned to a tag, which its owner can move.

**Change:** `.github/workflows/release.yml`, `.github/workflows/ci.yml`

- Replace every `uses: owner/action@vN` with `uses: owner/action@<full SHA> # vN`.
  Get the SHA with `gh api repos/<owner>/<action>/commits/<tag> --jq .sha`.
- Move the top-level `permissions:` block into the `release` job.
- Add `permissions: contents: read` at the top of `ci.yml`.
- Dependabot already updates SHA pins; keep the grouped config.

**Done when:** no `uses:` line ends in a bare tag, and a test tag on a fork
still publishes a release.

### 1.2 Set a short Accessibility timeout

**Why:** all AX calls run on the main thread with the default timeout of several
seconds. One hung app freezes Gutter during "Fit all windows", startup, and the
scan after access is granted.

**Change:** `WindowManager.start()`

```swift
// A hung app shouldn't freeze Gutter: give up on any AX call after half a second.
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
```

**Done when:** with an app paused (`kill -STOP <pid>`), "Fit all windows"
returns within about a second and the panel stays responsive. Resume with
`kill -CONT <pid>`.

### 1.3 Report a shortcut that failed to register

**Why:** `RegisterEventHotKey`'s result is ignored. If another app owns ⌃⌥⌘F,
the panel shows the shortcut as on, but it does nothing.

**Change:** `HotKey.swift`, `main.swift`, `MenuView.swift`

- Make `HotKey.init` failable (`init?`), returning `nil` when
  `RegisterEventHotKey` is not `noErr` (remove the event handler first).
- Publish a `hotKeyConflict: Bool` (on `WindowManager` or `AppDelegate` via
  `Preferences`), set when the shortcut is enabled but registration failed.
- In the Shortcut row, show "In use by another app" in `.secondary` with an
  `exclamationmark.triangle` symbol when there is a conflict.

**Done when:** registering ⌃⌥⌘F in a second test app first makes Gutter show
the warning instead of a silent "on" toggle.

### 1.4 Keep margins from making windows too small

**Why:** `fit()` silently does nothing when the target is under 200 pt. The top,
right and bottom sliders go up to 500/800 pt regardless of screen size.

**Change:** `MenuView.swift` (`otherMargins`, `MarginSlider`), `LayoutPreview.setGap`

- Compute each slider's upper bound from the selected screen's visible frame,
  so the window stays at least 200 pt wide and tall (or half the screen, like
  the left gap).
- Clamp the stored value if a smaller display is selected later.

**Done when:** no combination of sliders on any connected display produces a
window under 200 pt, and the preview never collapses to zero.

### 1.5 Fix the double click monitor and the window-display leak

**Change:** `StatusItemController.swift`, `WindowManager.swift`

- `showPanel()`: if a monitor exists, remove it before adding a new one (or
  return early when the panel is already visible and not dismissing).
- `WindowManager`: observe `kAXUIElementDestroyedNotification` for each window
  (or prune `windowDisplays[pid]` to the current `windows(of: pid)` whenever a
  window is created) so closed windows are removed.

**Done when:** opening Gutter from Spotlight while the panel is open, ten
times, leaves one monitor, and `windowDisplays` stays bounded after opening
and closing 100 Finder windows. Check with a debug `print` of the counts.

### 1.6 Use "pt", not "px"

**Why:** the values are points; on Retina, 200 pt is 400 pixels.

**Change:** `MenuView.swift` (preview label, accessibility value),
`StatusItemController.swift` (gap menu), `README.md`, `CHANGELOG.md`.
Accessibility value: "200 points".

**Done when:** `grep -rn "px" Sources README.md` finds no margin labels.

### 1.7 Mark the selected option for VoiceOver

**Change:** `CapsulePicker` in `MenuView.swift`

```swift
.accessibilityAddTraits(selected ? .isSelected : [])
```

Also give the group a label: `.accessibilityElement(children: .contain)` and
`.accessibilityLabel("Gap preset")` / `"Display"`.

**Done when:** VoiceOver reads "Comfy, selected, button".

### 1.8 Set CFBundleVersion on every build

**Why:** it is always `1`. macOS and Sparkle compare `CFBundleVersion`, so
updates would never look newer.

**Change:** `build.sh`, `scripts/package.sh`, `release.yml`

- `build.sh`: accept `BUILD_NUMBER` and set `CFBundleVersion` with PlistBuddy,
  like `VERSION`. Default to `$(git rev-list --count HEAD)`.
- `release.yml`: pass `BUILD_NUMBER: ${{ github.run_number }}` (or keep the
  commit count, which also works for local packages).

**Done when:** `defaults read build/Gutter.app/Contents/Info.plist CFBundleVersion`
shows a number that grows with each commit or release.

---

## Phase 2: Stable signing

### 2.1 Sign releases with a self-signed certificate

**Why:** ad hoc builds change identity every time, so every update makes users
remove and re-add Gutter under Accessibility. A stable certificate keeps the
same designated requirement across versions, so the grant should carry over.

**Steps:**

1. Create a code signing certificate: Keychain Access → Certificate Assistant
   → Create a Certificate → name `Gutter Self-Signed`, type Code Signing.
   Validity: 10 years.
2. Export it with its private key as a `.p12` with a strong password.
3. Add repo secrets: `SIGNING_CERT_P12` (base64 of the file), `SIGNING_CERT_PASSWORD`.
4. In `release.yml`, before packaging, import it into a temporary keychain:
   `security create-keychain`, `security import ... -T /usr/bin/codesign`,
   `security set-key-partition-list`, then add the keychain to the search list.
5. Run `SIGN_IDENTITY="Gutter Self-Signed" scripts/package.sh ...`.
6. Delete the temporary keychain in an `if: always()` step.
7. Use the same identity for local `./build.sh` (CONTRIBUTING: "set
   `SIGN_IDENTITY` to keep Accessibility access across rebuilds").

**Done when:** install release N, grant access, install release N+1 over it,
and fitting still works without touching System Settings. Confirm with
`codesign -dr - /Applications/Gutter.app` showing the same requirement for both.

### 2.2 Update the docs

- README "Install" and "Why the warning?": say access survives updates.
- SECURITY.md: name the certificate and how to check it
  (`codesign -dv --verbose=4`).
- ROADMAP: remove "Stable local signing" from "Before going public".

---

## Phase 3: Panel and Settings window (done)

**Status (28 Oct 2026):** done on the `settings-window` branch, with no design changes. The
panel keeps the status, access notice, display picker, preview, presets, Top/right/bottom and
the Fit buttons, and now ends with Settings and Quit buttons above the version and GitHub link.
A plain titled Settings window (⌘,) holds the same glass groups for the Stage Manager options,
Refit on display change, Shortcut, Open at login and Never resize. No tabs and no Undo; the
answers below are kept for the record.

### Goal

A ⌘, Settings window for the settings, and a shorter panel for everyday use, **keeping the
original visual design** of the panel.

### Problems from the first attempt, and how to avoid them

| Problem | Cause | This time |
|---|---|---|
| Design got "too rectangular" | Native segmented `Picker` / `NSSegmentedControl` and `.glass` buttons replaced the custom controls | Keep `CapsulePicker`, the capsule button styles, `GlassGroup` rows and the original fonts. No native segmented controls |
| Selected display and preset were gray | SwiftUI's segmented `Picker` ignores `.tint` on macOS | Not an issue with `CapsulePicker`; keep it |
| Panel slid up under the menu bar when switching displays | A `ScrollView` at the panel's root made the hosting view resize the window from its bottom edge | No `ScrollView` root: keep `MenuView().fixedSize()` and `fittingSize`. Add the `GlassPanel` top-edge pin (`setFrame` override) as a guard |
| Content could stop filling the panel | `hosting.sizingOptions = []` broke content-view autoresizing | Leave `sizingOptions` at the default |
| Offscreen snapshots hid both bugs | They don't click, aren't key windows, and can't draw glass | `--panel-test` clicks through the display tabs with real mouse events and fails if the panel moves or its content doesn't fill it; `GUTTER_PANEL_PNG` saves the real key panel |

### Reuse from the local branch `phase3-settings-window-unused`

It predates Phase 4 (`Margins` now lives in `GutterKit`), so copy pieces over by hand rather
than cherry-picking:

- `SettingsWindow.swift`: `NSTabViewController` with toolbar tabs, remembers the last tab,
  General / Margins / Apps, Undo for the Apps list
- `MainMenu.swift`: hidden main menu so ⌘, ⌘W, ⌘Z work in Settings
- `GlassPanel` top-edge pin, `Preferences.limitedMargins(for:)`, `AppInfo.appName/appIcon/openAccessibilitySettings`
- `Snapshot.swift`: `--settings-snapshot`, the improved `--panel-test`, `GUTTER_PANEL_PNG`

### Ask José before starting

1. Which options stay in the panel and which move to Settings? (First try kept: status, auto-fit
   switch, access notice, display picker, preview, presets, Fit buttons.)
2. Should the Settings window use the panel's visual language (glass groups, capsule controls)
   instead of a plain system grouped form?

### Done when

Light and dark renders of the panel and every Settings tab look like the original design,
`--panel-test` passes with every display connected, José has tried ⌘, ⌘W, Undo and switching
displays on the installed build, and CI passes.

---

## Phase 4: Tests and CI

### 4.1 Move the geometry into a library target

**Change:** `Package.swift`

```swift
targets: [
    .target(name: "GutterKit", path: "Sources/GutterKit"),
    .executableTarget(name: "Gutter", dependencies: ["GutterKit"], path: "Sources/Gutter"),
    .testTarget(name: "GutterKitTests", dependencies: ["GutterKit"]),
]
```

Move into `GutterKit`, as pure functions with no AppKit state:

- `Margins` and the presets
- `targetFrame(visible:margins:) -> CGRect?` (returns nil under 200 pt)
- `axRect(_:primaryHeight:)` (AppKit ↔ Accessibility coordinates)
- `screenIndex(containing:screens:)`
- the slider limits from 1.4

`WindowManager` and `LayoutPreview` call these, so the app and the preview
compute the same frame.

### 4.2 Unit tests (Swift Testing)

Table tests for:

- Single display, default margins.
- A second display left of, right of, above and below the primary.
- A window straddling two displays (center decides).
- Margins that leave less than 200 pt → `nil`.
- Full width when the strip is hidden.
- `axRect` round trip.

**Done when:** `swift test` passes with at least 15 cases.

### 4.3 Run the existing checks in CI

**Change:** `ci.yml`, after the build:

```yaml
- run: swift test
- run: swift run Gutter --menu-test
- run: swift run Gutter --snapshot light.png && swift run Gutter --snapshot dark.png --dark
- uses: actions/upload-artifact@<sha> # v7
  with: { name: snapshots, path: "*.png" }
```

Keep `--panel-test` local unless the runner has a menu bar session.

### 4.4 Document the manual checks

Add a "Before a release" checklist to CONTRIBUTING.md: grant access, open a
Finder and a Safari window with Stage Manager on and off, move a window to a
second display, press ⌃⌥⌘F, test with a paused app (1.2).

---

## Phase 5: Code cleanup

### 5.1 Split MenuView.swift (723 lines)

Move `GlassGroup`, `Row`, `DisclosureRow`, `SmallSwitch`, `KeyCap`,
`MarginSlider`, `CapsulePicker`, the button styles, `LayoutPreview` and
`MiniWindow` into `Sources/Gutter/UI/`. Target: no view file over about 300
lines. Update the file list in CONTRIBUTING.md.

### 5.2 One source for the status

Add `WindowManager.status` (an enum with `.active`, `.paused`, `.waiting`,
`.needsAccess` and its text), and use it in both `MenuView` and
`StatusItemController`.

### 5.3 Move to Swift 6

- `swift-tools-version:6.0`, Swift 6 language mode.
- `@MainActor` on `WindowManager`, `Preferences`, `StatusItemController`, `HotKey`.
- AX and Carbon callbacks: hop to the main actor with `MainActor.assumeIsolated`
  (they already run on the main run loop).
- Consider `@Observable` instead of `ObservableObject` (needs macOS 14, already the minimum).

**Done when:** `swift build` has no warnings in Swift 6 mode.

---

## Phase 6: Going public

### 6.1 Screenshot and demo

Follow `docs/DEMO-VIDEO.md`. Replace the README placeholder with
`docs/screenshot.png` (light and dark with `<picture>`) and the demo video.

### 6.2 Homebrew tap

1. Create `jleitaom/homebrew-tap` with `Casks/gutter.rb`:
   `version`, `sha256`, `url` to the release `.zip`, `name`, `desc`,
   `homepage`, `depends_on macos: ">= :sonoma"`, `app "Gutter.app"`, and a
   `zap trash:` for `~/Library/Preferences/io.github.jleitaom.gutter.plist`.
2. In `release.yml`, add a step that updates the cask's version and SHA and
   pushes to the tap (a fine-grained token limited to the tap repo, stored as
   a secret).
3. README: `brew install --cask jleitaom/tap/gutter` as the first install option.

Check Homebrew's current policy on apps that are not notarized before
documenting any quarantine workaround. Don't tell users to disable Gatekeeper.

### 6.3 Update checks with Sparkle

Needs 1.8 (growing `CFBundleVersion`) and 2.1 (stable signing).

- Add Sparkle via SwiftPM; embed `Sparkle.framework` in `build.sh` and re-sign.
- Generate an EdDSA key (`generate_keys`), put the public key in `Info.plist`
  (`SUPublicEDKey`), the private key in a GitHub secret.
- Publish `appcast.xml` from the release workflow (GitHub Pages or a release asset).
- Add "Check for Updates…" to the right-click menu and the General tab.
- Update SECURITY.md: Sparkle is the only network access, only to GitHub, and
  can be turned off.

### 6.4 Repo settings

- Enable private vulnerability reporting (SECURITY.md already points to it).
- Protect `main`: require the CI check, no force pushes.
- Add a feature request issue template and a short PR template.
- Topics: `macos`, `stage-manager`, `window-manager`, `menu-bar`, `swift`.

### 6.5 Release 0.2.0

Move **Unreleased** in CHANGELOG to `[0.2.0]`, tag `v0.2.0`, verify the
attestation and checksum from a second Mac, then make the repo public.

---

## Not in this plan

Kept in ROADMAP.md for later: per-app gaps, custom shortcuts, fit only the
first window. Notarization needs a paid Apple Developer account; revisit if
the Homebrew or Gatekeeper friction proves too high.
