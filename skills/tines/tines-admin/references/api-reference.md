# Tines Admin — API Reference

Complete endpoint specifications for admin operations. For core operations, see the main `SKILL.md`.

## User Management — Extended

### Resend Invitation

```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/users/{id}/resend_invitation"
```

### Expire User Sessions

```bash
curl -s -f -X POST -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/users/{id}/expire_sessions"
```

---

## Audit Logs

### List Audit Logs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/audit_logs?per_page=100" | jq .
```

Rate limit: 1000/min for audit_logs.

### Filter by Date Range

```bash
curl -s -f -H "$AUTH_HEADER" \
  "${TINES_BASE_URL}/audit_logs?per_page=100&created_at_from=2024-01-01&created_at_to=2024-12-31" | jq .
```

---

## Job Monitoring

### List Queued Jobs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/jobs/queued" | jq .
```

### List In-Progress Jobs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/jobs/in_progress" | jq .
```

### List Failed (Dead) Jobs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/jobs/dead" | jq .
```

### List Retry Jobs

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/jobs/retry" | jq .
```

### Delete Jobs by Status

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/jobs/dead"
```

---

## Team Members

### List Team Members

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/teams/{id}/members" | jq .
```

### Invite Team Member

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"email": "user@example.com", "role": "member"}' \
  "${TINES_BASE_URL}/teams/{id}/members" | jq .
```

### Remove Team Member

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/teams/{team_id}/members/{member_id}"
```

---

## Team Management — Extended

### Get Team

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/teams/{id}" | jq .
```

### Update Team

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Updated Team Name"}' \
  "${TINES_BASE_URL}/teams/{id}" | jq .
```

---

## Folder Management

### List Folders

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/folders?per_page=500" | jq .
```

### Get Folder

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/folders/{id}" | jq .
```

### Create Folder

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Folder Name", "team_id": TEAM_ID}' \
  "${TINES_BASE_URL}/folders" | jq .
```

Optional: `parent_id` for nested folders.

### Update Folder

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Updated Folder"}' \
  "${TINES_BASE_URL}/folders/{id}" | jq .
```

### Delete Folder

**DESTRUCTIVE** — May affect stories organized within. Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/folders/{id}"
```

---

## Tunnel Health

### Check Tunnel Health

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/tunnels/health" | jq .
```

---

## Admin Templates

### List Templates

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/templates?per_page=500" | jq .
```

### Get Template

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/templates/{id}" | jq .
```

### Create Template

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Template Name", "story_id": STORY_ID}' \
  "${TINES_BASE_URL}/admin/templates" | jq .
```

### Delete Template

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/admin/templates/{id}"
```
