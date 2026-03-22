# Tines Audit — API Reference

Key endpoints used during tenant auditing. For full endpoint specifications, see the relevant skill references: `tines-stories/references/api-reference.md`, `tines-credentials/references/api-reference.md`, `tines-admin/references/api-reference.md`.

## Quick Reference

### List Stories

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500" | jq '.stories[] | {id, name, disabled, edited_at}'
```

Paginate with `page` parameter. Returns story metadata for inventory and staleness checks.

### List Credentials

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/user_credentials?per_page=500" | jq '.user_credentials[] | {id, name, mode, team_id, read_access}'
```

Returns credential metadata only — credential values are never exposed. Paginate with `page` parameter.

### List Resources

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/resources?per_page=500" | jq .
```

Returns shared resources. Paginate with `page` parameter for large tenants.

### List Teams

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/teams?per_page=500" | jq '.teams[] | {id, name}'
```

Returns team metadata. Paginate with `page` parameter.

### Audit Logs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/audit_logs?per_page=500" | jq .
```

Returns tenant audit log entries. Requires admin-level access. Paginate with `page` parameter. Useful for identifying recent changes and activity patterns.

### Export Story (for deep inspection)

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/export" | jq .
```

Returns the full story definition. Used during Step 3 (Story Audit) to inspect individual stories for error handling and security issues.
