#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
DIST_DIR="$ROOT_DIR/dist"
TAG_NAME="app-bundle-test"
TEST_BUNDLE_ID="com.example.OpenRec.PackageTest"
TEST_VERSION="1.2.3"
APP_PATH="$DIST_DIR/OpenRec.app"
PLIST_PATH="$APP_PATH/Contents/Info.plist"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/OpenRecApp"

rm -rf "$DIST_DIR"

GITHUB_REF_NAME="$TAG_NAME" \
OPENREC_BUNDLE_ID="$TEST_BUNDLE_ID" \
OPENREC_VERSION="$TEST_VERSION" \
OPENREC_SKIP_CODESIGN=1 \
"$ROOT_DIR/scripts/package-release.sh" >/tmp/openrec-package-app-test.log

test -d "$APP_PATH"
test -f "$PLIST_PATH"
test -x "$EXECUTABLE_PATH"
test -f "$DIST_DIR/OpenRec-$TEST_VERSION.zip"
test -f "$DIST_DIR/OpenRec-$TEST_VERSION-macos.zip"
test -f "$DIST_DIR/OpenRec-$TEST_VERSION-macos.zip.sha256"

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST_PATH"
}

test "$(plist_value CFBundleName)" = "OpenRec"
test "$(plist_value CFBundleDisplayName)" = "OpenRec"
test "$(plist_value CFBundleIdentifier)" = "$TEST_BUNDLE_ID"
test "$(plist_value CFBundleVersion)" = "$TEST_VERSION"
test "$(plist_value CFBundleShortVersionString)" = "$TEST_VERSION"
test "$(plist_value CFBundleExecutable)" = "OpenRecApp"
test "$(plist_value CFBundlePackageType)" = "APPL"
test "$(plist_value LSMinimumSystemVersion)" = "14.0"
test "$(plist_value NSMicrophoneUsageDescription)" = "OpenRec records microphone audio when selected for local screen recordings."
test "$(plist_value LSUIElement)" = "true"

rm -rf "$DIST_DIR"
rm -f /tmp/openrec-package-app-test.log

echo "package app bundle test passed"
