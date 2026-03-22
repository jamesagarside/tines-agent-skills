#!/usr/bin/env bash
#
# Tests for scripts/tines-api.sh wrapper
# Validates credential resolution, profile management, and command parsing.
# Does NOT require a Tines tenant — tests use mock credentials files.
#
# Usage: ./tests/test-api-wrapper.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API_SCRIPT="$REPO_ROOT/scripts/tines-api.sh"

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

# Create temp directory for mock credentials
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

echo "=========================================="
echo " Tines Agent Skills — API Wrapper Tests"
echo "=========================================="
echo ""

# ─────────────────────────────────────────────
# Test 1: Script exists and is executable
# ─────────────────────────────────────────────
echo "1. Script Basics"
echo "─────────────────"

if [[ -f "$API_SCRIPT" ]]; then
  pass "tines-api.sh exists"
else
  fail "tines-api.sh not found"
fi

if [[ -x "$API_SCRIPT" ]]; then
  pass "tines-api.sh is executable"
else
  fail "tines-api.sh is not executable"
fi

# Check shebang
if head -1 "$API_SCRIPT" | grep -q '#!/usr/bin/env bash'; then
  pass "tines-api.sh has bash shebang"
else
  fail "tines-api.sh missing bash shebang"
fi

echo ""

# ─────────────────────────────────────────────
# Test 2: Usage / help
# ─────────────────────────────────────────────
echo "2. Usage Output"
echo "────────────────"

help_output=$(bash "$API_SCRIPT" --help 2>&1)
if [[ $? -eq 0 ]]; then
  pass "tines-api.sh --help exits cleanly"
else
  fail "tines-api.sh --help exits with error"
fi

if echo "$help_output" | grep -q "GET"; then
  pass "help mentions GET"
else
  fail "help missing GET"
fi

if echo "$help_output" | grep -q "POST"; then
  pass "help mentions POST"
else
  fail "help missing POST"
fi

if echo "$help_output" | grep -q "profile"; then
  pass "help mentions profile commands"
else
  fail "help missing profile commands"
fi

if echo "$help_output" | grep -q "paginate"; then
  pass "help mentions pagination"
else
  fail "help missing pagination"
fi

# No args should also show usage
no_args_output=$(bash "$API_SCRIPT" 2>&1)
if echo "$no_args_output" | grep -qi "usage"; then
  pass "no-args shows usage"
else
  fail "no-args does not show usage"
fi

echo ""

# ─────────────────────────────────────────────
# Test 3: Profile management with mock creds file
# ─────────────────────────────────────────────
echo "3. Profile Management"
echo "─────────────────────"

# Create mock credentials file
MOCK_CREDS="$TMPDIR_TEST/credentials"
cat > "$MOCK_CREDS" << 'EOF'
current = default

[default]
tenant_url = https://default.tines.com
api_token = default-token-123

[staging]
tenant_url = https://staging.tines.com
api_token = staging-token-456

[production]
tenant_url = https://prod.tines.com
api_token = prod-token-789
EOF
chmod 600 "$MOCK_CREDS"

# Test profile listing
profile_output=$(TINES_CREDENTIALS_FILE="$MOCK_CREDS" bash "$API_SCRIPT" profiles 2>&1)
if echo "$profile_output" | grep -q "default"; then
  pass "profiles: lists default profile"
else
  fail "profiles: missing default profile"
fi

if echo "$profile_output" | grep -q "staging"; then
  pass "profiles: lists staging profile"
else
  fail "profiles: missing staging profile"
fi

if echo "$profile_output" | grep -q "production"; then
  pass "profiles: lists production profile"
else
  fail "profiles: missing production profile"
fi

if echo "$profile_output" | grep -q "active"; then
  pass "profiles: marks active profile"
else
  fail "profiles: does not mark active profile"
fi

# Test show active profile
active_output=$(TINES_CREDENTIALS_FILE="$MOCK_CREDS" bash "$API_SCRIPT" profile 2>&1)
if echo "$active_output" | grep -q "default"; then
  pass "profile: shows default as active"
else
  fail "profile: does not show default as active"
fi

# Test env var override for profile
env_profile_output=$(TINES_PROFILE=staging TINES_CREDENTIALS_FILE="$MOCK_CREDS" bash "$API_SCRIPT" profile 2>&1)
if echo "$env_profile_output" | grep -q "staging" && echo "$env_profile_output" | grep -q "env var"; then
  pass "profile: env var TINES_PROFILE overrides"
else
  fail "profile: env var TINES_PROFILE does not override"
fi

