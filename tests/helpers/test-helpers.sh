#!/usr/bin/env bash
#
# Shared test helpers for Tines Agent Skills test suite.
# Source this file from test scripts: source "$(dirname "$0")/helpers/test-helpers.sh"
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0
WARN=0

# Test resource prefix for identification and orphan cleanup
TEST_PREFIX="__test_$(date +%s)__"

# Cleanup stack (LIFO order)
CLEANUP_STACK=()

# Dry run mode
DRY_RUN="${DRY_RUN:-false}"

# ─────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────

init_test_env() {
  local test_name="$1"

  if [[ -z "${TINES_TENANT_URL:-}" ]]; then
    echo -e "${RED}Error: TINES_TENANT_URL is not set${NC}"
    exit 1
  fi
  if [[ -z "${TINES_API_TOKEN:-}" ]]; then
    echo -e "${RED}Error: TINES_API_TOKEN is not set${NC}"
    exit 1
  fi

  TINES_BASE_URL="${TINES_TENANT_URL%/}/api/v1"
  AUTH_HEADER="x-user-token: $TINES_API_TOKEN"

  echo "=========================================="
  echo " Tines Agent Skills — $test_name"
  echo "=========================================="
  echo ""
  echo "Tenant: $TINES_TENANT_URL"
  echo "Prefix: $TEST_PREFIX"
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}Mode: DRY RUN (no API calls)${NC}"
  fi
  echo ""

  trap run_cleanup EXIT
}

# ─────────────────────────────────────────────
# Result functions
# ─────────────────────────────────────────────

pass() {
  echo -e "  ${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "  ${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "  ${YELLOW}SKIP${NC} $1"
  SKIP=$((SKIP + 1))
}

warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"
  WARN=$((WARN + 1))
}

section() {
  echo "$1"
  echo "${1//?/─}"
}

# ─────────────────────────────────────────────
# API helpers
# ─────────────────────────────────────────────

# Make an API call. Returns body + HTTP code on last line.
api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  if [[ "$DRY_RUN" == true && "$method" != "GET" ]]; then
    echo '{"id": 999999, "case_id": 999999, "name": "dry-run"}'
    echo "200"
    return 0
  fi

  local args=(-s -w "\n%{http_code}" -H "$AUTH_HEADER")

  case "$method" in
    GET)    ;;
    POST)   args+=(-X POST -H "Content-Type: application/json") ; [[ -n "$data" ]] && args+=(-d "$data") ;;
    PUT)    args+=(-X PUT -H "Content-Type: application/json" -d "$data") ;;
    PATCH)  args+=(-X PATCH -H "Content-Type: application/json" -d "$data") ;;
    DELETE) args+=(-X DELETE) ;;
    POST_NO_CT) args+=(-X POST) ; [[ -n "$data" ]] && args+=(-d "$data") ;;
  esac

  /usr/bin/curl "${args[@]}" "${TINES_BASE_URL}${endpoint}"
}

get_http_code() {
  echo "$1" | tail -1
}

get_body() {
  echo "$1" | sed '$d'
}

# Extract a JSON field value
json_field() {
  local body="$1"
  local expr="$2"
  echo "$body" | jq -r "$expr" 2>/dev/null
}

# ─────────────────────────────────────────────
# Assertion helpers
# ─────────────────────────────────────────────

# Assert HTTP status code
assert_http() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$test_name (HTTP $actual)"
  else
    fail "$test_name (expected HTTP $expected, got $actual)"
  fi
}

# Assert HTTP code is one of several valid codes
assert_http_one_of() {
  local test_name="$1"
  shift
  local actual="${!#}"  # last argument
  local codes=("${@:1:$#-1}")  # all but last

  for code in "${codes[@]}"; do
    if [[ "$actual" == "$code" ]]; then
      pass "$test_name (HTTP $actual)"
      return
    fi
  done
  fail "$test_name (expected one of [${codes[*]}], got $actual)"
}

# Assert JSON field exists and is not null
assert_json_exists() {
  local test_name="$1"
  local body="$2"
  local expr="$3"

  local val
  val=$(echo "$body" | jq -e "$expr" 2>/dev/null)
  if [[ $? -eq 0 && "$val" != "null" ]]; then
    pass "$test_name"
  else
    fail "$test_name (field $expr missing or null)"
  fi
}

