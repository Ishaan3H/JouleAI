#!/bin/bash
# Builds an optimised JouleAI.app and zips it for testers, e.g.
# build/JouleAI-0.1.0.zip. Upload that zip to a GitHub Release.
#
# Usage:
#   scripts/make-release.sh
#
# The app is signed "ad hoc" (see build-app.sh), so testers will see macOS's
# "Apple could not verify…" message the first time. docs/TESTING.md explains
# how to open it anyway.
set -euo pipefail

cd "$(dirname "$0")/.."

# The version testers see, read from Info.plist (CFBundleShortVersionString).
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
ZIP="build/JouleAI-$VERSION.zip"

scripts/build-app.sh release

# ditto keeps the app bundle intact (permissions, signature, symlinks) in a
# way plain `zip` doesn't. --keepParent puts JouleAI.app itself in the zip.
echo "==> Zipping"
rm -f "$ZIP"
ditto -c -k --keepParent build/JouleAI.app "$ZIP"

echo "==> Release zip: $ZIP"
