#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
APP_PATH="$ROOT_DIR/.build/OpenRec-dev.app"

OPENREC_DEV_NO_OPEN=1 "$ROOT_DIR/scripts/launch-dev-app.sh" >/tmp/openrec-launch-dev-app-test.log

if ! /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" \
    | grep -qx 'dev.freecodetiger.OpenRec'; then
  echo "Expected dev app bundle identifier to be dev.freecodetiger.OpenRec" >&2
  exit 1
fi

if ! codesign -dr - "$APP_PATH" 2>&1 \
    | grep -qx 'designated => identifier "dev.freecodetiger.OpenRec"'; then
  echo "Expected dev app designated requirement to use stable bundle identifier" >&2
  exit 1
fi

rm -f /tmp/openrec-launch-dev-app-test.log
echo "launch-dev-app.sh test passed"