# Assert JSON field equals expected value
assert_json_equals() {
  local test_name="$1"
  local body="$2"
  local expr="$3"
  local expected="$4"

  local actual
  actual=$(echo "$body" | jq -r "$expr" 2>/dev/null)
  if [[ "$actual" == "$expected" ]]; then
    pass "$test_name"
  else
    fail "$test_name (expected '$expected', got '$actual')"
  fi
}

# Assert JSON array has at least N items
assert_json_min_length() {
  local test_name="$1"
  local body="$2"
  local expr="$3"
  local min="$4"

  local len
  len=$(echo "$body" | jq "$expr | length" 2>/dev/null || echo "0")
  if [[ "$len" -ge "$min" ]]; then
    pass "$test_name ($len items)"
  else
    fail "$test_name (expected >= $min items, got $len)"
  fi
}

# Assert response body does NOT contain a string (for secret leakage)
assert_not_contains() {
  local test_name="$1"
  local body="$2"
  local forbidden="$3"

  if echo "$body" | grep -q "$forbidden"; then
    fail "$test_name (found forbidden string)"
  else
    pass "$test_name"
  fi
}

# ─────────────────────────────────────────────
# Cleanup helpers
# ─────────────────────────────────────────────

register_cleanup() {
  local type="$1"
  local id="$2"
  CLEANUP_STACK+=("${type}:${id}")
}

run_cleanup() {
  if [[ ${#CLEANUP_STACK[@]} -eq 0 ]]; then
    return
  fi

  echo ""
  echo -e "${BLUE}Cleaning up ${#CLEANUP_STACK[@]} test resources...${NC}"

  # LIFO order — delete children before parents
  for (( i=${#CLEANUP_STACK[@]}-1; i>=0; i-- )); do
    local entry="${CLEANUP_STACK[$i]}"
    local type="${entry%%:*}"
    local id="${entry#*:}"
    echo -e "  Deleting $type/$id..."
    /usr/bin/curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/${type}/${id}" > /dev/null 2>&1 || true
  done
  echo -e "${GREEN}Cleanup complete${NC}"
}

# Rate limit pause for write-heavy test groups
rate_limit_pause() {
  if [[ "$DRY_RUN" != true ]]; then
    sleep 0.5
  fi
}

# ─────────────────────────────────────────────
# Discovery helpers — find existing resources for testing
# ─────────────────────────────────────────────

discover_team_id() {
  local resp
  resp=$(api_call GET "/teams?per_page=1")
  local body
  body=$(get_body "$resp")
  json_field "$body" '.teams[0].id'
}

discover_story_id() {
  local resp
  resp=$(api_call GET "/stories?per_page=1")
  local body
  body=$(get_body "$resp")
  json_field "$body" '.stories[0].id'
}

discover_case_id() {
  local resp
  resp=$(api_call GET "/cases?per_page=1")
  local body
  body=$(get_body "$resp")
  json_field "$body" '.cases[0].case_id'
}

discover_agent_id() {
  local resp
  resp=$(api_call GET "/agents?per_page=1")
  local body
  body=$(get_body "$resp")
  json_field "$body" '.agents[0].id'
}

discover_credential_id() {
  local resp
  resp=$(api_call GET "/user_credentials?per_page=1")
  local body
  body=$(get_body "$resp")
  json_field "$body" '.user_credentials[0].id'
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

print_summary() {
  echo ""
  echo "=========================================="
  echo " Summary"
  echo "=========================================="
  echo ""
  echo -e "  ${GREEN}PASS${NC}: $PASS"
  echo -e "  ${RED}FAIL${NC}: $FAIL"
  echo -e "  ${YELLOW}SKIP${NC}: $SKIP"
  if [[ $WARN -gt 0 ]]; then
    echo -e "  ${YELLOW}WARN${NC}: $WARN"
  fi
  echo ""

  if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}FAILED${NC} — $FAIL test(s) failed"
    return 1
  else
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    return 0
  fi
}
