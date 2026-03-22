# Tines Records — API Reference

Complete endpoint specifications for record types, views, and artifacts. For core record operations, see the main `SKILL.md`.

## Record Types — Extended

### Get Record Type

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/record_types/{id}" | jq .
```

### Update Record Type

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Updated Name"}' \
  "${TINES_BASE_URL}/record_types/{id}" | jq .
```

---

## Record Views

### List Record Views

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/record_views" | jq .
```

### Delete Record View

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/record_views/{id}"
```

### Export Record View

```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/record_views/export" | jq .
```

### Import Record View

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d @record_view_export.json \
  "${TINES_BASE_URL}/record_views/import" | jq .
```

---

## Record Artifacts

### Get Record Artifact

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/records/artifacts/{id}" | jq .
```
