#!/bin/bash
# Remove o Crab Companion: app, LaunchAgent e hooks do Claude Code.
set -uo pipefail

APP="$HOME/Applications/Crab Companion.app"
PLIST="$HOME/Library/LaunchAgents/com.crab-companion.pet.plist"
LABEL="com.crab-companion.pet"
SETTINGS="$HOME/.claude/settings.json"

curl -s -m 2 localhost:4923/quit >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$APP"

if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  cp "$SETTINGS" "$SETTINGS.crab-backup"
  jq '
    if .hooks then
      .hooks |= (with_entries(
        .value |= map(
          select(((.hooks // []) | any(.command // "" | contains("Crab Companion.app"))) | not)
        )
      ) | with_entries(select(.value | length > 0)))
      | (if .hooks == {} then del(.hooks) else . end)
    else . end
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
  echo "Hooks do Crab Companion removidos de $SETTINGS (backup: $SETTINGS.crab-backup)"
fi

echo "🦀 Desinstalado. Até a próxima!"
