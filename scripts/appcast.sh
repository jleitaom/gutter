#!/bin/bash
# Writes the Sparkle appcast for one release: an item for the given zip, with its EdDSA
# signature. Sparkle reads it from the latest release, so it only needs the newest version.
#
#   scripts/appcast.sh <version> <build number> <zip> <download url> > appcast.xml
#
# Signs with the key in SPARKLE_KEY_FILE when set (CI), otherwise with the "gutter" key in
# the login keychain (made by Sparkle's generate_keys --account gutter).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: scripts/appcast.sh <version> <build number> <zip> <download url>}
BUILD=${2:?build number}
ZIP=${3:?zip}
URL=${4:?download url}

SIGN_UPDATE=.build/artifacts/sparkle/Sparkle/bin/sign_update
[[ -x "$SIGN_UPDATE" ]] || swift package resolve >/dev/null
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
    SIGNATURE=$("$SIGN_UPDATE" --ed-key-file "$SPARKLE_KEY_FILE" "$ZIP")
else
    SIGNATURE=$("$SIGN_UPDATE" --account gutter "$ZIP")
fi

cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Gutter</title>
    <link>https://github.com/jleitaom/gutter</link>
    <item>
      <title>Gutter $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/jleitaom/gutter/releases/tag/v$VERSION</sparkle:fullReleaseNotesLink>
      <enclosure url="$URL" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
EOF
