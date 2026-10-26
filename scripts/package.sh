#!/bin/bash
# Builds a release and packages it as dist/Gutter-<version>.zip and .dmg, plus SHA256SUMS.txt.
#
#   scripts/package.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: scripts/package.sh <version>}
APP=build/Gutter.app
DIST=dist

VERSION="$VERSION" ./build.sh

rm -rf "$DIST"
mkdir -p "$DIST"

ditto -c -k --keepParent "$APP" "$DIST/Gutter-$VERSION.zip"

STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname Gutter -srcfolder "$STAGING" -ov -format UDZO "$DIST/Gutter-$VERSION.dmg" >/dev/null
rm -rf "$STAGING"

(cd "$DIST" && shasum -a 256 ./*.zip ./*.dmg > SHA256SUMS.txt)
echo "Packaged:"
ls -lh "$DIST"
