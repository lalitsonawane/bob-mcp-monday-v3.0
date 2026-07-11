#!/usr/bin/env bash
# Store MONDAY_TOKEN in macOS Keychain for scripts/monday-mcp.sh
# Usage:
#   ./scripts/store-monday-token.sh              # prompts securely
#   MONDAY_TOKEN=... ./scripts/store-monday-token.sh
#   ./scripts/store-monday-token.sh /path/to/.env
set -euo pipefail

KEYCHAIN_SERVICE="${MONDAY_KEYCHAIN_SERVICE:-monday-api-token}"
TOKEN="${MONDAY_TOKEN:-}"

load_from_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  # Prefer MONDAY_TOKEN, then common aliases — never echo values
  local line
  for key in MONDAY_TOKEN MONDAY_API_TOKEN MONDAY_API_KEY; do
    line="$(grep -E "^[[:space:]]*${key}=" "$file" | tail -n1 || true)"
    if [[ -n "$line" ]]; then
      TOKEN="${line#*=}"
      TOKEN="${TOKEN%\"}"
      TOKEN="${TOKEN#\"}"
      TOKEN="${TOKEN%\'}"
      TOKEN="${TOKEN#\'}"
      TOKEN="$(echo -n "$TOKEN" | tr -d '\r\n')"
      if [[ -n "$TOKEN" && "$TOKEN" != your_monday_* && "$TOKEN" != *placeholder* && "$TOKEN" != *here ]]; then
        return 0
      fi
      TOKEN=""
    fi
  done
  return 1
}

if [[ -z "$TOKEN" && "${1:-}" != "" ]]; then
  load_from_env_file "$1" || true
fi

if [[ -z "$TOKEN" ]]; then
  for candidate in \
    "${HOME}/.bob/monday.env" \
    "$(cd "$(dirname "$0")/.." && pwd)/.env" \
    "/Users/lalit/Developments/bob-connects-monday/.env" \
    "/Users/lalit/Developments/bob-mscp-monday-v2.0/.env"
  do
    if load_from_env_file "$candidate" 2>/dev/null; then
      echo "Loaded token from env file (path redacted)."
      break
    fi
  done
fi

if [[ -z "$TOKEN" ]]; then
  if [[ -t 0 ]]; then
    echo "Paste your monday personal API token (input hidden), then Enter:"
    read -rs TOKEN
    echo
  fi
fi

if [[ -z "$TOKEN" ]]; then
  echo "No token provided. Create one: monday avatar → Developers → My access tokens" >&2
  echo "Then re-run: MONDAY_TOKEN='...' $0" >&2
  exit 1
fi

security add-generic-password -U -a "${USER}" -s "$KEYCHAIN_SERVICE" -w "$TOKEN" >/dev/null
# Also write chmod-600 fallback for Bob processes that may not unlock Keychain
mkdir -p "${HOME}/.bob"
umask 077
printf 'MONDAY_TOKEN=%s\n' "$TOKEN" > "${HOME}/.bob/monday.env"
chmod 600 "${HOME}/.bob/monday.env"

echo "Stored monday token in Keychain service '${KEYCHAIN_SERVICE}' and ~/.bob/monday.env (600)."
echo "Token length: ${#TOKEN} chars (value not shown)."
