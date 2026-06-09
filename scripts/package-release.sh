#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
DIST_DIR="$ROOT_DIR/dist"
EXECUTABLE_NAME="OpenRecApp"
BUNDLE_ID="${OPENREC_BUNDLE_ID:-com.freecodetiger.OpenRec}"
APP_PATH="$DIST_DIR/OpenRec.app"

version_ref() {
    if [ -n "${OPENREC_RELEASE_VERSION:-}" ]; then
        printf '%s\n' "$OPENREC_RELEASE_VERSION"
        return
    fi

    if [ -n "${OPENREC_VERSION:-}" ]; then
        printf '%s\n' "$OPENREC_VERSION"
        return
    fi

    if [ -n "${GITHUB_REF_NAME:-}" ]; then
        printf '%s\n' "$GITHUB_REF_NAME"
        return
    fi

    exact_tag="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)"
    if [ -n "$exact_tag" ]; then
        printf '%s\n' "$exact_tag"
        return
    fi

    nearest_tag="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
    if [ -n "$nearest_tag" ]; then
        printf '%s\n' "$nearest_tag"
        return
    fi

    git -C "$ROOT_DIR" rev-parse --short HEAD
}

xml_escape() {
    printf '%s' "$1" \
        | sed \
            -e 's/&/\&amp;/g' \
            -e 's/</\&lt;/g' \
            -e 's/>/\&gt;/g' \
            -e 's/"/\&quot;/g' \
            -e "s/'/\&apos;/g"
}

redacted_arg() {
    if [ -n "${OPENREC_NOTARY_PASSWORD:-}" ] && [ "$1" = "$OPENREC_NOTARY_PASSWORD" ]; then
        printf '<redacted>'
    else
        printf '%s' "$1"
    fi
}

run_cmd() {
    if [ "${OPENREC_DRY_RUN:-0}" = "1" ]; then
        printf 'DRY RUN:'
        for arg in "$@"; do
            printf ' %s' "$(redacted_arg "$arg")"
        done
        printf '\n'
        return 0
    fi

    "$@"
}

create_app_zip() {
    app="$1"
    zip_path="$2"
    rm -f "$zip_path"
    if command -v ditto >/dev/null 2>&1; then
        ditto -c -k --keepParent "$app" "$zip_path"
    else
        (
            cd "$(dirname "$app")"
            /usr/bin/zip -qry "$zip_path" "$(basename "$app")"
        )
    fi
}

create_checksum() {
    artifact_path="$1"
    shasum -a 256 "$artifact_path" > "$artifact_path.sha256"
    echo "Created $artifact_path.sha256"
}

create_source_zip() {
    archive_dir="$1"
    zip_path="$2"
    rm -rf "$archive_dir" "$zip_path"
    mkdir -p "$archive_dir"
    git -C "$ROOT_DIR" archive --format=tar HEAD | tar -x -C "$archive_dir"
    (
        cd "$DIST_DIR"
        /usr/bin/zip -qry "$(basename "$zip_path")" "$(basename "$archive_dir")"
    )
    echo "Created $zip_path"
    create_checksum "$zip_path"
}

build_release_app() {
    app_path="$1"
    version="$2"
    version_without_v="$(printf '%s' "$version" | sed 's/^[vV]//')"
    short_version="${OPENREC_SHORT_VERSION:-$(printf '%s' "$version_without_v" | sed -nE 's/^([0-9]+(\.[0-9]+){0,2}).*/\1/p')}"
    if [ -z "$short_version" ]; then
        short_version="0.0.0"
    fi
    build_version="${OPENREC_BUILD_VERSION:-$version_without_v}"

    swift build --package-path "$ROOT_DIR" --configuration release
    bin_dir="$(swift build --package-path "$ROOT_DIR" --configuration release --show-bin-path)"

    mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
    cp "$bin_dir/$EXECUTABLE_NAME" "$app_path/Contents/MacOS/$EXECUTABLE_NAME"

    cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>OpenRec</string>
  <key>CFBundleDisplayName</key><string>OpenRec</string>
  <key>CFBundleIdentifier</key><string>$(xml_escape "$BUNDLE_ID")</string>
  <key>CFBundleVersion</key><string>$(xml_escape "$build_version")</string>
  <key>CFBundleShortVersionString</key><string>$(xml_escape "$short_version")</string>
  <key>CFBundleExecutable</key><string>$EXECUTABLE_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSMicrophoneUsageDescription</key><string>OpenRec records microphone audio when selected for local screen recordings.</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

    printf 'APPL????' > "$app_path/Contents/PkgInfo"
}

