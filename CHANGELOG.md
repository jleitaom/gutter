# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.1] - 2026-10-30

### Fixed

- ⌃⌥⌘F no longer resizes apps in **Never resize**; the popup says so instead. **Fit** in the panel and the right-click menu are greyed out for them

## [0.3.0] - 2026-10-29

### Added

- **⌃⌥⌘D** fits every window, like **Fit all windows** in the panel. It has its own switch in Settings, next to ⌃⌥⌘F
- After either shortcut, a popup under the menu bar icon says what was fitted ("Fitted Safari", "Fitted 7 windows"), or why nothing was. Turn it off with **Show a popup after a shortcut** in Settings

### Fixed

- Chrome and other Electron apps no longer play a slow, choppy animation when Gutter resizes their windows

## [0.2.0] - 2026-10-28

First public release.

### Added

- Homebrew: `brew install --cask jleitaom/tap/gutter`, kept up to date by the release workflow
- Update checks with [Sparkle](https://sparkle-project.org): **Check for Updates…** in the right-click menu, and **Check for updates automatically** and **Check Now** in Settings. Sparkle asks before checking on its own, and updates must be signed with the project's key
- Unit tests for the window-fitting math (margins, coordinates across displays, target frames), run in CI with the right-click menu check and panel snapshots

### Changed

- A Settings window (⌘,, or **Settings…** in the panel and the right-click menu) now holds the Stage Manager options, Refit on display change, Shortcut, Open at login and Never resize, so the panel is shorter
- The panel ends with **Settings** and **Quit** buttons, with the version and GitHub link below them
- Releases are signed with a stable self-signed certificate, so updating Gutter keeps its Accessibility access
- The release workflow can be run by hand as a dry run that builds and signs without publishing
- The app is built in Swift 6 mode
- Every build has its own build number (`CFBundleVersion`), counted from commits, so macOS and future update checks can tell versions apart

### Fixed

- Gutter no longer freezes for seconds when an app stops responding during "Fit all windows" or at startup
- The Shortcut row shows "In use" when ⌃⌥⌘F can't be registered because another app claimed it, instead of looking on while doing nothing
- Margins can no longer add up to more than half of a display, which made fitting silently do nothing; the sliders and preview now show the real limits for each display
- Gap sizes are labeled in points (pt), not pixels: 200 pt is 400 pixels on a Retina display
- VoiceOver announces which display and gap preset are selected

## [0.1.0] - 2026-10-27

First working version (not public yet).

### Added

- Auto-fit new windows with configurable left, top, right and bottom margins
- Separate margins for each display, picked from tabs in the panel
- Full width when Stage Manager's recent apps strip is hidden
- Refit windows moved to another display, and when displays are connected or disconnected
- Liquid Glass menu bar panel with a live layout preview of your screen: drag the edge to set the gap
- Gap presets (Snug, Comfy, Roomy)
- "Only with Stage Manager" mode
- "Fit all windows": fits every window on every display to that display's gap
- ⌃⌥⌘F shortcut to fit the current window
- Per-app exclusions, from running apps or any installed app
- Right-click menu: status, fit all or one window, gap presets per display, quick "Never resize" for the current app, every option, About and Quit
- Launch at login
- Universal build (Apple Silicon + Intel)
