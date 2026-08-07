#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  ./script/release.sh github <version> [--dry-run]
  ./script/release.sh app-store <version> [--dry-run]

Examples:
  ./script/release.sh github 1.0.0 --dry-run
  ./script/release.sh github 1.0.0
  ./script/release.sh app-store 1.0.0 --dry-run
  ./script/release.sh app-store 1.0.0

Run ./script/setup_release_credentials.sh before the first real release.
USAGE
}

case "${1:-}" in
  -h|--help|help|"")
    usage
    exit 0
    ;;
  github)
    shift
    exec "$ROOT_DIR/script/release_github.sh" "$@"
    ;;
  app-store)
    shift
    exec "$ROOT_DIR/script/release_app_store.sh" "$@"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
