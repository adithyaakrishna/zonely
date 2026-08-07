#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_ROOT_DIR="$ROOT_DIR"
# shellcheck source=script/lib/release_common.sh
source "$ROOT_DIR/script/lib/release_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./script/release.sh github <version> [--dry-run]

Builds, signs, notarizes, verifies, tags, and publishes a GitHub release.
With --dry-run, builds and verifies ad-hoc signed artifacts without publishing.
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
      release_die "Unknown GitHub release option: $1"
      ;;
  esac
  shift
done

require_macos
load_release_env
validate_semver "$VERSION"
ensure_release_worktree "$DRY_RUN"

BUILD_NUMBER="${BUILD_NUMBER:-$(default_build_number)}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || release_die "BUILD_NUMBER must contain only digits."

require_command swift
require_command xcrun
require_command codesign
require_command hdiutil
run_project_checks

if [[ "$DRY_RUN" == "1" ]]; then
  release_log "Building unsigned GitHub release artifacts (dry run)"
  VERSION="$VERSION" \
  BUILD_NUMBER="$BUILD_NUMBER" \
  SIGNING_IDENTITY=- \
  NOTARIZE=0 \
    "$ROOT_DIR/script/build_distribution.sh"

  verify_bundle_metadata "$ROOT_DIR/dist/Zonely.app" "$VERSION" "$BUILD_NUMBER"

  VERSION="$VERSION" \
  REQUIRE_NOTARIZATION=0 \
    "$ROOT_DIR/script/verify_distribution.sh"

  release_log "GitHub release dry run completed; no tag or release was created"
  exit 0
fi

require_command gh
gh auth status >/dev/null 2>&1 || release_die "GitHub CLI is not authenticated. Run: gh auth login"

SIGNING_IDENTITY="${ZONELY_DEVELOPER_ID_IDENTITY:-$(find_signing_identity "Developer ID Application")}"
[[ -n "$SIGNING_IDENTITY" ]] \
  || release_die "No Developer ID Application certificate is installed. Run ./script/setup_release_credentials.sh github"

NOTARY_PROFILE="${ZONELY_NOTARY_PROFILE:-Zonely-Notary}"
release_log "Validating Apple notarization credentials"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null \
  || release_die "Notary profile '$NOTARY_PROFILE' is unavailable. Run ./script/setup_release_credentials.sh github"

REMOTE="${ZONELY_GITHUB_REMOTE:-origin}"
git -C "$ROOT_DIR" remote get-url "$REMOTE" >/dev/null 2>&1 \
  || release_die "Git remote not found: $REMOTE"

TAG="v$VERSION"
HEAD_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
REMOTE_TAG_COMMIT="$(git -C "$ROOT_DIR" ls-remote --tags "$REMOTE" "refs/tags/$TAG^{}" | awk 'NR == 1 { print $1 }')"
if [[ -z "$REMOTE_TAG_COMMIT" ]]; then
  REMOTE_TAG_COMMIT="$(git -C "$ROOT_DIR" ls-remote --tags "$REMOTE" "refs/tags/$TAG" | awk 'NR == 1 { print $1 }')"
fi
if [[ -n "$REMOTE_TAG_COMMIT" && "$REMOTE_TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
  release_die "Remote tag $TAG already points to another commit."
fi

if git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  TAG_COMMIT="$(git -C "$ROOT_DIR" rev-list -n 1 "$TAG")"
  [[ "$TAG_COMMIT" == "$HEAD_COMMIT" ]] \
    || release_die "Tag $TAG already points to another commit."
fi

release_log "Building signed and notarized GitHub release"
VERSION="$VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
SIGNING_IDENTITY="$SIGNING_IDENTITY" \
NOTARIZE=1 \
NOTARY_KEYCHAIN_PROFILE="$NOTARY_PROFILE" \
  "$ROOT_DIR/script/build_distribution.sh"

verify_bundle_metadata "$ROOT_DIR/dist/Zonely.app" "$VERSION" "$BUILD_NUMBER"

VERSION="$VERSION" \
REQUIRE_NOTARIZATION=1 \
  "$ROOT_DIR/script/verify_distribution.sh"

if ! git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  release_log "Creating annotated tag $TAG"
  git -C "$ROOT_DIR" tag -a "$TAG" -m "Zonely $TAG"
fi

if [[ -z "$REMOTE_TAG_COMMIT" ]]; then
  release_log "Pushing tag $TAG to $REMOTE"
  git -C "$ROOT_DIR" push "$REMOTE" "$TAG"
fi

ASSETS=(
  "$ROOT_DIR/dist/Zonely-$VERSION-macos-universal.dmg"
  "$ROOT_DIR/dist/Zonely-$VERSION-macos-universal.dmg.sha256"
  "$ROOT_DIR/dist/Zonely-$VERSION-macos-universal.zip"
  "$ROOT_DIR/dist/Zonely-$VERSION-macos-universal.zip.sha256"
)

RELEASE_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zonely-github-release.XXXXXX")"
cleanup() {
  rm -rf "$RELEASE_TEMP_DIR"
}
trap cleanup EXIT

REPOSITORY="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
GENERATED_NOTES="$RELEASE_TEMP_DIR/generated-notes.md"
RELEASE_NOTES="$RELEASE_TEMP_DIR/release-notes.md"
gh api \
  --method POST \
  "repos/$REPOSITORY/releases/generate-notes" \
  -f tag_name="$TAG" \
  -f target_commitish="$HEAD_COMMIT" \
  -f configuration_file_path=.github/release.yml \
  --jq .body >"$GENERATED_NOTES"

{
  printf '## Download\n\n'
  printf 'Download the signed and notarized universal DMG below, then drag **Zonely** to **Applications**. '
  printf 'SHA-256 checksum files are provided for both the DMG and ZIP archives.\n\n'
  cat "$GENERATED_NOTES"
} >"$RELEASE_NOTES"

release_log "Publishing GitHub release $TAG"
if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  RELEASE_CREATE_CHANNEL=(--latest)
  RELEASE_EDIT_CHANNEL=(--prerelease=false --latest)
else
  RELEASE_CREATE_CHANNEL=(--prerelease)
  RELEASE_EDIT_CHANNEL=(--prerelease=true)
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "${ASSETS[@]}" --clobber
  gh release edit "$TAG" \
    --title "Zonely $TAG" \
    --notes-file "$RELEASE_NOTES" \
    --draft=false \
    "${RELEASE_EDIT_CHANNEL[@]}"
else
  gh release create "$TAG" "${ASSETS[@]}" \
    --verify-tag \
    --title "Zonely $TAG" \
    --notes-file "$RELEASE_NOTES" \
    "${RELEASE_CREATE_CHANNEL[@]}"
fi

release_log "Published Zonely $TAG to GitHub"
