# Security

## What the app can access

- **Accessibility**: the only permission it asks for. It's used to read the position and size of
  windows and to move and resize them. The app does not read window contents, keystrokes or screen
  pixels.
- **Network: update checks only.** Gutter connects to one place, GitHub, to see whether there's a
  newer release (the `appcast.xml` attached to the latest release). It uses
  [Sparkle](https://sparkle-project.org) for this. Sparkle asks before it checks on its own, it
  checks at most once a day, and you can turn it off in Settings → *Check for updates
  automatically*. The request carries Gutter's and Sparkle's version numbers and nothing else:
  no system profile, no identifiers. The GitHub link in the panel opens in your browser.
- **No data collection.** Settings are stored locally in `~/Library/Preferences`.

## Verifying a download

Releases are built by GitHub Actions directly from the tagged source code. They are not notarized
by Apple (the project doesn't use a paid developer account), so you can verify them yourself:

```sh
# 1. Check the file was built by this repo's release workflow
gh attestation verify Gutter-0.1.0.dmg --repo jleitaom/gutter

# 2. Or compare the checksum with SHA256SUMS.txt from the release page
shasum -a 256 Gutter-0.1.0.dmg
```

Or skip downloads entirely and build from source with `./build.sh`.

## Code signing

Releases are signed with the project's self-signed certificate, `Gutter Self-Signed`, so
every version has the same code identity and keeps the Accessibility access you granted. To
check a downloaded app:

```sh
codesign -dr - /Applications/Gutter.app
# designated => identifier "io.github.jleitaom.gutter" and certificate leaf = H"2842389dd54d9e20e7e29f768e76f707477741aa"
```

If a release ever shows a different certificate hash, don't install it and report it as below.

Updates are checked twice before they're installed: Sparkle only accepts an archive signed with
the project's EdDSA key (its public half is `SUPublicEDKey` in `Info.plist`), and the new app
must be signed with the same certificate as the one you have.

The app is signed with one entitlement, `com.apple.security.cs.disable-library-validation`. It
lets the hardened runtime load `Sparkle.framework`, which is signed with the same self-signed
certificate. That certificate has no Apple Team ID, and library validation requires one.

## Reporting a vulnerability

Please don't open a public issue. Use GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository (Security tab → Report a vulnerability).
