#!/bin/bash
# Instala o Crab Companion: compila, monta o .app, registra o LaunchAgent
# (inicia no login) e adiciona os hooks do Claude Code.
set -euo pipefail
cd "$(dirname "$0")"

APP="$HOME/Applications/Crab Companion.app"
PLIST="$HOME/Library/LaunchAgents/com.crab-companion.pet.plist"
LABEL="com.crab-companion.pet"
SETTINGS="$HOME/.claude/settings.json"

command -v swiftc >/dev/null 2>&1 || {
  echo "erro: swiftc não encontrado. Instale o Xcode Command Line Tools: xcode-select --install"
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "erro: jq não encontrado. Instale com: brew install jq"
  exit 1
}

echo "==> Compilando"
swiftc main.swift -o pet

echo "==> Gerando ícone"
TMP=$(mktemp -d)
swift make_icon.swift "$TMP/icon.png" >/dev/null
mkdir -p "$TMP/icon.iconset"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$TMP/icon.png" --out "$TMP/icon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z "$d" "$d" "$TMP/icon.png" --out "$TMP/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/icon.iconset" -o "$TMP/crab.icns"

echo "==> Montando $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp pet "$APP/Contents/MacOS/pet"
cp ask.sh notify.sh "$APP/Contents/Resources/"
chmod +x "$APP/Contents/Resources/ask.sh" "$APP/Contents/Resources/notify.sh"
cp "$TMP/crab.icns" "$APP/Contents/Resources/crab.icns"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.crab-companion.pet</string>
    <key>CFBundleName</key><string>Crab Companion</string>
    <key>CFBundleExecutable</key><string>pet</string>
    <key>CFBundleIconFile</key><string>crab</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

echo "==> LaunchAgent (inicia no login)"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$APP/Contents/MacOS/pet</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
</dict>
</plist>
EOF
# bootout é assíncrono: espera descarregar antes do bootstrap, com fallback pra kickstart
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
sleep 1
if ! launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null || {
    echo "aviso: não consegui (re)carregar o LaunchAgent agora; ele carrega no próximo login."
  }
fi
for _ in 1 2 3 4 5; do
  sleep 1
  curl -s -m 1 localhost:4923/idle >/dev/null 2>&1 && break
done

echo "==> Hooks do Claude Code em $SETTINGS"
mkdir -p "$HOME/.claude"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.crab-backup"

NOTIFY="\"$APP/Contents/Resources/notify.sh\""
ASKSH="\"$APP/Contents/Resources/ask.sh\""

add_hook() {
  local event="$1" entry="$2"
  if jq -e --arg e "$event" '.hooks[$e] // empty | length > 0' "$SETTINGS" >/dev/null 2>&1; then
    echo "    - $event: já existe um hook seu, não vou sobrescrever (veja o README)"
  else
    jq --arg e "$event" --argjson h "$entry" '.hooks //= {} | .hooks[$e] = $h' \
      "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    echo "    + $event"
  fi
}

add_hook UserPromptSubmit \
  "$(jq -n --arg c "$NOTIFY working" '[{hooks:[{type:"command",command:$c,async:true}]}]')"
add_hook Stop \
  "$(jq -n --arg c "$NOTIFY done" '[{hooks:[{type:"command",command:$c,async:true}]}]')"
add_hook Notification \
  "$(jq -n --arg c "$NOTIFY attention" '[{hooks:[{type:"command",command:$c,async:true}]}]')"
add_hook PermissionRequest \
  "$(jq -n --arg c "$ASKSH" '[{hooks:[{type:"command",command:$c,timeout:60}]}]')"

echo
echo "🦀 Pronto! O caranguejo deve estar no canto superior direito da tela."
echo "   - Reinicie sessões do Claude Code abertas para os hooks passarem a valer."
echo "   - Teste rápido: curl localhost:4923/done  (ele comemora)"
echo "   - Backup da sua configuração anterior: $SETTINGS.crab-backup"
