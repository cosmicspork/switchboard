#!/usr/bin/env bash
# Stop and remove the LaunchAgent and the installed app bundle.
set -euo pipefail

APP_NAME="Switchboard"
BUNDLE_ID="com.cosmicspork.switchboard"
AGENT="$HOME/Library/LaunchAgents/${BUNDLE_ID}.plist"

launchctl bootout "gui/$(id -u)/${BUNDLE_ID}" 2>/dev/null || true
rm -f "$AGENT"
rm -rf "$HOME/Applications/${APP_NAME}.app"

echo "Uninstalled ${APP_NAME}."
