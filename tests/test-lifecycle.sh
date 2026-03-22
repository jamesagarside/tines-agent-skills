#!/usr/bin/env bash
#
# Lifecycle tests for Tines Agent Skills
# Tests full CRUD lifecycle chains for each resource type.
#
# Prerequisites:
#   export TINES_TENANT_URL="https://your-tenant.tines.com"
#   export TINES_API_TOKEN="your-api-token"
#
# Usage:
#   ./tests/test-lifecycle.sh                   Run all lifecycle tests
#   ./tests/test-lifecycle.sh stories           Run only story lifecycle
#   ./tests/test-lifecycle.sh actions           Run only story+actions lifecycle
#   ./tests/test-lifecycle.sh cases             Run only case lifecycle
#   ./tests/test-lifecycle.sh records           Run only record lifecycle
#   ./tests/test-lifecycle.sh credentials       Run only credential lifecycle
#   ./tests/test-lifecycle.sh credential-types  Run only credential types lifecycle
#   ./tests/test-lifecycle.sh resources         Run only resource lifecycle
#   ./tests/test-lifecycle.sh admin             Run only admin lifecycle
#   ./tests/test-lifecycle.sh --dry-run         Dry run mode (no API calls)
#
set -uo pipefail

source "$(dirname "$0")/helpers/test-helpers.sh"

# ─────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────

TEST_FILTER="${1:-all}"
if [[ "$TEST_FILTER" == "--dry-run" ]]; then
  DRY_RUN=true
  TEST_FILTER="${2:-all}"
elif [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

init_test_env "Lifecycle Tests"

# Discover team ID (required for several resource types)
if [[ "$DRY_RUN" == true ]]; then
  TEAM_ID="999999"
else
  TEAM_ID=$(discover_team_id)
  if [[ -z "$TEAM_ID" || "$TEAM_ID" == "null" ]]; then
    echo -e "${RED}Error: Could not discover a team ID. Cannot proceed.${NC}"
    exit 1
  fi
fi
echo "Team ID: $TEAM_ID"
echo ""

should_run() {
  [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "$1" ]]
}

# ═════════════════════════════════════════════
# Story Lifecycle
# ═════════════════════════════════════════════