stage_app() {
    rm -rf "$APP_PATH"
    if [ -n "${OPENREC_APP_PATH:-}" ]; then
        if [ ! -d "$OPENREC_APP_PATH" ]; then
            echo "OPENREC_APP_PATH does not exist or is not a directory: $OPENREC_APP_PATH" >&2
            exit 1
        fi
        if command -v ditto >/dev/null 2>&1; then
            ditto "$OPENREC_APP_PATH" "$APP_PATH"
        else
            cp -R "$OPENREC_APP_PATH" "$APP_PATH"
        fi
    else
        build_release_app "$APP_PATH" "$VERSION"
    fi
}

sign_app() {
    if [ "${OPENREC_SKIP_CODESIGN:-0}" = "1" ]; then
        echo "Signing: unsigned"
        return
    fi

    if [ -n "${OPENREC_SIGN_IDENTITY:-}" ]; then
        echo "Signing: Developer ID"
        set -- codesign --force --deep --options runtime --timestamp --sign "$OPENREC_SIGN_IDENTITY"
        if [ -n "${OPENREC_ENTITLEMENTS:-}" ]; then
            set -- "$@" --entitlements "$OPENREC_ENTITLEMENTS"
        fi
        run_cmd "$@" "$APP_PATH"
        return
    fi

    if [ "${OPENREC_AD_HOC_SIGN:-0}" = "1" ]; then
        echo "Signing: ad-hoc"
        run_cmd codesign --force --deep --sign - "$APP_PATH"
    else
        echo "Signing: unsigned"
    fi
}

notary_credentials_available() {
    if [ -n "${OPENREC_NOTARY_PROFILE:-}" ]; then
        return 0
    fi

    if [ -n "${OPENREC_NOTARY_APPLE_ID:-}" ] \
        && [ -n "${OPENREC_NOTARY_TEAM_ID:-}" ] \
        && [ -n "${OPENREC_NOTARY_PASSWORD:-}" ]; then
        return 0
    fi

    return 1
}

notarize_and_staple() {
    notary_zip_path="$1"

    if [ -z "${OPENREC_SIGN_IDENTITY:-}" ]; then
        echo "Notarization: skipped; Developer ID signing identity not configured"
        return
    fi

    if ! notary_credentials_available; then
        if [ "${OPENREC_NOTARIZE:-0}" = "1" ]; then
            echo "OPENREC_NOTARIZE=1 requires OPENREC_NOTARY_PROFILE or Apple ID credentials" >&2
            exit 1
        fi
        echo "Notarization: skipped; credentials not configured"
        return
    fi

    echo "Notarization: submit --wait"
    create_app_zip "$APP_PATH" "$notary_zip_path"

    if [ -n "${OPENREC_NOTARY_PROFILE:-}" ]; then
        run_cmd xcrun notarytool submit "$notary_zip_path" \
            --keychain-profile "$OPENREC_NOTARY_PROFILE" \
            --wait
    else
        run_cmd xcrun notarytool submit "$notary_zip_path" \
            --apple-id "$OPENREC_NOTARY_APPLE_ID" \
            --team-id "$OPENREC_NOTARY_TEAM_ID" \
            --password "$OPENREC_NOTARY_PASSWORD" \
            --wait
    fi

    echo "Staple: app"
    run_cmd xcrun stapler staple "$APP_PATH"
}

VERSION="$(version_ref)"
ARTIFACT_VERSION="$(printf '%s' "$VERSION" | tr '/ :' '---')"
SOURCE_ARCHIVE_DIR="$DIST_DIR/OpenRec-$ARTIFACT_VERSION"
SOURCE_ZIP_PATH="$DIST_DIR/OpenRec-$ARTIFACT_VERSION.zip"
MACOS_ZIP_PATH="$DIST_DIR/OpenRec-$ARTIFACT_VERSION-macos.zip"
NOTARY_ZIP_PATH="$DIST_DIR/OpenRec-$ARTIFACT_VERSION-notary.zip"

mkdir -p "$DIST_DIR"
rm -f "$MACOS_ZIP_PATH" "$MACOS_ZIP_PATH.sha256" "$NOTARY_ZIP_PATH"

if [ "${OPENREC_PACKAGE_SOURCE_ZIP:-1}" = "1" ]; then
    create_source_zip "$SOURCE_ARCHIVE_DIR" "$SOURCE_ZIP_PATH"
fi

stage_app
sign_app
notarize_and_staple "$NOTARY_ZIP_PATH"

create_app_zip "$APP_PATH" "$MACOS_ZIP_PATH"
rm -f "$NOTARY_ZIP_PATH"
echo "Created $MACOS_ZIP_PATH"
create_checksum "$MACOS_ZIP_PATH"
