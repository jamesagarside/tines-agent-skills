---
name: tines-review
description: Review Tines stories for quality and best practice compliance — audit naming conventions, error handling, security issues, formula correctness, and structural integrity. Use when the user wants to review, audit, or improve a Tines workflow or story.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Review Tines stories for quality and best practice compliance.

## Scope

This skill covers story-level quality review, including naming conventions, error handling, security, formula validation, and structural integrity.

- For building new stories, see **tines-build**
- For tenant-wide auditing, see **tines-audit**
- For story import/export operations, see **tines-stories**
- For best practice rules, see **shared/best-practices.md**
- For story structure validation, see **shared/story-schema.md**

## Jobs to Be Done

- Review a story export for quality and best practice compliance
- Check naming conventions against standards
- Verify error handling on HTTP Request and integration actions
- Identify security issues (hardcoded secrets, missing webhook authentication)
- Validate formula syntax and references
- Produce a prioritised report with specific fix recommendations

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

## Review Process

### Step 1 — Obtain the Story

Export the story from the tenant or accept a JSON file directly:

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/export" | jq .
```

To find a story by name first:

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500" | jq '.stories[] | {id, name}'
```

Paginate for large tenants — see `shared/common-patterns.md` for the pagination loop.

### Step 2 — Structural Review

Validate the exported JSON against `shared/story-schema.md`:

- Every agent has `type`, `name`, and `options`
- All `links` reference valid agent indices
- `diagram_layout` is present and positions all agents
- Story has a `name` and `description`

### Step 3 — Naming Review

Check against `shared/best-practices.md` naming conventions:

- Action names use `snake_case` (not camelCase or spaces)
- Names describe what the action does (e.g. `enrich_alert` not `step_2`)
- Story name is descriptive and concise
- No duplicate action names within the story

### Step 4 — Error Handling Review

- All HTTP Request actions have `emit_failure_event: true`
- Trigger actions have both match and no-match branches where appropriate
- Stories with external API calls include at least one failure handling path
- Delay actions are used before retries where relevant

### Step 5 — Security Review

- No hardcoded API keys, tokens, passwords, or secrets in action options
- Credentials are referenced via CREDENTIAL objects, not inline strings
- Webhook actions use a `secret` for authentication where exposed externally
- Sensitive data is not logged or emitted unnecessarily

### Step 6 — Formula Review

- All formulas use valid `<< >>` syntax
- Formula references point to actions that exist in the story by exact name
- Pipe functions are valid (see `shared/formulas.md` for the full list)
- No broken chains — every referenced action is upstream of the consuming action

### Step 7 — Report

Produce a summary grouped by severity:

| Severity | Meaning |
|---|---|
| **Critical** | Security vulnerabilities, broken references, missing error handling on external calls |
| **Warning** | Naming convention violations, missing descriptions, suboptimal patterns |
| **Info** | Style suggestions, minor improvements, documentation gaps |

Each finding should include:
- The affected action name and type
- What the issue is
- A specific fix recommendation

## Review Checklist

| Check | Severity | What to Look For |
|---|---|---|
| Hardcoded secrets | Critical | API keys, tokens, passwords in `options` fields |
| Missing `emit_failure_event` | Critical | HTTP Request actions without failure event emission |
| Broken formula references | Critical | `<<action_name.body.x>>` where `action_name` does not exist |
| Missing webhook secret | Warning | Webhook actions exposed without authentication |
| Non-snake_case names | Warning | Action names with spaces, camelCase, or unclear abbreviations |
| Missing story description | Warning | Story-level `description` field is empty or absent |
| Unused actions | Info | Actions with no inbound links and no trigger role |
| Missing diagram layout | Info | `diagram_layout` absent or incomplete |

---

## Extended Operations

See `references/api-reference.md` for the story export and action listing endpoint specifications used during review.

## Guidelines

- Always export the latest version of a story before reviewing — do not review stale JSON
- Be specific in recommendations — name the action and the exact field to change
- Distinguish between critical issues (must fix) and style suggestions (nice to have)
- When reviewing formulas, trace the full data path from trigger to the consuming action
- Cross-reference credential usage with `tines-credentials` if credential scope is in question
