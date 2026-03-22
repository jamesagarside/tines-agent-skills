---
name: tines-build
description: Build Tines stories from natural language descriptions — design workflow steps, select action types, configure formulas, and produce export-ready story JSON. Use when the user wants to create, design, or generate a new Tines automation workflow.
metadata:
  author: jamesagarside
  version: "0.5.0"
---

Build Tines stories (workflows) from natural language descriptions.

## Scope

This skill covers designing complete workflows from requirements, selecting action types, configuring formulas and options, and producing export-ready story JSON.

- For importing/exporting finished stories, see **tines-stories**
- For reviewing story quality after building, see **tines-review**
- For action type details, see **shared/action-types.md**
- For formula syntax and pipe functions, see **shared/formulas.md**
- For story JSON structure, see **shared/story-schema.md**

## Jobs to Be Done

- Design a workflow from a natural language description
- Select appropriate action types for each step
- Configure action options and formulas
- Generate export-ready story JSON
- Optionally import the built story into a Tines tenant

## Prerequisites

Tines credentials are only required if importing the built story into a tenant. Credentials are resolved via environment variables (`TINES_TENANT_URL`, `TINES_API_TOKEN`) or a credentials file (`~/.tines/credentials`). Run `tines-auth` first to configure or validate connectivity.

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

## Build Process

### Step 1 — Understand the Requirement

Clarify the workflow before building:

- **Trigger**: What starts the workflow? (webhook, schedule, manual, event from another story)
- **Data sources**: What systems or APIs does it read from?
- **Outcomes**: What should happen at the end? (send email, create ticket, update record)
- **Integrations**: Which third-party services are involved?
- **Error handling**: What happens when a step fails?

### Step 2 — Design the Workflow

Map each logical step to a Tines action type (see `shared/action-types.md`):

1. Sketch the flow from trigger to outcome
2. Choose the correct action type for each step (see quick reference below)
3. Determine data flow between actions — what each action receives and emits
4. Identify which steps need credentials (HTTP requests to authenticated APIs)
5. Identify branching points (conditions, triggers with multiple receivers)

### Step 3 — Configure Each Action

For every action in the workflow:

1. Build the `options` JSON — the core configuration for that action type
2. Write formulas using `<< >>` syntax (see `shared/formulas.md` for pipe functions)
3. Reference upstream actions by name: `<<action_name.body.field>>`
4. Apply error handling patterns from `shared/best-practices.md` (e.g. `emit_failure_event` on HTTP requests)
5. Set `keep_events_for` appropriately

### Step 4 — Assemble the Story JSON

Follow the structure defined in `shared/story-schema.md`:

- `name` and `description` at story level
- `agents` array with each action's full configuration
- `links` array defining connections between actions
- `diagram_layout` for visual positioning
- Validate that all formula references point to actions that exist in the story

### Step 5 — Deploy (Optional)

Import the built story into the tenant via the stories import endpoint:

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d @story.json \
  "${TINES_BASE_URL}/stories/import" | jq .
```

Verify the import by listing stories:

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500" | jq '.stories[] | {id, name}'
```

Paginate if the tenant has many stories — see `shared/common-patterns.md` for the pagination loop pattern.

## Action Type Quick Reference

| Type | When to Use |
|---|---|
| **Webhook** | Receive inbound data (HTTP POST trigger, scheduled trigger) |
| **HTTP Request** | Call external APIs, fetch data from services |
| **Event Transform** | Reshape data, combine fields, build payloads |
| **Trigger** | Branch workflow based on conditions (if/else logic) |
| **Send to Story** | Pass data to another story for modular design |
| **Send Email** | Deliver email notifications or reports |
| **Delay** | Wait for a time period before continuing |
| **Group** | Organise related actions visually within the story |

See `shared/action-types.md` for full configuration details on each type.

## Example

**Requirement**: "When a webhook receives an alert, enrich it via an API, check severity, and email the on-call team if critical."

**Designed workflow**:

1. **Webhook** `receive_alert` — receives inbound alert JSON
2. **HTTP Request** `enrich_alert` — calls enrichment API with `<<receive_alert.body.indicator>>`
3. **Trigger** `check_severity` — branches on `<<enrich_alert.body.severity>>` equals `"critical"`
4. **Send Email** `notify_oncall` — sends email with enriched alert details to on-call distribution list

**Resulting story JSON** (abbreviated):

```json
{
  "name": "Alert Enrichment and Notification",
  "description": "Enrich inbound alerts and notify on-call if critical",
  "agents": [
    {
      "type": "webhook",
      "name": "receive_alert",
      "options": {}
    },
    {
      "type": "httpRequest",
      "name": "enrich_alert",
      "options": {
        "url": "https://enrichment.example.com/lookup",
        "method": "post",
        "payload": { "indicator": "<<receive_alert.body.indicator>>" },
        "emit_failure_event": true
      }
    },
    {
      "type": "trigger",
      "name": "check_severity",
      "options": {
        "rules": [
          { "type": "field==value", "value": "critical", "path": "<<enrich_alert.body.severity>>" }
        ]
      }
    },
    {
      "type": "sendEmail",
      "name": "notify_oncall",
      "options": {
        "recipients": "oncall@example.com",
        "subject": "Critical Alert: <<receive_alert.body.title>>",
        "body": "Severity: <<enrich_alert.body.severity>>\nDetails: <<enrich_alert.body.summary>>"
      }
    }
  ],
  "links": [
    { "source": 0, "receiver": 1 },
    { "source": 1, "receiver": 2 },
    { "source": 2, "receiver": 3 }
  ]
}
```

---

## Extended Operations

See `references/api-reference.md` for the story import and export endpoint specifications used during deployment.

## Guidelines

- Follow naming conventions from `shared/best-practices.md` — use `snake_case` action names that describe the step
- Always include `emit_failure_event: true` on HTTP Request actions
- Use CREDENTIAL references for secrets — never hardcode API keys or tokens in action options
- Keep stories focused on a single workflow; use Send to Story for modular composition
- Validate all formula references before finalising the story JSON
- Export and re-import to verify round-trip fidelity
