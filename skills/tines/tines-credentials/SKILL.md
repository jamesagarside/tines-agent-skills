---
name: tines-credentials
description: Manage Tines credentials and shared resources — list, view, create, update, delete credentials (AWS, HTTP, JWT, MTLS, OAuth, Text) and shared resources (file, JSON, text). Use when the user wants to manage secrets, API keys, or shared data in Tines.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Manage Tines credentials and shared resources.

## Scope

This skill covers credential CRUD (6 types) and shared resource management.

- For workflow/story management, see **tines-stories**
- For case/incident management, see **tines-cases**
- For tenant administration, see **tines-admin**
- For validating API connectivity, see **tines-auth**

## Jobs to Be Done

- List, view, create, update, and delete credentials
- Create credentials of any type: Text, AWS, HTTP Request, JWT, OAuth, MTLS
- Manage credential access scope (team, global, specific teams)
- List, view, create, update, and delete shared resources (JSON, text)

## Prerequisites

Requires Tines credentials via environment variables (`TINES_TENANT_URL`, `TINES_API_TOKEN`) or a credentials file (`~/.tines/credentials`). Run `tines-auth` first to configure or validate connectivity.

## Common Patterns

Resolve credentials (env vars take priority over credentials file):

```bash
TINES_TENANT_URL="${TINES_TENANT_URL:-}"
TINES_API_TOKEN="${TINES_API_TOKEN:-}"
if [ -z "$TINES_TENANT_URL" ] || [ -z "$TINES_API_TOKEN" ]; then
  TINES_CREDS_FILE="${TINES_CREDENTIALS_FILE:-$HOME/.tines/credentials}"
  if [ -f "$TINES_CREDS_FILE" ]; then
    # Resolve active profile: env var > 'current' attribute > default
    if [ -z "${TINES_PROFILE:-}" ]; then
      TINES_PROFILE=$(awk '/^current\s*=/{gsub(/^current\s*=\s*/, ""); print; exit}' "$TINES_CREDS_FILE")
    fi
    TINES_PROFILE="${TINES_PROFILE:-default}"
    TINES_TENANT_URL="${TINES_TENANT_URL:-$(awk "/^\[${TINES_PROFILE}\]/{found=1; next} /^\[/{found=0} found && /^tenant_url/{print \$3}" "$TINES_CREDS_FILE")}"
    TINES_API_TOKEN="${TINES_API_TOKEN:-$(awk "/^\[${TINES_PROFILE}\]/{found=1; next} /^\[/{found=0} found && /^api_token/{print \$3}" "$TINES_CREDS_FILE")}"
  fi
fi
TINES_BASE_URL="${TINES_TENANT_URL%/}/api/v1"
AUTH_HEADER='x-user-token: '"$TINES_API_TOKEN"''
```

## Security Rules

**CRITICAL**:
- Never echo, log, or output `$TINES_API_TOKEN`
- Never display credential secret values (keys, tokens, passwords) in any output
- When listing credentials, show ONLY metadata: name, type, team, scope
- When creating credentials, do not echo the secret values back

## Operations — Credentials

### List Credentials

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/user_credentials?per_page=500" \
  | jq '.user_credentials[] | {id, name, mode, team_id, read_access}'
```

**Note**: Only display metadata fields — never show secret values.

### Get Credential Details

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/user_credentials/{id}" \
  | jq '{id, name, mode, team_id, read_access, description, allowed_hosts}'
```

### Create Text Credential

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "Credential Name",
    "mode": "TEXT",
    "team_id": TEAM_ID,
    "value": "secret-value-here"
  }' \
  "${TINES_BASE_URL}/user_credentials" | jq '{id, name, mode}'
```

### Update Credential

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Updated Name", "description": "Updated description"}' \
  "${TINES_BASE_URL}/user_credentials/{id}" | jq '{id, name, mode}'
```

### Delete Credential

**DESTRUCTIVE** — Stories using this credential will break. Confirm with user and warn about downstream impact.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/user_credentials/{id}"
```

### Access Scope Options

- `read_access`: `TEAM` (default), `GLOBAL`, or `SPECIFIC_TEAMS`
- `shared_team_slugs`: Array of team slugs (when `read_access` is `SPECIFIC_TEAMS`)

---

## Operations — Shared Resources

### List Resources

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/resources?per_page=500" | jq .
```

### Create JSON Resource

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "Resource Name",
    "type": "json",
    "team_id": TEAM_ID,
    "value": {"key": "value"}
  }' \
  "${TINES_BASE_URL}/resources" | jq .
```

### Delete Resource

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/resources/{id}"
```

---

## Credential Types

See `references/api-reference.md` for complete JSON schemas for all 6 credential types:

| Type | Mode Value | Key Fields |
|---|---|---|
| Text | `TEXT` | `value` |
| AWS (Key) | `AWS` | `aws_authentication_type`, `aws_access_key`, `aws_secret_key` |
| AWS (Role) | `AWS` | `aws_authentication_type`, `aws_assumed_role_arn` |
| HTTP Request | `HTTP_REQUEST` | `headers`, `allowed_hosts` |
| JWT | `JWT` | `jwt_algorithm`, `jwt_private_key`, `jwt_payload` |
| OAuth | `OAUTH` | `oauth_url`, `oauth_token_url`, `oauth_client_id`, `oauth_client_secret`, `oauth_scope` |
