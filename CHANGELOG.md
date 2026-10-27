# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Gutter no longer freezes for seconds when an app stops responding during "Fit all windows" or at startup
- The Shortcut row shows "In use" when ⌃⌥⌘F can't be registered because another app claimed it, instead of looking on while doing nothing
- Margins can no longer add up to more than half of a display, which made fitting silently do nothing; the sliders and preview now show the real limits for each display

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
