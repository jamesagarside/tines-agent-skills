---
name: tines-admin
description: Administer Tines tenant — manage users, view audit logs, monitor jobs, check system health, manage teams, folders, and tunnels. Use when the user wants to perform Tines admin operations, check system status, or manage users and teams.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Administer a Tines tenant.

## Scope

This skill covers tenant-level administration: users, teams, folders, audit logs, jobs, system health, tunnels, and templates.

- For workflow/story management, see **tines-stories**
- For case/incident management, see **tines-cases**
- For credential management, see **tines-credentials**
- For structured data records, see **tines-records**

## Jobs to Be Done

- List, invite, update, and remove users
- View and filter audit logs
- Monitor job queues (queued, in-progress, failed, retry)
- Check tenant info and system statistics
- Manage teams and team membership
- Manage folders (create, rename, nest, delete)
- Check tunnel health
- Manage admin templates

## Prerequisites

Requires Tines credentials via environment variables (`TINES_TENANT_URL`, `TINES_API_TOKEN`) or a credentials file (`~/.tines/credentials`). The API token must have **admin-level permissions** for most operations. Run `tines-auth` first to configure or validate connectivity.

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

**CRITICAL**: Never echo or log `$TINES_API_TOKEN`. See `shared/common-patterns.md` for the full resolution logic, pagination, and error handling.

## Safety Warning

Admin operations affect the entire tenant. All destructive operations (deleting users, modifying access controls) MUST be confirmed with the user before execution. Warn about the blast radius.

## Operations

### User Management

```bash
# List users
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/users?per_page=500" \
  | jq '.admin_users[] | {id, email, role, last_sign_in_at}'

# Get user
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/users/{id}" | jq .

# Invite user
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"email": "user@example.com", "role": "member"}' \
  "${TINES_BASE_URL}/admin/users" | jq .

# Update user role
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"role": "admin"}' \
  "${TINES_BASE_URL}/admin/users/{id}" | jq .
```

**DESTRUCTIVE** — Delete user (permanently removes access). Confirm with user:
```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/users/{id}"
```

Rate limit: 500/min for admin/users.

### System Info

```bash
# Tenant info
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/info" | jq .

# Web statistics
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/info/web_statistics" | jq .

# Worker statistics
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/info/worker_statistics" | jq .
```

### Team Management

```bash
# List teams
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/teams?per_page=500" | jq .

# Create team
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Team Name"}' \
  "${TINES_BASE_URL}/teams" | jq .
```

---

## Extended Operations

See `references/api-reference.md` for full endpoint details on:

| Operation Area | Endpoints | Key Operations |
|---|---|---|
| Audit Logs | `/audit_logs` | List, filter by date/user/action |
| Job Monitoring | `/admin/jobs/{status}` | List queued/in-progress/dead/retry, delete by status |
| Team Members | `/teams/{id}/members` | List, invite, remove |
| Folders | `/folders` | List, get, create, update, delete (supports nesting) |
| Tunnel Health | `/admin/tunnels/health` | Check health status |
| Admin Templates | `/admin/templates` | List, get, create, delete |
| User Actions | `/admin/users/{id}/*` | Resend invitation, expire sessions |

## Guidelines

- Always confirm destructive operations — admin actions have tenant-wide blast radius
- Audit log queries support date range filtering (`created_at_from`, `created_at_to`)
- Rate limit: 1000/min for audit_logs
- Folders support nesting via `parent_id` parameter
