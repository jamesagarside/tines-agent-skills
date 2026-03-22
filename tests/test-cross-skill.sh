#!/usr/bin/env bash
#
# Cross-skill consistency tests for Tines Agent Skills.
# Validates structural consistency across SKILL.md files and behavioral
# consistency of the Tines API responses against skill assumptions.
#
# Usage:
#   ./tests/test-cross-skill.sh              Run all tests
#   ./tests/test-cross-skill.sh --dry-run    Structural tests only (no API calls)
#
set -uo pipefail

source "$(dirname "$0")/helpers/test-helpers.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills/tines"

for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

init_test_env "Cross-Skill Consistency Tests"

SKILL_FILES=()
while IFS= read -r -d '' f; do
  SKILL_FILES+=("$f")
done < <(find "$SKILLS_DIR" -name "SKILL.md" -print0 2>/dev/null)

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
  echo -e "${RED}No skill files found in $SKILLS_DIR${NC}"
  exit 1
fi
echo "Found ${#SKILL_FILES[@]} skill files"
echo ""

skill_name() { basename "$(dirname "$1")"; }

# Returns expected keywords for a given skill name
expected_keywords_for() {
  case "$1" in
    tines-actions)     echo "events|logs|re-emit|memory" ;;
    tines-admin)       echo "users|audit|jobs|teams" ;;
    tines-auth)        echo "connect|verify|credentials|token|authenticate" ;;
    tines-cases)       echo "comments|tasks|files|metadata" ;;
    tines-credentials) echo "credentials|secrets|resources" ;;
    tines-records)     echo "records|record.types|record.views" ;;
    tines-stories)     echo "export|import|runs" ;;
    tines-build)       echo "build|design|workflow|action.type|story.JSON" ;;
    tines-review)      echo "review|quality|best.practice|naming|security" ;;
    tines-audit)       echo "audit|tenant|unused|credential|health" ;;
    *)                 echo "" ;;
  esac
}

# ==========================================================================
# 1. STRUCTURAL CONSISTENCY (no API needed)
# ==========================================================================

section "1. Structural Consistency"
echo ""

# 1a — All skills use TINES_BASE_URL variable (not hardcoded URLs)
section "1a. TINES_BASE_URL usage (no hardcoded URLs)"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  if grep -qE 'https?://[a-zA-Z0-9-]+\.tines\.com/api' "$f"; then
    fail "$name — contains hardcoded Tines URL"
  elif grep -q 'TINES_BASE_URL' "$f"; then
    pass "$name — uses TINES_BASE_URL variable"
  else
    fail "$name — does not reference TINES_BASE_URL"
  fi
done
echo ""

# 1b — Non-auth skills document prerequisites mentioning env vars
section "1b. Prerequisites document env vars"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  if grep -q 'TINES_TENANT_URL' "$f" && grep -q 'TINES_API_TOKEN' "$f"; then
    pass "$name — documents required env vars"
  else
    fail "$name — missing env var prerequisites"
  fi
done
echo ""

# 1c — DELETE operations have DESTRUCTIVE/confirm warnings
section "1c. DELETE operations have DESTRUCTIVE warnings"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  if grep -q 'DELETE' "$f"; then
    if grep -qi 'DESTRUCTIVE\|confirm with user' "$f"; then
      pass "$name — DELETE operations have safety warnings"
    else
      fail "$name — DELETE operations lack DESTRUCTIVE/confirm warnings"
    fi
  else
    skip "$name — no DELETE operations"
  fi
done
echo ""

# 1d — POST/PUT/PATCH curl commands include Content-Type header
section "1d. POST/PUT/PATCH commands include Content-Type header"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  has_write=false; missing_ct=false
  while IFS= read -r line; do
    has_write=true
    line_num=$(grep -nF "$line" "$f" 2>/dev/null | head -1 | cut -d: -f1)
    if [[ -n "$line_num" ]]; then
      start=$((line_num > 3 ? line_num - 3 : 1))
      context=$(sed -n "${start},$((line_num + 3))p" "$f")
      if ! echo "$context" | grep -q 'Content-Type'; then
        # Only flag if using -d (JSON data), not -F (multipart file upload)
        if echo "$context" | grep -qE '\-d\s' && ! echo "$context" | grep -q '\-F '; then
          missing_ct=true
        fi
      fi
    fi
  done < <(grep -E 'curl.*-X (POST|PUT|PATCH)' "$f" | grep -v '^\s*#')
  if [[ "$has_write" == false ]]; then
    skip "$name — no POST/PUT/PATCH commands"
  elif [[ "$missing_ct" == true ]]; then
    fail "$name — POST/PUT/PATCH with body missing Content-Type header"
  else
    pass "$name — write commands include Content-Type"
  fi
done
echo ""

# 1e — No skill uses .actions[] in jq (should be .agents[])
section "1e. No .actions[] in jq (should be .agents[])"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  if grep -q '\.actions\[\]' "$f"; then
    fail "$name — uses .actions[] instead of .agents[] in jq"
  else
    pass "$name — correct (no .actions[] in jq)"
  fi
done
echo ""

