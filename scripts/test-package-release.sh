#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TAG_NAME="script-test"
ZIP_PATH="$DIST_DIR/OpenRec-$TAG_NAME.zip"

rm -rf "$DIST_DIR"

GITHUB_REF_NAME="$TAG_NAME" "$ROOT_DIR/scripts/package-release.sh" >/tmp/openrec-package-release-test.log

test -f "$ZIP_PATH"

/usr/bin/zipinfo -1 "$ZIP_PATH" | grep -qx "OpenRec-$TAG_NAME/Package.swift"
/usr/bin/zipinfo -1 "$ZIP_PATH" | grep -qx "OpenRec-$TAG_NAME/README.md"
/usr/bin/zipinfo -1 "$ZIP_PATH" | grep -qx "OpenRec-$TAG_NAME/Sources/OpenRecApp/OpenRecApplication.swift"
if /usr/bin/zipinfo -1 "$ZIP_PATH" | grep -q "^OpenRec-$TAG_NAME/dist/"; then
    echo "release ZIP must not include dist/" >&2
    exit 1
fi

rm -rf "$DIST_DIR"
rm -f /tmp/openrec-package-release-test.log

echo "package-release.sh test passed"
