#!/usr/bin/env bash
# MacRMB release pipeline: build (Release) → notarize app → DMG → notarize
# DMG → Sparkle zip + appcast.xml → GitHub release.
#
# One-time setup for notarization credentials (interactive, password not
# stored in shell history):
#   xcrun notarytool store-credentials "macrmb-notary"
#
# Usage:
#   ./release.sh                 # tag from MARKETING_VERSION (e.g. v1.1.0)
#   TAG=v1.2.0 ./release.sh      # explicit tag
set -euo pipefail
cd "$(dirname "$0")"

REPO="ikoshura/MacRMB"
VERSION="$(grep 'MARKETING_VERSION:' project.yml | head -1 | awk '{print $2}')"
TAG="${TAG:-v${VERSION}}"
NOTARY_PROFILE="${NOTARY_PROFILE:-macrmb-notary}"
SIGN_ID="Developer ID Application: Abrar Zharifan Syah (JSYLVAZ935)"
SPARKLE_BIN="${SPARKLE_BIN:-/Users/abrar/Developer/sparkle-tools/extract/bin}"   # generate_appcast + sign_update (Sparkle release tools)
APP="build/Build/Products/Release/MacRMB.app"
DMG="dist/MacRMB-${VERSION}.dmg"
ZIP="dist/MacRMB-${VERSION}.zip"

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "ERROR: notarization credentials '$NOTARY_PROFILE' not found in keychain."
  echo "Run once (interactive):  xcrun notarytool store-credentials \"$NOTARY_PROFILE\""
  exit 1
fi

echo "==> [1/8] Generate project"
xcodegen generate >/dev/null

echo "==> [2/8] Build Release"
xcodebuild -project MacRMB.xcodeproj -scheme MacRMB -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build build | tail -1
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> [3/8] Notarize app (zip → notarytool → staple)"
mkdir -p dist
RAWZIP="dist/MacRMB-${VERSION}-raw.zip"
rm -f "$RAWZIP" "$ZIP" "$DMG"
ditto -c -k --keepParent "$APP" "$RAWZIP"
xcrun notarytool submit "$RAWZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$RAWZIP"

echo "==> [4/8] Package DMG (app + /Applications symlink)"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "MacRMB" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo "==> [5/8] Sign + notarize + staple DMG"
codesign --sign "$SIGN_ID" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG" || true

echo "==> [6/8] Sparkle update zip (stapled app) + appcast.xml"
ditto -c -k --keepParent "$APP" "$ZIP"
"$SPARKLE_BIN/sign_update" "$ZIP" || true   # info only; generate_appcast signs itself
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/${REPO}/releases/download/${TAG}/" \
  dist

echo "==> [7/8] Create GitHub release ${TAG}"
gh release create "$TAG" "$DMG" "$ZIP" "dist/appcast.xml" \
  --repo "$REPO" \
  --title "MacRMB ${VERSION}" \
  --notes "$(printf 'MacRMB %s\n\n- Download **MacRMB-%s.dmg** and drag to /Applications.\n- Sparkle updates use appcast.xml from this release.\n' "$VERSION" "$VERSION")"

echo "==> [8/8] Done"
echo "Appcast feed: https://github.com/${REPO}/releases/latest/download/appcast.xml"