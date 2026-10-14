#!/bin/sh
# Builds the menu bar app and assembles Clima.app.
# Usage: scripts/build_app.sh [destination-folder]   (default: ~/Applications)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HOME/Applications}"
APP="$DEST/Clima.app"

echo "→ Building the app (swift build -c release)..."
# Output is shown only if the build fails (with Command Line Tools, SwiftPM warns about XCTest for no reason)
if ! output="$(swift build -c release --package-path "$ROOT/app" --product Clima 2>&1)"; then
  echo "$output" >&2
  exit 1
fi

mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/app/.build/release/Clima" "$APP/Contents/MacOS/Clima"
cp "$ROOT/app/Support/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" 2>/dev/null  # local (ad-hoc) signature
echo "✓ $APP"
