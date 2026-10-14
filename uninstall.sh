#!/bin/sh
# Removes Clima. Keeps the configuration (~/.config/clima) unless --purge is given.
set -eu

CLIMA_HOME="${CLIMA_HOME:-$HOME/.local/share/clima}"
CLIMA_BIN_DIR="${CLIMA_BIN_DIR:-$HOME/.local/bin}"
CLIMA_APP_DIR="${CLIMA_APP_DIR:-$HOME/Applications}"
LABEL="dev.clima.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$AGENT"
rm -rf "$CLIMA_APP_DIR/Clima.app"
defaults delete "$LABEL" 2>/dev/null || true  # saved menu bar position
[ -L "$CLIMA_BIN_DIR/clima" ] && rm -f "$CLIMA_BIN_DIR/clima"
rm -rf "$CLIMA_HOME"
echo "✓ Clima removed"

if [ "${1:-}" = "--purge" ]; then
  rm -rf "$HOME/.config/clima"
  echo "✓ Configuration removed"
else
  echo "  (configuration kept in ~/.config/clima; use --purge to delete it)"
fi
