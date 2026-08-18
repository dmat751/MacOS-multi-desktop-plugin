#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${REPO_ROOT}/build/Build/Products/Release/DesktopNumber.app"

cd "$REPO_ROOT"

echo "Building DesktopNumber (Release)..."
xcodebuild \
  -scheme DesktopNumber \
  -configuration Release \
  -derivedDataPath build \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build finished, but app not found at: ${APP_PATH}" >&2
  exit 1
fi

echo "Opening ${APP_PATH}"
open "$APP_PATH"