# Test switch profile
SWITCH_CREDS="$TMPDIR_TEST/switch-credentials"
cp "$MOCK_CREDS" "$SWITCH_CREDS"
chmod 600 "$SWITCH_CREDS"
switch_output=$(TINES_CREDENTIALS_FILE="$SWITCH_CREDS" bash "$API_SCRIPT" switch staging 2>&1)
if echo "$switch_output" | grep -q "Switched to profile: staging"; then
  pass "switch: reports success"
else
  fail "switch: does not report success"
fi

# Verify the file was actually updated
if grep -q "^current = staging" "$SWITCH_CREDS"; then
  pass "switch: updates current in file"
else
  fail "switch: does not update current in file"
fi

# Verify active profile changed
post_switch=$(TINES_CREDENTIALS_FILE="$SWITCH_CREDS" bash "$API_SCRIPT" profile 2>&1)
if echo "$post_switch" | grep -q "staging"; then
  pass "switch: profile command reflects new active"
else
  fail "switch: profile command does not reflect new active"
fi

# Test switching to nonexistent profile
bad_switch=$(TINES_CREDENTIALS_FILE="$MOCK_CREDS" bash "$API_SCRIPT" switch nonexistent 2>&1)
if [[ $? -ne 0 ]] || echo "$bad_switch" | grep -q "not found"; then
  pass "switch: rejects nonexistent profile"
else
  fail "switch: does not reject nonexistent profile"
fi

echo ""

# ─────────────────────────────────────────────
# Test 4: Credential resolution precedence
# ─────────────────────────────────────────────
echo "4. Credential Resolution"
echo "────────────────────────"

# Env vars should take priority over creds file
# We can't actually make an API call, but we can test that the script
# tries to use env vars by providing a bad creds file and good env vars
NO_CREDS="$TMPDIR_TEST/nocreds"
touch "$NO_CREDS"
chmod 600 "$NO_CREDS"

# Test missing credentials (no env vars, empty creds file)
unset TINES_TENANT_URL 2>/dev/null || true
unset TINES_API_TOKEN 2>/dev/null || true
error_output=$(TINES_CREDENTIALS_FILE="$NO_CREDS" bash "$API_SCRIPT" GET /info 2>&1)
if echo "$error_output" | grep -qi "error.*credentials\|not found"; then
  pass "resolution: reports error when no credentials available"
else
  fail "resolution: does not report error for missing credentials"
fi

# Test credentials file resolution (reads correct profile)
PROFILE_CREDS="$TMPDIR_TEST/profile-creds"
cat > "$PROFILE_CREDS" << 'EOF'
current = staging

[default]
tenant_url = https://default.example.com
api_token = default-token

[staging]
tenant_url = https://staging.example.com
api_token = staging-token
EOF
chmod 600 "$PROFILE_CREDS"

# The test command would try to connect and fail (no real server),
# but we can verify it reads the right profile by checking the error message
test_output=$(TINES_CREDENTIALS_FILE="$PROFILE_CREDS" bash "$API_SCRIPT" test 2>&1 || true)
if echo "$test_output" | grep -q "staging"; then
  pass "resolution: reads current profile from credentials file"
else
  fail "resolution: does not read current profile"
fi

echo ""

# ─────────────────────────────────────────────
# Test 5: File permissions warning
# ─────────────────────────────────────────────
echo "5. Security Checks"
echo "───────────────────"

# Create creds file with bad permissions
BAD_PERMS_CREDS="$TMPDIR_TEST/bad-perms"
cat > "$BAD_PERMS_CREDS" << 'EOF'
[default]
tenant_url = https://test.tines.com
api_token = test-token
EOF
chmod 644 "$BAD_PERMS_CREDS"

perms_output=$(TINES_CREDENTIALS_FILE="$BAD_PERMS_CREDS" bash "$API_SCRIPT" test 2>&1 || true)
if echo "$perms_output" | grep -qi "warning.*permissions\|should be 600"; then
  pass "security: warns about insecure file permissions"
else
  fail "security: no warning for insecure file permissions"
fi

# Verify script never outputs token value
if echo "$perms_output" | grep -q "test-token"; then
  fail "security: token value leaked in output"
else
  pass "security: token value not leaked"
fi

echo ""

# ─────────────────────────────────────────────
# Test 6: Command validation
# ─────────────────────────────────────────────
echo "6. Command Validation"
echo "─────────────────────"

# Unknown command should fail
unknown_output=$(bash "$API_SCRIPT" INVALID 2>&1)
if echo "$unknown_output" | grep -qi "unknown\|error"; then
  pass "validation: rejects unknown command"
