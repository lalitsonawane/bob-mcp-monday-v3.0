#!/usr/bin/env bash
# Launch official monday Platform MCP with token from macOS Keychain (or env).
# Never commit tokens. Keychain service name: monday-api-token
set -euo pipefail

KEYCHAIN_SERVICE="${MONDAY_KEYCHAIN_SERVICE:-monday-api-token}"

if [[ -z "${MONDAY_TOKEN:-}" ]]; then
  if TOKEN="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)" && [[ -n "$TOKEN" ]]; then
    export MONDAY_TOKEN="$TOKEN"
  elif [[ -f "${HOME}/.bob/monday.env" ]]; then
    # Optional local fallback (chmod 600). Format: MONDAY_TOKEN=...
    # shellcheck disable=SC1091
    set -a
    source "${HOME}/.bob/monday.env"
    set +a
  fi
fi

if [[ -z "${MONDAY_TOKEN:-}" ]]; then
  echo "monday-mcp: MONDAY_TOKEN is not set." >&2
  echo "Create a personal API token (monday avatar → Developers → My access tokens)," >&2
  echo "then store it:" >&2
  echo "  security add-generic-password -U -a \"\$USER\" -s ${KEYCHAIN_SERVICE} -w 'YOUR_TOKEN'" >&2
  echo "Or export MONDAY_TOKEN / put it in ~/.bob/monday.env (chmod 600)." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_BIN="$ROOT/node_modules/@mondaydotcomorg/monday-api-mcp/dist/index.js"

if [[ -x "$LOCAL_BIN" || -f "$LOCAL_BIN" ]]; then
  exec node "$LOCAL_BIN" "$@"
fi

# Fallback if deps are not installed locally
exec npx -y @mondaydotcomorg/monday-api-mcp@3.3.0 "$@"
