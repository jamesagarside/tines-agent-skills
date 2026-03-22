# Tines Credentials — API Reference

Complete endpoint specifications and credential type schemas. For core operations, see the main `SKILL.md`.

## Credential Type Schemas

### AWS Credential (Key-based)

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "AWS Credential",
    "mode": "AWS",
    "team_id": TEAM_ID,
    "aws_authentication_type": "KEY",
    "aws_access_key": "AKIA...",
    "aws_secret_key": "secret..."
  }' \
  "${TINES_BASE_URL}/user_credentials" | jq '{id, name, mode}'
```

### AWS Credential (Role-based)

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "AWS Role Credential",
    "mode": "AWS",
    "team_id": TEAM_ID,
    "aws_authentication_type": "ROLE",
    "aws_assumed_role_arn": "arn:aws:iam::..."
  }' \
  "${TINES_BASE_URL}/user_credentials" | jq '{id, name, mode}'
```

### HTTP Request Credential

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "HTTP API Key",
    "mode": "HTTP_REQUEST",
    "team_id": TEAM_ID,
    "headers": {"Authorization": "Bearer token-here"},
    "allowed_hosts": ["api.example.com"]
  }' \
  "${TINES_BASE_URL}/user_credentials" | jq '{id, name, mode}'
```

### JWT Credential

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "JWT Credential",
    "mode": "JWT",
    "team_id": TEAM_ID,
    "jwt_algorithm": "RS256",
    "jwt_private_key": "...",
    "jwt_payload": {}
  }' \
  "${TINES_BASE_URL}/user_credentials" | jq '{id, name, mode}'
```

### OAuth Credential

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "OAuth Credential",
    "mode": "OAUTH",
    "team_id": TEAM_ID,
    "oauth_url": "https://example.com/oauth/authorize",
    "oauth_token_url": "https://example.com/oauth/token",
    "oauth_client_id": "client-id",
    "oauth_client_secret": "client-secret",
    "oauth_scope": "read write"
  }' \
  "${TINES_BASE_URL}/user_credentials" | jq '{id, name, mode}'
```

---

## Shared Resources — Extended

### Get Resource

```bash
curl -s -f -H "$AUTH_HEADER" "${TINES_BASE_URL}/resources/{id}" | jq .
```

### Create Text Resource

```bash
curl -s -f -X POST -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{
    "name": "Resource Name",
    "type": "text",
    "team_id": TEAM_ID,
    "value": "text content here"
  }' \
  "${TINES_BASE_URL}/resources" | jq .
```

### Update Resource

```bash
curl -s -f -X PATCH -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
  -d '{"value": {"updated": "data"}}' \
  "${TINES_BASE_URL}/resources/{id}" | jq .
```
