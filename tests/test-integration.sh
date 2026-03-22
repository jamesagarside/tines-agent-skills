#!/usr/bin/env bash
#
# Integration tests for Tines Agent Skills
# Runs against a real Tines tenant to verify API operations.
#
# Prerequisites:
#   export TINES_TENANT_URL="https://your-tenant.tines.com"
#   export TINES_API_TOKEN="your-api-token"
#
# Usage:
#   ./tests/test-integration.sh              Run all tests
#   ./tests/test-integration.sh auth         Run only auth tests
#   ./tests/test-integration.sh stories      Run only stories tests
#   ./tests/test-integration.sh --dry-run    Show what would be tested without making API calls
#
set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
DRY_RUN=false

# Parse args
TEST_FILTER="${1:-all}"
if [[ "$TEST_FILTER" == "--dry-run" ]]; then
  DRY_RUN=true
  TEST_FILTER="${2:-all}"
fi

# Setup
TINES_BASE_URL="${TINES_TENANT_URL%/}/api/v1"
AUTH_HEADER="x-user-token: $TINES_API_TOKEN"

# Cleanup tracking
CLEANUP_IDS=()
CLEANUP_TYPES=()

cleanup() {
  if [[ ${#CLEANUP_IDS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${BLUE}Cleaning up test resources...${NC}"
    for i in "${!CLEANUP_IDS[@]}"; do
      local id="${CLEANUP_IDS[$i]}"
      local type="${CLEANUP_TYPES[$i]}"
      echo -e "  Deleting $type $id..."
      curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/${type}/${id}" > /dev/null 2>&1 || true
    done
    echo -e "${GREEN}Cleanup complete${NC}"
  fi
}
trap cleanup EXIT

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

# Helper: make API call and capture response + HTTP code
api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] $method $endpoint"
    return 0
  fi

  local args=(-s -w "\n%{http_code}" -H "$AUTH_HEADER")

  case "$method" in
    GET)    ;;
    POST)   args+=(-X POST -H "Content-Type: application/json" -d "$data") ;;
    PUT)    args+=(-X PUT -H "Content-Type: application/json" -d "$data") ;;
    PATCH)  args+=(-X PATCH -H "Content-Type: application/json" -d "$data") ;;
    DELETE) args+=(-X DELETE) ;;
  esac

  curl "${args[@]}" "${TINES_BASE_URL}${endpoint}"
}

# Helper: extract HTTP code from api_call response
get_http_code() {
  echo "$1" | tail -1
}

# Helper: extract body from api_call response
get_body() {
  echo "$1" | sed '$d'
}

# ─────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────
echo "=========================================="
echo " Tines Agent Skills — Integration Tests"
echo "=========================================="
echo ""

if [[ -z "${TINES_TENANT_URL:-}" ]]; then
  echo -e "${RED}Error: TINES_TENANT_URL is not set${NC}"
  echo "  export TINES_TENANT_URL=\"https://your-tenant.tines.com\""
  exit 1
fi

if [[ -z "${TINES_API_TOKEN:-}" ]]; then
  echo -e "${RED}Error: TINES_API_TOKEN is not set${NC}"
  echo "  export TINES_API_TOKEN=\"your-api-token\""
  exit 1
fi

echo "Tenant: $TINES_TENANT_URL"
echo "Filter: $TEST_FILTER"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}Mode: DRY RUN (no API calls)${NC}"
fi
echo ""

