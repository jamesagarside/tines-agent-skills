# Tines Action Types Reference

Complete reference for all 8 Tines action types with API slugs, option schemas, and creation examples.

## Action Type Summary

| Type | API Slug | Purpose |
|------|----------|---------|
| Webhook | `Agents::WebhookAgent` | Entry point — receives incoming HTTP requests |
| HTTP Request | `Agents::HTTPRequestAgent` | Makes outbound HTTP/API calls |
| Event Transform | `Agents::EventTransformationAgent` | Transform, deduplicate, delay, explode, implode events |
| Condition (Trigger) | `Agents::TriggerAgent` | Boolean logic to route events |
| Send Email | `Agents::EmailAgent` | Send email messages |
| Receive Email | `Agents::IMAPAgent` | Receive/poll incoming emails |
| Send to Story | `Agents::SendToStoryAgent` | Route events to other stories |
| AI Agent | `Agents::AIAgent` | LLM-powered reasoning step |

---

## Webhook — `Agents::WebhookAgent`

### When to Use

- Ingest events from external systems (SIEM alerts, ticketing, chat)
- Provide a unique URL that third parties POST data to
- Accept form submissions or API callbacks

### Options Schema

```json
{
  "path": "my-webhook-path",
  "secret": "optional-shared-secret",
  "verbs": "get,post",
  "access_control": "team",
  "response": "Event received",
  "response_code": "201",
  "response_headers": { "X-Custom": "value" },
  "include_headers": "true",
  "match_rules": [],
  "must_match": "0",
  "rate_limit": ""
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | string | no | auto-generated | Custom URL path segment |
| `secret` | string | no | — | Shared secret for HMAC validation |
| `verbs` | string | no | `"get,post"` | Comma-separated HTTP methods to accept |
| `access_control` | string | no | `"team"` | `team`, `global`, or `story` |
| `response` | string | no | `""` | Static body returned to caller |
| `response_code` | string | no | `"201"` | HTTP status code returned to caller |
| `response_headers` | object | no | `{}` | Custom response headers |
| `include_headers` | string | no | `"false"` | Include request headers in the event |
| `match_rules` | array | no | `[]` | Filter rules — reject events that don't match |
| `must_match` | string | no | `"0"` | Minimum rules that must match (`0` = disabled) |
| `rate_limit` | string | no | `""` | Max events per minute (blank = unlimited) |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::WebhookAgent",
      "name": "Receive Alert",
      "story_id": '"$STORY_ID"',
      "options": {
        "path": "inbound-alerts",
        "secret": "<<CREDENTIAL.webhook_secret>>",
        "verbs": "post",
        "include_headers": "true"
      }
    }
  }' | jq .
```

---

## HTTP Request — `Agents::HTTPRequestAgent`

### When to Use

- Call external REST/GraphQL APIs
- Download files or fetch web content
- Submit data to third-party services

### Options Schema

```json
{
  "url": "https://api.example.com/endpoint",
  "method": "post",
  "headers": { "Authorization": "Bearer <<CREDENTIAL.api_token>>" },
  "content_type": "json",
  "payload": { "key": "<<previous_action.body.value>>" },
  "basic_auth": [],
  "manual_time": "",
  "emit_failure_event": "true",
  "retry_on_status": "429,500,502,503,504",
  "log_to_story_run": "true"
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `url` | string | yes | — | Target URL (supports formulas) |
| `method` | string | no | `"get"` | `get`, `post`, `put`, `patch`, `delete`, `head`, `options` |
| `headers` | object | no | `{}` | Custom request headers |
| `content_type` | string | no | `"json"` | `json`, `xml`, `form`, `text`, `raw` |
| `payload` | object/string | no | `{}` | Request body (structure depends on content_type) |
| `basic_auth` | array | no | `[]` | `["username", "password"]` for HTTP Basic Auth |
| `manual_time` | string | no | `""` | Delay before execution (e.g. `"30"` seconds) |
| `emit_failure_event` | string | no | `"false"` | Emit an event on HTTP error instead of failing |
| `retry_on_status` | string | no | `""` | Comma-separated status codes to auto-retry |
| `log_to_story_run` | string | no | `"true"` | Include request/response in story run logs |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::HTTPRequestAgent",
      "name": "Get User Details",
      "story_id": '"$STORY_ID"',
      "options": {
        "url": "https://api.example.com/users/<<receive_alert.body.user_id>>",
        "method": "get",
        "headers": {
          "Authorization": "Bearer <<CREDENTIAL.example_api_token>>"
        },
        "content_type": "json",
        "emit_failure_event": "true",
        "retry_on_status": "429,500,502,503,504"
      }
    }
  }' | jq .
```