# 1f — tines-cases uses case_id not bare id in jq for case resources
section "1f. tines-cases uses case_id in jq selectors"
cases_file="$SKILLS_DIR/tines-cases/SKILL.md"
if [[ -f "$cases_file" ]]; then
  if grep -qE 'jq.*case_id' "$cases_file"; then
    pass "tines-cases — uses case_id in jq selectors"
  else
    fail "tines-cases — missing case_id in jq selectors"
  fi
else
  skip "tines-cases SKILL.md not found"
fi
echo ""

# 1g — All skills use -s -f flags on curl commands
section "1g. Curl commands use -s -f flags"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  curl_count=$(grep -c 'curl ' "$f" 2>/dev/null || echo "0")
  if [[ "$curl_count" -eq 0 ]]; then skip "$name — no curl commands"; continue; fi
  missing_flags=false
  while IFS= read -r line; do
    if ! echo "$line" | grep -qE '\-[a-z]*s[a-z]*f|\-[a-z]*f[a-z]*s|\-s.*\-f|\-f.*\-s'; then
      missing_flags=true
    fi
  done < <(grep -E '^\s*curl |curl -' "$f" | grep -v '^\s*#')
  if [[ "$missing_flags" == true ]]; then
    fail "$name — some curl commands missing -s -f flags"
  else
    pass "$name — curl commands use -s -f flags"
  fi
done
echo ""

# 1h — All skills pipe to jq for structured output
section "1h. Curl commands pipe to jq"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  get_curls=$(grep 'curl ' "$f" | grep -v 'DELETE' | grep -v '\-o ' | grep -v '^\s*#' || true)
  if [[ -z "$get_curls" ]]; then skip "$name — no relevant curl commands"; continue; fi
  has_jq=$(echo "$get_curls" | grep -c 'jq' || echo "0")
  total=$(echo "$get_curls" | wc -l | tr -d ' ')
  if [[ "$has_jq" -gt 0 ]]; then
    pass "$name — pipes output to jq ($has_jq/$total commands)"
  else
    fail "$name — no curl commands pipe to jq"
  fi
done
echo ""

# 1i — All skills have token security warning (CRITICAL/never echo)
section "1i. Token security warning present"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  if grep -qi 'CRITICAL' "$f" && grep -qiE 'never.*(echo|log|output|print)' "$f"; then
    pass "$name — has CRITICAL token security warning"
  else
    fail "$name — missing CRITICAL/never-echo token security warning"
  fi
done
echo ""

# 1j — tines-records references team_id for record_types
section "1j. tines-records documents team_id for record_types"
records_file="$SKILLS_DIR/tines-records/SKILL.md"
if [[ -f "$records_file" ]]; then
  if grep -q 'team_id' "$records_file" && grep -qi 'record.type' "$records_file"; then
    pass "tines-records — documents team_id requirement for record_types"
  else
    fail "tines-records — missing team_id requirement for record_types"
  fi
else
  skip "tines-records SKILL.md not found"
fi

# 1k — tines-records references record_type_id for records listing
section "1k. tines-records documents record_type_id for records listing"
if [[ -f "$records_file" ]]; then
  if grep -q 'record_type_id' "$records_file"; then
    pass "tines-records — documents record_type_id requirement"
  else
    fail "tines-records — missing record_type_id requirement"
  fi
else
  skip "tines-records SKILL.md not found"
fi
echo ""

# ==========================================================================
# 2. API BEHAVIORAL CONSISTENCY (needs API)
# ==========================================================================

section "2. API Behavioral Consistency"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}Skipping API tests (--dry-run mode)${NC}"
  echo ""
