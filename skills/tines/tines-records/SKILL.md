---
name: tines-records
description: Manage Tines records — list, view, create, update, delete records, manage record types and record views. Use when the user wants to work with structured data records in Tines.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Manage Tines records (structured data storage).

## Scope

This skill covers records, record types, record views, and record artifacts.

- For case/incident management, see **tines-cases**
- For credential management, see **tines-credentials**
- For workflow/story management, see **tines-stories**

## Jobs to Be Done

- List, create, update, and delete records (by record type)
- Manage record type schemas (fields and definitions)
- List, export, import, and delete record views
- Retrieve record artifacts

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

The records endpoint has a **400 requests/minute** limit. When performing bulk record operations, pace requests and warn the user about the limit.

## Operations

### List Records

**Note**: The `record_type_id` parameter is required — you cannot list all records without specifying a record type.

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/records?record_type_id={type_id}&per_page=500" | jq .
```

To discover available record types, use the List Record Types endpoint below.

Paginate with `meta.next_page_number`.

### Get Record

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/records/{id}" | jq .
```

### Create Record

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "record_type_id": TYPE_ID,
    "field_values": [
      {"field_id": FIELD_ID, "value": "field value"}
    ]
  }' \
  "${TINES_BASE_URL}/records" | jq .
```

Optional fields: `case_ids` (array to link cases), `test_mode` (boolean).

### Update Record

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "field_values": [
      {"field_id": FIELD_ID, "value": "updated value"}
    ]
  }' \
  "${TINES_BASE_URL}/records/{id}" | jq .
```

### Delete Record

**DESTRUCTIVE** — Confirm with user before executing.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/records/{id}"
```

---

## Record Types

Record types define the schema (fields) for records. Requires `team_id` as a query parameter.

```bash
# List record types
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/record_types?team_id={team_id}" | jq .

# Create record type
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Type Name", "fields": [{"name": "Field Name", "type": "text"}]}' \
  "${TINES_BASE_URL}/record_types" | jq .
```

**DESTRUCTIVE** — Delete record type (may affect records using it). Confirm with user:
```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/record_types/{id}"
```

---

## Extended Operations

See `references/api-reference.md` for full endpoint details on:

| Operation | Endpoints |
|---|---|
| Record Type CRUD | `/record_types`, `/record_types/{id}` |
| Record Views | `/record_views` — list, delete, export, import |
| Record Artifacts | `/records/artifacts/{id}` |

## Batch Operation Guidance

When the user asks to operate on many records:
1. Warn about the 400/min rate limit
2. List records first to show scope
3. Process with delays between calls if more than 50 records
4. Report progress during execution