---

## Event Transform — `Agents::EventTransformationAgent`

### When to Use

- Reshape event data between actions
- Deduplicate, delay, explode, or implode events
- Extract specific fields or compute derived values

### Options Schema

```json
{
  "mode": "message_only",
  "payload": {
    "summary": "<<previous_action.body.title>>",
    "severity": "<<previous_action.body.priority | downcase>>"
  }
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `mode` | string | yes | `"message_only"` | Transform mode (see Modes below) |
| `payload` | object | varies | `{}` | Output payload (used in `message_only`, `extract`) |
| `path` | string | varies | — | JSONpath for `explode`, `deduplicate`, `implode` |
| `to` | string | varies | — | Target key for `extract` mode |
| `lookback` | string | varies | — | Dedup window in seconds |
| `period` | string | varies | — | Delay/throttle period in seconds |
| `limit` | string | varies | — | Max events for `implode` before flushing |
| `guid` | string | varies | — | Dedup/implode identifier path |

### Modes

| Mode | Purpose | Required Fields |
|------|---------|-----------------|
| `message_only` | Reshape event with a new payload | `payload` |
| `extract` | Pull a nested value to top level | `path`, `to` |
| `explode` | Split an array into individual events | `path` |
| `implode` | Collect multiple events into one array | `path`, `guid`, `limit`, `period` |
| `deduplicate` | Suppress duplicate events | `path`, `lookback`, `period` |
| `delay` | Hold event for a fixed duration | `period` |
| `throttle` | Rate-limit events | `period`, `limit` |
| `automatic` | Auto-detect mode from payload | varies |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::EventTransformationAgent",
      "name": "Normalize Alert",
      "story_id": '"$STORY_ID"',
      "options": {
        "mode": "message_only",
        "payload": {
          "alert_id": "<<receive_alert.body.id>>",
          "severity": "<<receive_alert.body.priority | downcase>>",
          "source": "siem"
        }
      }
    }
  }' | jq .
```

---

## Condition (Trigger) — `Agents::TriggerAgent`

### When to Use

- Branch workflow based on event data
- Filter events that don't meet criteria
- Implement if/else routing logic

### Options Schema

```json
{
  "rules": [
    {
      "type": "field==value",
      "value": "critical",
      "path": "<<normalize_alert.severity>>"
    }
  ],
  "must_match": "1"
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `rules` | array | yes | `[]` | Array of rule objects |
| `rules[].type` | string | yes | — | Comparison operator (see Rule Types) |
| `rules[].value` | string | yes | — | Value to compare against |
| `rules[].path` | string | yes | — | Formula referencing the field to test |
| `must_match` | string | no | `"0"` | Min rules to match (`0` = all must match) |

### Rule Types

| Type | Description |
|------|-------------|
| `field==value` | Exact equality |
| `field!=value` | Not equal |
| `field>value` | Greater than |
| `field>=value` | Greater than or equal |
| `field<value` | Less than |
| `field<=value` | Less than or equal |
| `field=~regex` | Regex match |
| `field!~regex` | Regex no match |
| `in` | Value in comma-separated list |
| `not in` | Value not in comma-separated list |
| `is true` | Boolean true check |
| `is false` | Boolean false check |
| `is present` | Field exists and is not blank |
| `is not present` | Field is missing or blank |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::TriggerAgent",
      "name": "Is Critical?",
      "story_id": '"$STORY_ID"',
      "options": {
        "rules": [
          {
            "type": "field==value",
            "value": "critical",
            "path": "<<normalize_alert.severity>>"
          }
        ],
        "must_match": "1"
      }
    }
  }' | jq .
```

---

## Send Email — `Agents::EmailAgent`

### When to Use

- Notify stakeholders of incidents or approvals
- Send formatted reports or summaries
- Deliver confirmation messages

### Options Schema

