#!/usr/bin/env bash
#
# Domain knowledge validation tests for Tines Agent Skills.
# Validates shared reference docs and workflow skill cross-references.
#
# Usage: ./tests/test-domain-knowledge.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED_DIR="$REPO_ROOT/skills/tines/shared"
SKILLS_DIR="$REPO_ROOT/skills/tines"

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

echo "=========================================="
echo " Tines Agent Skills — Domain Knowledge"
echo "=========================================="
echo ""

# ─────────────────────────────────────────────
# Test 1: Shared files exist
# ─────────────────────────────────────────────
echo "1. Shared Knowledge Files Exist"
echo "───────────────────────────────"

for f in common-patterns.md action-types.md formulas.md story-schema.md best-practices.md; do
  if [[ -f "$SHARED_DIR/$f" ]]; then
    lines=$(wc -l < "$SHARED_DIR/$f" | tr -d ' ')
    pass "$f exists ($lines lines)"
  else
    fail "$f not found in shared/"
  fi
done

echo ""

# ─────────────────────────────────────────────
# Test 2: Action types coverage
# ─────────────────────────────────────────────
echo "2. Action Types Coverage"
echo "────────────────────────"

AT_FILE="$SHARED_DIR/action-types.md"
if [[ -f "$AT_FILE" ]]; then
  # All 8 action type slugs must be documented
  for slug in "WebhookAgent" "HTTPRequestAgent" "EventTransformationAgent" "TriggerAgent" "EmailAgent" "IMAPAgent" "SendToStoryAgent" "AIAgent"; do
    if grep -q "$slug" "$AT_FILE"; then
      pass "action-types.md: documents $slug"
    else
      fail "action-types.md: missing $slug"
    fi
  done

  # Should have options/schema examples
  if grep -q 'options' "$AT_FILE" && grep -q '"type"' "$AT_FILE"; then
    pass "action-types.md: includes options schemas"
  else
    fail "action-types.md: missing options schemas"
  fi

  # Should have API create examples
  if grep -q 'curl.*POST' "$AT_FILE" || grep -q 'TINES_BASE_URL.*agents' "$AT_FILE"; then
    pass "action-types.md: includes API create examples"
  else
    warn "action-types.md: no API create examples found"
  fi
else
  fail "action-types.md: file not found"
fi

echo ""

# ─────────────────────────────────────────────
# Test 3: Formulas coverage
# ─────────────────────────────────────────────
echo "3. Formulas Coverage"
echo "────────────────────"

F_FILE="$SHARED_DIR/formulas.md"
if [[ -f "$F_FILE" ]]; then
  # Formula syntax basics
  if grep -q '<<' "$F_FILE" && grep -q '>>' "$F_FILE"; then
    pass "formulas.md: documents << >> syntax"
  else
    fail "formulas.md: missing << >> syntax"
  fi

  # CREDENTIAL reference syntax
  if grep -q 'CREDENTIAL' "$F_FILE"; then
    pass "formulas.md: documents CREDENTIAL references"
  else
    fail "formulas.md: missing CREDENTIAL reference syntax"
  fi

  # RESOURCE reference syntax
  if grep -q 'RESOURCE' "$F_FILE"; then
    pass "formulas.md: documents RESOURCE references"
  else
    fail "formulas.md: missing RESOURCE reference syntax"
  fi

  # Function categories (check at least 5 core categories)
  for category in "Text" "Array" "Date" "Math" "Logical"; do
    if grep -qi "$category" "$F_FILE"; then
      pass "formulas.md: covers $category functions"
    else
      fail "formulas.md: missing $category function category"
    fi
  done

  # Should have function tables
  if grep -q '|.*|.*|' "$F_FILE"; then
    pass "formulas.md: has function reference tables"
  else
    fail "formulas.md: missing function reference tables"
  fi
else
  fail "formulas.md: file not found"
fi

echo ""

# ─────────────────────────────────────────────
# Test 4: Story schema coverage
# ─────────────────────────────────────────────
echo "4. Story Schema Coverage"
echo "────────────────────────"

