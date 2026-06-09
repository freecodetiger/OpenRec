#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
DIST_DIR="$ROOT_DIR/dist"
FIXTURE_DIR="$DIST_DIR/package-release-fixture"
FIXTURE_APP="$FIXTURE_DIR/OpenRec.app"
VERSION="1.2.3-test"
SOURCE_ZIP_PATH="$DIST_DIR/OpenRec-$VERSION.zip"
APP_ZIP_PATH="$DIST_DIR/OpenRec-$VERSION-macos.zip"
CHECKSUM_PATH="$APP_ZIP_PATH.sha256"
UNSIGNED_LOG="/tmp/openrec-package-release-unsigned.log"
DRY_RUN_LOG="/tmp/openrec-package-release-dry-run.log"
NOTARIZE_MISSING_IDENTITY_LOG="/tmp/openrec-package-release-notarize-missing-identity.log"

create_fixture_app() {
    rm -rf "$FIXTURE_DIR"
    mkdir -p "$FIXTURE_APP/Contents/MacOS" "$FIXTURE_APP/Contents/Resources"
    cat > "$FIXTURE_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>OpenRec</string>
  <key>CFBundleDisplayName</key><string>OpenRec</string>
  <key>CFBundleIdentifier</key><string>dev.freecodetiger.OpenRec</string>
  <key>CFBundleVersion</key><string>1.2.3-test</string>
  <key>CFBundleShortVersionString</key><string>1.2.3-test</string>
  <key>CFBundleExecutable</key><string>OpenRecApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict>
</plist>
PLIST
    printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_APP/Contents/MacOS/OpenRecApp"
    chmod +x "$FIXTURE_APP/Contents/MacOS/OpenRecApp"
    printf 'APPL????' > "$FIXTURE_APP/Contents/PkgInfo"
}

assert_contains() {
    file="$1"
    pattern="$2"
    if ! grep -Fq -- "$pattern" "$file"; then
        echo "Expected $file to contain: $pattern" >&2
        exit 1
    fi
}

assert_not_contains() {
    file="$1"
    pattern="$2"
    if grep -Fq -- "$pattern" "$file"; then
        echo "Expected $file not to contain: $pattern" >&2
        exit 1
    fi
}

rm -rf "$DIST_DIR"
create_fixture_app

OPENREC_APP_PATH="$FIXTURE_APP" \
OPENREC_RELEASE_VERSION="$VERSION" \
GITHUB_REF_NAME="$VERSION" \
"$ROOT_DIR/scripts/package-release.sh" >"$UNSIGNED_LOG"

test -f "$SOURCE_ZIP_PATH"
test -f "$APP_ZIP_PATH"
test -f "$CHECKSUM_PATH"

/usr/bin/zipinfo -1 "$SOURCE_ZIP_PATH" | grep -qx "OpenRec-$VERSION/Package.swift"
/usr/bin/zipinfo -1 "$SOURCE_ZIP_PATH" | grep -qx "OpenRec-$VERSION/README.md"
/usr/bin/zipinfo -1 "$SOURCE_ZIP_PATH" | grep -qx "OpenRec-$VERSION/Sources/OpenRecApp/OpenRecApplication.swift"
if /usr/bin/zipinfo -1 "$SOURCE_ZIP_PATH" | grep -q "^OpenRec-$VERSION/dist/"; then
    echo "source ZIP must not include dist/" >&2
    exit 1
fi

/usr/bin/zipinfo -1 "$APP_ZIP_PATH" | grep -qx "OpenRec.app/Contents/Info.plist"
/usr/bin/zipinfo -1 "$APP_ZIP_PATH" | grep -qx "OpenRec.app/Contents/MacOS/OpenRecApp"
if /usr/bin/zipinfo -1 "$APP_ZIP_PATH" | grep -Eq '(^__MACOSX/|(^|/)\._)'; then
    echo "macOS app ZIP must not include AppleDouble metadata" >&2
    exit 1
fi

expected_checksum="$(shasum -a 256 "$APP_ZIP_PATH" | awk '{print $1}')"
actual_checksum="$(awk '{print $1}' "$CHECKSUM_PATH")"
test "$expected_checksum" = "$actual_checksum"
assert_contains "$UNSIGNED_LOG" "Signing: unsigned"
assert_contains "$UNSIGNED_LOG" "Created $SOURCE_ZIP_PATH"
assert_contains "$UNSIGNED_LOG" "Created $APP_ZIP_PATH"
assert_contains "$UNSIGNED_LOG" "Created $CHECKSUM_PATH"

rm -f "$APP_ZIP_PATH" "$CHECKSUM_PATH"

OPENREC_APP_PATH="$FIXTURE_APP" \
OPENREC_RELEASE_VERSION="$VERSION" \
GITHUB_REF_NAME="$VERSION" \
OPENREC_SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID1234)" \
OPENREC_NOTARY_APPLE_ID="release@example.com" \
OPENREC_NOTARY_TEAM_ID="TEAMID1234" \
OPENREC_NOTARY_PASSWORD="app-password-secret" \
OPENREC_DRY_RUN=1 \
"$ROOT_DIR/scripts/package-release.sh" >"$DRY_RUN_LOG"

test -f "$APP_ZIP_PATH"
test -f "$CHECKSUM_PATH"
assert_contains "$DRY_RUN_LOG" "DRY RUN: codesign --force --deep --options runtime --timestamp --sign"
assert_contains "$DRY_RUN_LOG" "DRY RUN: xcrun notarytool submit"
assert_contains "$DRY_RUN_LOG" "--wait"
assert_contains "$DRY_RUN_LOG" "DRY RUN: xcrun stapler staple"
assert_not_contains "$DRY_RUN_LOG" "app-password-secret"

if OPENREC_APP_PATH="$FIXTURE_APP" \
    OPENREC_RELEASE_VERSION="$VERSION" \
    GITHUB_REF_NAME="$VERSION" \
    OPENREC_NOTARIZE=1 \
    "$ROOT_DIR/scripts/package-release.sh" >"$NOTARIZE_MISSING_IDENTITY_LOG" 2>&1; then
    echo "OPENREC_NOTARIZE=1 must fail without Developer ID signing identity" >&2
    exit 1
fi
assert_contains "$NOTARIZE_MISSING_IDENTITY_LOG" "OPENREC_NOTARIZE=1 requires OPENREC_SIGN_IDENTITY"

rm -rf "$DIST_DIR"
rm -f "$UNSIGNED_LOG" "$DRY_RUN_LOG" "$NOTARIZE_MISSING_IDENTITY_LOG"

echo "package-release.sh test passed"
