#!/bin/bash
# Monta dist/Craby.app (+ zip) a partir de um binário ./pet já compilado.
# Usado pelo install.sh e pelo workflow de release.
set -euo pipefail
cd "$(dirname "$0")"

[ -f pet ] || { echo "erro: compile antes: swiftc Sources/*.swift -o pet"; exit 1; }

APP="dist/Craby.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Gerando ícone"
TMP=$(mktemp -d)
swiftc Sources/Sprites.swift tools/main.swift -o "$TMP/render"
"$TMP/render" icon "$TMP/icon.png" >/dev/null
mkdir -p "$TMP/icon.iconset"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$TMP/icon.png" --out "$TMP/icon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z "$d" "$d" "$TMP/icon.png" --out "$TMP/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/icon.iconset" -o "$TMP/crab.icns"

echo "==> Montando $APP"
cp pet "$APP/Contents/MacOS/pet"
cp ask.sh notify.sh setup.sh bin/craby "$APP/Contents/Resources/"
chmod +x "$APP/Contents/Resources/ask.sh" "$APP/Contents/Resources/notify.sh" \
  "$APP/Contents/Resources/setup.sh" "$APP/Contents/Resources/craby"
cp "$TMP/crab.icns" "$APP/Contents/Resources/crab.icns"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.crab-companion.pet</string>
    <key>CFBundleName</key><string>Craby</string>
    <key>CFBundleExecutable</key><string>pet</string>
    <key>CFBundleIconFile</key><string>crab</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.6.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

ditto -c -k --keepParent "$APP" dist/Craby.app.zip
echo "==> dist/Craby.app e dist/Craby.app.zip prontos"
