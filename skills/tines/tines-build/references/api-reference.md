# Tines Build — API Reference

This skill generates story JSON and optionally imports it. For full story CRUD and export/import endpoint details, see `tines-stories/references/api-reference.md`. For action creation endpoints, see `tines-actions/references/api-reference.md`.

## Quick Reference

### Import Story

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d @story_export.json \
  "${TINES_BASE_URL}/stories/import" | jq .
```

Accepts a full story export JSON (with `agents`, `links`, and `diagram_layout`). Returns the created story object including its new `id`.

### Export Story

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/export" | jq .
```

Returns the complete story definition as JSON, suitable for re-import or offline review.

### List Stories

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500" | jq '.stories[] | {id, name}'
```

Paginate with `page` parameter. See `shared/common-patterns.md` for the full pagination loop.
