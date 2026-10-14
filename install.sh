#!/bin/sh
# Installs Clima: the `clima` command, the widget bridge and the menu bar app.
#
#   ./install.sh                 full install (recommended)
#   ./install.sh --no-app        only the `clima` command (no widget)
#   ./install.sh --no-login      don't open the widget automatically at login
#   ./install.sh --extras ""     no provider dependencies (default: midea)
#
# Folders (can be overridden with environment variables):
#   CLIMA_HOME     ~/.local/share/clima   Python environment
#   CLIMA_BIN_DIR  ~/.local/bin           `clima` command link
#   CLIMA_APP_DIR  ~/Applications         Clima.app
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLIMA_HOME="${CLIMA_HOME:-$HOME/.local/share/clima}"
CLIMA_BIN_DIR="${CLIMA_BIN_DIR:-$HOME/.local/bin}"
CLIMA_APP_DIR="${CLIMA_APP_DIR:-$HOME/Applications}"
LABEL="dev.clima.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

WITH_APP=1
WITH_LOGIN=1
EXTRAS="midea"
while [ $# -gt 0 ]; do
  case "$1" in
    --no-app) WITH_APP=0; WITH_LOGIN=0 ;;
    --no-login) WITH_LOGIN=0 ;;
    --extras) EXTRAS="$2"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

fail() { echo "✗ $*" >&2; exit 1; }

# ---------------------------------------------------------------- 1. Python >= 3.10
find_python() {
  for candidate in python3.13 python3.12 python3.11 python3.10 python3; do
    if command -v "$candidate" >/dev/null 2>&1 &&
       "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}
PYTHON="$(find_python)" || fail "Python 3.10+ not found. Install it with: brew install python"
echo "→ Using $("$PYTHON" --version) ($PYTHON)"

# ---------------------------------------------------------------- 2. environment and package
echo "→ Creating environment at $CLIMA_HOME/venv..."
mkdir -p "$CLIMA_HOME"
"$PYTHON" -m venv "$CLIMA_HOME/venv"
"$CLIMA_HOME/venv/bin/pip" install --quiet --upgrade pip
SPEC="$ROOT"
[ -n "$EXTRAS" ] && SPEC="$ROOT[$EXTRAS]"
"$CLIMA_HOME/venv/bin/pip" install --quiet "$SPEC"

mkdir -p "$CLIMA_BIN_DIR"
ln -sf "$CLIMA_HOME/venv/bin/clima" "$CLIMA_BIN_DIR/clima"
echo "✓ Command installed at $CLIMA_BIN_DIR/clima"

# ---------------------------------------------------------------- 3. menu bar app
if [ "$WITH_APP" = 1 ]; then
  command -v swift >/dev/null 2>&1 || fail "Swift not found. Run: xcode-select --install (or use --no-app)"
  "$ROOT/scripts/build_app.sh" "$CLIMA_APP_DIR"
fi

# ---------------------------------------------------------------- 4. menu bar position
# New icons are placed to the left of existing ones and, on Macs with a notch, can end up hidden behind it.
# Start near the clock/battery (distance from the right edge); if the user ⌘-drags it, their choice wins.
if [ "$WITH_APP" = 1 ]; then
  POSITION_KEY="NSStatusItem Preferred Position Item-0"
  defaults read "$LABEL" "$POSITION_KEY" >/dev/null 2>&1 || defaults write "$LABEL" "$POSITION_KEY" -float 250
fi

# ---------------------------------------------------------------- 5. open at login
if [ "$WITH_LOGIN" = 1 ]; then
  mkdir -p "$(dirname "$AGENT")"
  cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$CLIMA_APP_DIR/Clima.app/Contents/MacOS/Clima</string></array>
  <key>EnvironmentVariables</key><dict><key>CLIMA_BRIDGE</key><string>$CLIMA_HOME/venv/bin/clima-bridge</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/clima.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/clima.log</string>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  # Right after a bootout, bootstrap can fail ("Input/output error") while the old instance shuts down
  attempt=1
  until launchctl bootstrap "gui/$(id -u)" "$AGENT" 2>/dev/null; do
    [ "$attempt" -ge 5 ] && fail "could not start the widget (launchctl bootstrap). See ~/Library/Logs/clima.log"
    attempt=$((attempt + 1))
    sleep 1
  done
  echo "✓ Widget opened and set to start at login"
fi

# ---------------------------------------------------------------- next steps
echo
case ":$PATH:" in
  *":$CLIMA_BIN_DIR:"*) ;;
  *) echo "⚠ Add to your shell: export PATH=\"$CLIMA_BIN_DIR:\$PATH\"" ;;
esac
CONFIG="${CLIMA_CONFIG:-$HOME/.config/clima/config.json}"
if [ ! -f "$CONFIG" ]; then
  echo "Next step: configure your device with"
  echo "    clima setup"
  echo "(no device? try: clima setup --provider demo)"
fi