SS_FILE="$SHARED_DIR/story-schema.md"
if [[ -f "$SS_FILE" ]]; then
  # Top-level fields
  for field in "name" "agents" "links" "exported_at" "guid"; do
    if grep -q "$field" "$SS_FILE"; then
      pass "story-schema.md: documents '$field' field"
    else
      fail "story-schema.md: missing '$field' field"
    fi
  done

  # Agent object structure
  if grep -q 'type.*string\|"type"' "$SS_FILE" && grep -q 'options' "$SS_FILE"; then
    pass "story-schema.md: documents agent object structure"
  else
    fail "story-schema.md: missing agent object structure"
  fi

  # Minimal valid example
  if grep -q 'WebhookAgent\|HTTPRequestAgent' "$SS_FILE" && grep -q '"agents"' "$SS_FILE"; then
    pass "story-schema.md: has valid example"
  else
    fail "story-schema.md: missing valid example"
  fi

  # Import considerations
  if grep -qi 'import' "$SS_FILE"; then
    pass "story-schema.md: documents import considerations"
  else
    fail "story-schema.md: missing import considerations"
  fi
else
  fail "story-schema.md: file not found"
fi

echo ""

# ─────────────────────────────────────────────
# Test 5: Best practices coverage
# ─────────────────────────────────────────────
echo "5. Best Practices Coverage"
echo "──────────────────────────"

BP_FILE="$SHARED_DIR/best-practices.md"
if [[ -f "$BP_FILE" ]]; then
  # Core categories
  if grep -qi 'naming' "$BP_FILE"; then
    pass "best-practices.md: covers naming conventions"
  else
    fail "best-practices.md: missing naming conventions"
  fi

  if grep -qi 'error.handling\|error handling' "$BP_FILE"; then
    pass "best-practices.md: covers error handling"
  else
    fail "best-practices.md: missing error handling"
  fi

  if grep -qi 'security' "$BP_FILE"; then
    pass "best-practices.md: covers security practices"
  else
    fail "best-practices.md: missing security practices"
  fi

  if grep -qi 'CREDENTIAL\|credential' "$BP_FILE"; then
    pass "best-practices.md: covers credential usage"
  else
    fail "best-practices.md: missing credential usage"
  fi

  if grep -qi 'workflow\|pattern' "$BP_FILE"; then
    pass "best-practices.md: covers workflow patterns"
  else
    fail "best-practices.md: missing workflow patterns"
  fi
else
  fail "best-practices.md: file not found"
fi

echo ""

# ─────────────────────────────────────────────
# Test 6: Workflow skill cross-references
# ─────────────────────────────────────────────
echo "6. Workflow Skill Cross-References"
echo "──────────────────────────────────"

# tines-build should reference action-types and formulas
BUILD_FILE="$SKILLS_DIR/tines-build/SKILL.md"
if [[ -f "$BUILD_FILE" ]]; then
  if grep -q 'action-types' "$BUILD_FILE"; then
    pass "tines-build: references action-types.md"
  else
    fail "tines-build: missing reference to action-types.md"
  fi

  if grep -q 'formulas' "$BUILD_FILE"; then
    pass "tines-build: references formulas.md"
  else
    fail "tines-build: missing reference to formulas.md"
  fi

  if grep -q 'story-schema' "$BUILD_FILE"; then
    pass "tines-build: references story-schema.md"
  else
    warn "tines-build: no reference to story-schema.md"
  fi
else
  fail "tines-build/SKILL.md: file not found"
fi

# tines-review should reference best-practices and story-schema
REVIEW_FILE="$SKILLS_DIR/tines-review/SKILL.md"
if [[ -f "$REVIEW_FILE" ]]; then
  if grep -q 'best-practices' "$REVIEW_FILE"; then
    pass "tines-review: references best-practices.md"
  else
    fail "tines-review: missing reference to best-practices.md"
  fi

  if grep -q 'story-schema' "$REVIEW_FILE"; then
    pass "tines-review: references story-schema.md"
  else
    fail "tines-review: missing reference to story-schema.md"
  fi
else
  fail "tines-review/SKILL.md: file not found"
fi

# tines-audit should reference existing API skills
AUDIT_FILE="$SKILLS_DIR/tines-audit/SKILL.md"
if [[ -f "$AUDIT_FILE" ]]; then
  if grep -q 'tines-credentials\|tines-stories\|tines-admin' "$AUDIT_FILE"; then
    pass "tines-audit: references existing API skills"
  else
    fail "tines-audit: missing references to API skills"
  fi
else
  fail "tines-audit/SKILL.md: file not found"
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
