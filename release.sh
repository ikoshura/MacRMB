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

echo "==> [2.5/8] Re-sign all code (Developer ID + timestamp, strip debug entitlements)"
# Sparkle's SPM package ships nested helpers ad-hoc; Xcode's sign step also
# omitted timestamps and injected get-task-allow. Re-sign innermost → outer,
# preserving nested entitlements where they exist (never for the main app).
SIGN_SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"

# Apple's timestamp service is occasionally unavailable (it failed mid-run
# with "The timestamp service is not available") — retry with backoff
# instead of letting set -e kill the pipeline with no explanation.
sign_with_retry() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if codesign "$@"; then
      return 0
    fi
    echo "  codesign attempt ${attempt}/5 failed — retrying in 5s..." >&2
    sleep 5
  done
  echo "ERROR: codesign failed after 5 attempts" >&2
  exit 1
}

resign_nested() {
  local target="$1" ent
  ent="$(mktemp)"
  if codesign -d --entitlements :- "$target" >"$ent" 2>/dev/null \
     && plutil -lint "$ent" >/dev/null 2>&1; then
    sign_with_retry --force --timestamp --options runtime --entitlements "$ent" --sign "$SIGN_ID" "$target"
  else
    sign_with_retry --force --timestamp --options runtime --sign "$SIGN_ID" "$target"
  fi
  rm -f "$ent"
}

resign_nested "$SIGN_SPARKLE/XPCServices/Downloader.xpc"
resign_nested "$SIGN_SPARKLE/XPCServices/Installer.xpc"
resign_nested "$SIGN_SPARKLE/Autoupdate"
resign_nested "$SIGN_SPARKLE/Updater.app"
resign_nested "$SIGN_SPARKLE/Sparkle"
resign_nested "$APP/Contents/Frameworks/Sparkle.framework"
resign_nested "$APP/Contents/Frameworks/MacRMBKit.framework"
# Main app last — signed WITHOUT entitlements so get-task-allow is dropped.
sign_with_retry --force --timestamp --options runtime --sign "$SIGN_ID" "$APP"

echo "==> [2.6/8] Verify signing prerequisites for notarization"
# Capture output first, then pattern-match the string — avoids the whole
# errexit/pipefail/SIGPIPE-grep class of bugs that bit earlier iterations.
SIGN_INFO="$(codesign -dvvv "$APP" 2>&1 || true)"
ENT_INFO="$(codesign -d --entitlements - "$APP/Contents/MacOS/MacRMB" 2>/dev/null || true)"
case "$SIGN_INFO" in
  *"Timestamp="*) ;;
  *) echo "ERROR: app signature has no secure timestamp"; exit 1 ;;
esac
case "$ENT_INFO" in
  *"get-task-allow"*) echo "ERROR: get-task-allow still present in main executable"; exit 1 ;;
esac
for f in "$SIGN_SPARKLE/Updater.app" "$SIGN_SPARKLE/Autoupdate" "$SIGN_SPARKLE/Sparkle" \
         "$SIGN_SPARKLE/XPCServices/Downloader.xpc" "$SIGN_SPARKLE/XPCServices/Installer.xpc"; do
  NESTED_INFO="$(codesign -dvvv "$f" 2>&1 || true)"
  case "$NESTED_INFO" in
    *"Signature=adhoc"*) echo "ERROR: $f is still ad-hoc signed"; exit 1 ;;
  esac
done
echo "signing OK"

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
# generate_appcast refuses a directory holding two archives with the same
# bundle version (our DMG lives in dist/ too) — use a zip-only subfolder.
SPARKLE_DIR="dist/sparkle"
rm -rf "$SPARKLE_DIR"
mkdir -p "$SPARKLE_DIR"
cp "$ZIP" "$SPARKLE_DIR/"
"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "https://github.com/${REPO}/releases/download/${TAG}/" \
  "$SPARKLE_DIR"
# Some generate_appcast runs skip EdDSA signing — inject it if missing,
# otherwise Sparkle rejects the update client-side.
if ! grep -q 'edSignature' "$SPARKLE_DIR/appcast.xml"; then
  SIG_LINE=$("$SPARKLE_BIN/sign_update" "$ZIP" | sed 's/ length="[0-9]*"//')
  sed -i '' "s|<enclosure url|<enclosure ${SIG_LINE} url|" "$SPARKLE_DIR/appcast.xml"
fi
grep -q 'edSignature' "$SPARKLE_DIR/appcast.xml" || { echo "ERROR: appcast has no edSignature"; exit 1; }

echo "==> [7/8] Create GitHub release ${TAG}"
gh release create "$TAG" "$DMG" "$ZIP" "$SPARKLE_DIR/appcast.xml" \
  --repo "$REPO" \
  --title "MacRMB ${VERSION}" \
  --notes "$(printf 'MacRMB %s\n\n- Download **MacRMB-%s.dmg** and drag to /Applications.\n- Sparkle updates use appcast.xml from this release.\n' "$VERSION" "$VERSION")"

echo "==> [8/8] Done"
echo "Appcast feed: https://github.com/${REPO}/releases/latest/download/appcast.xml"