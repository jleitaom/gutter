#!/bin/bash
# Prints the Homebrew cask for one release, for jleitaom/homebrew-tap (Casks/gutter.rb).
#
#   scripts/cask.sh <version> <sha256 of Gutter-<version>.zip>
set -euo pipefail

VERSION=${1:?usage: scripts/cask.sh <version> <sha256>}
SHA256=${2:?sha256}

cat <<EOF
cask "gutter" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/jleitaom/gutter/releases/download/v#{version}/Gutter-#{version}.zip"
  name "Gutter"
  desc "Fit new windows beside the Stage Manager strip"
  homepage "https://github.com/jleitaom/gutter"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Gutter updates itself with Sparkle.
  auto_updates true
  depends_on macos: ">= :sonoma"

  app "Gutter.app"

  uninstall quit: "io.github.jleitaom.gutter"

  zap trash: [
    "~/Library/Caches/io.github.jleitaom.gutter",
    "~/Library/HTTPStorages/io.github.jleitaom.gutter",
    "~/Library/Preferences/io.github.jleitaom.gutter.plist",
  ]
end
EOF