else
  fail "validation: does not reject unknown command"
fi

# Missing endpoint should fail
missing_ep=$(TINES_TENANT_URL="https://test.com" TINES_API_TOKEN="test" bash "$API_SCRIPT" GET 2>&1)
if echo "$missing_ep" | grep -qi "endpoint.*required\|error"; then
  pass "validation: requires endpoint for HTTP methods"
else
  fail "validation: does not require endpoint"
fi

# Switch without profile name should fail
no_profile_switch=$(bash "$API_SCRIPT" switch 2>&1)
if echo "$no_profile_switch" | grep -qi "usage\|error"; then
  pass "validation: switch requires profile name"
else
  fail "validation: switch does not require profile name"
fi

echo ""

# ─────────────────────────────────────────────
# Test 7: Script structure
# ─────────────────────────────────────────────
echo "7. Script Structure"
echo "────────────────────"

# Should not contain hardcoded tokens/URLs
if grep -qE 'api_token\s*=\s*"[^$]' "$API_SCRIPT" || grep -qE 'tines\.com' "$API_SCRIPT"; then
  fail "structure: contains hardcoded credentials or URLs"
else
  pass "structure: no hardcoded credentials or URLs"
fi

# Should use set -euo pipefail
if grep -q 'set -euo pipefail' "$API_SCRIPT"; then
  pass "structure: uses strict bash mode"
else
  fail "structure: missing strict bash mode"
fi

# Should never echo the token
if grep -qE '^\s*echo.*\$TINES_API_TOKEN\b' "$API_SCRIPT" | grep -v 'x-user-token' > /dev/null 2>&1; then
  fail "structure: may echo token value"
else
  pass "structure: does not echo token value"
fi

# Should support all HTTP methods
for method in GET POST PATCH PUT DELETE; do
  if grep -q "$method)" "$API_SCRIPT"; then
    pass "structure: supports $method method"
  else
    fail "structure: missing $method method"
  fi
done

# Should have pagination support
if grep -q 'paginate\|--paginate' "$API_SCRIPT"; then
  pass "structure: has pagination support"
else
  fail "structure: missing pagination support"
fi

echo ""

# ─────────────────────────────────────────────
# Test 8: Credentials file without current attribute
# ─────────────────────────────────────────────
echo "8. Edge Cases"
echo "──────────────"

# Creds file without 'current' should default to 'default'
NO_CURRENT_CREDS="$TMPDIR_TEST/no-current"
cat > "$NO_CURRENT_CREDS" << 'EOF'
[default]
tenant_url = https://test.tines.com
api_token = test-token

[other]
tenant_url = https://other.tines.com
api_token = other-token
EOF
chmod 600 "$NO_CURRENT_CREDS"

no_current_output=$(TINES_CREDENTIALS_FILE="$NO_CURRENT_CREDS" bash "$API_SCRIPT" profile 2>&1)
if echo "$no_current_output" | grep -q "default"; then
  pass "edge: defaults to 'default' when no current attribute"
else
  fail "edge: does not default to 'default' without current attribute"
fi

# Test adding current to a file that doesn't have one
SWITCH_NO_CURRENT="$TMPDIR_TEST/switch-no-current"
cp "$NO_CURRENT_CREDS" "$SWITCH_NO_CURRENT"
chmod 600 "$SWITCH_NO_CURRENT"
TINES_CREDENTIALS_FILE="$SWITCH_NO_CURRENT" bash "$API_SCRIPT" switch other 2>&1 > /dev/null
if grep -q "^current = other" "$SWITCH_NO_CURRENT"; then
  pass "edge: adds current attribute when switching on file without one"
else
  fail "edge: cannot add current to file without existing attribute"
fi

# Empty creds file
EMPTY_CREDS="$TMPDIR_TEST/empty-creds"
touch "$EMPTY_CREDS"
chmod 600 "$EMPTY_CREDS"
empty_output=$(TINES_CREDENTIALS_FILE="$EMPTY_CREDS" bash "$API_SCRIPT" profiles 2>&1)
if [[ $? -eq 0 ]]; then
  pass "edge: handles empty credentials file without crashing"
else
  fail "edge: crashes on empty credentials file"
fi

# Missing credentials file
missing_output=$(TINES_CREDENTIALS_FILE="$TMPDIR_TEST/nonexistent" bash "$API_SCRIPT" profiles 2>&1)
if [[ $? -eq 0 ]]; then
  pass "edge: handles missing credentials file gracefully"
else
  fail "edge: crashes on missing credentials file"
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
