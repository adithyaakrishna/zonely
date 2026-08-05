#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
NOTARIZE="${NOTARIZE:-0}"

APP_PATH="$OUTPUT_DIR/Zonely.app"
ZIP_PATH="$OUTPUT_DIR/Zonely-$VERSION-macos-universal.zip"
DMG_PATH="$OUTPUT_DIR/Zonely-$VERSION-macos-universal.dmg"

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "$SIGNING_IDENTITY" || "$SIGNING_IDENTITY" == "-" ]]; then
    echo "NOTARIZE=1 requires a Developer ID Application SIGNING_IDENTITY" >&2
    exit 2
  fi
  : "${APPLE_ID:?APPLE_ID is required when NOTARIZE=1}"
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required when NOTARIZE=1}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required when NOTARIZE=1}"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zonely-release.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

CONFIGURATION=release \
VERSION="$VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
OUTPUT_DIR="$OUTPUT_DIR" \
SIGNING_IDENTITY="$SIGNING_IDENTITY" \
UNIVERSAL=1 \
  "$ROOT_DIR/script/build_app.sh"

if [[ "$NOTARIZE" == "1" ]]; then
  PRE_NOTARY_ZIP="$TEMP_DIR/Zonely-pre-notary.zip"
  ditto -c -k --keepParent "$APP_PATH" "$PRE_NOTARY_ZIP"
  xcrun notarytool submit "$PRE_NOTARY_ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose=4 "$APP_PATH"
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

APP_PATH="$APP_PATH" \
DMG_PATH="$DMG_PATH" \
SIGNING_IDENTITY="$SIGNING_IDENTITY" \
  "$ROOT_DIR/script/create_dmg.sh"

if [[ "$NOTARIZE" == "1" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" >"$(basename "$ZIP_PATH").sha256"
  shasum -a 256 "$(basename "$DMG_PATH")" >"$(basename "$DMG_PATH").sha256"
)

echo "Created distribution artifacts:"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
