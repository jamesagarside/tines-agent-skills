#!/usr/bin/env bash
#
# tines-api.sh — Tines API wrapper with credential resolution
#
# Handles credential resolution (env vars > ~/.tines/credentials > error)
# and provides a simple interface for API calls.
#
# Usage:
#   bash scripts/tines-api.sh GET /stories
#   bash scripts/tines-api.sh GET /stories?per_page=500
#   bash scripts/tines-api.sh GET /cases --paginate
#   bash scripts/tines-api.sh POST /stories/import @story.json
#   bash scripts/tines-api.sh PATCH /cases/123 '{"status": "closed"}'
#   bash scripts/tines-api.sh DELETE /cases/123
#   bash scripts/tines-api.sh profile                    # show active profile
#   bash scripts/tines-api.sh profiles                   # list all profiles
#   bash scripts/tines-api.sh switch <profile-name>      # switch active profile
#   bash scripts/tines-api.sh test                       # test connection
#
set -euo pipefail

# ─────────────────────────────────────────────
# Credential Resolution
# ─────────────────────────────────────────────

resolve_credentials() {
  # 1. Try env vars first
  TINES_TENANT_URL="${TINES_TENANT_URL:-}"
  TINES_API_TOKEN="${TINES_API_TOKEN:-}"

  # 2. Fall back to credentials file
  if [ -z "$TINES_TENANT_URL" ] || [ -z "$TINES_API_TOKEN" ]; then
    local creds_file="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"
    if [ -f "$creds_file" ]; then
      # Check file permissions
      local perms
      perms=$(stat -f "%Lp" "$creds_file" 2>/dev/null || stat -c "%a" "$creds_file" 2>/dev/null)
      if [ "$perms" != "600" ]; then
        echo "WARNING: $creds_file has permissions $perms (should be 600)" >&2
      fi

      # Resolve active profile: env var > current attribute > default
      local profile="${TINES_PROFILE:-}"
      if [ -z "$profile" ]; then
        profile=$(awk '/^current *= */{gsub(/^current *= */, ""); print; exit}' "$creds_file")
      fi
      profile="${profile:-default}"

      TINES_TENANT_URL="${TINES_TENANT_URL:-$(awk "/^\[${profile}\]/{found=1; next} /^\[/{found=0} found && /^tenant_url/{print \$3}" "$creds_file")}"
      TINES_API_TOKEN="${TINES_API_TOKEN:-$(awk "/^\[${profile}\]/{found=1; next} /^\[/{found=0} found && /^api_token/{print \$3}" "$creds_file")}"

      RESOLVED_PROFILE="$profile"
      RESOLVED_SOURCE="$creds_file"
    fi
  fi

  # 3. Validate
  if [ -z "$TINES_TENANT_URL" ] || [ -z "$TINES_API_TOKEN" ]; then
    echo "ERROR: Tines credentials not found." >&2
    echo "Set TINES_TENANT_URL and TINES_API_TOKEN env vars," >&2
    echo "or create ~/.tines/credentials (run: bash scripts/tines-api.sh configure)" >&2
    exit 1
  fi

  TINES_BASE_URL="${TINES_TENANT_URL%/}/api/v1"
}

# ─────────────────────────────────────────────
# API Call
# ─────────────────────────────────────────────

api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local url="${TINES_BASE_URL}${endpoint}"
  local args=(-s -f -H "x-user-token: ${TINES_API_TOKEN}")

  case "$method" in
    GET)
      ;;
    POST)
      args+=(-X POST -H "Content-Type: application/json")
      if [ -n "$data" ]; then
        if [[ "$data" == @* ]]; then
          args+=(-d "$data")
        else
          args+=(-d "$data")
        fi
      fi
      ;;
    PATCH)
      args+=(-X PATCH -H "Content-Type: application/json" -d "$data")
      ;;
    PUT)
      args+=(-X PUT -H "Content-Type: application/json" -d "$data")
      ;;
    DELETE)
      args+=(-X DELETE)
      ;;
    *)
      echo "ERROR: Unknown method: $method" >&2
      exit 1
      ;;
  esac

  curl "${args[@]}" "$url"
}

# ─────────────────────────────────────────────
# Paginated fetch
# ─────────────────────────────────────────────

paginate() {
  local endpoint="$1"
  local page=1
  local sep=""

  # Append per_page if not already in the endpoint
  if [[ "$endpoint" != *"per_page"* ]]; then
    if [[ "$endpoint" == *"?"* ]]; then
      endpoint="${endpoint}&per_page=500"
    else
      endpoint="${endpoint}?per_page=500"
    fi
  fi

  echo "["
  while true; do
    local page_endpoint
    if [[ "$endpoint" == *"?"* ]]; then
      page_endpoint="${endpoint}&page=${page}"
    else
      page_endpoint="${endpoint}?page=${page}"
    fi

    local response
    response=$(api_call GET "$page_endpoint")

    # Extract the data array (first array key in response)
    local items
    items=$(echo "$response" | jq -c 'to_entries | map(select(.value | type == "array")) | .[0].value // []' 2>/dev/null)

    if [ -z "$items" ] || [ "$items" = "[]" ] || [ "$items" = "null" ]; then
      break
    fi

    # Output items (without array brackets) separated by commas
    local count
    count=$(echo "$items" | jq 'length')
    if [ "$count" -gt 0 ]; then
      echo -n "$sep"
      echo "$items" | jq -c '.[]' | while IFS= read -r item; do
        echo -n "$sep$item"
        sep=","
      done
      sep=","
    fi

    # Check for next page
    local next
    next=$(echo "$response" | jq -r '.meta.next_page_number // empty' 2>/dev/null)
    if [ -z "$next" ]; then
      break
    fi
    page=$next
  done
  echo ""
  echo "]"
}

