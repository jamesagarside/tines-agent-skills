---
name: tines-stories
description: Manage Tines stories — list, view, create, update, delete, export, import stories, and inspect story runs, events, and versions. Use when the user wants to work with Tines workflows/stories.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Manage Tines stories (workflows).

## Scope

This skill covers story CRUD, export/import, runs, events, versions, and change control.

- For individual workflow step management, see **tines-actions**
- For case/incident management, see **tines-cases**
- For credential management, see **tines-credentials**
- For structured data records, see **tines-records**

## Jobs to Be Done

- List, create, update, and delete stories
- Export and import story definitions as JSON
- View story runs and run events
- Manage story versions and change control
- Re-emit events through workflows

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

**CRITICAL**: Never echo or log `$TINES_API_TOKEN`. See `shared/common-patterns.md` for the full resolution logic, pagination, and error handling.

## Operations

### List Stories

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500" | jq '.stories[] | {id, name, team_id, edited_at, disabled}'
```

For pagination:
```bash
PAGE=1
while true; do
  RESPONSE=$(curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500&page=${PAGE}")
  echo "$RESPONSE" | jq '.stories[] | {id, name, team_id, edited_at, disabled}'
  NEXT=$(echo "$RESPONSE" | jq -r '.meta.next_page_number // empty')
  [ -z "$NEXT" ] && break
  PAGE=$NEXT
done
```

### Get Story Details

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}" | jq .
```

### Create Story

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Story Name", "team_id": TEAM_ID}' \
  "${TINES_BASE_URL}/stories" | jq .
```

Optional fields: `description`, `keep_events_for`, `folder_id`, `tags` (array), `disabled`, `priority`.

### Update Story

```bash
curl -s -f -X PUT -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "New Name"}' \
  "${TINES_BASE_URL}/stories/{id}" | jq .
```

### Delete Story

**DESTRUCTIVE** — Confirm with user before executing.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}"
```

### Export Story

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/export" | jq .
```

Save to file:
```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/export" > story_export.json
```

### Import Story

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d @story_export.json \
  "${TINES_BASE_URL}/stories/import" | jq .
```

---

## Extended Operations

See `references/api-reference.md` for full endpoint details on:

| Operation | Endpoints |
|---|---|
| Story Runs | `/stories/{id}/runs` |
| Story Events | `/stories/{id}/events`, `/agents/{id}/events` |
| Run Events | `/stories/{id}/runs/{run_id}/events` |
| Re-emit Event | `/events/{event_id}/reemit` |
| Versions | `/stories/{id}/versions` |
| Change Control | `/stories/{id}/change-requests` |

## Guidelines

- Story-level events (`/stories/{id}/events`) may return 404 — use per-agent events (`/agents/{id}/events`) instead
- Export before making significant changes for easy rollback
- Use change control for production stories that require approval workflows
