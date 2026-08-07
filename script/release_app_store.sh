#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_ROOT_DIR="$ROOT_DIR"
# shellcheck source=script/lib/release_common.sh
source "$ROOT_DIR/script/lib/release_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./script/release.sh app-store <version> [--dry-run]

Archives and uploads Zonely to Mac App Store Connect using Xcode automatic
signing. With --dry-run, creates and verifies an unsigned local archive only.
USAGE
}

VERSION="${1:-}"
[[ -n "$VERSION" ]] || {
  usage >&2
  exit 2
}
shift

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      release_die "Unknown App Store release option: $1"
      ;;
  esac
  shift
done

require_macos
load_release_env
validate_store_version "$VERSION"
ensure_release_worktree "$DRY_RUN"

BUILD_NUMBER="${BUILD_NUMBER:-$(default_build_number)}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || release_die "BUILD_NUMBER must contain only digits."

require_command xcodebuild
require_command plutil
require_command lipo
run_project_checks

ARCHIVE_ROOT="$ROOT_DIR/dist/app-store"
ARCHIVE_PATH="$ARCHIVE_ROOT/Zonely.xcarchive"
EXPORT_PATH="$ARCHIVE_ROOT/export"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Zonely.app"
mkdir -p "$ARCHIVE_ROOT"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

ARCHIVE_ARGS=(
  -quiet
  -project "$ROOT_DIR/Zonely.xcodeproj"
  -scheme Zonely
  -configuration Release
  -destination "generic/platform=macOS"
  -archivePath "$ARCHIVE_PATH"
  MARKETING_VERSION="$VERSION"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

if [[ "$DRY_RUN" == "1" ]]; then
  release_log "Creating unsigned Mac App Store archive (dry run)"
  xcodebuild "${ARCHIVE_ARGS[@]}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    archive
else
  TEAM_ID="${ZONELY_TEAM_ID:-}"
  [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] \
    || release_die "ZONELY_TEAM_ID is missing or invalid. Run ./script/setup_release_credentials.sh app-store"

  release_log "Creating signed Mac App Store archive"
  xcodebuild "${ARCHIVE_ARGS[@]}" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates \
    archive
fi

verify_bundle_metadata "$APP_PATH" "$VERSION" "$BUILD_NUMBER"
test -f "$APP_PATH/Contents/Resources/Zonely.icns"
test -f "$APP_PATH/Contents/Resources/ZonelyMenuBar.svg"

if [[ "$DRY_RUN" == "1" ]]; then
  sandbox_enabled="$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.app-sandbox" "$ROOT_DIR/Config/ZonelyAppStore.entitlements")"
  [[ "$sandbox_enabled" == "true" ]] || release_die "App Sandbox is not enabled in the App Store entitlements."
  release_log "Mac App Store dry run completed; no build was uploaded"
  exit 0
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -d --entitlements :- "$APP_PATH" 2>&1 \
  | grep -q "com.apple.security.app-sandbox" \
  || release_die "Signed App Store archive does not contain the App Sandbox entitlement."

EXPORT_OPTIONS="$(mktemp "${TMPDIR:-/tmp}/zonely-export-options.XXXXXX")"
cleanup() {
  rm -f "$EXPORT_OPTIONS"
}
trap cleanup EXIT

plutil -create xml1 "$EXPORT_OPTIONS"
plutil -insert method -string app-store-connect "$EXPORT_OPTIONS"
plutil -insert destination -string upload "$EXPORT_OPTIONS"
plutil -insert signingStyle -string automatic "$EXPORT_OPTIONS"
plutil -insert teamID -string "$TEAM_ID" "$EXPORT_OPTIONS"
plutil -insert distributionBundleIdentifier -string com.adikris.Zonely "$EXPORT_OPTIONS"
plutil -insert manageAppVersionAndBuildNumber -bool NO "$EXPORT_OPTIONS"
plutil -insert uploadSymbols -bool YES "$EXPORT_OPTIONS"

release_log "Validating and uploading Zonely $VERSION ($BUILD_NUMBER) to App Store Connect"
mkdir -p "$EXPORT_PATH"
xcodebuild -exportArchive \
  -quiet \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

release_log "Uploaded Zonely $VERSION ($BUILD_NUMBER) to App Store Connect"
printf '%s\n' "Complete screenshots, pricing, compliance, and Submit for Review in App Store Connect."
