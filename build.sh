#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Porch"
APP_BUNDLE="${APP_NAME}.app"
SKIP_WINDOW=false

# Parse args
for arg in "$@"; do
    case "$arg" in
        --debug) BUILD_MODE="debug" ;;
        --skip-window) SKIP_WINDOW=true ;;
    esac
done

if [ "$BUILD_MODE" = "debug" ]; then
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

# Copy Porch binary
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

# Build Window (unless --skip-window)
if [ "$SKIP_WINDOW" = false ] && [ -d Window ]; then
    echo "Building Window..."
    (
        cd Window
        bun install --frozen-lockfile 2>/dev/null || bun install
        bun run build:canary
    )
else
    if [ "$SKIP_WINDOW" = true ]; then
        echo "Skipping Window build (--skip-window)"
    fi
fi

# Embed Window if a built .app exists
WINDOW_APP=$(find Window/build -name "Window*.app" -maxdepth 2 -type d 2>/dev/null | sort -r | head -1)
if [ -n "$WINDOW_APP" ]; then
    echo "Embedding $WINDOW_APP..."
    cp -a "$WINDOW_APP" "${APP_BUNDLE}/Contents/Resources/$(basename "$WINDOW_APP")"
fi

# Ad-hoc sign
codesign --force --deep --sign - --entitlements PorchApp/PorchApp.entitlements "${APP_BUNDLE}"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Install: cp -r ${APP_BUNDLE} /Applications/"
