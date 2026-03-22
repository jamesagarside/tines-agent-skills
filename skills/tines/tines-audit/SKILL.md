---
name: tines-audit
description: Audit a Tines tenant for hygiene and compliance — find unused credentials, disabled stories, stale resources, orphaned records, and security issues. Use when the user wants to audit, clean up, or assess the health of their Tines tenant.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Audit a Tines tenant for hygiene, compliance, and overall health.

## Scope

This skill covers tenant-wide health checks including unused credentials, disabled or stale stories, orphaned resources, and security posture.

- For reviewing individual stories, see **tines-review**
- For user and team management, see **tines-admin**
- For credential management, see **tines-credentials**
- For story operations, see **tines-stories**
- For record management, see **tines-records**

## Jobs to Be Done

- Identify unused or orphaned credentials
- Find disabled or stale stories with no recent activity
- Check stories for missing error handling patterns
- Review credential scope and access controls
- Identify orphaned shared resources
- Generate a tenant health report with prioritised recommendations

## Prerequisites

Requires Tines credentials via environment variables (`TINES_TENANT_URL`, `TINES_API_TOKEN`) or a credentials file (`~/.tines/credentials`). Run `tines-auth` first to configure or validate connectivity.

**Note**: An admin-level API token is recommended for a complete audit. Limited tokens may restrict visibility into credentials, teams, or audit logs.

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

This is a **read-only audit** — no changes are made without explicit user approval. Before starting a full audit, be aware of API rate limits. Paginate all list requests and avoid rapid-fire calls against large tenants.

## Audit Process

### Step 1 — Inventory

Collect a full inventory of tenant resources:

**List all stories:**

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500" | jq '.stories[] | {id, name, disabled, edited_at}'
```

**List all credentials (metadata only):**

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/user_credentials?per_page=500" | jq '.user_credentials[] | {id, name, mode, team_id, read_access}'
```

**List all resources:**

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/resources?per_page=500" | jq .
```

**List all teams:**

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/teams?per_page=500" | jq '.teams[] | {id, name}'
```

Paginate all of the above for large tenants — see `shared/common-patterns.md` for the pagination loop.

### Step 2 — Credential Audit

For each credential in the inventory:

1. Check which stories reference the credential (search story exports for the credential name)
2. Flag credentials referenced by zero stories as **unused**
3. Check credential `read_access` scope — flag overly broad access (e.g. `TEAM` when `SPECIFIC_TEAMS` would suffice)
4. Check credential `mode` — note any credentials in `TEXT` mode that should be `OAUTH` or `AWS`

### Step 3 — Story Audit

For each story in the inventory:

1. Flag stories where `disabled` is `true`
2. Flag stories with `edited_at` older than 90 days as potentially stale
3. For active stories, export and run through `tines-review` checklist:
   - Missing `emit_failure_event` on HTTP Request actions
   - Hardcoded secrets in action options
   - Broken formula references
4. Flag stories with no actions (empty workflows)

### Step 4 — Resource Audit

1. List all shared resources and check which stories reference each one
2. Flag resources referenced by zero stories as **orphaned**
3. Check record types — verify they are actively used by at least one story
4. Review resource naming for consistency

### Step 5 — Report

Produce a summary grouped by category:

| Category | Items Checked | Issues Found | Critical | Warning | Info |
|---|---|---|---|---|---|
| Credentials | count | count | count | count | count |
| Stories | count | count | count | count | count |
| Resources | count | count | count | count | count |
| Teams | count | count | count | count | count |

Follow with prioritised recommendations, starting with critical issues.

## Audit Checklist

| Category | Check | Severity |
|---|---|---|
| Credentials | Unused credentials (no story references) | Warning |
| Credentials | Overly broad `read_access` scope | Warning |
| Credentials | TEXT mode credentials that should be OAUTH | Info |
| Stories | Disabled stories | Info |
| Stories | Stale stories (no edits in 90+ days) | Info |
| Stories | Stories without error handling | Critical |
| Stories | Stories with hardcoded secrets | Critical |
| Stories | Empty stories (no actions) | Warning |
| Resources | Orphaned resources (no story references) | Warning |
| Resources | Inconsistent resource naming | Info |
| Teams | Teams with no stories | Info |

---

## Extended Operations

See `references/api-reference.md` for the full list of endpoints used during auditing, including audit logs and team listings.

## Guidelines

- This audit is strictly read-only — never modify, delete, or disable resources without explicit user approval
- Respect API rate limits — add brief pauses between paginated requests on large tenants
- Paginate all list endpoints using `per_page=500` and the `page` parameter
- For credential audits, only metadata is accessed — credential values are never read or logged
- Cross-reference findings with `tines-review` for story-level detail and `tines-credentials` for credential management
- Present findings with clear severity levels so the user can prioritise remediation
