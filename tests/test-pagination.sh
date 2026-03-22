#!/usr/bin/env bash
#
# Pagination tests for Tines API list endpoints
# Verifies pagination meta structure, per-page control, page navigation,
# full pagination loops, and edge cases across all list endpoints.
#
# READ-ONLY: This test creates no resources.
#
# Prerequisites:
#   export TINES_TENANT_URL="https://your-tenant.tines.com"
#   export TINES_API_TOKEN="your-api-token"
#
# Usage:
#   ./tests/test-pagination.sh              Run all pagination tests
#   DRY_RUN=true ./tests/test-pagination.sh Dry run (no API calls)
#
set -uo pipefail

source "$(dirname "$0")/helpers/test-helpers.sh"

# Parse --dry-run from arguments
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  fi
done

init_test_env "Pagination Tests"

# ─────────────────────────────────────────────
# Endpoint definitions: path -> response array key
# ─────────────────────────────────────────────

declare -a ENDPOINTS=(
  "/stories?per_page=1|stories"
  "/cases?per_page=1|cases"
  "/agents?per_page=1|agents"
  "/user_credentials?per_page=1|user_credentials"
  "/teams?per_page=1|teams"
  "/folders?per_page=1|folders"
  "/admin/users?per_page=1|admin_users"
  "/audit_logs?per_page=1|audit_logs"
)

# Admin-only endpoints that may return 401 for non-admin tokens
declare -a ADMIN_ENDPOINTS=("/admin/users" "/audit_logs")

is_admin_endpoint() {
  local path="$1"
  for admin_path in "${ADMIN_ENDPOINTS[@]}"; do
    if [[ "$path" == "$admin_path"* ]]; then
      return 0
    fi
  done
  return 1
}

# ─────────────────────────────────────────────
# 1. Pagination meta structure
# ─────────────────────────────────────────────

section "1. Pagination meta structure"
echo ""

