#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
APP_PATH="$ROOT_DIR/.build/OpenRec-dev.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/OpenRecApp"
BUNDLE_ID="dev.freecodetiger.OpenRec"

swift build --package-path "$ROOT_DIR"
BIN_DIR="$(swift build --package-path "$ROOT_DIR" --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_DIR/OpenRecApp" "$EXECUTABLE_PATH"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>OpenRec</string>
  <key>CFBundleDisplayName</key><string>OpenRec</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>0.1.0-dev</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleExecutable</key><string>OpenRecApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSMicrophoneUsageDescription</key><string>OpenRec records microphone audio when selected for local screen recordings.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"
codesign --force --deep --sign - \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" \
  "$APP_PATH"

if [ "${OPENREC_DEV_NO_OPEN:-0}" != "1" ]; then
  pkill -x OpenRecApp || true
  open -n "$APP_PATH"
  sleep 1
  pgrep -fl OpenRecApp || true
fi
