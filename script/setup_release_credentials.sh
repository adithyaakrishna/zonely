#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_ROOT_DIR="$ROOT_DIR"
# shellcheck source=script/lib/release_common.sh
source "$ROOT_DIR/script/lib/release_common.sh"

usage() {
  cat <<'USAGE'
Usage: ./script/setup_release_credentials.sh [github|app-store|all]

This stores notarization credentials in macOS Keychain and writes only
non-secret release configuration to the ignored .env file.
USAGE
}

upsert_env_value() {
  local key="$1"
  local value="$2"
  local env_file="$ROOT_DIR/.env"
  local temp_file

  temp_file="$(mktemp "${TMPDIR:-/tmp}/zonely-env.XXXXXX")"
  if [[ -f "$env_file" ]]; then
    awk -F= -v key="$key" '$1 != key { print }' "$env_file" >"$temp_file"
  fi
  printf '%s=%s\n' "$key" "$value" >>"$temp_file"
  mv "$temp_file" "$env_file"
  chmod 600 "$env_file"
}

prompt_team_id() {
  local current_team_id="${ZONELY_TEAM_ID:-}"
  local entered_team_id

  if [[ -n "$current_team_id" ]]; then
    printf '%s' "$current_team_id"
    return
  fi

  read -r -p "Apple Developer Team ID (10 characters): " entered_team_id
  [[ "$entered_team_id" =~ ^[A-Z0-9]{10}$ ]] || release_die "Invalid Apple Team ID."
  printf '%s' "$entered_team_id"
}

setup_github_release() {
  local apple_id team_id profile identity

  require_command gh
  require_command security
  require_command xcrun

  release_log "Configuring GitHub CLI"
  if ! gh auth status >/dev/null 2>&1; then
    gh auth login --hostname github.com --git-protocol ssh --web
  fi

  identity="${ZONELY_DEVELOPER_ID_IDENTITY:-$(find_signing_identity "Developer ID Application")}"
  if [[ -z "$identity" ]]; then
    cat >&2 <<'MESSAGE'
No Developer ID Application identity was found.

Create it in Xcode > Settings > Accounts > Manage Certificates,
then choose + > Developer ID Application and run this setup again.
MESSAGE
    exit 2
  fi
  printf 'Using signing identity: %s\n' "$identity"

  read -r -p "Apple Account email used for notarization: " apple_id
  [[ -n "$apple_id" ]] || release_die "Apple Account email is required."
  team_id="$(prompt_team_id)"
  profile="${ZONELY_NOTARY_PROFILE:-Zonely-Notary}"

  release_log "Saving notarization credentials as Keychain profile $profile"
  xcrun notarytool store-credentials "$profile" \
    --apple-id "$apple_id" \
    --team-id "$team_id"

  upsert_env_value ZONELY_TEAM_ID "$team_id"
  upsert_env_value ZONELY_NOTARY_PROFILE "$profile"
  upsert_env_value ZONELY_GITHUB_REMOTE "${ZONELY_GITHUB_REMOTE:-origin}"
  upsert_env_value ZONELY_DEVELOPER_ID_IDENTITY "$identity"
}

setup_app_store_release() {
  local team_id
  require_command xcodebuild
  team_id="$(prompt_team_id)"
  upsert_env_value ZONELY_TEAM_ID "$team_id"

  cat <<MESSAGE

Mac App Store configuration saved for Team ID $team_id.

One-time Xcode step:
  1. Open Xcode > Settings > Accounts.
  2. Add the Apple Account that belongs to Team $team_id.
  3. Confirm the app ID com.adikris.Zonely exists in your developer account.
  4. Confirm a matching macOS app record exists in App Store Connect.

The release script uses Xcode automatic signing and provisioning updates.
MESSAGE
}

require_macos
load_release_env

case "${1:-all}" in
  -h|--help|help)
    usage
    exit 0
    ;;
  github)
    setup_github_release
    ;;
  app-store)
    setup_app_store_release
    ;;
  all)
    setup_github_release
    load_release_env
    setup_app_store_release
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

release_log "Release credentials setup is complete"