for entry in "${ENDPOINTS[@]}"; do
  endpoint="${entry%%|*}"
  array_key="${entry##*|}"
  label="${endpoint%%\?*}"

  if [[ "$DRY_RUN" == true ]]; then
    skip "Meta structure for $label (dry run)"
    continue
  fi

  resp=$(api_call GET "$endpoint")
  http_code=$(get_http_code "$resp")
  body=$(get_body "$resp")

  # Skip admin endpoints that return 401/403
  if is_admin_endpoint "$label" && [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
    skip "Meta structure for $label (HTTP $http_code - insufficient permissions)"
    continue
  fi

  if [[ "$http_code" != "200" ]]; then
    fail "Meta structure for $label (HTTP $http_code)"
    continue
  fi

  assert_json_exists "meta.current_page exists for $label" "$body" ".meta.current_page"
  assert_json_equals "meta.per_page equals 1 for $label" "$body" ".meta.per_page" "1"
  assert_json_exists "meta.count exists for $label" "$body" ".meta.count"
  assert_json_exists "meta.pages exists for $label" "$body" ".meta.pages"
done

echo ""

# ─────────────────────────────────────────────
# 2. Per-page control
# ─────────────────────────────────────────────

section "2. Per-page control"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  skip "Per-page=1 returns exactly 1 story (dry run)"
  skip "Per-page=2 returns at most 2 stories (dry run)"
else
  # per_page=1
  resp=$(api_call GET "/stories?per_page=1")
  http_code=$(get_http_code "$resp")
  body=$(get_body "$resp")

  if [[ "$http_code" == "200" ]]; then
    count=$(echo "$body" | jq '.stories | length' 2>/dev/null || echo "0")
    if [[ "$count" -eq 1 ]]; then
      pass "per_page=1 returns exactly 1 story"
    elif [[ "$count" -eq 0 ]]; then
      skip "per_page=1 returned 0 stories (tenant may have no stories)"
    else
      fail "per_page=1 returned $count stories (expected 1)"
    fi
  else
    fail "per_page=1 request failed (HTTP $http_code)"
  fi

  # per_page=2
  resp=$(api_call GET "/stories?per_page=2")
  http_code=$(get_http_code "$resp")
  body=$(get_body "$resp")

  if [[ "$http_code" == "200" ]]; then
    count=$(echo "$body" | jq '.stories | length' 2>/dev/null || echo "0")
    total=$(echo "$body" | jq -r '.meta.count' 2>/dev/null || echo "0")
    if [[ "$count" -le 2 && "$count" -gt 0 ]]; then
      pass "per_page=2 returns $count stories (total: $total)"
    elif [[ "$count" -eq 0 ]]; then
      skip "per_page=2 returned 0 stories (tenant may have no stories)"
    else
      fail "per_page=2 returned $count stories (expected <= 2)"
    fi

    # Verify item count matches per_page (or total if fewer exist)
    expected_count=2
    if [[ "$total" -lt 2 ]]; then
      expected_count="$total"
    fi
    if [[ "$count" -eq "$expected_count" ]]; then
      pass "Item count ($count) matches expected per_page bound"
    else
      fail "Item count ($count) does not match expected ($expected_count)"
    fi
  else
    fail "per_page=2 request failed (HTTP $http_code)"
  fi
fi

echo ""

# ─────────────────────────────────────────────
# 3. Page navigation
# ─────────────────────────────────────────────

section "3. Page navigation"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  skip "Page 1 returns first story (dry run)"
  skip "Page 2 returns different story (dry run)"
  skip "meta.current_page matches requested page (dry run)"
else
  # Page 1
  resp1=$(api_call GET "/stories?per_page=1&page=1")
  http1=$(get_http_code "$resp1")
  body1=$(get_body "$resp1")

  if [[ "$http1" == "200" ]]; then
    # meta.current_page is a URL in Tines API, not a page number — verify it exists
    assert_json_exists "meta.current_page exists for page=1" "$body1" ".meta.current_page"
    story1_id=$(echo "$body1" | jq -r '.stories[0].id // empty' 2>/dev/null)

    if [[ -n "$story1_id" ]]; then
      pass "Page 1 returns first story (id: $story1_id)"
    else
      skip "Page 1 returned no stories (tenant may be empty)"
    fi
  else
    fail "Page 1 request failed (HTTP $http1)"
  fi

  # Page 2
  resp2=$(api_call GET "/stories?per_page=1&page=2")
  http2=$(get_http_code "$resp2")
  body2=$(get_body "$resp2")

  if [[ "$http2" == "200" ]]; then
    # meta.current_page is a URL in Tines API, not a page number — verify it exists
    assert_json_exists "meta.current_page exists for page=2" "$body2" ".meta.current_page"
    story2_id=$(echo "$body2" | jq -r '.stories[0].id // empty' 2>/dev/null)

    if [[ -n "$story1_id" && -n "$story2_id" ]]; then
      if [[ "$story1_id" != "$story2_id" ]]; then
        pass "Page 2 returns different story (id: $story2_id)"
      else
        fail "Page 2 returned same story as page 1 (id: $story1_id)"
      fi
    elif [[ -z "$story2_id" ]]; then
      skip "Page 2 returned no stories (only 1 story exists)"
    fi
  else
    fail "Page 2 request failed (HTTP $http2)"
  fi
fi

echo ""

# ─────────────────────────────────────────────
# 4. Full pagination loop
# ─────────────────────────────────────────────

section "4. Full pagination loop (stories, per_page=2)"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  skip "Full pagination loop (dry run)"
else
  page=1
  total_items=0
  expected_count=0
  max_pages=10
  pages_fetched=0

  while [[ "$page" != "null" && "$page" != "" && "$pages_fetched" -lt "$max_pages" ]]; do
    resp=$(api_call GET "/stories?per_page=2&page=$page")
    http_code=$(get_http_code "$resp")
    body=$(get_body "$resp")

    if [[ "$http_code" != "200" ]]; then
      fail "Pagination loop failed at page $page (HTTP $http_code)"
      break
    fi

    item_count=$(echo "$body" | jq '.stories | length' 2>/dev/null || echo "0")
    total_items=$((total_items + item_count))
    pages_fetched=$((pages_fetched + 1))

    # Capture expected total from first page
    if [[ "$pages_fetched" -eq 1 ]]; then
      expected_count=$(echo "$body" | jq -r '.meta.count' 2>/dev/null || echo "0")
    fi

    # Get next page
    next_page=$(echo "$body" | jq -r '.meta.next_page_number // "null"' 2>/dev/null)
    page="$next_page"
  done

  if [[ "$pages_fetched" -ge "$max_pages" && "$page" != "null" ]]; then
    warn "Pagination loop hit safety limit ($max_pages pages), collected $total_items of $expected_count items"
  fi

  if [[ "$pages_fetched" -gt 0 ]]; then
    pass "Pagination loop completed: $pages_fetched pages fetched"

    if [[ "$total_items" -eq "$expected_count" ]]; then
      pass "Total items collected ($total_items) matches meta.count ($expected_count)"
    elif [[ "$pages_fetched" -ge "$max_pages" ]]; then
      skip "Cannot verify total count (hit safety limit at $max_pages pages)"
    else
      fail "Total items ($total_items) does not match meta.count ($expected_count)"
    fi
  else
    fail "Pagination loop fetched 0 pages"
  fi
fi

echo ""

# ─────────────────────────────────────────────
# 5. Edge cases
# ─────────────────────────────────────────────

section "5. Edge cases"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  skip "per_page=500 (max allowed) returns 200 (dry run)"
  skip "page=99999 (beyond data) returns empty results (dry run)"
else
  # per_page=500 (max allowed)
  resp=$(api_call GET "/stories?per_page=500")
  http_code=$(get_http_code "$resp")
  body=$(get_body "$resp")

  assert_http "per_page=500 (max allowed) returns 200" "200" "$http_code"
  if [[ "$http_code" == "200" ]]; then
    count=$(echo "$body" | jq '.stories | length' 2>/dev/null || echo "0")
    per_page_val=$(echo "$body" | jq -r '.meta.per_page' 2>/dev/null || echo "0")
    pass "per_page=500 accepted by API (meta.per_page=$per_page_val, returned $count items)"
  fi

  # page=99999 (beyond data)
  resp=$(api_call GET "/stories?per_page=1&page=99999")
  http_code=$(get_http_code "$resp")
  body=$(get_body "$resp")

  assert_http "page=99999 (beyond data) returns 200" "200" "$http_code"
  if [[ "$http_code" == "200" ]]; then
    count=$(echo "$body" | jq '.stories | length' 2>/dev/null || echo "0")
    if [[ "$count" -eq 0 ]]; then
      pass "page=99999 returns empty results array"
    else
      fail "page=99999 returned $count items (expected 0)"
    fi
  fi
fi

echo ""

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

print_summary
