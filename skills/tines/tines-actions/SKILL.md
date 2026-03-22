---
name: tines-actions
description: Manage Tines actions within stories — list, view, create, update, delete actions, view action events and logs, re-emit events, and clear action memory. Use when the user wants to work with individual workflow steps/actions in Tines.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Manage Tines actions (individual workflow steps within stories).

> **Note:** The Tines API accepts both `/actions` and `/agents` as endpoint paths — they are aliases. The examples below use `/agents`, which matches the response JSON key (`agents`). You can substitute `/actions` in any URL path and get the same result.

## Scope

This skill covers action CRUD, event inspection, log viewing, and memory management within stories.

- For story-level management, see **tines-stories**
- For case/incident management, see **tines-cases**
- For credential management, see **tines-credentials**

## Jobs to Be Done

- List all actions within a story
- Create, update, and delete actions
- View action events and logs
- Re-emit events through the workflow
- Clear action memory/stored state

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

## Rate Limit Warning

The agents/actions endpoint has a **100 requests/minute** limit. When performing batch operations on multiple agents, pace requests with delays between calls. Warn the user if an operation will hit many agents.

## Operations

### List Actions in a Story

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents?story_id={story_id}&per_page=500" | jq '.agents[] | {id, name, type, position}'
```

### Get Action Details

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents/{id}" | jq .
```

### Create Action

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "story_id": STORY_ID,
    "name": "Action Name",
    "type": "ACTION_TYPE",
    "options": {}
  }' \
  "${TINES_BASE_URL}/agents" | jq .
```

### Update Action

```bash
curl -s -f -X PUT -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "New Name", "options": {}}' \
  "${TINES_BASE_URL}/agents/{id}" | jq .
```

### Delete Action

**DESTRUCTIVE** — Confirm with user before executing.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents/{id}"
```

---

## Extended Operations

See `references/api-reference.md` for full endpoint details on:

| Operation | Endpoint | Notes |
|---|---|---|
| List Events | `/agents/{id}/events` | Per-agent event retrieval |
| Re-emit Event | `/events/{event_id}/reemit` | Replay through workflow |
| View Logs | `/agents/{id}/logs` | Action execution logs |
| Delete Logs | `/agents/{id}/logs` | **DESTRUCTIVE** |
| Clear Memory | `/agents/{id}/memory` | **DESTRUCTIVE**, may not be available on all plans |

## Batch Operation Guidance

When the user asks to operate on many agents (e.g., "update all agents in story X"):
1. Warn about the 100/min rate limit
2. List agents first to show scope
3. Process with 1-second delays between calls if more than 20 agents
4. Report progress during execution
