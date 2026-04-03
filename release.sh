#!/bin/bash
set -e
cd "$(dirname "$0")"

# Usage: ./release.sh v0.2.0

VERSION="${1:?Usage: ./release.sh vX.Y.Z}"

# Validate version format
if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format vX.Y.Z (e.g. v0.1.0)"
    exit 1
fi

SEMVER="${VERSION#v}"
echo "Releasing Porch ${VERSION}..."

# Update version in Porch Info.plist
sed -i '' "s|<string>[0-9]*\.[0-9]*\.[0-9]*</string><!-- CFBundleShortVersionString -->|<string>${SEMVER}</string><!-- CFBundleShortVersionString -->|" PorchApp/Info.plist 2>/dev/null || true
# Simpler: just replace the version string after CFBundleShortVersionString key
python3 -c "
import re
with open('PorchApp/Info.plist') as f: s = f.read()
s = re.sub(r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(</string>)', r'\g<1>${SEMVER}\2', s)
with open('PorchApp/Info.plist', 'w') as f: f.write(s)
print('Updated Porch version to ${SEMVER}')
"

# Update version in Window electrobun.config.ts
sed -i '' "s/version: \"[^\"]*\"/version: \"${SEMVER}\"/" Window/electrobun.config.ts
echo "Updated Window version to ${SEMVER}"

# Full build (release + notarized)
./build.sh

# Create release zip
ZIP="Porch-${VERSION}-macos-arm64.zip"
zip -r -q "$ZIP" Porch.app
echo "Created $ZIP ($(du -h "$ZIP" | cut -f1))"

# Tag and push
git add PorchApp/Info.plist Window/electrobun.config.ts
git commit -m "Release ${VERSION}" || true
git tag -f "$VERSION"
git push origin main --tags

# Create GitHub release
gh release create "$VERSION" "$ZIP" \
    --title "Porch ${VERSION}" \
    --generate-notes

rm -f "$ZIP"
echo ""
echo "Released: https://github.com/kortexa-ai/openhome-porch/releases/tag/${VERSION}"
