#!/bin/bash
# Builds Reckon and packages it as build/Reckon.app.
#
# Usage:
#   scripts/build-app.sh          # debug build
#   scripts/build-app.sh release  # optimised build
#   scripts/build-app.sh --run    # debug build, then (re)launch the app
#
# Signing: by default the app is signed "ad hoc" (no Apple developer account
# needed). Set SIGN_IDENTITY to a real certificate name to use that instead.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="debug"
RUN=false
for arg in "$@"; do
  case "$arg" in
    release) CONFIG="release" ;;
    --run) RUN=true ;;
  esac
done

echo "==> Compiling ($CONFIG)"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Reckon.app"
echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Reckon" "$APP/Contents/MacOS/Reckon"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> Signing (Hardened Runtime on)"
codesign --force --options runtime \
  --entitlements Resources/Reckon.entitlements \
  --sign "${SIGN_IDENTITY:--}" \
  "$APP"

echo "==> Built $APP"

if $RUN; then
  # Quit any running copy first so the new build is the one that launches.
  pkill -x Reckon 2>/dev/null || true
  sleep 0.5
  open "$APP"
  echo "==> Launched. Look for the Reckon icon in the menu bar."
fi
