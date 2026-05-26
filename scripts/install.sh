#!/usr/bin/env bash
# Build a bundle, copy it to ~/Applications, and install a user LaunchAgent so
# Switchboard starts at login and is kept alive by launchd.
set -euo pipefail

APP_NAME="Switchboard"
BUNDLE_ID="com.cosmicspork.switchboard"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="$HOME/Applications"
AGENT="$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"

"$ROOT/scripts/make-app-bundle.sh"

mkdir -p "$INSTALL_DIR"
rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
cp -R "$ROOT/${APP_NAME}.app" "$INSTALL_DIR/"

EXEC="$INSTALL_DIR/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${BUNDLE_ID}</string>
    <key>ProgramArguments</key>
    <array><string>${EXEC}</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/${BUNDLE_ID}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo "Installed ${APP_NAME}.app to ${INSTALL_DIR} and started it."
echo "When you first enable the auto-light helper, grant the Automation prompt"
echo "(System Settings -> Privacy & Security -> Automation)."
