#!/usr/bin/env bash
#
# Cleanup orphaned test resources from a Tines tenant.
# Finds and deletes resources whose names contain "__test_", left behind
# by interrupted or failed test runs.
#
# Prerequisites:
#   export TINES_TENANT_URL="https://your-tenant.tines.com"
#   export TINES_API_TOKEN="your-api-token"
#
# Usage:
#   ./tests/helpers/cleanup.sh              Interactive cleanup (prompts before delete)
#   ./tests/helpers/cleanup.sh --dry-run    List orphans without deleting
#   ./tests/helpers/cleanup.sh --force      Delete without confirmation prompt
#
set -uo pipefail

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TEST_PATTERN="__test_"

DRY_RUN=false
FORCE=false

# ─────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force)   FORCE=true ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--dry-run] [--force]"
      echo ""
      echo "  --dry-run  List orphaned test resources without deleting"
      echo "  --force    Delete without confirmation prompt"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $arg${NC}" >&2
      exit 1
      ;;
  esac
done

# ─────────────────────────────────────────────
# Environment validation
# ─────────────────────────────────────────────

if [[ -z "${TINES_TENANT_URL:-}" ]]; then
  echo -e "${RED}Error: TINES_TENANT_URL is not set${NC}" >&2
  exit 1
fi
if [[ -z "${TINES_API_TOKEN:-}" ]]; then
  echo -e "${RED}Error: TINES_API_TOKEN is not set${NC}" >&2
  exit 1
fi

TINES_BASE_URL="${TINES_TENANT_URL%/}/api/v1"
AUTH_HEADER="x-user-token: ${TINES_API_TOKEN}"

# ─────────────────────────────────────────────
# API helper
# ─────────────────────────────────────────────

api_get() {
  local endpoint="$1"
  /usr/bin/curl -s -H "$AUTH_HEADER" "${TINES_BASE_URL}${endpoint}"
}

api_delete() {
  local endpoint="$1"
  /usr/bin/curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    -H "$AUTH_HEADER" "${TINES_BASE_URL}${endpoint}"
}

# ─────────────────────────────────────────────
# Orphan collection
# ─────────────────────────────────────────────

# Arrays to hold discovered orphans: "type|id|name"
ORPHANS=()

