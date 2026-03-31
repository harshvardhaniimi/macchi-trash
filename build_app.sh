#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/MacchiTrash.app"
BIN_SRC="$ROOT_DIR/.build/release/macchi-trash"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_SRC" "$APP_DIR/Contents/MacOS/macchi-trash"
chmod +x "$APP_DIR/Contents/MacOS/macchi-trash"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>MacchiTrash</string>
  <key>CFBundleDisplayName</key>
  <string>Macchi Trash</string>
  <key>CFBundleExecutable</key>
  <string>macchi-trash</string>
  <key>CFBundleIdentifier</key>
  <string>com.harshvardhan.macchitrash</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
echo "Built app bundle: $APP_DIR"
