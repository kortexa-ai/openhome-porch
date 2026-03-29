#!/bin/bash
set -e

APP_NAME="Porch"
BUNDLE_ID="ai.kortexa.porch"
APP_BUNDLE="${APP_NAME}.app"

if [ "$1" = "--debug" ]; then
    BUILD_CONFIG="debug"
    BUILD_DIR=".build/debug"
    echo "Building debug..."
    swift build
else
    BUILD_CONFIG="release"
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

# Copy .env if present
if [ -f .env ]; then
    cp .env "${APP_BUNDLE}/Contents/MacOS/.env"
fi

# Copy assets
if [ -f assets/appIcon.icns ]; then
    cp assets/appIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
if [ -f assets/appIcon.png ]; then
    cp assets/appIcon.png "${APP_BUNDLE}/Contents/Resources/appIcon.png"
fi

# Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Porch</string>
    <key>CFBundleDisplayName</key>
    <string>Porch</string>
    <key>CFBundleIdentifier</key>
    <string>ai.kortexa.porch</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleExecutable</key>
    <string>Porch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign with entitlements
codesign --force --deep --sign - --entitlements PorchApp/PorchApp.entitlements "${APP_BUNDLE}"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Install: cp -r ${APP_BUNDLE} /Applications/"
