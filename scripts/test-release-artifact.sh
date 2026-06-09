#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
SMOKE_COMMAND="${OPENREC_RELEASE_SMOKE_COMMAND:-swift test}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/openrec-release-artifact.XXXXXX")"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [source-zip]" >&2
  exit 2
fi

if [ "$#" -eq 1 ]; then
  ARTIFACT_PATH="$1"
  if [ ! -f "$ARTIFACT_PATH" ] && [ "${ARTIFACT_PATH#/}" = "$ARTIFACT_PATH" ]; then
    ARTIFACT_PATH="$ROOT_DIR/$ARTIFACT_PATH"
  fi
  if [ ! -f "$ARTIFACT_PATH" ]; then
    echo "source ZIP not found: $1" >&2
    exit 1
  fi

  /usr/bin/unzip -q "$ARTIFACT_PATH" -d "$TMP_DIR"
  SOURCE_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [ -z "$SOURCE_DIR" ]; then
    echo "source ZIP did not expand to a source directory" >&2
    exit 1
  fi
else
  SOURCE_DIR="$TMP_DIR/OpenRec-HEAD"
  mkdir -p "$SOURCE_DIR"
  git -C "$ROOT_DIR" archive --format=tar HEAD | tar -x -C "$SOURCE_DIR"
fi

if [ ! -f "$SOURCE_DIR/Package.swift" ]; then
  echo "release artifact is missing Package.swift" >&2
  exit 1
fi

if [ -d "$SOURCE_DIR/.git" ]; then
  echo "release artifact smoke must run from an exported source tree, not a git checkout" >&2
  exit 1
fi

echo "Running release artifact smoke in $SOURCE_DIR: $SMOKE_COMMAND"
(
  cd "$SOURCE_DIR"
  sh -c "$SMOKE_COMMAND"
)

echo "release artifact smoke passed"
