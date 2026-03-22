#!/usr/bin/env bash
#
# Write operations tests for Tines Agent Skills
# Tests all POST/PUT/PATCH/DELETE operations against a real Tines tenant.
#
# Prerequisites:
#   export TINES_TENANT_URL="https://your-tenant.tines.com"
#   export TINES_API_TOKEN="your-api-token"
#
# Usage:
#   ./tests/test-write-operations.sh                  Run all tests
#   ./tests/test-write-operations.sh stories          Run only stories tests
#   ./tests/test-write-operations.sh actions           Run only actions tests
#   ./tests/test-write-operations.sh cases             Run only cases tests
#   ./tests/test-write-operations.sh records           Run only records tests
#   ./tests/test-write-operations.sh credentials       Run only credentials tests
#   ./tests/test-write-operations.sh admin             Run only admin tests
#   ./tests/test-write-operations.sh --dry-run         Dry run (no API calls)
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
fi

should_run() {
  [[ "$TEST_FILTER" == "all" || "$TEST_FILTER" == "$1" ]]
}

init_test_env "Write Operations Tests"

# ─────────────────────────────────────────────
# Discover shared prerequisites
# ─────────────────────────────────────────────

TEAM_ID=$(discover_team_id)
if [[ -z "$TEAM_ID" || "$TEAM_ID" == "null" ]]; then
  echo -e "${RED}Cannot discover team_id. Aborting.${NC}"
  exit 1
fi
echo "Team ID: $TEAM_ID"
echo ""

# ─────────────────────────────────────────────
# Stories
# ─────────────────────────────────────────────

