#!/bin/bash
# Builds Gutter.app into ./build.
#
#   ./build.sh             build only
#   ./build.sh --install   also copy to /Applications and launch
#
# Environment:
#   VERSION         overrides CFBundleShortVersionString (e.g. 1.2.0)
#   BUILD_NUMBER    CFBundleVersion (default: the number of commits, so it grows with every
#                   release; macOS and update checks compare this one)
#   SIGN_IDENTITY   codesigning identity (default: "Gutter Self-Signed" when it's in your
#                   keychain, so rebuilds keep Accessibility access; otherwise "-" for ad-hoc)
set -euo pipefail
cd "$(dirname "$0")"

BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_FLAGS[@]}"
BIN_PATH=$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)

APP=build/Gutter.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/Gutter" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
BUILD_NUMBER=${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

if [[ -z "${SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY=-
    if security find-identity -p codesigning 2>/dev/null | grep -q '"Gutter Self-Signed"'; then
        SIGN_IDENTITY="Gutter Self-Signed"
    fi
fi
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
echo "Signed with: $SIGN_IDENTITY"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Gutter || true
    rm -rf /Applications/Gutter.app
    cp -R "$APP" /Applications/
    open /Applications/Gutter.app
    echo "Installed and launched /Applications/Gutter.app"
fi
