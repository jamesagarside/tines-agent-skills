#!/usr/bin/env bash
#
# Error handling tests for Tines Agent Skills
# Tests error paths, edge cases, and invalid input behavior against a real Tines tenant.
# All tests are READ-ONLY — no resources are created or modified (invalid payloads
# are expected to be rejected by the API).
#
# Prerequisites:
#   export TINES_TENANT_URL="https://your-tenant.tines.com"
#   export TINES_API_TOKEN="your-api-token"
#
# Usage:
#   ./tests/test-error-handling.sh                  Run all tests
#   ./tests/test-error-handling.sh auth             Run only auth error tests
#   ./tests/test-error-handling.sh not-found        Run only 404 tests
#   ./tests/test-error-handling.sh --dry-run        Show what would be tested
#
set -uo pipefail

source "$(dirname "$0")/helpers/test-helpers.sh"

# ─────────────────────────────────────────────
# Arg parsing
# ─────────────────────────────────────────────

TEST_FILTER="${1:-all}"
if [[ "$TEST_FILTER" == "--dry-run" ]]; then
  DRY_RUN=true
  TEST_FILTER="${2:-all}"
elif [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

init_test_env "Error Handling Tests"

# ─────────────────────────────────────────────
# Helper: should_run checks the test filter
# ─────────────────────────────────────────────

should_run() {
  local group="$1"
  [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "$group" ]]
}

# ─────────────────────────────────────────────
# Helper: raw curl without the shared auth header
# Used for auth error tests where we control headers directly.
# ─────────────────────────────────────────────

raw_curl() {
  local method="$1"
  local endpoint="$2"
  shift 2
  # Remaining args are extra curl flags
  if [[ "$DRY_RUN" == true ]]; then
    echo '{"error":"dry-run"}'
    echo "401"
    return 0
  fi
  /usr/bin/curl -s -w "\n%{http_code}" -X "$method" "$@" "${TINES_BASE_URL}${endpoint}"
}

# ==========================================================================
# 1. AUTH ERRORS
# ==========================================================================

if should_run "auth"; then
  section "1. Authentication Errors"

  # 1a. Empty token
  resp=$(raw_curl GET "/stories?per_page=1" -H "x-user-token: ")
  code=$(get_http_code "$resp")
  assert_http_one_of "Empty token returns 401" 401 403 "$code"

  rate_limit_pause

  # 1b. Malformed token
  resp=$(raw_curl GET "/stories?per_page=1" -H "x-user-token: not-a-real-token-abc123")
  code=$(get_http_code "$resp")
  assert_http_one_of "Malformed token returns 401" 401 403 "$code"

  rate_limit_pause

  # 1c. Missing auth header entirely
  resp=$(raw_curl GET "/stories?per_page=1")
  code=$(get_http_code "$resp")
  assert_http_one_of "Missing auth header returns 401" 401 403 "$code"

  echo ""
fi

# ==========================================================================
# 2. NON-EXISTENT RESOURCES (expect 404)
# ==========================================================================

if should_run "not-found"; then
  section "2. Non-Existent Resources (404)"

  NOT_FOUND_ENDPOINTS=(
    "/stories/999999999"
    "/agents/999999999"
    "/cases/999999999"
    "/records/999999999"
    "/user_credentials/999999999"
    "/admin/users/999999999"
    "/teams/999999999"
    "/folders/999999999"
    "/record_types/999999999"
  )

  for endpoint in "${NOT_FOUND_ENDPOINTS[@]}"; do
    resp=$(api_call GET "$endpoint")
    code=$(get_http_code "$resp")
    # Some endpoints return 404, others may return 422 for non-existent IDs
    assert_http_one_of "GET $endpoint returns 404" 404 422 "$code"
    rate_limit_pause
  done

  echo ""
fi

# ==========================================================================
# 3. INVALID CREATE PAYLOADS (expect 400 or 422)
# ==========================================================================

