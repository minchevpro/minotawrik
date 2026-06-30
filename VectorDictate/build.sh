#!/bin/bash
# Builds Vector Dictate and packages it as a standalone .app bundle.
# Requires only the Xcode Command Line Tools (no full Xcode needed):
#   xcode-select --install
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="VectorDictate"
APP_DISPLAY_NAME="Vector Dictate"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_DISPLAY_NAME}.app"

echo "==> Building release binary..."
swift build -c release

echo "==> Assembling ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Done. '${APP_BUNDLE}' is ready in $(pwd)."
echo "Move it to /Applications, then launch it once from Finder (double-click)."
echo "On first launch macOS Gatekeeper may warn about an unidentified developer:"
echo "  right-click the app -> Open -> Open, to approve it once."
