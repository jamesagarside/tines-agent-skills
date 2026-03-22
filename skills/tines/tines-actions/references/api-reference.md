# Tines Actions — API Reference

Complete endpoint specifications for action events, logs, and memory. For core action CRUD, see the main `SKILL.md`.

## Agent Events

Events are retrieved per-agent. Story-level event listing (`/stories/{id}/events`) is not supported and returns 404.

### List Agent Events

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents/{id}/events?per_page=20" | jq .
```

### Re-emit Agent Event

Replay a specific event through the workflow:
```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/events/{event_id}/reemit"
```

---

## Agent Logs

### View Agent Logs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents/{id}/logs?per_page=20" | jq .
```

### Delete Agent Logs

**DESTRUCTIVE** — Confirm with user before executing.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents/{id}/logs"
```

---

## Agent Memory

### Clear Agent Memory

**DESTRUCTIVE** — This clears the agent's stored state. Confirm with user before executing. This endpoint may not be available on all Tines plans (returns 404 if unavailable).

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/agents/{id}/memory"
```