test_stories() {
  section "Stories — Write Operations"

  local story_name="${TEST_PREFIX}story"
  local resp body code story_id

  # Create story
  resp=$(api_call POST "/stories" "{\"name\": \"${story_name}\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create story" "200" "201" "$code"
  assert_json_exists "Create story — has id" "$body" ".id"
  assert_json_equals "Create story — name matches" "$body" ".name" "$story_name"
  story_id=$(json_field "$body" ".id")
  register_cleanup "stories" "$story_id"
  rate_limit_pause

  if [[ -z "$story_id" || "$story_id" == "null" ]]; then
    skip "Remaining story tests (create failed)"
    return
  fi

  # Update story name
  local updated_name="${TEST_PREFIX}story_updated"
  resp=$(api_call PUT "/stories/${story_id}" "{\"name\": \"${updated_name}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update story name" "200" "$code"
  assert_json_equals "Update story — name changed" "$body" ".name" "$updated_name"
  rate_limit_pause

  # Export story
  resp=$(api_call GET "/stories/${story_id}/export")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Export story" "200" "$code"
  assert_json_exists "Export story — has name" "$body" ".name"
  rate_limit_pause

  # Create version
  resp=$(api_call POST "/stories/${story_id}/versions" "{\"name\": \"${TEST_PREFIX}v1.0\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create story version" "200" "201" "$code"
  rate_limit_pause

  # Delete story (cleanup will also attempt, but explicit test is needed)
  resp=$(api_call DELETE "/stories/${story_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete story" "200" "204" "$code"
  rate_limit_pause

  echo ""
}

# ─────────────────────────────────────────────
# Actions / Agents
# ─────────────────────────────────────────────

test_actions() {
  section "Actions (Agents) — Write Operations"

  # Create a story to hold the agent
  local story_name="${TEST_PREFIX}action_story"
  local resp body code story_id agent_id

  resp=$(api_call POST "/stories" "{\"name\": \"${story_name}\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  story_id=$(json_field "$body" ".id")
  register_cleanup "stories" "$story_id"
  rate_limit_pause

  if [[ -z "$story_id" || "$story_id" == "null" ]]; then
    skip "Action tests (story creation failed)"
    return
  fi

  # Create agent
  local agent_name="${TEST_PREFIX}agent"
  resp=$(api_call POST "/agents" "{\"story_id\": ${story_id}, \"name\": \"${agent_name}\", \"type\": \"Agents::EventTransformationAgent\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create agent" "200" "201" "$code"
  assert_json_exists "Create agent — has id" "$body" ".id"
  assert_json_equals "Create agent — name matches" "$body" ".name" "$agent_name"
  agent_id=$(json_field "$body" ".id")
  register_cleanup "agents" "$agent_id"
  rate_limit_pause

  if [[ -z "$agent_id" || "$agent_id" == "null" ]]; then
    skip "Remaining agent tests (create failed)"
    return
  fi

  # Update agent
  local updated_agent_name="${TEST_PREFIX}agent_updated"
  resp=$(api_call PUT "/agents/${agent_id}" "{\"name\": \"${updated_agent_name}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update agent" "200" "$code"
  assert_json_equals "Update agent — name changed" "$body" ".name" "$updated_agent_name"
  rate_limit_pause

  # Delete agent logs
  resp=$(api_call DELETE "/agents/${agent_id}/logs")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete agent logs" "200" "204" "404" "$code"
  rate_limit_pause

  # Delete agent
  resp=$(api_call DELETE "/agents/${agent_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete agent" "200" "204" "$code"
  rate_limit_pause

  echo ""
}

# ─────────────────────────────────────────────
# Cases
# ─────────────────────────────────────────────

test_cases() {
  section "Cases — Write Operations"

  local case_name="${TEST_PREFIX}case"
  local resp body code case_id

  # Create case
  resp=$(api_call POST "/cases" "{\"name\": \"${case_name}\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create case" "200" "201" "$code"
  assert_json_exists "Create case — has case_id" "$body" ".case_id"
  assert_json_equals "Create case — name matches" "$body" ".name" "$case_name"
  case_id=$(json_field "$body" ".case_id")
  register_cleanup "cases" "$case_id"
  rate_limit_pause

  if [[ -z "$case_id" || "$case_id" == "null" ]]; then
    skip "Remaining case tests (create failed)"
    return
  fi

  # Update case status (API only allows "OPEN" or "CLOSED")
  resp=$(api_call PATCH "/cases/${case_id}" '{"status": "CLOSED"}')
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update case status" "200" "$code"
  assert_json_equals "Update case — status changed" "$body" ".status" "CLOSED"
  rate_limit_pause

  # Set case description (API replaces description, no append mode)
  resp=$(api_call PATCH "/cases/${case_id}" '{"description": "Test appended text."}')
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Set case description" "200" "$code"
  rate_limit_pause

  # --- Metadata (set via PATCH on the case itself) ---
  resp=$(api_call PATCH "/cases/${case_id}" '{"metadata":{"test_key":"test_value"}}')
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Set case metadata" "200" "$code"
  rate_limit_pause

  # Verify metadata via GET
  resp=$(api_call GET "/cases/${case_id}/metadata")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Get case metadata" "200" "$code"
  local meta_val
  meta_val=$(json_field "$body" '.metadata.test_key')
  if [[ "$meta_val" == "test_value" ]]; then
    pass "Verify case metadata value"
  else
    fail "Verify case metadata value (expected 'test_value', got '$meta_val')"
  fi
  rate_limit_pause

  # Update metadata
  resp=$(api_call PATCH "/cases/${case_id}" '{"metadata":{"test_key":"updated_value"}}')
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update case metadata" "200" "$code"
  rate_limit_pause

  # Delete metadata (set key to null)
  resp=$(api_call PATCH "/cases/${case_id}" '{"metadata":{"test_key":null}}')
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Delete case metadata" "200" "$code"
  rate_limit_pause

  # --- Linked cases ---
  local case2_name="${TEST_PREFIX}case_linked"
  local case2_id
  resp=$(api_call POST "/cases" "{\"name\": \"${case2_name}\", \"team_id\": ${TEAM_ID}}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  case2_id=$(json_field "$body" ".case_id")
  register_cleanup "cases" "$case2_id"
  rate_limit_pause

  if [[ -n "$case2_id" && "$case2_id" != "null" ]]; then
    # Link cases (may 404 on some plans)
    resp=$(api_call POST "/cases/${case_id}/linked_cases" "{\"linked_case_id\": ${case2_id}}")
    code=$(get_http_code "$resp")
    if [[ "$code" == "404" ]]; then
      skip "Link cases (HTTP 404 — endpoint not available on this plan)"
    else
      assert_http_one_of "Link cases" "200" "201" "$code"
      rate_limit_pause

      # Unlink cases
      resp=$(api_call DELETE "/cases/${case_id}/linked_cases/${case2_id}")
      code=$(get_http_code "$resp")
      assert_http_one_of "Unlink cases" "200" "204" "$code"
      rate_limit_pause
    fi
  else
    skip "Linked case tests (second case create failed)"
  fi

  # --- Subscribers ---
  # Discover current user for subscriber test
  local user_resp user_body user_id
  user_resp=$(api_call GET "/admin/users?per_page=1")
  user_body=$(get_body "$user_resp")
  user_id=$(json_field "$user_body" '.admin_users[0].id')

  if [[ -n "$user_id" && "$user_id" != "null" ]]; then
    local sub_id
    resp=$(api_call POST "/cases/${case_id}/subscribers" "{\"user_id\": ${user_id}}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http_one_of "Add case subscriber" "200" "201" "$code"
    sub_id=$(json_field "$body" ".id")
    rate_limit_pause

    if [[ -n "$sub_id" && "$sub_id" != "null" ]]; then
      resp=$(api_call DELETE "/cases/${case_id}/subscribers/${sub_id}")
      code=$(get_http_code "$resp")
      assert_http_one_of "Remove case subscriber" "200" "204" "$code"
      rate_limit_pause
    else
      skip "Remove subscriber (add returned no id)"
    fi
  else
    skip "Subscriber tests (cannot discover user_id)"
  fi

  # Delete case
  resp=$(api_call DELETE "/cases/${case_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete case" "200" "204" "$code"
  rate_limit_pause

  echo ""
}

# ─────────────────────────────────────────────
# Records
# ─────────────────────────────────────────────

test_records() {
  section "Records — Write Operations"

  local resp body code

  # Create record type
  local rt_name="${TEST_PREFIX}record_type"
  resp=$(api_call POST "/record_types" "{\"name\": \"${rt_name}\", \"team_id\": ${TEAM_ID}, \"editable\": true, \"fields\": [{\"name\": \"Test Field\", \"result_type\": \"TEXT\"}]}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create record type" "200" "201" "$code"
  assert_json_exists "Create record type — has id" "$body" ".id"

  local rt_id field_id
  rt_id=$(json_field "$body" ".id")
  field_id=$(json_field "$body" ".record_fields[0].id")
  register_cleanup "record_types" "$rt_id"
  rate_limit_pause

  if [[ -z "$rt_id" || "$rt_id" == "null" ]]; then
    skip "Remaining record tests (record type create failed)"
    return
  fi

  if [[ -z "$field_id" || "$field_id" == "null" ]]; then
    skip "Record CRUD tests (no field_id returned)"
    return
  fi

  # Create record
  resp=$(api_call POST "/records" "{\"record_type_id\": ${rt_id}, \"field_values\": [{\"field_id\": \"${field_id}\", \"value\": \"initial\"}]}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create record" "200" "201" "$code"
  assert_json_exists "Create record — has id" "$body" ".id"

  local record_id
  record_id=$(json_field "$body" ".id")
  register_cleanup "records" "$record_id"
  rate_limit_pause

  if [[ -z "$record_id" || "$record_id" == "null" ]]; then
    skip "Remaining record tests (record create failed)"
    return
  fi

  # Update record
  resp=$(api_call PATCH "/records/${record_id}" "{\"field_values\": [{\"field_id\": \"${field_id}\", \"value\": \"updated\"}]}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http "Update record" "200" "$code"
  rate_limit_pause

  # Delete record
  resp=$(api_call DELETE "/records/${record_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete record" "200" "204" "$code"
  rate_limit_pause

  # Delete record type
  resp=$(api_call DELETE "/record_types/${rt_id}")
  code=$(get_http_code "$resp")
  assert_http_one_of "Delete record type" "200" "204" "$code"
  rate_limit_pause

  echo ""
}

# ─────────────────────────────────────────────
# Credentials
# ─────────────────────────────────────────────

test_credentials() {
  section "Credentials — Write Operations"

  local resp body code

  # --- TEXT credential ---
  local cred_name="${TEST_PREFIX}cred"
  local secret_value="super-secret-value-$(date +%s)"

  resp=$(api_call POST "/user_credentials" "{\"name\": \"${cred_name}\", \"mode\": \"TEXT\", \"team_id\": ${TEAM_ID}, \"value\": \"${secret_value}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create TEXT credential" "200" "201" "$code"
  assert_json_exists "Create credential — has id" "$body" ".id"
  assert_json_equals "Create credential — mode is TEXT" "$body" ".mode" "TEXT"

  # Verify secret is not leaked in response
  assert_not_contains "Create credential — secret not in response" "$body" "$secret_value"

  local cred_id
  cred_id=$(json_field "$body" ".id")
  register_cleanup "user_credentials" "$cred_id"
  rate_limit_pause

  if [[ -n "$cred_id" && "$cred_id" != "null" ]]; then
    # Update credential name
    local updated_cred_name="${TEST_PREFIX}cred_updated"
    resp=$(api_call PATCH "/user_credentials/${cred_id}" "{\"name\": \"${updated_cred_name}\", \"mode\": \"TEXT\"}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Update credential name" "200" "$code"
    assert_json_equals "Update credential — name changed" "$body" ".name" "$updated_cred_name"
    rate_limit_pause

    # Delete credential
    resp=$(api_call DELETE "/user_credentials/${cred_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Delete credential" "200" "204" "$code"
    rate_limit_pause
  else
    skip "Credential update/delete (create returned no id)"
  fi


  # --- AWS credential ---
  local aws_cred_name="${TEST_PREFIX}aws_cred"
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${aws_cred_name}\", \"mode\": \"AWS\", \"team_id\": ${TEAM_ID}, \"aws_authentication_type\": \"KEY\", \"aws_access_key\": \"AKIAIOSFODNN7EXAMPLE\", \"aws_secret_key\": \"wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create AWS credential" "200" "201" "$code"
  assert_json_exists "Create AWS credential — has id" "$body" ".id"
  assert_json_equals "Create AWS credential — mode is AWS" "$body" ".mode" "AWS"

  local aws_cred_id
  aws_cred_id=$(json_field "$body" ".id")
  register_cleanup "user_credentials" "$aws_cred_id"
  rate_limit_pause

  # --- JWT credential ---
  local jwt_cred_name="${TEST_PREFIX}jwt_cred"
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${jwt_cred_name}\", \"mode\": \"JWT\", \"team_id\": ${TEAM_ID}, \"jwt_algorithm\": \"HS256\", \"jwt_auto_generate_time_claims\": false, \"jwt_payload\": \"{}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create JWT credential" "200" "201" "$code"
  assert_json_exists "Create JWT credential — has id" "$body" ".id"
  assert_json_equals "Create JWT credential — mode is JWT" "$body" ".mode" "JWT"

  local jwt_cred_id
  jwt_cred_id=$(json_field "$body" ".id")
  register_cleanup "user_credentials" "$jwt_cred_id"
  rate_limit_pause

  # --- MTLS credential ---
  local mtls_cred_name="${TEST_PREFIX}mtls_cred"
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${mtls_cred_name}\", \"mode\": \"MTLS\", \"team_id\": ${TEAM_ID}, \"mtls_client_certificate\": \"test-cert\", \"mtls_client_private_key\": \"test-key\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create MTLS credential" "200" "201" "$code"
  assert_json_exists "Create MTLS credential — has id" "$body" ".id"
  assert_json_equals "Create MTLS credential — mode is MTLS" "$body" ".mode" "MTLS"

  local mtls_cred_id
  mtls_cred_id=$(json_field "$body" ".id")
  register_cleanup "user_credentials" "$mtls_cred_id"
  rate_limit_pause

  # --- OAUTH credential ---
  local oauth_cred_name="${TEST_PREFIX}oauth_cred"
  resp=$(api_call POST "/user_credentials" "{\"name\": \"${oauth_cred_name}\", \"mode\": \"OAUTH\", \"team_id\": ${TEAM_ID}, \"oauth_url\": \"https://example.com/auth\", \"oauth_token_url\": \"https://example.com/token\", \"oauth_client_id\": \"test-client\", \"oauth_client_secret\": \"test-secret\", \"oauth_grant_type\": \"authorization_code\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create OAUTH credential" "200" "201" "$code"
  assert_json_exists "Create OAUTH credential — has id" "$body" ".id"
  assert_json_equals "Create OAUTH credential — mode is OAUTH" "$body" ".mode" "OAUTH"

  local oauth_cred_id
  oauth_cred_id=$(json_field "$body" ".id")
  register_cleanup "user_credentials" "$oauth_cred_id"
  rate_limit_pause

  # --- JSON resource ---
  local res_name="${TEST_PREFIX}resource"
  resp=$(api_call POST "/global_resources" "{\"name\": \"${res_name}\", \"value_type\": \"json\", \"team_id\": ${TEAM_ID}, \"value\": \"{}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create JSON resource" "200" "201" "$code"
  assert_json_exists "Create resource — has id" "$body" ".id"

  local res_id
  res_id=$(json_field "$body" ".id")
  register_cleanup "global_resources" "$res_id"
  rate_limit_pause

  if [[ -n "$res_id" && "$res_id" != "null" ]]; then
    # Update resource
    resp=$(api_call PATCH "/global_resources/${res_id}" '{"value": {"test": false, "updated": true}}')
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Update resource" "200" "$code"
    rate_limit_pause

    # Delete resource
    resp=$(api_call DELETE "/global_resources/${res_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Delete resource" "200" "204" "$code"
    rate_limit_pause
  else
    skip "Resource update/delete (create returned no id)"
  fi

  echo ""
}

# ─────────────────────────────────────────────
# Admin
# ─────────────────────────────────────────────

test_admin() {
  section "Admin — Write Operations"

  local resp body code

  # --- Create team ---
  local team_name="${TEST_PREFIX}team"
  resp=$(api_call POST "/teams" "{\"name\": \"${team_name}\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create team" "200" "201" "$code"
  assert_json_exists "Create team — has id" "$body" ".id"

  local new_team_id
  new_team_id=$(json_field "$body" ".id")
  register_cleanup "teams" "$new_team_id"
  rate_limit_pause

  if [[ -n "$new_team_id" && "$new_team_id" != "null" ]]; then
    # Update team
    local updated_team_name="${TEST_PREFIX}team_updated"
    resp=$(api_call PATCH "/teams/${new_team_id}" "{\"name\": \"${updated_team_name}\"}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Update team" "200" "$code"
    assert_json_equals "Update team — name changed" "$body" ".name" "$updated_team_name"
    rate_limit_pause
  else
    skip "Team update (create returned no id)"
  fi

  # --- Create folder ---
  local folder_name="${TEST_PREFIX}folder"
  resp=$(api_call POST "/folders" "{\"name\": \"${folder_name}\", \"team_id\": ${TEAM_ID}, \"content_type\": \"STORY\"}")
  code=$(get_http_code "$resp")
  body=$(get_body "$resp")
  assert_http_one_of "Create folder" "200" "201" "$code"
  assert_json_exists "Create folder — has id" "$body" ".id"

  local folder_id
  folder_id=$(json_field "$body" ".id")
  register_cleanup "folders" "$folder_id"
  rate_limit_pause

  if [[ -n "$folder_id" && "$folder_id" != "null" ]]; then
    # Update folder name
    local updated_folder="${TEST_PREFIX}folder_renamed"
    resp=$(api_call PATCH "/folders/${folder_id}" "{\"name\": \"${updated_folder}\"}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    assert_http "Update folder" "200" "$code"
    assert_json_equals "Update folder — name changed" "$body" ".name" "$updated_folder"
    rate_limit_pause

    # Delete folder
    resp=$(api_call DELETE "/folders/${folder_id}")
    code=$(get_http_code "$resp")
    assert_http_one_of "Delete folder" "200" "204" "$code"
    rate_limit_pause

    # Verify folder gone
    resp=$(api_call GET "/folders/${folder_id}")
    code=$(get_http_code "$resp")
    assert_http "Verify folder deleted (404)" "404" "$code"
    rate_limit_pause
  else
    skip "Folder update/delete (create returned no id)"
  fi

  # --- Template (best-effort, requires a story) ---
  local template_story_id
  template_story_id=$(discover_story_id)

  if [[ -n "$template_story_id" && "$template_story_id" != "null" ]]; then
    local tmpl_name="${TEST_PREFIX}template"
    resp=$(api_call POST "/admin/templates" "{\"name\": \"${tmpl_name}\", \"story_id\": ${template_story_id}}")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")

    if [[ "$code" == "201" || "$code" == "200" ]]; then
      pass "Create admin template (HTTP $code)"
      local tmpl_id
      tmpl_id=$(json_field "$body" ".id")
      if [[ -n "$tmpl_id" && "$tmpl_id" != "null" ]]; then
        register_cleanup "admin/templates" "$tmpl_id"
        rate_limit_pause

        resp=$(api_call DELETE "/admin/templates/${tmpl_id}")
        code=$(get_http_code "$resp")
        assert_http_one_of "Delete admin template" "200" "204" "$code"
        rate_limit_pause
      fi
    elif [[ "$code" == "400" || "$code" == "403" || "$code" == "404" || "$code" == "422" ]]; then
      skip "Create admin template (HTTP $code — insufficient permissions or unavailable)"
    else
      fail "Create admin template (expected 200/201/400/403/404/422, got $code)"
    fi
  else
    skip "Admin template tests (no stories available)"
  fi

  echo ""
}

# ─────────────────────────────────────────────
# Run test groups
# ─────────────────────────────────────────────

should_run "stories"     && test_stories
should_run "actions"     && test_actions
should_run "cases"       && test_cases
should_run "records"     && test_records
should_run "credentials" && test_credentials
should_run "admin"       && test_admin

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

print_summary