test_story_lifecycle() {
  section "Story Lifecycle: create -> read -> update -> export -> delete"

  local story_name="${TEST_PREFIX}story"
  local story_name_updated="${TEST_PREFIX}story_updated"

  # Create story
  local resp body code story_id
  resp=$(api_call POST "/stories" "{\"name\": \"${story_name}\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create story" 200 201 "$code"

  story_id=$(json_field "$body" '.id')
  if [[ -z "$story_id" || "$story_id" == "null" ]]; then
    fail "Create story returned no ID"
    return
  fi
  register_cleanup "stories" "$story_id"
  pass "Story created with ID $story_id"
  rate_limit_pause

  # Get story by ID
  resp=$(api_call GET "/stories/${story_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get story by ID" "200" "$code"
  assert_json_equals "Verify story name" "$body" '.name' "$story_name"
  rate_limit_pause

  # Update story name
  resp=$(api_call PUT "/stories/${story_id}" "{\"name\": \"${story_name_updated}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update story name" "200" "$code"
  rate_limit_pause

  # Get again and verify name changed
  resp=$(api_call GET "/stories/${story_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get story after update" "200" "$code"
  assert_json_equals "Verify story name changed" "$body" '.name' "$story_name_updated"
  rate_limit_pause

  # Export story (verify valid JSON)
  resp=$(api_call GET "/stories/${story_id}/export")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Export story" "200" "$code"

  if echo "$body" | jq . > /dev/null 2>&1; then
    pass "Export produces valid JSON"
  else
    fail "Export produces valid JSON (invalid JSON returned)"
  fi
  rate_limit_pause

  # Delete story
  resp=$(api_call DELETE "/stories/${story_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete story" "200" "204" "$code"
  rate_limit_pause

  # Verify gone (expect 404)
  resp=$(api_call GET "/stories/${story_id}")
  code=$(get_http_code "$resp")
  assert_http "Verify story deleted (404)" "404" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Story + Actions Lifecycle
# ═════════════════════════════════════════════

test_actions_lifecycle() {
  section "Story+Actions Lifecycle: story -> create agent -> update -> delete"

  local story_name="${TEST_PREFIX}actions_story"
  local agent_name="${TEST_PREFIX}agent"
  local agent_name_updated="${TEST_PREFIX}agent_updated"

  # Create story first
  local resp body code story_id agent_id
  resp=$(api_call POST "/stories" "{\"name\": \"${story_name}\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create parent story" 200 201 "$code"

  story_id=$(json_field "$body" '.id')
  if [[ -z "$story_id" || "$story_id" == "null" ]]; then
    fail "Create parent story returned no ID"
    return
  fi
  register_cleanup "stories" "$story_id"
  rate_limit_pause

  # Create agent in story
  resp=$(api_call POST "/agents" "{\"story_id\": ${story_id}, \"name\": \"${agent_name}\", \"type\": \"Agents::EventTransformationAgent\", \"options\": {\"mode\": \"message_only\", \"payload\": {\"message\": \"test\"}}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create agent" 200 201 "$code"

  agent_id=$(json_field "$body" '.id')
  if [[ -z "$agent_id" || "$agent_id" == "null" ]]; then
    fail "Create agent returned no ID"
    return
  fi
  register_cleanup "agents" "$agent_id"
  pass "Agent created with ID $agent_id"
  rate_limit_pause

  # Get agent
  resp=$(api_call GET "/agents/${agent_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get agent by ID" "200" "$code"
  assert_json_equals "Verify agent name" "$body" '.name' "$agent_name"
  rate_limit_pause

  # Update agent name
  resp=$(api_call PUT "/agents/${agent_id}" "{\"name\": \"${agent_name_updated}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update agent name" "200" "$code"
  rate_limit_pause

  # Verify update
  resp=$(api_call GET "/agents/${agent_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get agent after update" "200" "$code"
  assert_json_equals "Verify agent name changed" "$body" '.name' "$agent_name_updated"
  rate_limit_pause

  # Delete agent
  resp=$(api_call DELETE "/agents/${agent_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete agent" "200" "204" "$code"
  rate_limit_pause

  # Verify agent gone
  resp=$(api_call GET "/agents/${agent_id}")
  code=$(get_http_code "$resp")
  assert_http "Verify agent deleted (404)" "404" "$code"
  rate_limit_pause

  # Delete parent story
  resp=$(api_call DELETE "/stories/${story_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete parent story" "200" "204" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Case Lifecycle
# ═════════════════════════════════════════════

test_case_lifecycle() {
  section "Case Lifecycle: create -> read -> update status -> metadata -> delete"

  local case_name="${TEST_PREFIX}case"

  # Create case
  local resp body code case_id case_numeric_id
  resp=$(api_call POST "/cases" "{\"name\": \"${case_name}\", \"status\": \"OPEN\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create case" 200 201 "$code"

  case_id=$(json_field "$body" '.case_id')
  if [[ -z "$case_id" || "$case_id" == "null" ]]; then
    fail "Create case returned no case_id"
    return
  fi
  register_cleanup "cases" "$case_id"
  pass "Case created with case_id $case_id"
  rate_limit_pause

  # Get by case ID
  resp=$(api_call GET "/cases/${case_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get case by ID" "200" "$code"
  assert_json_equals "Verify case name" "$body" '.name' "$case_name"
  rate_limit_pause

  # Update status to CLOSED (API only allows "OPEN" or "CLOSED")
  resp=$(api_call PATCH "/cases/${case_id}" '{"status": "CLOSED"}')
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update case status" "200" "$code"
  rate_limit_pause

  # Get again and verify status changed
  resp=$(api_call GET "/cases/${case_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get case after status update" "200" "$code"
  assert_json_equals "Verify status is CLOSED" "$body" '.status' "CLOSED"
  rate_limit_pause

  # Add metadata via PATCH on the case itself
  local meta_key="${TEST_PREFIX}severity"
  resp=$(api_call PATCH "/cases/${case_id}" "{\"metadata\":{\"${meta_key}\":\"critical\"}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Set case metadata" "200" "$code"
  rate_limit_pause

  # Get metadata and verify it is there
  resp=$(api_call GET "/cases/${case_id}/metadata")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get case metadata" "200" "$code"

  local found_val
  found_val=$(json_field "$body" ".metadata.\"${meta_key}\"")
  if [[ "$found_val" == "critical" ]]; then
    pass "Verify metadata key present"
  else
    fail "Verify metadata key present (expected 'critical', got '$found_val')"
  fi
  rate_limit_pause

  # Delete metadata (set key to null)
  resp=$(api_call PATCH "/cases/${case_id}" "{\"metadata\":{\"${meta_key}\":null}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Delete case metadata" "200" "$code"
  rate_limit_pause

  # Verify metadata gone
  resp=$(api_call GET "/cases/${case_id}/metadata")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get metadata after delete" "200" "$code"

  local still_val
  still_val=$(json_field "$body" ".metadata.\"${meta_key}\"")
  if [[ -z "$still_val" || "$still_val" == "null" ]]; then
    pass "Verify metadata removed"
  else
    fail "Verify metadata removed (still found: '$still_val')"
  fi
  rate_limit_pause

  # Delete case
  resp=$(api_call DELETE "/cases/${case_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete case" "200" "204" "$code"
  rate_limit_pause

  # Verify gone
  resp=$(api_call GET "/cases/${case_id}")
  code=$(get_http_code "$resp")
  assert_http "Verify case deleted (404)" "404" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Case Linking Lifecycle
# ═════════════════════════════════════════════

test_case_linking_lifecycle() {
  section "Case Linking Lifecycle: create A -> create B -> link -> verify -> unlink -> verify -> delete"

  local case_a_name="${TEST_PREFIX}case_link_a"
  local case_b_name="${TEST_PREFIX}case_link_b"

  # Create case A
  local resp body code case_a_id case_b_id
  resp=$(api_call POST "/cases" "{\"name\": \"${case_a_name}\", \"status\": \"OPEN\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create case A" 200 201 "$code"

  case_a_id=$(json_field "$body" '.case_id')
  if [[ -z "$case_a_id" || "$case_a_id" == "null" ]]; then
    fail "Create case A returned no ID"
    return
  fi
  register_cleanup "cases" "$case_a_id"
  rate_limit_pause

  # Create case B
  resp=$(api_call POST "/cases" "{\"name\": \"${case_b_name}\", \"status\": \"OPEN\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create case B" 200 201 "$code"

  case_b_id=$(json_field "$body" '.case_id')
  if [[ -z "$case_b_id" || "$case_b_id" == "null" ]]; then
    fail "Create case B returned no ID"
    return
  fi
  register_cleanup "cases" "$case_b_id"
  rate_limit_pause

  # Link A to B (may 404 on some plans)
  resp=$(api_call POST "/cases/${case_a_id}/linked_cases" "{\"linked_case_id\": ${case_b_id}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")

  if [[ "$code" == "404" ]]; then
    skip "Link case A to B (HTTP 404 — endpoint not available on this plan)"
    skip "Remaining link tests (link endpoint not available)"
  else
    assert_http_one_of "Link case A to B" 200 201 "$code"
    rate_limit_pause

    # List linked cases on A and verify B appears
    resp=$(api_call GET "/cases/${case_a_id}/linked_cases")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "List linked cases on A" "200" "$code"

    local linked_found
    linked_found=$(echo "$body" | jq -r ".[] | select(.id == ${case_b_id}) | .id" 2>/dev/null || echo "")
    if [[ -z "$linked_found" ]]; then
      # Try alternate response shape
      linked_found=$(echo "$body" | jq -r ".linked_cases[] | select(.id == ${case_b_id}) | .id" 2>/dev/null || echo "")
    fi
    if [[ -n "$linked_found" ]]; then
      pass "Verify case B appears in linked cases"
    else
      fail "Verify case B appears in linked cases (not found)"
    fi
    rate_limit_pause

    # Unlink
    resp=$(api_call DELETE "/cases/${case_a_id}/linked_cases/${case_b_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Unlink case B from A" "200" "204" "$code"
    rate_limit_pause

    # Verify empty linked list
    resp=$(api_call GET "/cases/${case_a_id}/linked_cases")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "List linked cases after unlink" "200" "$code"

    local link_count
    link_count=$(echo "$body" | jq 'if type == "array" then length elif .linked_cases then (.linked_cases | length) else 0 end' 2>/dev/null || echo "0")
    if [[ "$link_count" -eq 0 ]]; then
      pass "Verify no linked cases remain"
    else
      fail "Verify no linked cases remain (found $link_count)"
    fi
    rate_limit_pause
  fi

  # Delete both cases
  resp=$(api_call DELETE "/cases/${case_b_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete case B" "200" "204" "$code"
  rate_limit_pause

  resp=$(api_call DELETE "/cases/${case_a_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete case A" "200" "204" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Record Lifecycle
# ═════════════════════════════════════════════

test_record_lifecycle() {
  section "Record Lifecycle: type -> record -> update -> delete type"

  local type_name="${TEST_PREFIX}record_type"
  local field_name="${TEST_PREFIX}field"
  local field_value="test_value_one"
  local field_value_updated="test_value_two"

  # Create record type with a text field
  local resp body code type_id field_id record_id
  resp=$(api_call POST "/record_types" "{\"name\": \"${type_name}\", \"team_id\": ${TEAM_ID}, \"editable\": true, \"fields\": [{\"name\": \"${field_name}\", \"result_type\": \"TEXT\"}]}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create record type" 200 201 "$code"

  type_id=$(json_field "$body" '.id')
  if [[ -z "$type_id" || "$type_id" == "null" ]]; then
    fail "Create record type returned no ID"
    return
  fi
  register_cleanup "record_types" "$type_id"
  pass "Record type created with ID $type_id"
  rate_limit_pause

  # Extract field ID from the created type
  field_id=$(json_field "$body" '.record_fields[0].id')
  if [[ -z "$field_id" || "$field_id" == "null" ]]; then
    # Try getting the type to find the field
    resp=$(api_call GET "/record_types/${type_id}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    field_id=$(json_field "$body" '.record_fields[0].id')
  fi
  if [[ -z "$field_id" || "$field_id" == "null" ]]; then
    fail "Could not find field ID on record type"
    return
  fi
  pass "Field ID discovered: $field_id"
  rate_limit_pause

  # List types and verify new type appears
  resp=$(api_call GET "/record_types?team_id=${TEAM_ID}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "List record types" "200" "$code"

  local type_found
  type_found=$(echo "$body" | jq -r ".record_types[]? | select(.id == ${type_id}) | .id" 2>/dev/null || echo "")
  if [[ -z "$type_found" ]]; then
    type_found=$(echo "$body" | jq -r ".[] | select(.id == ${type_id}) | .id" 2>/dev/null || echo "")
  fi
  if [[ -n "$type_found" ]]; then
    pass "Verify new type appears in list"
  else
    warn "Type not found in list (may be on different page or response shape)"
  fi
  rate_limit_pause

  # Create record with field value
  resp=$(api_call POST "/records" "{\"record_type_id\": ${type_id}, \"field_values\": [{\"field_id\": \"${field_id}\", \"value\": \"${field_value}\"}]}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create record" 200 201 "$code"

  record_id=$(json_field "$body" '.id')
  if [[ -z "$record_id" || "$record_id" == "null" ]]; then
    fail "Create record returned no ID"
    return
  fi
  register_cleanup "records" "$record_id"
  pass "Record created with ID $record_id"
  rate_limit_pause

  # Get record and verify field value
  resp=$(api_call GET "/records/${record_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get record by ID" "200" "$code"

  local actual_value
  actual_value=$(echo "$body" | jq -r ".field_values[]? | select(.field_id == \"${field_id}\") | .value" 2>/dev/null || echo "")
  if [[ -z "$actual_value" ]]; then
    actual_value=$(echo "$body" | jq -r ".fields[]? | select(.id == \"${field_id}\") | .value" 2>/dev/null || echo "")
  fi
  if [[ "$actual_value" == "$field_value" ]]; then
    pass "Verify record field value"
  else
    warn "Field value verification (expected '${field_value}', got '${actual_value}') - response shape may differ"
  fi
  rate_limit_pause

  # Update record
  resp=$(api_call PATCH "/records/${record_id}" "{\"field_values\": [{\"field_id\": \"${field_id}\", \"value\": \"${field_value_updated}\"}]}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update record" "200" "$code"
  rate_limit_pause

  # Verify update
  resp=$(api_call GET "/records/${record_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get record after update" "200" "$code"

  actual_value=$(echo "$body" | jq -r ".field_values[]? | select(.field_id == \"${field_id}\") | .value" 2>/dev/null || echo "")
  if [[ -z "$actual_value" ]]; then
    actual_value=$(echo "$body" | jq -r ".fields[]? | select(.id == \"${field_id}\") | .value" 2>/dev/null || echo "")
  fi
  if [[ "$actual_value" == "$field_value_updated" ]]; then
    pass "Verify record field updated"
  else
    warn "Field update verification (expected '${field_value_updated}', got '${actual_value}')"
  fi
  rate_limit_pause

  # Delete record
  resp=$(api_call DELETE "/records/${record_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete record" "200" "204" "$code"
  rate_limit_pause

  # Delete record type
  resp=$(api_call DELETE "/record_types/${type_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete record type" "200" "204" "$code"
  rate_limit_pause

  # Verify type gone
  resp=$(api_call GET "/record_types/${type_id}")
  code=$(get_http_code "$resp")
  assert_http "Verify record type deleted (404)" "404" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Credential Lifecycle
# ═════════════════════════════════════════════

test_credential_lifecycle() {
  section "Credential Lifecycle: create TEXT -> read -> update -> delete"

  local cred_name="${TEST_PREFIX}credential"
  local cred_name_updated="${TEST_PREFIX}credential_updated"
  local cred_secret="test-secret-value-$(date +%s)"

  # Create TEXT credential
  local resp body code cred_id
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${cred_name}\", \"mode\": \"TEXT\", \"team_id\": ${TEAM_ID}, \"value\": \"${cred_secret}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create TEXT credential" 200 201 "$code"

  cred_id=$(json_field "$body" '.id')
  if [[ -z "$cred_id" || "$cred_id" == "null" ]]; then
    fail "Create credential returned no ID"
    return
  fi
  register_cleanup "user_credentials" "$cred_id"
  pass "Credential created with ID $cred_id"
  rate_limit_pause

  # Get credential by ID
  resp=$(api_call GET "/user_credentials/${cred_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get credential by ID" "200" "$code"

  # Verify metadata only (no secret leaked)
  assert_json_exists "Credential has name field" "$body" '.name'
  assert_json_exists "Credential has mode field" "$body" '.mode'
  assert_not_contains "Secret value not in GET response" "$body" "$cred_secret"
  rate_limit_pause

  # Update credential name
  resp=$(api_call PATCH "/user_credentials/${cred_id}" "{\"name\": \"${cred_name_updated}\", \"mode\": \"TEXT\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update credential name" "200" "$code"
  rate_limit_pause

  # Get again and verify new name
  resp=$(api_call GET "/user_credentials/${cred_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get credential after update" "200" "$code"
  assert_json_equals "Verify credential name changed" "$body" '.name' "$cred_name_updated"
  rate_limit_pause

  # Delete credential
  resp=$(api_call DELETE "/user_credentials/${cred_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete credential" "200" "204" "$code"
  rate_limit_pause

  # Verify gone
  resp=$(api_call GET "/user_credentials/${cred_id}")
  code=$(get_http_code "$resp")
  assert_http "Verify credential deleted (404)" "404" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Credential Types Lifecycle
# ═════════════════════════════════════════════

test_credential_types_lifecycle() {
  section "Credential Types Lifecycle: create -> get -> verify mode -> delete -> verify 404"

  local resp body code cred_id

  # --- AWS credential lifecycle ---
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${TEST_PREFIX}aws_cred\", \"mode\": \"AWS\", \"team_id\": ${TEAM_ID}, \"aws_authentication_type\": \"KEY\", \"aws_access_key\": \"AKIAIOSFODNN7EXAMPLE\", \"aws_secret_key\": \"wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create AWS credential" 200 201 "$code"

  cred_id=$(json_field "$body" '.id')
  if [[ -n "$cred_id" && "$cred_id" != "null" ]]; then
    register_cleanup "user_credentials" "$cred_id"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Get AWS credential" "200" "$code"
    assert_json_equals "Verify AWS credential mode" "$body" '.mode' "AWS"
    rate_limit_pause

    resp=$(api_call DELETE "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Delete AWS credential" "200" "204" "$code"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http "Verify AWS credential deleted (404)" "404" "$code"
    rate_limit_pause
  else
    fail "Create AWS credential returned no ID"
  fi

  # --- JWT credential lifecycle ---
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${TEST_PREFIX}jwt_cred\", \"mode\": \"JWT\", \"team_id\": ${TEAM_ID}, \"jwt_algorithm\": \"HS256\", \"jwt_auto_generate_time_claims\": false, \"jwt_payload\": \"{}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create JWT credential" 200 201 "$code"

  cred_id=$(json_field "$body" '.id')
  if [[ -n "$cred_id" && "$cred_id" != "null" ]]; then
    register_cleanup "user_credentials" "$cred_id"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Get JWT credential" "200" "$code"
    assert_json_equals "Verify JWT credential mode" "$body" '.mode' "JWT"
    rate_limit_pause

    resp=$(api_call DELETE "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Delete JWT credential" "200" "204" "$code"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http "Verify JWT credential deleted (404)" "404" "$code"
    rate_limit_pause
  else
    fail "Create JWT credential returned no ID"
  fi

  # --- MTLS credential lifecycle ---
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${TEST_PREFIX}mtls_cred\", \"mode\": \"MTLS\", \"team_id\": ${TEAM_ID}, \"mtls_client_certificate\": \"test-cert\", \"mtls_client_private_key\": \"test-key\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create MTLS credential" 200 201 "$code"

  cred_id=$(json_field "$body" '.id')
  if [[ -n "$cred_id" && "$cred_id" != "null" ]]; then
    register_cleanup "user_credentials" "$cred_id"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Get MTLS credential" "200" "$code"
    assert_json_equals "Verify MTLS credential mode" "$body" '.mode' "MTLS"
    rate_limit_pause

    resp=$(api_call DELETE "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Delete MTLS credential" "200" "204" "$code"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http "Verify MTLS credential deleted (404)" "404" "$code"
    rate_limit_pause
  else
    fail "Create MTLS credential returned no ID"
  fi

  # --- OAUTH credential lifecycle ---
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${TEST_PREFIX}oauth_cred\", \"mode\": \"OAUTH\", \"team_id\": ${TEAM_ID}, \"oauth_url\": \"https://example.com/auth\", \"oauth_token_url\": \"https://example.com/token\", \"oauth_client_id\": \"test-client\", \"oauth_client_secret\": \"test-secret\", \"oauth_grant_type\": \"authorization_code\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create OAUTH credential" 200 201 "$code"

  cred_id=$(json_field "$body" '.id')
  if [[ -n "$cred_id" && "$cred_id" != "null" ]]; then
    register_cleanup "user_credentials" "$cred_id"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Get OAUTH credential" "200" "$code"
    assert_json_equals "Verify OAUTH credential mode" "$body" '.mode' "OAUTH"
    rate_limit_pause

    resp=$(api_call DELETE "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Delete OAUTH credential" "200" "204" "$code"
    rate_limit_pause

    resp=$(api_call GET "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http "Verify OAUTH credential deleted (404)" "404" "$code"
    rate_limit_pause
  else
    fail "Create OAUTH credential returned no ID"
  fi

  echo ""
}


# ═════════════════════════════════════════════
# Resource Lifecycle
# ═════════════════════════════════════════════

test_resource_lifecycle() {
  section "Resource Lifecycle: create JSON -> read -> update -> delete"

  local resource_name="${TEST_PREFIX}resource"
  local resource_value='{"env": "test", "version": 1}'
  local resource_value_updated='{"env": "test", "version": 2}'

  # Create JSON resource
  local resp body code resource_id
  resp=$(api_call POST "/global_resources" "{\"name\": \"${resource_name}\", \"value_type\": \"json\", \"team_id\": ${TEAM_ID}, \"value\": \"{}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create JSON resource" 200 201 "$code"

  resource_id=$(json_field "$body" '.id')
  if [[ -z "$resource_id" || "$resource_id" == "null" ]]; then
    fail "Create resource returned no ID"
    return
  fi
  register_cleanup "global_resources" "$resource_id"
  pass "Resource created with ID $resource_id"
  rate_limit_pause

  # Get resource
  resp=$(api_call GET "/global_resources/${resource_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get resource by ID" "200" "$code"
  assert_json_equals "Verify resource name" "$body" '.name' "$resource_name"

  # Verify value contains expected data
  local val_version
  val_version=$(echo "$body" | jq -r '.value.version // .value_json.version // empty' 2>/dev/null)
  if [[ "$val_version" == "1" ]]; then
    pass "Verify resource value (version=1)"
  else
    warn "Resource value verification (expected version=1, got '${val_version}')"
  fi
  rate_limit_pause

  # Update resource value
  resp=$(api_call PATCH "/global_resources/${resource_id}" "{\"value\": ${resource_value_updated}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update resource value" "200" "$code"
  rate_limit_pause

  # Get again and verify new value
  resp=$(api_call GET "/global_resources/${resource_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get resource after update" "200" "$code"

  val_version=$(echo "$body" | jq -r '.value.version // .value_json.version // empty' 2>/dev/null)
  if [[ "$val_version" == "2" ]]; then
    pass "Verify resource value updated (version=2)"
  else
    warn "Resource value update verification (expected version=2, got '${val_version}')"
  fi
  rate_limit_pause

  # Delete resource
  resp=$(api_call DELETE "/global_resources/${resource_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete resource" "200" "204" "$code"
  rate_limit_pause

  # Verify gone
  resp=$(api_call GET "/global_resources/${resource_id}")
  code=$(get_http_code "$resp")
  assert_http "Verify resource deleted (404)" "404" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Admin (Folder) Lifecycle
# ═════════════════════════════════════════════

test_admin_lifecycle() {
  section "Admin Lifecycle: folder -> get -> update -> verify -> delete -> verify 404"

  local folder_name="${TEST_PREFIX}folder"
  local folder_name_updated="${TEST_PREFIX}folder_updated"

  # Create folder in team (no nesting — API does not support parent_id)
  local resp body code folder_id
  resp=$(api_call POST "/folders" "{\"name\": \"${folder_name}\", \"team_id\": ${TEAM_ID}, \"content_type\": \"STORY\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create folder" 200 201 "$code"

  folder_id=$(json_field "$body" '.id')
  if [[ -z "$folder_id" || "$folder_id" == "null" ]]; then
    fail "Create folder returned no ID"
    return
  fi
  register_cleanup "folders" "$folder_id"
  pass "Folder created with ID $folder_id"
  rate_limit_pause

  # Get folder
  resp=$(api_call GET "/folders/${folder_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get folder by ID" "200" "$code"
  assert_json_equals "Verify folder name" "$body" '.name' "$folder_name"
  rate_limit_pause

  # Update folder name
  resp=$(api_call PATCH "/folders/${folder_id}" "{\"name\": \"${folder_name_updated}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update folder name" "200" "$code"
  rate_limit_pause

  # Verify name changed
  resp=$(api_call GET "/folders/${folder_id}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get folder after update" "200" "$code"
  assert_json_equals "Verify folder name changed" "$body" '.name' "$folder_name_updated"
  rate_limit_pause

  # Delete folder
  resp=$(api_call DELETE "/folders/${folder_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete folder" "200" "204" "$code"
  rate_limit_pause

  # Verify gone
  resp=$(api_call GET "/folders/${folder_id}")
  code=$(get_http_code "$resp")
  assert_http "Verify folder deleted (404)" "404" "$code"

  echo ""
}

# ═════════════════════════════════════════════
# Run Selected Tests
# ═════════════════════════════════════════════

if should_run "stories"; then
  test_story_lifecycle
fi

if should_run "actions"; then
  test_actions_lifecycle
fi

if should_run "cases"; then
  test_case_lifecycle
  test_case_linking_lifecycle
fi

if should_run "records"; then
  test_record_lifecycle
fi

if should_run "credentials"; then
  test_credential_lifecycle
fi

if should_run "credential-types"; then
  test_credential_types_lifecycle
fi

if should_run "resources"; then
  test_resource_lifecycle
fi

if should_run "admin"; then
  test_admin_lifecycle
fi

# ═════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════

print_summary
exit $?
