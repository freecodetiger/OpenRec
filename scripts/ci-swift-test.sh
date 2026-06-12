#!/bin/sh
set -eu

# AVAssetWriter encoding integration tests pass on local macOS hardware but can
# hang indefinitely on GitHub's headless macOS runners. Keep them in the normal
# local `swift test` path, and use this CI-safe gate for hosted release jobs.
swift test --skip avAssetRecordingOutputWriter
