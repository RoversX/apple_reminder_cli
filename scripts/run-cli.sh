#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if [[ "${1:-}" == "--" ]]; then
  shift
fi

"$ROOT/scripts/generate-version.sh"
swift package clean
swift run apple_reminder_cli "$@"