# ─────────────────────────────────────────────
# Profile Management
# ─────────────────────────────────────────────

show_profile() {
  local creds_file="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"
  if [ -n "${TINES_PROFILE:-}" ]; then
    echo "Active profile: $TINES_PROFILE (from env var)"
  elif [ -f "$creds_file" ]; then
    local current
    current=$(awk '/^current *= */{gsub(/^current *= */, ""); print; exit}' "$creds_file")
    echo "Active profile: ${current:-default} (from $creds_file)"
  else
    echo "Active profile: default (no credentials file found)"
  fi
}

list_profiles() {
  local creds_file="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"
  if [ -f "$creds_file" ]; then
    local current
    current=$(awk '/^current *= */{gsub(/^current *= */, ""); print; exit}' "$creds_file")
    current="${current:-default}"
    echo "Profiles in $creds_file:"
    { grep '^\[' "$creds_file" 2>/dev/null || true; } | tr -d '[]' | while IFS= read -r name; do
      [ -z "$name" ] && continue
      if [ "$name" = "$current" ]; then
        echo "  * $name (active)"
      else
        echo "    $name"
      fi
    done
  else
    echo "No credentials file found at $creds_file"
  fi
}

switch_profile() {
  local new_profile="$1"
  local creds_file="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"

  if [ ! -f "$creds_file" ]; then
    echo "ERROR: No credentials file at $creds_file" >&2
    exit 1
  fi

  # Verify profile exists
  if ! grep -q "^\[${new_profile}\]" "$creds_file"; then
    echo "ERROR: Profile '$new_profile' not found in $creds_file" >&2
    echo "Available profiles:" >&2
    { grep '^\[' "$creds_file" 2>/dev/null || true; } | tr -d '[]' | sed 's/^/  /' >&2
    exit 1
  fi

  # Update current line
  if grep -q '^current = ' "$creds_file"; then
    sed -i.bak "s/^current = .*/current = ${new_profile}/" "$creds_file" && rm -f "${creds_file}.bak"
  else
    sed -i.bak "1s/^/current = ${new_profile}\n\n/" "$creds_file" && rm -f "${creds_file}.bak"
  fi

  echo "Switched to profile: $new_profile"
}

test_connection() {
  resolve_credentials
  echo "Profile: ${RESOLVED_PROFILE:-env vars}"
  echo "Tenant:  $TINES_TENANT_URL"
  echo ""
  echo "Testing connection..."
  local response
  if response=$(api_call GET "/info" 2>/dev/null); then
    echo "$response" | jq '{tenant_name: .tenant_name, user_email: .user_email, plan: .plan}' 2>/dev/null || echo "$response"
    echo ""
    echo "Connection: OK"
  else
    echo "Connection: FAILED"
    echo "Check your credentials and tenant URL."
    exit 1
  fi
}

# ─────────────────────────────────────────────
# Usage
# ─────────────────────────────────────────────

usage() {
  cat <<'USAGE'
Usage: bash scripts/tines-api.sh <command> [args]

API Commands:
  GET <endpoint>                   GET request (e.g., /stories, /cases/123)
  GET <endpoint> --paginate        GET with automatic pagination
  POST <endpoint> <data|@file>     POST request with JSON body
  PATCH <endpoint> <data>          PATCH request with JSON body
  PUT <endpoint> <data>            PUT request with JSON body
  DELETE <endpoint>                DELETE request

Profile Commands:
  profile                          Show active profile
  profiles                         List all profiles
  switch <name>                    Switch active profile
  test                             Test API connection

Examples:
  bash scripts/tines-api.sh GET /stories?per_page=500 | jq '.stories[] | {id, name}'
  bash scripts/tines-api.sh GET /stories --paginate | jq '.[].name'
  bash scripts/tines-api.sh POST /stories/import @story.json | jq .
  bash scripts/tines-api.sh PATCH /cases/123 '{"status": "closed"}' | jq .
  bash scripts/tines-api.sh switch staging
  bash scripts/tines-api.sh test
USAGE
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

if [ $# -eq 0 ]; then
  usage
  exit 0
fi

case "$1" in
  profile)
    show_profile
    ;;
  profiles)
    list_profiles
    ;;
  switch)
    if [ $# -lt 2 ]; then
      echo "ERROR: Usage: bash scripts/tines-api.sh switch <profile-name>" >&2
      exit 1
    fi
    switch_profile "$2"
    ;;
  test)
    test_connection
    ;;
  GET|POST|PATCH|PUT|DELETE)
    resolve_credentials
    method="$1"
    endpoint="${2:-}"
    if [ -z "$endpoint" ]; then
      echo "ERROR: Endpoint required" >&2
      exit 1
    fi

    # Check for --paginate flag
    if [ "$method" = "GET" ] && { [ "${3:-}" = "--paginate" ] || [ "${3:-}" = "-p" ]; }; then
      paginate "$endpoint"
    else
      data="${3:-}"
      api_call "$method" "$endpoint" "$data"
    fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "ERROR: Unknown command: $1" >&2
    usage
    exit 1
    ;;
esac
