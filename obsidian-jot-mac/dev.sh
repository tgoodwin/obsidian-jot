#!/usr/bin/env bash
# Build, kill any running ObsidianJot, and launch the fresh build.
# Usage: ./dev.sh
set -euo pipefail

cd "$(dirname "$0")"

# Always regenerate so newly added/removed sources are picked up.
xcodegen --quiet

CONFIG="${CONFIG:-Debug}"
DERIVED_DATA="${PWD}/.build/DerivedData"

BUILD_LOG="$(mktemp -t obsidianjot-build).log"
trap 'rm -f "$BUILD_LOG"' EXIT

set +e
xcodebuild \
    -project ObsidianJot.xcodeproj \
    -scheme ObsidianJot \
    -configuration "$CONFIG" \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA" \
    build > "$BUILD_LOG" 2>&1
BUILD_STATUS=$?
set -e

if [ $BUILD_STATUS -ne 0 ]; then
    echo "Build failed. Errors:" >&2
    grep -E "(error:|warning:|note:)" "$BUILD_LOG" | head -40 >&2
    echo >&2
    echo "Full log: $BUILD_LOG" >&2
    trap - EXIT
    exit $BUILD_STATUS
fi

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/ObsidianJot.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Build did not produce $APP_PATH" >&2
    exit 1
fi

pkill -x ObsidianJot 2>/dev/null || true
sleep 0.2
open "$APP_PATH"
echo "Launched $APP_PATH"