else
  # 2a — /agents and /actions return identical response structure
  section "2a. /agents and /actions endpoint equivalence"
  resp_agents=$(api_call GET "/agents?per_page=1")
  body_agents=$(get_body "$resp_agents")
  resp_actions=$(api_call GET "/actions?per_page=1")
  body_actions=$(get_body "$resp_actions")
  assert_http "/agents returns 200" "200" "$(get_http_code "$resp_agents")"
  assert_http "/actions returns 200" "200" "$(get_http_code "$resp_actions")"
  assert_json_exists "/agents response has .agents key" "$body_agents" ".agents"
  assert_json_exists "/actions response has .agents key" "$body_actions" ".agents"
  echo ""

  # 2b — Cases response uses case_id field
  section "2b. Cases use case_id field"
  resp_cases=$(api_call GET "/cases?per_page=1")
  code_cases=$(get_http_code "$resp_cases")
  body_cases=$(get_body "$resp_cases")
  assert_http "/cases returns 200" "200" "$code_cases"
  first_case=$(echo "$body_cases" | jq '.cases[0]' 2>/dev/null)
  if [[ "$first_case" != "null" && -n "$first_case" ]]; then
    assert_json_exists "First case has case_id" "$first_case" ".case_id"
    has_bare_id=$(echo "$first_case" | jq 'has("id")' 2>/dev/null)
    if [[ "$has_bare_id" == "true" ]]; then
      warn "Cases have both case_id and id — skills should prefer case_id"
    else
      pass "Cases use case_id without bare id at top level"
    fi
  else
    skip "No cases available to test case_id field"
  fi
  echo ""

  # 2c — Stories response uses id field
  section "2c. Stories use id field"
  resp_stories=$(api_call GET "/stories?per_page=1")
  body_stories=$(get_body "$resp_stories")
  assert_http "/stories returns 200" "200" "$(get_http_code "$resp_stories")"
  first_story=$(echo "$body_stories" | jq '.stories[0]' 2>/dev/null)
  if [[ "$first_story" != "null" && -n "$first_story" ]]; then
    assert_json_exists "First story has id field" "$first_story" ".id"
  else
    skip "No stories available to test id field"
  fi
  echo ""

  # 2d — All list endpoints return consistent meta structure
  section "2d. Consistent meta structure across list endpoints"
  endpoints=("stories" "cases" "agents" "teams" "user_credentials")
  meta_keys_baseline=""
  for ep in "${endpoints[@]}"; do
    resp=$(api_call GET "/${ep}?per_page=1")
    code=$(get_http_code "$resp")
    body=$(get_body "$resp")
    if [[ "$code" != "200" ]]; then fail "/${ep} did not return 200 (got $code)"; continue; fi
    meta=$(echo "$body" | jq -r '.meta | keys | sort | join(",")' 2>/dev/null)
    if [[ -z "$meta" || "$meta" == "null" ]]; then fail "/${ep} — missing meta object"; continue; fi
    if [[ -z "$meta_keys_baseline" ]]; then
      meta_keys_baseline="$meta"
      pass "/${ep} — meta keys: $meta (baseline)"
    elif [[ "$meta" == "$meta_keys_baseline" ]]; then
      pass "/${ep} — meta keys match baseline"
    else
      warn "/${ep} — meta keys differ: $meta (baseline: $meta_keys_baseline)"
    fi
  done
  echo ""

  # 2e — POST without Content-Type header fails or returns error
  section "2e. POST without Content-Type header"
  resp_no_ct=$(api_call POST_NO_CT "/stories" '{"name": "should-fail-no-ct"}')
  code_no_ct=$(get_http_code "$resp_no_ct")
  if [[ "$code_no_ct" != "200" && "$code_no_ct" != "201" ]]; then
    pass "POST /stories without Content-Type rejected (HTTP $code_no_ct)"
  else
    warn "POST /stories without Content-Type was accepted (HTTP $code_no_ct)"
    body_no_ct=$(get_body "$resp_no_ct")
    created_id=$(echo "$body_no_ct" | jq -r '.id // empty' 2>/dev/null)
    [[ -n "$created_id" ]] && register_cleanup "stories" "$created_id"
  fi
  echo ""

  # 2f — Auth header works in both formats
  section "2f. Auth header format compatibility"
  resp_xtoken=$(api_call GET "/info")
  assert_http "x-user-token header works on /info" "200" "$(get_http_code "$resp_xtoken")"
  resp_bearer=$(/usr/bin/curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $TINES_API_TOKEN" \
    "${TINES_BASE_URL}/info")
  assert_http "Authorization: Bearer header works on /info" "200" "$(get_http_code "$resp_bearer")"
  echo ""
fi

# ==========================================================================
# 3. SKILL DESCRIPTION COVERAGE
# ==========================================================================

section "3. Skill Description Coverage"
echo ""

# 3a — Each skill description mentions key operations
section "3a. Descriptions mention key operations"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  desc=$(grep '^description:' "$f" | head -1 | sed 's/^description: *//')
  keywords=$(expected_keywords_for "$name")
  if [[ -z "$keywords" ]]; then skip "$name — no expected keywords defined"; continue; fi
  if echo "$desc" | grep -qiE "$keywords"; then
    pass "$name — description covers key operations"
  else
    fail "$name — description missing expected keywords ($keywords)"
  fi
done
echo ""

# 3b — No two skills have identical descriptions
section "3b. Unique descriptions"
all_descs=""
duplicates=false
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  desc=$(grep '^description:' "$f" | head -1 | sed 's/^description: *//')
  # Check if this description already appeared in another skill
  for f2 in "${SKILL_FILES[@]}"; do
    [[ "$f2" == "$f" ]] && continue
    desc2=$(grep '^description:' "$f2" | head -1 | sed 's/^description: *//')
    if [[ "$desc" == "$desc2" ]]; then
      other=$(skill_name "$f2")
      fail "$name — identical description to $other"
      duplicates=true
      break
    fi
  done
done
[[ "$duplicates" == false ]] && pass "All ${#SKILL_FILES[@]} skills have unique descriptions"
echo ""

# 3c — All descriptions are > 50 chars
section "3c. Description minimum length (>50 chars)"
for f in "${SKILL_FILES[@]}"; do
  name=$(skill_name "$f")
  desc=$(grep '^description:' "$f" | head -1 | sed 's/^description: *//')
  len=${#desc}
  if [[ "$len" -gt 50 ]]; then
    pass "$name — description length $len chars"
  else
    fail "$name — description too short ($len chars, need >50)"
  fi
done
echo ""

print_summary