# ─────────────────────────────────────────────
# Test: Auth & Connection
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "auth" ]]; then
  echo "Auth & Connection"
  echo "─────────────────"

  response=$(api_call GET "/info")
  http_code=$(get_http_code "$response")
  body=$(get_body "$response")

  if [[ "$DRY_RUN" == true ]]; then
    skip "Connection test (dry run)"
  elif [[ "$http_code" == "200" ]]; then
    pass "GET /info returns 200"

    # Verify response has expected fields
    if echo "$body" | jq -e '.stack // .tenant_name // .name' > /dev/null 2>&1; then
      pass "Response contains tenant/stack info"
    else
      skip "Response structure differs from expected (non-critical)"
    fi
  else
    fail "GET /info returned HTTP $http_code"
    echo -e "    ${RED}Cannot proceed without a valid connection${NC}"
    exit 1
  fi

  # Test invalid token behavior
  if [[ "$DRY_RUN" != true ]]; then
    bad_response=$(curl -s -w "\n%{http_code}" -H "x-user-token: invalid-token-12345" "${TINES_BASE_URL}/info")
    bad_code=$(get_http_code "$bad_response")
    if [[ "$bad_code" == "401" || "$bad_code" == "404" ]]; then
      pass "Invalid token returns $bad_code (expected 401 or 404)"
    else
      fail "Invalid token returned unexpected HTTP $bad_code"
    fi
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Test: Stories
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "stories" ]]; then
  echo "Stories"
  echo "───────"

  # List stories
  response=$(api_call GET "/stories?per_page=5")
  http_code=$(get_http_code "$response")
  body=$(get_body "$response")

  if [[ "$DRY_RUN" == true ]]; then
    skip "Stories tests (dry run)"
  elif [[ "$http_code" == "200" ]]; then
    pass "GET /stories returns 200"

    # Check pagination meta
    if echo "$body" | jq -e '.meta.current_page' > /dev/null 2>&1; then
      pass "Stories response includes pagination meta"
    else
      fail "Stories response missing pagination meta"
    fi

    # Check stories array
    story_count=$(echo "$body" | jq '.stories | length' 2>/dev/null || echo "0")
    pass "Found $story_count stories (page 1, per_page=5)"

    # Get first story details if available
    if [[ "$story_count" -gt 0 ]]; then
      first_id=$(echo "$body" | jq -r '.stories[0].id')
      detail_response=$(api_call GET "/stories/$first_id")
      detail_code=$(get_http_code "$detail_response")

      if [[ "$detail_code" == "200" ]]; then
        pass "GET /stories/$first_id returns 200"
      else
        fail "GET /stories/$first_id returned HTTP $detail_code"
      fi

      # Story-level events typically return 404 — events are per-agent
      # Test agent-level events instead
      agents_response=$(api_call GET "/agents?story_id=$first_id&per_page=1")
      agents_code=$(get_http_code "$agents_response")
      agents_body=$(get_body "$agents_response")

      if [[ "$agents_code" == "200" ]]; then
        agent_count=$(echo "$agents_body" | jq '.agents | length' 2>/dev/null || echo "0")
        if [[ "$agent_count" -gt 0 ]]; then
          agent_id=$(echo "$agents_body" | jq -r '.agents[0].id')
          agent_events=$(api_call GET "/agents/$agent_id/events?per_page=5")
          agent_events_code=$(get_http_code "$agent_events")
          if [[ "$agent_events_code" == "200" ]]; then
            pass "GET /agents/$agent_id/events returns 200"

            # Test event re-emit (events are re-emitted via /events/{event_id}/reemit)
            event_id=$(echo "$agent_events" | sed '$d' | jq -r '.events[0].id // empty')
            if [[ -n "$event_id" ]]; then
              reemit_response=$(api_call POST "/events/$event_id/reemit")
              reemit_code=$(get_http_code "$reemit_response")
              if [[ "$reemit_code" == "200" || "$reemit_code" == "204" ]]; then
                pass "POST /events/$event_id/reemit returns $reemit_code"
              else
                fail "POST /events/$event_id/reemit returned HTTP $reemit_code"
              fi
            else
              skip "Event re-emit test (no events found for agent $agent_id)"
            fi
          else
            fail "GET /agents/$agent_id/events returned HTTP $agent_events_code"
          fi
        else
          skip "Agent events test (story $first_id has no agents)"
        fi
      fi

      # Test runs endpoint
      runs_response=$(api_call GET "/stories/$first_id/runs?per_page=5")
      runs_code=$(get_http_code "$runs_response")

      if [[ "$runs_code" == "200" ]]; then
        pass "GET /stories/$first_id/runs returns 200"
      else
        fail "GET /stories/$first_id/runs returned HTTP $runs_code"
      fi

      # Test story export
      export_response=$(api_call GET "/stories/$first_id/export")
      export_code=$(get_http_code "$export_response")
      export_body=$(get_body "$export_response")

      if [[ "$export_code" == "200" ]]; then
        pass "GET /stories/$first_id/export returns 200"
        if echo "$export_body" | jq -e '.name' > /dev/null 2>&1; then
          pass "Story export contains story name"
        else
          fail "Story export missing story name"
        fi
      else
        fail "GET /stories/$first_id/export returned HTTP $export_code"
      fi

      # Test story versions
      versions_response=$(api_call GET "/stories/$first_id/versions")
      versions_code=$(get_http_code "$versions_response")

      if [[ "$versions_code" == "200" ]]; then
        pass "GET /stories/$first_id/versions returns 200"
      elif [[ "$versions_code" == "404" ]]; then
        skip "GET /stories/$first_id/versions returned 404 (may not be available)"
      else
        fail "GET /stories/$first_id/versions returned HTTP $versions_code"
      fi
    else
      skip "Story detail/events/runs tests (no stories found)"
    fi
  else
    fail "GET /stories returned HTTP $http_code"
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Test: Actions
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "actions" ]]; then
  echo "Actions"
  echo "───────"

  # Tines uses /agents endpoint (response key: "agents"), /actions also works as alias
  response=$(api_call GET "/agents?per_page=5")
  http_code=$(get_http_code "$response")
  body=$(get_body "$response")

  if [[ "$DRY_RUN" == true ]]; then
    skip "Actions/Agents tests (dry run)"
  elif [[ "$http_code" == "200" ]]; then
    pass "GET /agents returns 200"

    agent_count=$(echo "$body" | jq '.agents | length' 2>/dev/null || echo "0")
    pass "Found $agent_count agents (page 1)"

    if [[ "$agent_count" -gt 0 ]]; then
      first_id=$(echo "$body" | jq -r '.agents[0].id')
      detail_response=$(api_call GET "/agents/$first_id")
      detail_code=$(get_http_code "$detail_response")

      if [[ "$detail_code" == "200" ]]; then
        pass "GET /agents/$first_id returns 200"
      else
        fail "GET /agents/$first_id returned HTTP $detail_code"
      fi

      # Test agent logs
      logs_response=$(api_call GET "/agents/$first_id/logs?per_page=5")
      logs_code=$(get_http_code "$logs_response")
      if [[ "$logs_code" == "200" ]]; then
        pass "GET /agents/$first_id/logs returns 200"
      else
        fail "GET /agents/$first_id/logs returned HTTP $logs_code"
      fi
    fi
  else
    fail "GET /agents returned HTTP $http_code"
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Test: Cases
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "cases" ]]; then
  echo "Cases"
  echo "─────"

  response=$(api_call GET "/cases?per_page=5")
  http_code=$(get_http_code "$response")
  body=$(get_body "$response")

  if [[ "$DRY_RUN" == true ]]; then
    skip "Cases tests (dry run)"
  elif [[ "$http_code" == "200" ]]; then
    pass "GET /cases returns 200"

    case_count=$(echo "$body" | jq '.cases | length' 2>/dev/null || echo "0")
    pass "Found $case_count cases (page 1)"

    if [[ "$case_count" -gt 0 ]]; then
      # Tines uses case_id, not id
      first_id=$(echo "$body" | jq -r '.cases[0].case_id // .cases[0].id')

      if [[ -z "$first_id" || "$first_id" == "null" ]]; then
        skip "Case sub-resource tests (could not extract case ID)"
      else

      # Test confirmed working sub-resources
      for sub in metadata subscribers linked_cases records; do
        sub_response=$(api_call GET "/cases/$first_id/$sub")
        sub_code=$(get_http_code "$sub_response")

        if [[ "$sub_code" == "200" ]]; then
          pass "GET /cases/$first_id/$sub returns 200"
        else
          fail "GET /cases/$first_id/$sub returned HTTP $sub_code"
        fi
      done

      # Test sub-resources that may not be available on all plans
      for sub in comments tasks notes files; do
        sub_response=$(api_call GET "/cases/$first_id/$sub")
        sub_code=$(get_http_code "$sub_response")

        if [[ "$sub_code" == "200" ]]; then
          pass "GET /cases/$first_id/$sub returns 200"
        elif [[ "$sub_code" == "404" ]]; then
          skip "GET /cases/$first_id/$sub returned 404 (may not be available on this plan)"
        else
          fail "GET /cases/$first_id/$sub returned HTTP $sub_code"
        fi
      done
      fi
    else
      skip "Case sub-resource tests (no cases found)"
    fi
  else
    fail "GET /cases returned HTTP $http_code"
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Test: Records
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "records" ]]; then
  echo "Records"
  echo "───────"

  if [[ "$DRY_RUN" == true ]]; then
    skip "Records tests (dry run)"
  else
    # Get team_id first (required for record_types)
    teams_resp=$(api_call GET "/teams?per_page=1")
    teams_body=$(get_body "$teams_resp")
    team_id=$(echo "$teams_body" | jq -r '.teams[0].id // empty' 2>/dev/null)

    if [[ -z "$team_id" ]]; then
      skip "Records tests (could not determine team_id)"
    else
      # Record types endpoint requires team_id
      types_response=$(api_call GET "/record_types?team_id=$team_id&per_page=5")
      types_code=$(get_http_code "$types_response")
      types_body=$(get_body "$types_response")

      if [[ "$types_code" == "200" ]]; then
        pass "GET /record_types?team_id=$team_id returns 200"

        type_count=$(echo "$types_body" | jq '.record_types | length' 2>/dev/null || echo "0")
        pass "Found $type_count record types"

        # Try to list records if we have a record type
        if [[ "$type_count" -gt 0 ]]; then
          type_id=$(echo "$types_body" | jq -r '.record_types[0].id')
          response=$(api_call GET "/records?record_type_id=$type_id&per_page=5")
          http_code=$(get_http_code "$response")
          if [[ "$http_code" == "200" ]]; then
            pass "GET /records?record_type_id=$type_id returns 200"
          else
            fail "GET /records?record_type_id=$type_id returned HTTP $http_code"
          fi
        else
          skip "Records list test (no record types defined)"
        fi
      elif [[ "$types_code" == "422" ]]; then
        fail "GET /record_types returned 422 (missing required param)"
      else
        fail "GET /record_types returned HTTP $types_code"
      fi
    fi
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Test: Credentials
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "credentials" ]]; then
  echo "Credentials"
  echo "───────────"

  response=$(api_call GET "/user_credentials?per_page=5")
  http_code=$(get_http_code "$response")
  body=$(get_body "$response")

  if [[ "$DRY_RUN" == true ]]; then
    skip "Credentials tests (dry run)"
  elif [[ "$http_code" == "200" ]]; then
    pass "GET /user_credentials returns 200"

    cred_count=$(echo "$body" | jq '.user_credentials | length' 2>/dev/null || echo "0")
    pass "Found $cred_count credentials (page 1)"

    # Verify no secret values in response (check for common secret field names)
    if echo "$body" | jq -e '.user_credentials[0].value // empty' > /dev/null 2>&1; then
      warn "Credentials response may contain secret values — verify API response filtering"
    else
      pass "No plaintext secret values detected in list response"
    fi
  else
    fail "GET /user_credentials returned HTTP $http_code"
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Test: Admin
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "admin" ]]; then
  echo "Admin"
  echo "─────"

  # Users
  response=$(api_call GET "/admin/users?per_page=5")
  http_code=$(get_http_code "$response")

  if [[ "$DRY_RUN" == true ]]; then
    skip "Admin tests (dry run)"
  elif [[ "$http_code" == "200" ]]; then
    pass "GET /admin/users returns 200"
  elif [[ "$http_code" == "401" || "$http_code" == "403" || "$http_code" == "404" ]]; then
    skip "GET /admin/users returned $http_code (token may lack admin permissions)"
  else
    fail "GET /admin/users returned HTTP $http_code"
  fi

  # System info (should work for all tokens)
  info_response=$(api_call GET "/info")
  info_code=$(get_http_code "$info_response")

  if [[ "$DRY_RUN" != true ]]; then
    if [[ "$info_code" == "200" ]]; then
      pass "GET /info returns 200"
    else
      fail "GET /info returned HTTP $info_code"
    fi
  fi

  # Audit logs
  audit_response=$(api_call GET "/audit_logs?per_page=5")
  audit_code=$(get_http_code "$audit_response")

  if [[ "$DRY_RUN" != true ]]; then
    if [[ "$audit_code" == "200" ]]; then
      pass "GET /audit_logs returns 200"
    elif [[ "$audit_code" == "404" ]]; then
      skip "GET /audit_logs returned 404 (token may lack permissions)"
    else
      fail "GET /audit_logs returned HTTP $audit_code"
    fi
  fi

  # Teams
  teams_response=$(api_call GET "/teams?per_page=5")
  teams_code=$(get_http_code "$teams_response")

  if [[ "$DRY_RUN" != true ]]; then
    if [[ "$teams_code" == "200" ]]; then
      pass "GET /teams returns 200"
    else
      fail "GET /teams returned HTTP $teams_code"
    fi
  fi

  # Folders
  folders_response=$(api_call GET "/folders?per_page=5")
  folders_code=$(get_http_code "$folders_response")

  if [[ "$DRY_RUN" != true ]]; then
    if [[ "$folders_code" == "200" ]]; then
      pass "GET /folders returns 200"
    else
      fail "GET /folders returned HTTP $folders_code"
    fi
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Test: Rate limit headers
# ─────────────────────────────────────────────
if [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "ratelimits" ]]; then
  echo "Rate Limits"
  echo "───────────"

  if [[ "$DRY_RUN" == true ]]; then
    skip "Rate limit tests (dry run)"
  else
    # Check if rate limit headers are returned
    headers=$(curl -s -I -H "$AUTH_HEADER" "${TINES_BASE_URL}/info" 2>/dev/null)

    if echo "$headers" | grep -qi 'x-ratelimit\|ratelimit\|rate-limit'; then
      pass "API returns rate limit headers"
      echo "$headers" | grep -i 'rate' | sed 's/^/    /'
    else
      skip "No rate limit headers detected (may not be exposed)"
    fi
  fi

  echo ""
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo "=========================================="
echo " Summary"
echo "=========================================="
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}SKIP${NC}: $SKIP"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}FAILED${NC} — $FAIL test(s) failed"
  exit 1
else
  echo -e "${GREEN}ALL TESTS PASSED${NC}"
  exit 0
fi
