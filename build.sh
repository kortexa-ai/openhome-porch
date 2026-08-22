#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Porch"
APP_BUNDLE="${APP_NAME}.app"
BUILD_MODE="release"
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
rm -rf "${APP_BUNDLE:?}"
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
        bun run build
    )
else
    if [ "$SKIP_WINDOW" = true ]; then
        echo "Skipping Window build (--skip-window)"
    fi
fi

# Embed Window — extract flat .app from stable tarball
WINDOW_TAR=$(find Window/artifacts -name "*-Window*.app.tar.zst" 2>/dev/null | head -1)
if [ -n "$WINDOW_TAR" ]; then
    echo "Extracting Window from $WINDOW_TAR..."
    EXTRACT_DIR=$(mktemp -d)
    zstd -d -o "$EXTRACT_DIR/Window.tar" "$WINDOW_TAR"
    tar xf "$EXTRACT_DIR/Window.tar" -C "${APP_BUNDLE}/Contents/Resources/"
    rm -rf "${EXTRACT_DIR:?}"
    echo "Embedded Window.app"
fi

# Code sign
if [ "$BUILD_MODE" = "debug" ]; then
    echo "Ad-hoc signing (debug)..."
    codesign --force --deep --sign - --entitlements PorchApp/PorchApp.entitlements "${APP_BUNDLE}"
else
    SIGN_ID="Developer ID Application: Franci Penov (C49792BN94)"
    echo "Signing with: ${SIGN_ID}..."

    # Sign embedded Window.app (inside-out: dylibs, then binaries, then the .app)
    EMBEDDED_WINDOW=$(find "${APP_BUNDLE}/Contents/Resources" -name "Window*.app" -maxdepth 1 -type d 2>/dev/null | head -1)
    if [ -n "$EMBEDDED_WINDOW" ]; then
        echo "Signing embedded Window..."
        # Sign every Mach-O payload, then its containing frameworks and app.
        find "$EMBEDDED_WINDOW" -type f | while read f; do
            if file "$f" | grep -q "Mach-O"; then
                codesign --force --sign "${SIGN_ID}" --options runtime --timestamp "$f"
            fi
        done
        find "$EMBEDDED_WINDOW" -name "*.framework" -type d | while read f; do
            codesign --force --sign "${SIGN_ID}" --options runtime --timestamp "$f"
        done
        # Sign the Window.app bundle itself
        codesign --force --sign "${SIGN_ID}" --options runtime --timestamp "$EMBEDDED_WINDOW"
    fi

    # Sign the outer Porch app (NOT --deep, Window already signed)
    codesign --force --sign "${SIGN_ID}" --entitlements PorchApp/PorchApp.entitlements --options runtime --timestamp "${APP_BUNDLE}"

    echo "Notarizing..."
    ditto -c -k --keepParent "${APP_BUNDLE}" "${APP_BUNDLE}.zip"
    NOTARY_RESULT=$(xcrun notarytool submit "${APP_BUNDLE}.zip" \
        --keychain-profile "notarytool" --wait --output-format json)
    echo "${NOTARY_RESULT}"
    NOTARY_STATUS=$(echo "${NOTARY_RESULT}" | plutil -extract status raw -o - -)
    if [ "${NOTARY_STATUS}" = "Accepted" ]; then
        xcrun stapler staple "${APP_BUNDLE}"
        echo "Notarization successful"
    else
        echo "Notarization failed with status: ${NOTARY_STATUS}" >&2
        exit 1
    fi
    rm -f "${APP_BUNDLE}.zip"
fi

# Remove quarantine to prevent app translocation on first launch
xattr -dr com.apple.quarantine "${APP_BUNDLE}" 2>/dev/null || true

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Install: cp -r ${APP_BUNDLE} /Applications/"
