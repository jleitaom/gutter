# Security

## What the app can access

- **Accessibility**: the only permission it asks for. It's used to read the position and size of
  windows and to move and resize them. The app does not read window contents, keystrokes or screen
  pixels.
- **No network access.** The app never connects to the internet. The GitHub link in the menu opens
  in your browser.
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

## Reporting a vulnerability

Please don't open a public issue. Use GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository (Security tab → Report a vulnerability).
