---
name: tines-auth
description: Validate Tines API connection, check credentials, and test tenant connectivity. Use when the user wants to connect to Tines, verify their API token, check tenant status, troubleshoot authentication issues, configure credentials, or switch profiles.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Validate and test the Tines API connection.

## Scope

This skill covers credential configuration, profile management, connection validation, token verification, and tenant health checks.

- For story/workflow management, see **tines-stories**
- For case/incident management, see **tines-cases**
- For credential management, see **tines-credentials**
- For tenant administration, see **tines-admin**

## Jobs to Be Done

- Configure Tines credentials (interactive setup)
- Switch between credential profiles (default, staging, production, etc.)
- Show the active profile and available profiles
- Validate environment variables and credentials file
- Test API connection and token validity
- Display tenant info and connection status
- Troubleshoot authentication issues

## Credential Sources

Credentials are resolved in priority order:

1. **Environment variables** — `$TINES_TENANT_URL` and `$TINES_API_TOKEN` (highest priority)
2. **Credentials file** — `~/.tines/credentials` using the active profile
3. **Prompt the user** — if neither source provides credentials

The active profile is determined by:

1. `$TINES_PROFILE` env var (override for scripting/CI)
2. `current` attribute in `~/.tines/credentials`
3. Falls back to `default`

Override the credentials file location: `export TINES_CREDENTIALS_FILE=/path/to/credentials`.

## Configure Credentials

When the user asks to configure or set up Tines credentials, write a credentials file:

```bash
mkdir -p ~/.tines && chmod 700 ~/.tines

cat > ~/.tines/credentials << 'CREDS'
current = default

[default]
tenant_url = https://TENANT.tines.com
api_token = TOKEN
CREDS

chmod 600 ~/.tines/credentials
```

Replace `TENANT` and `TOKEN` with values provided by the user. **Never echo the token back** — just confirm the file was written.

### Add a Profile

```bash
cat >> ~/.tines/credentials << 'CREDS'

[staging]
tenant_url = https://staging.tines.com
api_token = STAGING_TOKEN
CREDS
```

## Profile Management

### Switch Profile

Update the `current` attribute in the credentials file:

```bash
sed -i.bak 's/^current = .*/current = staging/' ~/.tines/credentials && rm -f ~/.tines/credentials.bak
```

If the file has no `current` line yet, add it:

```bash
if grep -q '^current = ' ~/.tines/credentials; then
  sed -i.bak 's/^current = .*/current = staging/' ~/.tines/credentials && rm -f ~/.tines/credentials.bak
else
  sed -i.bak '1s/^/current = staging\n\n/' ~/.tines/credentials && rm -f ~/.tines/credentials.bak
fi
```

### List Profiles

```bash
echo "Available profiles:"
grep '^\[' ~/.tines/credentials 2>/dev/null | tr -d '[]'
```

### Show Active Profile

```bash
TINES_CREDS_FILE="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"
if [ -n "${TINES_PROFILE:-}" ]; then
  echo "Active profile: $TINES_PROFILE (from env var)"
elif [ -f "$TINES_CREDS_FILE" ]; then
  CURRENT=$(awk '/^current\s*=/{gsub(/^current\s*=\s*/, ""); print; exit}' "$TINES_CREDS_FILE")
  echo "Active profile: ${CURRENT:-default} (from credentials file)"
else
  echo "Active profile: default (no credentials file found)"
fi
```

## Resolve Credentials

All skills use this resolution logic before making API calls. See `shared/common-patterns.md` for the full implementation.

```bash
# 1. Env vars (highest priority)
TINES_TENANT_URL="${TINES_TENANT_URL:-}"
TINES_API_TOKEN="${TINES_API_TOKEN:-}"

# 2. Credentials file fallback
if [ -z "$TINES_TENANT_URL" ] || [ -z "$TINES_API_TOKEN" ]; then
  TINES_CREDS_FILE="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"
  if [ -f "$TINES_CREDS_FILE" ]; then
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
  echo "Either set TINES_TENANT_URL and TINES_API_TOKEN env vars,"
  echo "or run the configure step to create ~/.tines/credentials"
  exit 1
fi

TINES_BASE_URL="${TINES_TENANT_URL%/}/api/v1"
AUTH_HEADER='x-user-token: '"$TINES_API_TOKEN"''
```

## Token Security

**CRITICAL**: NEVER echo, log, print, or output `$TINES_API_TOKEN` in any command, regardless of whether it came from env vars or the credentials file. Always use variable references in curl commands, never interpolated values in output.

## Test Connection

After resolving credentials, call the info endpoint to validate:

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/info" | jq .
```

- On success (HTTP 200): Display tenant name, user info, and confirm connection is active
- On failure (HTTP 401/404): Report that the token is invalid or lacks permissions
- On failure (other): Report the HTTP status and suggest checking the tenant URL

Report:
- Tenant URL (safe to display)
- Active profile name
- Connection status
- User/tenant info from the response
- **Never show the API token value**

## Pagination Pattern

Tines returns paginated results with a `meta` object:
```bash
# Default: 20 items/page, max: 500
# Use ?per_page=500&page=1 for efficient fetching
# Follow meta.next_page_number until null
```

---

## Reference

See `references/api-reference.md` for the complete rate limits table and error code reference.
