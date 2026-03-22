# Tines Cases — API Reference

Complete endpoint specifications for case sub-resources. For core case CRUD operations, see the main `SKILL.md`.

## Case Comments

> **Note:** This endpoint may not be available on all Tines plans.

### List Comments

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/comments" | jq .
```

### Create Comment

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"body": "Comment text here"}' \
  "${TINES_BASE_URL}/cases/{id}/comments" | jq .
```

### Update Comment

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"body": "Updated comment"}' \
  "${TINES_BASE_URL}/cases/{case_id}/comments/{comment_id}" | jq .
```

### Delete Comment

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/comments/{comment_id}"
```

---

## Case Tasks

> **Note:** This endpoint may not be available on all Tines plans.

### List Tasks

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/tasks" | jq .
```

### Create Task

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"name": "Task description"}' \
  "${TINES_BASE_URL}/cases/{id}/tasks" | jq .
```

### Update Task (e.g., Mark Complete)

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"completed": true}' \
  "${TINES_BASE_URL}/cases/{case_id}/tasks/{task_id}" | jq .
```

### Delete Task

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/tasks/{task_id}"
```

---

## Case Files

> **Note:** This endpoint may not be available on all Tines plans.

### List Files

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/files" | jq .
```

### Upload File

```bash
curl -s -f -X POST -H "$AUTH_HEADER" \
  -F "file=@/path/to/file" \
  "${TINES_BASE_URL}/cases/{id}/files" | jq .
```

### Download File

```bash
curl -s -f -H "$AUTH_HEADER" -o output_filename \
  "${TINES_BASE_URL}/cases/{case_id}/files/{file_id}/download"
```

### Delete File

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/files/{file_id}"
```

---

## Case Notes

> **Note:** This endpoint may not be available on all Tines plans.

### List Notes

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/notes" | jq .
```

### Create Note

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"content": "Note content here"}' \
  "${TINES_BASE_URL}/cases/{id}/notes" | jq .
```

### Update Note

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"content": "Updated note"}' \
  "${TINES_BASE_URL}/cases/{case_id}/notes/{note_id}" | jq .
```

### Append to Note

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"content_append": "Additional content"}' \
  "${TINES_BASE_URL}/cases/{case_id}/notes/{note_id}" | jq .
```

### Delete Note

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/notes/{note_id}"
```

---

## Case Metadata

Key-value pairs attached to cases.

### List Metadata

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/metadata" | jq .
```

### Create Metadata

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"key": "severity", "value": "critical"}' \
  "${TINES_BASE_URL}/cases/{id}/metadata" | jq .
```

### Update Metadata

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"value": "high"}' \
  "${TINES_BASE_URL}/cases/{case_id}/metadata/{metadata_id}" | jq .
```

### Delete Metadata

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/metadata/{metadata_id}"
```

---

## Linked Cases

### List Linked Cases

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/linked_cases" | jq .
```

### Link Cases

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"linked_case_id": OTHER_CASE_ID}' \
  "${TINES_BASE_URL}/cases/{id}/linked_cases" | jq .
```

### Batch Link Cases

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"linked_case_ids": [ID1, ID2, ID3]}' \
  "${TINES_BASE_URL}/cases/{id}/linked_cases/batch" | jq .
```

### Unlink Case

**DESTRUCTIVE** — Confirm with user.

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/linked_cases/{linked_case_id}"
```

---

## Case Subscribers

### List Subscribers

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/subscribers" | jq .
```

### Add Subscriber

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"user_id": USER_ID}' \
  "${TINES_BASE_URL}/cases/{id}/subscribers" | jq .
```

### Remove Subscriber

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/subscribers/{subscriber_id}"
```

---

## Case Records

### List Records

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{id}/records" | jq .
```

### Add Record

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"record_id": RECORD_ID}' \
  "${TINES_BASE_URL}/cases/{id}/records" | jq .
```

### Remove Record

```bash
curl -s -f -X DELETE -H "$AUTH_HEADER" "${TINES_BASE_URL}/cases/{case_id}/records/{record_id}"
```
