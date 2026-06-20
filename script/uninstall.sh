#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexPulse"
BUNDLE_ID="dev.codex.CodexPulse"
APP_BUNDLE="$HOME/Applications/$APP_NAME.app"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

launchctl bootout "gui/$UID" "$LAUNCH_AGENT" >/dev/null 2>&1 || true
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
rm -rf "$APP_BUNDLE"
rm -f "$LAUNCH_AGENT"

echo "Uninstalled $APP_NAME"
