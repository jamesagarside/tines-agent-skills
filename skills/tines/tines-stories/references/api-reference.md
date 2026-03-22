# Tines Stories — API Reference

Complete endpoint specifications for story runs, events, versions, and change control. For core story operations, see the main `SKILL.md`.

## Story Runs

### List Story Runs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/runs?per_page=20" | jq .
```

### List Run Events

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/runs/{run_id}/events" | jq .
```

---

## Story Events

### List Story Events

> **Note**: Story-level events may not be available. Events are typically accessed per-agent via `/agents/{id}/events`. The endpoint below (`/stories/{id}/events`) returns 404 in live testing.

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/events?per_page=20" | jq .
```

To retrieve events per-agent instead:
```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents/{agent_id}/events?per_page=20" | jq .
```

### Re-emit Event

Replay a specific event through the workflow:
```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/events/{event_id}/reemit"
```

---

## Story Versions

### List Versions

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/versions" | jq .
```

### Get Version

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/versions/{version_id}" | jq .
```

### Create Version

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "v1.0"}' \
  "${TINES_BASE_URL}/stories/{id}/versions" | jq .
```

---

## Change Control

### Create Change Request

```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/change-requests" | jq .
```

### Approve Change Request

```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/change-requests/{request_id}/approve"
```

### Cancel Change Request

```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/change-requests/{request_id}/cancel"
```

### Promote Change Request

```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/change-requests/{request_id}/promote"
```
