---
name: tines-cases
description: Manage Tines cases — list, view, create, update, delete cases, and manage case comments, tasks, files, notes, metadata, linked cases, subscribers, records, and PDF exports. Use when the user wants to work with Tines case management for incidents or issues.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Manage Tines cases (incident/issue tracking).

## Scope

This skill covers case CRUD and all case sub-resources (comments, tasks, files, notes, metadata, linked cases, subscribers, records, PDF export).

- For workflow/story management, see **tines-stories**
- For credential management, see **tines-credentials**
- For structured data records outside cases, see **tines-records**
- For tenant administration, see **tines-admin**

## Jobs to Be Done

- List, filter, and search cases by status or priority
- Create, update, and delete cases
- Append context to case descriptions without overwriting
- Manage case sub-resources (comments, tasks, files, notes, metadata)
- Link and unlink related cases
- Export case reports as PDF
- Manage case subscribers and attached records

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

### List Cases

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases?per_page=500" | jq '.cases[] | {case_id, name, status, priority, created_at}'
```

Filter by status or priority:
```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases?status=open&per_page=500" | jq .
```

Paginate with `meta.next_page_number`.

### Get Case Details

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}" | jq .
```

### Create Case

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Case Name", "status": "open"}' \
  "${TINES_BASE_URL}/cases" | jq .
```

### Update Case

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"status": "in_progress", "priority": "high"}' \
  "${TINES_BASE_URL}/cases/{id}" | jq .
```

### Delete Case

**DESTRUCTIVE** — Confirm with user before executing.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}"
```

### Append to Case Description

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"description_append": "Additional context here"}' \
  "${TINES_BASE_URL}/cases/{id}" | jq .
```

### Export Case as PDF

```bash
curl -s -f -H "$AUTH_HEADER" -o case_report.pdf \
  "${TINES_BASE_URL}/cases/{id}/pdf"
```

---

## Sub-Resources

Cases support the following sub-resources. See `references/api-reference.md` for full endpoint details, request/response examples, and parameter definitions.

| Sub-Resource | Endpoint | Operations | Plan Note |
|---|---|---|---|
| Comments | `/cases/{id}/comments` | List, Create, Update, Delete | May not be available on all plans |
| Tasks | `/cases/{id}/tasks` | List, Create, Update (complete), Delete | May not be available on all plans |
| Files | `/cases/{id}/files` | List, Upload, Download, Delete | May not be available on all plans |
| Notes | `/cases/{id}/notes` | List, Create, Update, Append, Delete | May not be available on all plans |
| Metadata | `/cases/{id}/metadata` | List, Create, Update, Delete | |
| Linked Cases | `/cases/{id}/linked_cases` | List, Link, Batch Link, Unlink | |
| Subscribers | `/cases/{id}/subscribers` | List, Add, Remove | |
| Records | `/cases/{id}/records` | List, Add, Remove | |
| PDF Export | `/cases/{id}/pdf` | Download | |

## Guidelines

- Always list cases first to confirm scope before bulk operations
- Use `description_append` to add context without overwriting existing descriptions
- Sub-resource DELETE operations are **DESTRUCTIVE** — always confirm with the user
- Check plan availability before using comments, tasks, files, or notes endpoints
