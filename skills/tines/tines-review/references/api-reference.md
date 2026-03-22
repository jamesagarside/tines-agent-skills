# Tines Review — API Reference

This skill primarily works with exported story JSON. The endpoints below are used to obtain stories for review. For full story CRUD details, see `tines-stories/references/api-reference.md`.

## Quick Reference

### Export Story

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/export" | jq .
```

Returns the complete story definition including all agents, links, and diagram layout. This is the primary input for a story review.

### List Stories

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories?per_page=500" | jq '.stories[] | {id, name}'
```

Use to find stories by name before exporting. Paginate with `page` parameter for large tenants.

### List Actions in a Story

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/stories/{id}/agents?per_page=500" | jq '.agents[] | {id, name, type}'
```

Returns individual action details. Useful for checking action configuration without a full export. See `tines-actions/references/api-reference.md` for full action endpoint specifications.
