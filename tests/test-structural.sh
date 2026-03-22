#!/usr/bin/env bash
#
# Structural validation tests for Tines Agent Skills
# Validates skill files without requiring a Tines tenant.
#
# Usage: ./tests/test-structural.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() {
  echo -e "  ${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "  ${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "  ${YELLOW}WARN${NC} $1"
  WARN=$((WARN + 1))
}

# Discover all skill files
SKILL_FILES=()
while IFS= read -r -d '' f; do
  SKILL_FILES+=("$f")
done < <(find "$SKILLS_DIR" -name "SKILL.md" -print0 2>/dev/null)

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
  echo -e "${RED}No skill files found in $SKILLS_DIR${NC}"
  exit 1
fi

echo "=========================================="
echo " Tines Agent Skills — Structural Tests"
echo "=========================================="
echo ""
echo "Found ${#SKILL_FILES[@]} skill files"
echo ""

# ─────────────────────────────────────────────
# Test 1: Frontmatter validation
# ─────────────────────────────────────────────
echo "1. Frontmatter Validation"
echo "─────────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # Check frontmatter delimiters exist
  if ! head -1 "$skill_file" | grep -q '^---$'; then
    fail "$skill_name: missing opening frontmatter delimiter"
    continue
  fi

  # Check name field
  if grep -q '^name:' "$skill_file"; then
    fm_name="$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name: */, ""); print; exit}' "$skill_file")"
    if [[ "$fm_name" == "$skill_name" ]]; then
      pass "$skill_name: name field matches directory"
    else
      fail "$skill_name: name field '$fm_name' does not match directory '$skill_name'"
    fi
  else
    fail "$skill_name: missing 'name' field in frontmatter"
  fi

  # Check description field
  if grep -q '^description:' "$skill_file"; then
    desc="$(awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); print; exit}' "$skill_file")"
    if [[ ${#desc} -ge 20 ]]; then
      pass "$skill_name: description is descriptive (${#desc} chars)"
    else
      warn "$skill_name: description is short (${#desc} chars) — may not trigger well"
    fi
  else
    fail "$skill_name: missing 'description' field in frontmatter"
  fi

  # Check closing frontmatter
  if [[ $(grep -c '^---$' "$skill_file") -ge 2 ]]; then
    pass "$skill_name: frontmatter is properly closed"
  else
    fail "$skill_name: frontmatter is not properly closed (missing closing ---)"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 2: Kebab-case naming
# ─────────────────────────────────────────────
echo "2. Naming Convention"
echo "────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  if [[ "$skill_name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    pass "$skill_name: valid kebab-case name"
  else
    fail "$skill_name: name is not kebab-case"
  fi

  # No path traversal
  if [[ "$skill_name" == *".."* || "$skill_name" == *"/"* ]]; then
    fail "$skill_name: contains path traversal characters"
  else
    pass "$skill_name: no path traversal"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 3: Token security
# ─────────────────────────────────────────────
echo "3. Token Security"
echo "─────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # Check for dangerous patterns that would output the token value directly
  # Safe: curl -H ... "$TINES_API_TOKEN" (used in commands, not printed)
  # Safe: echo "TINES_API_TOKEN is not set" (referencing the name)
  # Unsafe: echo "$TINES_API_TOKEN" or echo "${TINES_API_TOKEN}" (printing the value)
  if grep -n '^\s*echo.*\$TINES_API_TOKEN\|^\s*printf.*\$TINES_API_TOKEN' "$skill_file" 2>/dev/null | grep -v 'is not set\|not set\|ERROR\|not configured\|TINES_API_TOKEN=' > /dev/null 2>&1; then
    fail "$skill_name: may echo TINES_API_TOKEN value"
  else
    pass "$skill_name: no token value leakage detected"
  fi

  # Check for token security warning
  if grep -qi 'never.*echo\|never.*log\|never.*output\|never.*display\|CRITICAL.*token' "$skill_file"; then
    pass "$skill_name: contains token security warning"
  else
    warn "$skill_name: no explicit token security warning found"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 4: Auth pattern consistency
# ─────────────────────────────────────────────
echo "4. Auth Pattern Consistency"
echo "──────────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # Skip auth skill — it defines the pattern
  if [[ "$skill_name" == "tines-auth" ]]; then
    continue
  fi

  # Check for TINES_BASE_URL pattern
  if grep -q 'TINES_BASE_URL' "$skill_file"; then
    pass "$skill_name: uses TINES_BASE_URL pattern"
  else
    fail "$skill_name: missing TINES_BASE_URL pattern"
  fi

  # Check for AUTH_HEADER pattern
  if grep -q 'AUTH_HEADER\|x-user-token' "$skill_file"; then
    pass "$skill_name: uses auth header pattern"
  else
    fail "$skill_name: missing auth header pattern"
  fi

  # Check for env var prerequisites mention
  if grep -qi 'TINES_TENANT_URL.*TINES_API_TOKEN\|Prerequisites\|environment variables' "$skill_file"; then
    pass "$skill_name: documents prerequisites"
  else
    warn "$skill_name: no clear prerequisites section"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 5: Destructive operation guards
# ─────────────────────────────────────────────
echo "5. Destructive Operation Guards"
echo "───────────────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # Check if skill has DELETE operations
  if grep -q 'DELETE' "$skill_file"; then
    # Check for confirmation/warning language
    if grep -qi 'DESTRUCTIVE\|confirm\|warning\|confirm with user\|irreversible' "$skill_file"; then
      pass "$skill_name: destructive operations have safety warnings"
    else
      fail "$skill_name: has DELETE operations but no safety warnings"
    fi
  else
    pass "$skill_name: no destructive operations (or n/a)"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 6: Curl command syntax
# ─────────────────────────────────────────────
echo "6. Curl Command Syntax"
echo "──────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # Check curl commands use -s (silent) and -f (fail on HTTP errors)
  curl_count=$(grep -c 'curl ' "$skill_file" 2>/dev/null || echo "0")

  if [[ "$curl_count" -gt 0 ]]; then
    silent_count=$(grep -c 'curl.*-s\|curl.*--silent' "$skill_file" 2>/dev/null || echo "0")
    fail_count=$(grep -c 'curl.*-f\|curl.*--fail' "$skill_file" 2>/dev/null || echo "0")

    if [[ "$silent_count" -gt 0 ]]; then
      pass "$skill_name: curl uses -s (silent) flag"
    else
      warn "$skill_name: curl commands missing -s flag"
    fi

    if [[ "$fail_count" -gt 0 ]]; then
      pass "$skill_name: curl uses -f (fail) flag"
    else
      warn "$skill_name: curl commands missing -f flag"
    fi

    # Check for jq piping (structured output)
    if grep -q 'jq' "$skill_file"; then
      pass "$skill_name: uses jq for structured output"
    else
      warn "$skill_name: no jq usage for response parsing"
    fi
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 7: Rate limit documentation
# ─────────────────────────────────────────────
echo "7. Rate Limit Awareness"
echo "───────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # Skills that should document rate limits
  case "$skill_name" in
    tines-actions|tines-records|tines-admin|tines-auth)
      if grep -qi 'rate.limit\|requests.*minute\|/min' "$skill_file"; then
        pass "$skill_name: documents rate limits"
      else
        warn "$skill_name: should document rate limits for its endpoints"
      fi
      ;;
  esac
done

echo ""

# ─────────────────────────────────────────────
# Test 8: Plugin manifests
# ─────────────────────────────────────────────
echo "8. Plugin Manifests"
echo "───────────────────"

# Check root marketplace.json
if [[ -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]]; then
  if python3 -c "import json; json.load(open('$REPO_ROOT/.claude-plugin/marketplace.json'))" 2>/dev/null; then
    pass "marketplace.json: valid JSON"
  else
    fail "marketplace.json: invalid JSON"
  fi
else
  fail "marketplace.json: not found at .claude-plugin/marketplace.json"
fi

# Check category plugin.json
if [[ -f "$SKILLS_DIR/tines/.claude-plugin/plugin.json" ]]; then
  if python3 -c "import json; json.load(open('$SKILLS_DIR/tines/.claude-plugin/plugin.json'))" 2>/dev/null; then
    pass "plugin.json: valid JSON"
  else
    fail "plugin.json: invalid JSON"
  fi
else
  fail "plugin.json: not found at skills/tines/.claude-plugin/plugin.json"
fi

echo ""

# ─────────────────────────────────────────────
# Test 9: Pagination patterns
# ─────────────────────────────────────────────
echo "9. Pagination Coverage"
echo "──────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # Skills that list resources should mention pagination
  if grep -q 'per_page\|next_page\|pagination\|Paginate' "$skill_file"; then
    pass "$skill_name: includes pagination pattern"
  elif grep -q 'GET.*list\|List ' "$skill_file"; then
    warn "$skill_name: has list operations but no pagination pattern"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 10: Credential file resolution
# ─────────────────────────────────────────────
echo "10. Credential File Resolution"
echo "──────────────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"

  # All skills should reference the credentials file path
  if grep -q '\.tines/credentials' "$skill_file"; then
    pass "$skill_name: references ~/.tines/credentials"
  else
    fail "$skill_name: missing ~/.tines/credentials reference"
  fi

  # All skills should support TINES_PROFILE
  if grep -q 'TINES_PROFILE' "$skill_file"; then
    pass "$skill_name: supports TINES_PROFILE"
  else
    fail "$skill_name: missing TINES_PROFILE support"
  fi

  # All non-auth skills should have the awk-based credential resolution
  if [[ "$skill_name" != "tines-auth" ]]; then
    if grep -q 'TINES_CREDS_FILE' "$skill_file"; then
      pass "$skill_name: has credential file resolution logic"
    else
      fail "$skill_name: missing credential file resolution logic"
    fi
  fi
done

# Check shared common-patterns has credential resolution
SHARED_FILE="$REPO_ROOT/skills/tines/shared/common-patterns.md"
if [[ -f "$SHARED_FILE" ]]; then
  if grep -q '\.tines/credentials' "$SHARED_FILE" && grep -q 'TINES_PROFILE' "$SHARED_FILE"; then
    pass "shared/common-patterns.md: documents credential file format"
  else
    fail "shared/common-patterns.md: missing credential file documentation"
  fi

  if grep -q 'chmod 600' "$SHARED_FILE"; then
    pass "shared/common-patterns.md: documents file permissions (chmod 600)"
  else
    fail "shared/common-patterns.md: missing file permission requirements"
  fi

  if grep -q 'TINES_CREDENTIALS_FILE' "$SHARED_FILE"; then
    pass "shared/common-patterns.md: documents TINES_CREDENTIALS_FILE override"
  else
    fail "shared/common-patterns.md: missing TINES_CREDENTIALS_FILE override"
  fi
else
  fail "shared/common-patterns.md: file not found"
fi

# Check tines-auth has configure flow
AUTH_FILE="$SKILLS_DIR/tines/tines-auth/SKILL.md"
if [[ -f "$AUTH_FILE" ]]; then
  if grep -qi 'configure\|setup' "$AUTH_FILE" && grep -q 'mkdir.*\.tines' "$AUTH_FILE"; then
    pass "tines-auth: has credential configure flow"
  else
    fail "tines-auth: missing credential configure flow"
  fi

  if grep -q 'chmod 700' "$AUTH_FILE" && grep -q 'chmod 600' "$AUTH_FILE"; then
    pass "tines-auth: enforces file permissions in configure flow"
  else
    fail "tines-auth: missing permission enforcement in configure flow"
  fi

  if grep -qi 'list.*profile\|grep.*\\\[' "$AUTH_FILE"; then
    pass "tines-auth: has list profiles command"
  else
    fail "tines-auth: missing list profiles command"
  fi

  if grep -q 'switch.*profile\|current = ' "$AUTH_FILE" && grep -q 'sed' "$AUTH_FILE"; then
    pass "tines-auth: has switch profile command"
  else
    fail "tines-auth: missing switch profile command"
  fi

  if grep -qi 'show.*active\|active.*profile' "$AUTH_FILE"; then
    pass "tines-auth: has show active profile command"
  else
    fail "tines-auth: missing show active profile command"
  fi
else
  fail "tines-auth SKILL.md: file not found"
fi

echo ""

# ─────────────────────────────────────────────
# Test 11: Credential resolution consistency
# ─────────────────────────────────────────────
echo "11. Credential Resolution Consistency"
echo "─────────────────────────────────────"

# All non-auth skills should have identical credential resolution patterns
RESOLUTION_PATTERN='TINES_CREDS_FILE.*TINES_CREDENTIALS_FILE.*HOME/.tines/credentials'
for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"
  [[ "$skill_name" == "tines-auth" ]] && continue

  # Check env var fallback order (env vars > creds file)
  if grep -q 'TINES_TENANT_URL:-' "$skill_file" && grep -q 'TINES_API_TOKEN:-' "$skill_file"; then
    pass "$skill_name: env var fallback syntax correct"
  else
    fail "$skill_name: missing env var fallback syntax"
  fi

  # Check profile defaults to 'default'
  if grep -q 'TINES_PROFILE:-default' "$skill_file"; then
    pass "$skill_name: profile defaults to 'default'"
  else
    fail "$skill_name: missing default profile fallback"
  fi

  # Check 'current' attribute resolution (env var > current > default)
  if grep -q 'current' "$skill_file" && grep -q 'awk.*current' "$skill_file"; then
    pass "$skill_name: resolves 'current' attribute from credentials file"
  else
    fail "$skill_name: missing 'current' attribute resolution"
  fi
done

# Check shared common-patterns documents 'current' attribute
if [[ -f "$SHARED_FILE" ]]; then
  if grep -q '^current = ' "$SHARED_FILE" && grep -q 'awk.*current' "$SHARED_FILE"; then
    pass "shared/common-patterns.md: documents 'current' attribute"
  else
    fail "shared/common-patterns.md: missing 'current' attribute documentation"
  fi
fi

echo ""

# ─────────────────────────────────────────────
# Test 12: References directory structure
# ─────────────────────────────────────────────
echo "12. References Directory Structure"
echo "──────────────────────────────────"

for skill_file in "${SKILL_FILES[@]}"; do
  skill_name="$(basename "$(dirname "$skill_file")")"
  skill_dir="$(dirname "$skill_file")"
  ref_dir="$skill_dir/references"

  if [[ -d "$ref_dir" ]]; then
    pass "$skill_name: has references/ directory"

    if [[ -f "$ref_dir/api-reference.md" ]]; then
      pass "$skill_name: has references/api-reference.md"
    else
      fail "$skill_name: missing references/api-reference.md"
    fi
  else
    fail "$skill_name: missing references/ directory"
  fi

  # SKILL.md should reference the references directory
  if grep -qi 'references/' "$skill_file"; then
    pass "$skill_name: SKILL.md references the references/ directory"
  else
    fail "$skill_name: SKILL.md does not reference the references/ directory"
  fi
done

# Check shared directory exists
if [[ -f "$REPO_ROOT/skills/tines/shared/common-patterns.md" ]]; then
  pass "shared/common-patterns.md exists"
else
  fail "shared/common-patterns.md missing"
fi

echo ""

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo "=========================================="
echo " Summary"
echo "=========================================="
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}FAILED${NC} — $FAIL test(s) failed"
  exit 1
else
  echo -e "${GREEN}ALL TESTS PASSED${NC}"
  exit 0
fi
