#!/bin/bash
set -e

APP_NAME="Porch"
APP_BUNDLE="${APP_NAME}.app"

if [ "$1" = "--debug" ]; then
    BUILD_DIR=".build/debug"
    echo "Building debug..."
    swift build
else
    BUILD_DIR=".build/release"
    echo "Building release..."
    swift build -c release
fi

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Info.plist — single source of truth
cp PorchApp/Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# Copy assets
if [ -f assets/appIcon.icns ]; then
    cp assets/appIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
if [ -f assets/appIcon.png ]; then
    cp assets/appIcon.png "${APP_BUNDLE}/Contents/Resources/appIcon.png"
fi

# Ad-hoc sign
codesign --force --deep --sign - --entitlements PorchApp/PorchApp.entitlements "${APP_BUNDLE}"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Install: cp -r ${APP_BUNDLE} /Applications/"