if should_run "invalid-create"; then
  section "3. Invalid Create Payloads (400/422)"

  # 3a. POST /stories with empty body
  resp=$(api_call POST "/stories" '{}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /stories with empty body" 400 422 500 "$code"
  rate_limit_pause

  # 3b. POST /stories with missing team_id
  resp=$(api_call POST "/stories" '{"name": "missing-team"}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /stories with missing team_id" 400 422 500 "$code"
  rate_limit_pause

  # 3c. POST /agents with missing story_id
  resp=$(api_call POST "/agents" '{"name": "orphan-agent", "type": "Agents::EventTransformationAgent"}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /agents with missing story_id" 400 404 422 "$code"
  rate_limit_pause

  # 3d. POST /cases with empty body
  resp=$(api_call POST "/cases" '{}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /cases with empty body" 400 422 "$code"
  rate_limit_pause

  # 3e. POST /records without record_type_id
  resp=$(api_call POST "/records" '{"field_values": []}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /records without record_type_id" 400 422 "$code"
  rate_limit_pause

  # 3f. POST /user_credentials without mode
  resp=$(api_call POST "/user_credentials" '{"name": "no-mode", "team_id": 1}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /user_credentials without mode" 400 422 "$code"
  rate_limit_pause

  # 3g. POST /user_credentials without team_id
  resp=$(api_call POST "/user_credentials" '{"name": "no-team", "mode": "TEXT", "value": "x"}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /user_credentials without team_id" 400 422 "$code"
  rate_limit_pause

  # 3h. POST /record_types without team_id
  resp=$(api_call POST "/record_types" '{"name": "no-team-rt"}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /record_types without team_id" 400 422 "$code"
  rate_limit_pause

  # 3i. POST /folders without team_id
  resp=$(api_call POST "/folders" '{"name": "no-team-folder"}')
  code=$(get_http_code "$resp")
  assert_http_one_of "POST /folders without team_id" 400 422 "$code"

  echo ""
fi

# ==========================================================================
# 4. INVALID UPDATE PAYLOADS
# ==========================================================================

if should_run "invalid-update"; then
  section "4. Invalid Update Payloads"

  # 4a. PATCH non-existent story
  resp=$(api_call PATCH "/stories/999999999" '{"name": "ghost"}')
  code=$(get_http_code "$resp")
  assert_http_one_of "PATCH /stories/999999999 (non-existent)" 404 422 "$code"
  rate_limit_pause

  # 4b. DELETE non-existent story — API may return 404 or 200 (idempotent)
  resp=$(api_call DELETE "/stories/999999999")
  code=$(get_http_code "$resp")
  assert_http_one_of "DELETE /stories/999999999 (non-existent)" 200 204 404 "$code"

  echo ""
fi

# ==========================================================================
# 5. METHOD VALIDATION
# ==========================================================================

if should_run "method"; then
  section "5. Method Validation"

  # 5a. POST without Content-Type header should fail or return error
  resp=$(api_call POST_NO_CT "/stories" '{"name": "no-ct", "team_id": 1}')
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  # Without Content-Type, the server may reject (400/415) or misparse the body (422)
  # or it may silently accept. We check that it does NOT return 201 (successful create).
  if [[ "$code" == "201" ]]; then
    fail "POST without Content-Type should not create a resource (got HTTP 201)"
    # Clean up if it accidentally created something
    created_id=$(json_field "$body" '.id')
    if [[ "$created_id" != "null" && -n "$created_id" ]]; then
      register_cleanup "stories" "$created_id"
    fi
  else
    pass "POST without Content-Type did not create resource (HTTP $code)"
  fi
  rate_limit_pause

  # 5b. Cases use PATCH for updates — verify PUT behavior differs or fails
  resp=$(api_call PUT "/cases/999999999" '{"name": "put-case"}')
  code=$(get_http_code "$resp")
  # PUT on cases endpoint may return 404 (not found), 405 (method not allowed),
  # or behave the same as PATCH. We accept any of these.
  assert_http_one_of "PUT /cases/999999999 (cases use PATCH)" 404 405 422 "$code"

  echo ""
fi

# ==========================================================================
# 6. STORY EVENTS BEHAVIOR
# ==========================================================================

if should_run "events"; then
  section "6. Story Events Behavior"

  # Discover a real story ID to test against
  REAL_STORY_ID=$(discover_story_id)

  if [[ -z "$REAL_STORY_ID" || "$REAL_STORY_ID" == "null" ]]; then
    skip "No stories found in tenant — cannot test story events endpoint"
  else
    # Events are per-agent, not per-story. /stories/{id}/events should return 404.
    resp=$(api_call GET "/stories/${REAL_STORY_ID}/events")
    code=$(get_http_code "$resp")
    assert_http_one_of "GET /stories/{id}/events returns 404 (events are per-agent)" 404 405 "$code"
  fi

  echo ""
fi

# ==========================================================================
# 7. RECORDS REQUIREMENT
# ==========================================================================

if should_run "records"; then
  section "7. Records Requirement"

  # GET /records without record_type_id should return 400 or 422
  resp=$(api_call GET "/records")
  code=$(get_http_code "$resp")
  assert_http_one_of "GET /records without record_type_id" 400 422 "$code"

  echo ""
fi

# ==========================================================================
# 8. API ALIAS VERIFICATION
# ==========================================================================

if should_run "alias"; then
  section "8. API Alias Verification"

  # GET /actions and GET /agents should return same structure
  resp_actions=$(api_call GET "/actions?per_page=1")
  code_actions=$(get_http_code "$resp_actions")
  body_actions=$(get_body "$resp_actions")

  resp_agents=$(api_call GET "/agents?per_page=1")
  code_agents=$(get_http_code "$resp_agents")
  body_agents=$(get_body "$resp_agents")

  # Both should succeed
  assert_http "GET /actions returns 200" 200 "$code_actions"
  assert_http "GET /agents returns 200" 200 "$code_agents"

  # Both responses should use the 'agents' key (not 'actions')
  actions_key=$(json_field "$body_actions" '.agents | type')
  agents_key=$(json_field "$body_agents" '.agents | type')

  if [[ "$actions_key" == "array" && "$agents_key" == "array" ]]; then
    pass "Both /actions and /agents return 'agents' key in response"
  else
    fail "Response key mismatch: /actions has agents=$actions_key, /agents has agents=$agents_key"
  fi

  echo ""
fi

# ==========================================================================
# Summary
# ==========================================================================

print_summary