```json
{
  "recipients": "oncall@example.com",
  "subject": "Alert: <<normalize_alert.alert_id>>",
  "body": "<h2>New Alert</h2><p>Severity: <<normalize_alert.severity>></p>",
  "sender": "tines@example.com",
  "reply_to": "security-team@example.com"
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `recipients` | string | yes | — | Comma-separated email addresses |
| `subject` | string | yes | — | Email subject line (supports formulas) |
| `body` | string | yes | — | Email body — HTML supported |
| `sender` | string | no | tenant default | From address |
| `reply_to` | string | no | — | Reply-to address |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::EmailAgent",
      "name": "Notify On-Call",
      "story_id": '"$STORY_ID"',
      "options": {
        "recipients": "oncall@example.com",
        "subject": "[<<normalize_alert.severity | upcase>>] Alert <<normalize_alert.alert_id>>",
        "body": "<h2>Alert Details</h2><p>ID: <<normalize_alert.alert_id>></p><p>Severity: <<normalize_alert.severity>></p>"
      }
    }
  }' | jq .
```

---

## Receive Email — `Agents::IMAPAgent`

### When to Use

- Poll an inbox for incoming messages (approvals, reports, phishing samples)
- Ingest email-based alerts into a workflow
- Monitor shared mailboxes

### Options Schema

```json
{
  "imap_server": "imap.example.com",
  "username": "<<CREDENTIAL.email_username>>",
  "password": "<<CREDENTIAL.email_password>>",
  "folder": "INBOX",
  "mark_as_read": "true",
  "ssl": "true"
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `imap_server` | string | yes | — | IMAP server hostname |
| `username` | string | yes | — | Mailbox username (use CREDENTIAL ref) |
| `password` | string | yes | — | Mailbox password (use CREDENTIAL ref) |
| `folder` | string | no | `"INBOX"` | IMAP folder to poll |
| `mark_as_read` | string | no | `"true"` | Mark fetched messages as read |
| `ssl` | string | no | `"true"` | Use SSL/TLS connection |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::IMAPAgent",
      "name": "Poll Phishing Inbox",
      "story_id": '"$STORY_ID"',
      "options": {
        "imap_server": "imap.example.com",
        "username": "<<CREDENTIAL.phishing_inbox_user>>",
        "password": "<<CREDENTIAL.phishing_inbox_pass>>",
        "folder": "INBOX",
        "mark_as_read": "true",
        "ssl": "true"
      }
    }
  }' | jq .
```

---

## Send to Story — `Agents::SendToStoryAgent`

### When to Use

- Decompose large workflows into reusable sub-stories
- Call a shared enrichment or remediation story
- Pass context to another team's workflow

### Options Schema

```json
{
  "story": "<<RESOURCE.sub_story_url>>",
  "send_to_story_mode": "no_merge",
  "payload": {
    "alert_id": "<<normalize_alert.alert_id>>",
    "source": "parent_story"
  }
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `story` | string | yes | — | Target story URL or `{{story_id}}` reference |
| `send_to_story_mode` | string | no | `"no_merge"` | `no_merge` (fire-and-forget) or `merge` (wait for response) |
| `payload` | object | no | `{}` | Data to send to the target story's webhook |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::SendToStoryAgent",
      "name": "Enrich via Sub-Story",
      "story_id": '"$STORY_ID"',
      "options": {
        "story": "<<RESOURCE.enrichment_story_url>>",
        "send_to_story_mode": "merge",
        "payload": {
          "indicator": "<<normalize_alert.ioc_value>>",
          "type": "<<normalize_alert.ioc_type>>"
        }
      }
    }
  }' | jq .
```

---

## AI Agent — `Agents::AIAgent`

### When to Use

- Summarize or classify unstructured data
- Generate natural-language responses
- Extract structured fields from free text
- Make reasoning-based decisions

### Options Schema

```json
{
  "model": "gpt-4o",
  "system_message": "You are a security analyst. Respond only with valid JSON.",
  "prompt": "Classify the following alert:\n\n<<normalize_alert.summary>>",
  "tools": []
}
```

### Field Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `model` | string | no | tenant default | LLM model identifier |
| `system_message` | string | no | `""` | System prompt for the LLM |
| `prompt` | string | yes | — | User prompt (supports formulas) |
| `tools` | array | no | `[]` | Tool definitions the AI agent can invoke |

### Create via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/agents" \
  -d '{
    "agent": {
      "type": "Agents::AIAgent",
      "name": "Classify Alert",
      "story_id": '"$STORY_ID"',
      "options": {
        "model": "gpt-4o",
        "system_message": "You are a security analyst. Return valid JSON with keys: category, confidence, summary.",
        "prompt": "Classify this alert and provide a one-line summary:\n\n<<normalize_alert.summary>>"
      }
    }
  }' | jq .
```
