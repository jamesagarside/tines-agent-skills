# Tines Story Export Schema

Reference for the JSON structure produced by `GET /api/v1/stories/{id}/export` and consumed by `POST /api/v1/stories/import`.

## Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Story display name |
| `description` | string | no | Markdown-supported description |
| `guid` | string | yes | Globally unique identifier (regenerated on import) |
| `slug` | string | yes | URL-safe identifier |
| `exported_at` | string | yes | ISO 8601 export timestamp |
| `schema_version` | integer | yes | Export format version |
| `standard_lib_version` | integer | no | Standard library version used |
| `action_runtime_version` | integer | no | Action runtime version |
| `agents` | array | yes | Array of agent (action) objects |
| `links` | array | yes | Array of link objects connecting agents |
| `diagram_layout` | string | no | JSON-encoded layout metadata |
| `keep_events_for` | integer | no | Event retention in seconds (0 = use team default) |
| `disabled` | boolean | no | Whether the story is disabled |
| `tags` | array | no | Array of tag strings |
| `forms` | array | no | Array of form objects |
| `pages` | array | no | Array of page objects |
| `send_to_story_enabled` | boolean | no | Whether this story can be called via Send to Story |
| `entry_agent_guid` | string | no | GUID of the entry agent for Send to Story |
| `exit_agent_guids` | array | no | GUIDs of exit agents for Send to Story merge mode |
| `reporting_status` | string | no | `"enabled"` or `"disabled"` |
| `monitor_failures` | boolean | no | Enable failure monitoring |
| `time_saved_value` | integer | no | Estimated time saved per run (for reporting) |
| `time_saved_unit` | string | no | Unit for time_saved_value (`"minutes"`, `"hours"`) |

## Agent (Action) Object

Each entry in the `agents` array describes one action in the story.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | yes | Action type slug (e.g. `Agents::HTTPRequestAgent`) |
| `name` | string | yes | Display name |
| `disabled` | boolean | no | Whether the action is disabled |
| `guid` | string | yes | Unique identifier (regenerated on import) |
| `options` | object | yes | Type-specific configuration (see action-types.md) |
| `schedule` | array/null | no | Cron-style schedule for polling actions |
| `keep_events_for` | integer | no | Per-action event retention override |
| `position` | object | no | Diagram coordinates |
| `position.x` | integer | no | Horizontal position |
| `position.y` | integer | no | Vertical position |
| `source_ids` | array | no | Indices of upstream agents in the `agents` array |
| `receiver_ids` | array | no | Indices of downstream agents in the `agents` array |

## Link Object

Each entry in the `links` array defines a connection between two agents.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source` | integer | yes | Index of the source agent in the `agents` array |
| `receiver` | integer | yes | Index of the receiving agent in the `agents` array |

## Minimal Valid Export Example

```json
{
  "name": "Simple Alert Handler",
  "description": "Receive an alert and send a notification email.",
  "guid": "a1b2c3d4e5f6",
  "slug": "simple_alert_handler",
  "exported_at": "2025-01-15T10:30:00Z",
  "schema_version": 18,
  "agents": [
    {
      "type": "Agents::WebhookAgent",
      "name": "Receive Alert",
      "disabled": false,
      "guid": "aaa111",
      "options": {
        "path": "alert-ingest",
        "verbs": "post",
        "secret": "<<CREDENTIAL.webhook_secret>>"
      },
      "position": { "x": 0, "y": 0 },
      "source_ids": [],
      "receiver_ids": [1]
    },
    {
      "type": "Agents::EventTransformationAgent",
      "name": "Normalize Alert",
      "disabled": false,
      "guid": "bbb222",
      "options": {
        "mode": "message_only",
        "payload": {
          "title": "<<receive_alert.body.title>>",
          "severity": "<<receive_alert.body.severity | downcase>>"
        }
      },
      "position": { "x": 0, "y": 150 },
      "source_ids": [0],
      "receiver_ids": [2]
    },
    {
      "type": "Agents::EmailAgent",
      "name": "Notify Team",
      "disabled": false,
      "guid": "ccc333",
      "options": {
        "recipients": "security@example.com",
        "subject": "[<<normalize_alert.severity>>] <<normalize_alert.title>>",
        "body": "<p>New alert: <<normalize_alert.title>></p><p>Severity: <<normalize_alert.severity>></p>"
      },
      "position": { "x": 0, "y": 300 },
      "source_ids": [1],
      "receiver_ids": []
    }
  ],
  "links": [
    { "source": 0, "receiver": 1 },
    { "source": 1, "receiver": 2 }
  ],
  "tags": ["alerts", "notifications"],
  "keep_events_for": 604800,
  "disabled": false,
  "send_to_story_enabled": false
}
```

## Import Considerations

| Concern | Behavior |
|---------|----------|
| **GUIDs** | Regenerated on import — never rely on exported GUIDs persisting |
| **Credential references** | `<<CREDENTIAL.*>>` refs must exist on the target tenant before import |
| **Resource references** | `<<RESOURCE.*>>` refs must exist on the target tenant before import |
| **Team assignment** | Story is assigned to the importing user's team (or a specified team) |
| **Agent IDs** | Internal numeric IDs are reassigned — `source_ids`/`receiver_ids` use array indices |
| **Diagram layout** | Preserved from export; positions are relative, not absolute |
| **Schedules** | Imported in a disabled state — must be manually re-enabled |
| **Send to Story URLs** | Change on import — downstream callers must be updated |
| **Duplicate names** | Tines allows duplicate story names — consider renaming before import |

## Import via API

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/stories/import" \
  -d @story_export.json | jq .
```

To import into a specific team:

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  "${TINES_BASE_URL}/stories/import?team_id=${TEAM_ID}" \
  -d @story_export.json | jq .
```

## Export via API

```bash
# Export a story by ID
curl -s -f -H "$AUTH_HEADER" \
  "${TINES_BASE_URL}/stories/${STORY_ID}/export" | jq . > story_export.json
```
