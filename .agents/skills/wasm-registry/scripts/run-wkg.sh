#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_WKG="$SCRIPT_DIR/wkg"

if [[ -x "$LOCAL_WKG" ]]; then
  WKG_BIN="$LOCAL_WKG"
elif command -v wkg >/dev/null 2>&1; then
  WKG_BIN="$(command -v wkg)"
else
  echo "run-wkg.sh: no wkg binary found. Add one at $LOCAL_WKG or install wkg globally." >&2
  exit 1
fi

exec "$WKG_BIN" "$@"
