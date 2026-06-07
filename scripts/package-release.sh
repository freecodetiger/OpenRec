#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TAG_NAME="${GITHUB_REF_NAME:-$(git -C "$ROOT_DIR" rev-parse --short HEAD)}"
ARCHIVE_DIR="$DIST_DIR/OpenRec-$TAG_NAME"
ZIP_PATH="$DIST_DIR/OpenRec-$TAG_NAME.zip"

rm -rf "$ARCHIVE_DIR" "$ZIP_PATH"
mkdir -p "$DIST_DIR" "$ARCHIVE_DIR"

git -C "$ROOT_DIR" archive --format=tar HEAD | tar -x -C "$ARCHIVE_DIR"

cd "$DIST_DIR"
/usr/bin/zip -qry "$(basename "$ZIP_PATH")" "$(basename "$ARCHIVE_DIR")"

echo "Created $ZIP_PATH"
