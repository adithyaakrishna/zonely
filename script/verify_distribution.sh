#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
REQUIRE_NOTARIZATION="${REQUIRE_NOTARIZATION:-0}"

APP_PATH="$OUTPUT_DIR/Zonely.app"
DMG_PATH="$OUTPUT_DIR/Zonely-$VERSION-macos-universal.dmg"
ZIP_PATH="$OUTPUT_DIR/Zonely-$VERSION-macos-universal.zip"

for path in "$APP_PATH" "$DMG_PATH" "$ZIP_PATH" "$DMG_PATH.sha256" "$ZIP_PATH.sha256"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing distribution artifact: $path" >&2
    exit 2
  fi
done

plutil -lint "$APP_PATH/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/MeetingFinder")"
if [[ "$ARCHITECTURES" != *"arm64"* || "$ARCHITECTURES" != *"x86_64"* ]]; then
  echo "Expected a universal binary, found: $ARCHITECTURES" >&2
  exit 1
fi

hdiutil verify "$DMG_PATH"
(
  cd "$OUTPUT_DIR"
  shasum -a 256 -c "$(basename "$DMG_PATH").sha256"
  shasum -a 256 -c "$(basename "$ZIP_PATH").sha256"
)

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zonely-verify.XXXXXX")"
cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" -quiet
test -d "$MOUNT_DIR/Zonely.app"
test -L "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR" -quiet
rmdir "$MOUNT_DIR"
trap - EXIT

if [[ "$REQUIRE_NOTARIZATION" == "1" ]]; then
  SIGNING_DETAILS="$(codesign -dvvv "$APP_PATH" 2>&1)"
  grep -q "Authority=Developer ID Application" <<<"$SIGNING_DETAILS"
  grep -q "flags=.*runtime" <<<"$SIGNING_DETAILS"
  codesign --verify --verbose=2 "$DMG_PATH"
  xcrun stapler validate "$APP_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type execute --verbose=4 "$APP_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

echo "Distribution verification passed for Zonely $VERSION ($ARCHITECTURES)"