scan_resource() {
  local label="$1"
  local endpoint="$2"
  local jq_expr="$3"

  echo -e "  Scanning ${CYAN}${label}${NC}..."
  local body
  body=$(api_get "$endpoint")

  local matches
  matches=$(echo "$body" | jq -r "$jq_expr" 2>/dev/null || true)

  local count=0
  while IFS=$'\t' read -r id name; do
    [[ -z "$id" || "$id" == "null" ]] && continue
    ORPHANS+=("${label}|${id}|${name}")
    count=$((count + 1))
  done <<< "$matches"

  if [[ $count -gt 0 ]]; then
    echo -e "    Found ${YELLOW}${count}${NC} orphan(s)"
  fi
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

echo "=========================================="
echo " Tines Test Resource Cleanup"
echo "=========================================="
echo ""
echo "Tenant:  ${TINES_TENANT_URL}"
echo "Pattern: ${TEST_PATTERN}"
if [[ "$DRY_RUN" == true ]]; then
  echo -e "Mode:    ${YELLOW}DRY RUN${NC}"
elif [[ "$FORCE" == true ]]; then
  echo -e "Mode:    ${RED}FORCE DELETE${NC}"
fi
echo ""

echo "Scanning for orphaned test resources..."
echo ""

# Discover a team ID for record_types (requires team_id parameter)
TEAM_ID=$(api_get "/teams?per_page=1" | jq -r '.teams[0].id // empty' 2>/dev/null || true)

scan_resource "stories" "/stories?per_page=500" \
  "[.stories[] | select(.name | test(\"${TEST_PATTERN}\")) | [.id, .name]] | .[] | @tsv"

scan_resource "cases" "/cases?per_page=500" \
  "[.cases[] | select(.name | test(\"${TEST_PATTERN}\")) | [.case_id, .name]] | .[] | @tsv"

scan_resource "credentials" "/user_credentials?per_page=500" \
  "[.user_credentials[] | select(.name | test(\"${TEST_PATTERN}\")) | [.id, .name]] | .[] | @tsv"

scan_resource "resources" "/resources?per_page=500" \
  "[.[] | select(.name | test(\"${TEST_PATTERN}\")) | [.id, .name]] | .[] | @tsv"

if [[ -n "$TEAM_ID" ]]; then
  scan_resource "record_types" "/record_types?team_id=${TEAM_ID}&per_page=500" \
    "[.record_types[] | select(.name | test(\"${TEST_PATTERN}\")) | [.id, .name]] | .[] | @tsv"
fi

scan_resource "teams" "/teams?per_page=500" \
  "[.teams[] | select(.name | test(\"${TEST_PATTERN}\")) | [.id, .name]] | .[] | @tsv"

scan_resource "folders" "/folders?per_page=500" \
  "[.[] | select(.name | test(\"${TEST_PATTERN}\")) | [.id, .name]] | .[] | @tsv"

echo ""

# ─────────────────────────────────────────────
# Report findings
# ─────────────────────────────────────────────

if [[ ${#ORPHANS[@]} -eq 0 ]]; then
  echo -e "${GREEN}No orphaned test resources found.${NC}"
  exit 0
fi

echo -e "${YELLOW}Found ${#ORPHANS[@]} orphaned resource(s):${NC}"
echo ""
printf "  %-15s %-10s %s\n" "TYPE" "ID" "NAME"
printf "  %-15s %-10s %s\n" "───────────────" "──────────" "────────────────────────"
for entry in "${ORPHANS[@]}"; do
  IFS='|' read -r type id name <<< "$entry"
  printf "  %-15s %-10s %s\n" "$type" "$id" "$name"
done
echo ""

if [[ "$DRY_RUN" == true ]]; then
  echo -e "${YELLOW}Dry run complete. No resources were deleted.${NC}"
  exit 0
fi

# ─────────────────────────────────────────────
# Confirmation
# ─────────────────────────────────────────────

if [[ "$FORCE" != true ]]; then
  echo -n "Delete all ${#ORPHANS[@]} orphaned resource(s)? [y/N] "
  read -r confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
  echo ""
fi

# ─────────────────────────────────────────────
# Deletion in safe dependency order
# ─────────────────────────────────────────────

DELETION_ORDER=("credentials" "resources" "record_types" "cases" "stories" "folders" "teams")
DELETED=0
FAILED=0

echo "Deleting orphaned resources..."
echo ""

for target_type in "${DELETION_ORDER[@]}"; do
  for entry in "${ORPHANS[@]}"; do
    IFS='|' read -r type id name <<< "$entry"
    [[ "$type" != "$target_type" ]] && continue

    # Map friendly type to API endpoint
    endpoint=""
    case "$type" in
      stories)      endpoint="/stories/${id}" ;;
      cases)        endpoint="/cases/${id}" ;;
      credentials)  endpoint="/user_credentials/${id}" ;;
      resources)    endpoint="/resources/${id}" ;;
      record_types) endpoint="/record_types/${id}" ;;
      teams)        endpoint="/teams/${id}" ;;
      folders)      endpoint="/folders/${id}" ;;
    esac

    http_code=""
    http_code=$(api_delete "$endpoint")

    if [[ "$http_code" =~ ^(200|204|404)$ ]]; then
      echo -e "  ${GREEN}Deleted${NC} ${type}/${id} (${name})"
      DELETED=$((DELETED + 1))
    else
      echo -e "  ${RED}Failed${NC} ${type}/${id} (HTTP ${http_code})"
      FAILED=$((FAILED + 1))
    fi
  done
done

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

echo ""
echo "=========================================="
echo " Cleanup Summary"
echo "=========================================="
echo ""
echo -e "  ${GREEN}Deleted${NC}: ${DELETED}"
if [[ $FAILED -gt 0 ]]; then
  echo -e "  ${RED}Failed${NC}:  ${FAILED}"
fi
echo ""

if [[ $FAILED -gt 0 ]]; then
  echo -e "${YELLOW}Some resources could not be deleted. Re-run to retry.${NC}"
  exit 1
else
  echo -e "${GREEN}All orphaned test resources cleaned up.${NC}"
  exit 0
fi
