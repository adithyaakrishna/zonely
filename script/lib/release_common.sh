#!/usr/bin/env bash

if [[ -z "${RELEASE_ROOT_DIR:-}" ]]; then
  RELEASE_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

release_log() {
  printf '\n==> %s\n' "$*"
}

release_warn() {
  printf 'warning: %s\n' "$*" >&2
}

release_die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || release_die "Required command not found: $command_name"
}

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || release_die "Zonely releases must run on macOS."
}

load_release_env() {
  local env_file="$RELEASE_ROOT_DIR/.env"
  local line key value

  [[ -f "$env_file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *=* ]] || release_die "Invalid line in $env_file: $line"

    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      ZONELY_TEAM_ID|ZONELY_NOTARY_PROFILE|ZONELY_GITHUB_REMOTE|ZONELY_DEVELOPER_ID_IDENTITY|APPLE_TEAM_ID|TEAM_ID)
        ;;
      DEVELOPER_ID_CERTIFICATE_BASE64|DEVELOPER_ID_CERTIFICATE_PASSWORD|APPLE_ID|APPLE_APP_SPECIFIC_PASSWORD)
        # Legacy runner secrets are deliberately not loaded into the local release environment.
        continue
        ;;
      *)
        release_warn "Ignoring unsupported .env key: $key"
        continue
        ;;
    esac

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value#\"}"
      value="${value%\"}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value#\'}"
      value="${value%\'}"
    fi

    printf -v "$key" '%s' "$value"
    export "$key"
  done <"$env_file"

  if [[ -z "${ZONELY_TEAM_ID:-}" ]]; then
    ZONELY_TEAM_ID="${APPLE_TEAM_ID:-${TEAM_ID:-}}"
    export ZONELY_TEAM_ID
  fi
}

validate_semver() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] \
    || release_die "Version must be semantic (for example 1.2.3), received: $version"
}

validate_store_version() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || release_die "Mac App Store versions must contain three numeric components (for example 1.2.3), received: $version"
}

default_build_number() {
  date -u +%Y%m%d%H%M%S
}

ensure_release_worktree() {
  local dry_run="$1"
  local status

  require_command git
  git -C "$RELEASE_ROOT_DIR" rev-parse --verify HEAD >/dev/null 2>&1 \
    || release_die "The repository has no releaseable HEAD commit."

  status="$(git -C "$RELEASE_ROOT_DIR" status --porcelain --untracked-files=all)"
  if [[ -n "$status" ]]; then
    if [[ "$dry_run" == "1" ]]; then
      release_warn "Dry run is continuing with a dirty worktree. Real releases require committed changes."
    else
      printf '%s\n' "$status" >&2
      release_die "Commit or stash all changes before publishing a release."
    fi
  fi
}

find_signing_identity() {
  local identity_pattern="$1"
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' -v pattern="$identity_pattern" 'index($2, pattern) { print $2; exit }'
}

run_project_checks() {
  release_log "Checking shell scripts"
  bash -n "$RELEASE_ROOT_DIR"/script/*.sh "$RELEASE_ROOT_DIR"/script/lib/*.sh

  release_log "Linting Swift sources"
  (
    cd "$RELEASE_ROOT_DIR"
    swift format lint --recursive --strict Sources Tests Package.swift
  )

  release_log "Running Swift tests"
  (
    cd "$RELEASE_ROOT_DIR"
    swift test --parallel
  )
}

verify_bundle_metadata() {
  local app_path="$1"
  local expected_version="$2"
  local expected_build="$3"
  local plist="$app_path/Contents/Info.plist"
  local bundle_id version build architectures

  [[ -d "$app_path" ]] || release_die "App bundle not found: $app_path"
  plutil -lint "$plist" >/dev/null

  bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$plist")"
  version="$(plutil -extract CFBundleShortVersionString raw -o - "$plist")"
  build="$(plutil -extract CFBundleVersion raw -o - "$plist")"
  [[ "$bundle_id" == "com.adikris.Zonely" ]] || release_die "Unexpected bundle ID: $bundle_id"
  [[ "$version" == "$expected_version" ]] || release_die "Unexpected app version: $version"
  [[ "$build" == "$expected_build" ]] || release_die "Unexpected app build number: $build"

  architectures="$(lipo -archs "$app_path/Contents/MacOS/MeetingFinder")"
  [[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]] \
    || release_die "Expected a universal app, found: $architectures"
}
