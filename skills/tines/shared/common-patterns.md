# Tines API — Common Patterns

Shared reference for all Tines agent skills.

## Credential Resolution

Credentials are resolved in this order (highest priority wins):

1. **Environment variables** — `$TINES_TENANT_URL` and `$TINES_API_TOKEN`
2. **Credentials file** — `~/.tines/credentials` using the active profile
3. **Prompt the user** — if neither source provides credentials

### Active Profile Resolution

The active profile is determined by (highest priority wins):

1. `$TINES_PROFILE` env var — override for scripting/CI
2. `current` attribute at the top of `~/.tines/credentials`
3. Falls back to `default` if neither is set

### Resolution Logic

```bash
# 1. Try env vars first
TINES_TENANT_URL="${TINES_TENANT_URL:-}"
TINES_API_TOKEN="${TINES_API_TOKEN:-}"

# 2. Fall back to credentials file
if [ -z "$TINES_TENANT_URL" ] || [ -z "$TINES_API_TOKEN" ]; then
  TINES_CREDS_FILE="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"
  if [ -f "$TINES_CREDS_FILE" ]; then
    # Check file permissions (must be 600 — user-read-only)
    PERMS=$(stat -f "%Lp" "$TINES_CREDS_FILE" 2>/dev/null || stat -c "%a" "$TINES_CREDS_FILE" 2>/dev/null)
    if [ "$PERMS" != "600" ]; then
      echo "WARNING: $TINES_CREDS_FILE has permissions $PERMS (should be 600). Run: chmod 600 $TINES_CREDS_FILE"
    fi
    # Resolve active profile: env var > current attribute > default
    if [ -z "${TINES_PROFILE:-}" ]; then
      TINES_PROFILE=$(awk '/^current\s*=/{gsub(/^current\s*=\s*/, ""); print; exit}' "$TINES_CREDS_FILE")
    fi
    TINES_PROFILE="${TINES_PROFILE:-default}"
    TINES_TENANT_URL="${TINES_TENANT_URL:-$(awk "/^\[${TINES_PROFILE}\]/{found=1; next} /^\[/{found=0} found && /^tenant_url/{print \$3}" "$TINES_CREDS_FILE")}"
    TINES_API_TOKEN="${TINES_API_TOKEN:-$(awk "/^\[${TINES_PROFILE}\]/{found=1; next} /^\[/{found=0} found && /^api_token/{print \$3}" "$TINES_CREDS_FILE")}"
  fi
fi

# 3. Validate
if [ -z "$TINES_TENANT_URL" ] || [ -z "$TINES_API_TOKEN" ]; then
  echo "ERROR: Tines credentials not found."
  echo "Set env vars or run: tines-auth configure"
  exit 1
fi

TINES_BASE_URL="${TINES_TENANT_URL%/}/api/v1"
AUTH_HEADER='x-user-token: '"$TINES_API_TOKEN"''
```

### Credentials File Format

Location: `~/.tines/credentials` (override with `$TINES_CREDENTIALS_FILE`)

```ini
current = default

[default]
tenant_url = https://my-tenant.tines.com
api_token = your-api-token-here

[staging]
tenant_url = https://staging.tines.com
api_token = staging-token-here

[production]
tenant_url = https://prod.tines.com
api_token = prod-token-here
```

### Switching Profiles

The agent can switch the active profile by updating the `current` line:

```bash
sed -i '' 's/^current = .*/current = staging/' ~/.tines/credentials
```

Or with `$TINES_PROFILE` env var for one-off overrides:
```bash
TINES_PROFILE=production   # overrides 'current' for this session only
```

### Security Requirements

- File permissions MUST be `600` (`chmod 600 ~/.tines/credentials`)
- The `~/.tines/` directory should be `700` (`chmod 700 ~/.tines`)
- Never store credentials inside a git repository
- The agent must verify the file is not inside a git working tree before reading

**CRITICAL**: Never echo, log, print, or output `$TINES_API_TOKEN` in any command, regardless of its source. Always use variable references — never interpolated values in output.

## Pagination

Tines returns paginated results with a `meta` object:

- Default: 20 items per page
- Maximum: 500 items per page (`?per_page=500`)
- Follow `meta.next_page_number` until null

```bash
PAGE=1
while true; do
  RESPONSE=$(curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/{endpoint}?per_page=500&page=${PAGE}")
  echo "$RESPONSE" | jq '.{resource}[]'
  NEXT=$(echo "$RESPONSE" | jq -r '.meta.next_page_number // empty')
  [ -z "$NEXT" ] && break
  PAGE=$NEXT
done
```

## Error Handling

| Code | Meaning | Action |
|------|---------|--------|
| 401 | Invalid token | Check credentials — may need to regenerate token |
| 404 | Not found or insufficient permissions | Tines returns 404 for underprivileged tokens |
| 429 | Rate limited | Back off and retry |
| 5xx | Server error | Retry with exponential backoff |

## Rate Limits

Enforced per IP address and API token combination.

| Endpoint | Requests/Minute |
|----------|-----------------|
| General | 5000 |
| actions/agents | 100 |
| admin/users | 500 |
| audit_logs | 1000 |
| records | 400 |
| tokens | 2500 |

## Curl Conventions

All curl commands in these skills follow these conventions:

- `-s` (silent) — suppress progress output
- `-f` (fail) — return error on HTTP failures
- `-H "$AUTH_HEADER"` — authenticate via token header
- `| jq .` — parse and format JSON output
- `-X POST/PATCH/PUT/DELETE` — explicit HTTP method for write operations
- `-H 'Content-Type: application/json'` — required for POST/PATCH/PUT with JSON body

## Destructive Operations

All DELETE operations and state-clearing actions are marked **DESTRUCTIVE** in each skill. The agent MUST:

1. Confirm with the user before executing
2. Warn about the blast radius (e.g., downstream dependencies)
3. Never batch-delete without explicit user approval
