# Tines Auth — API Reference

Rate limits, error codes, and authentication details.

## Rate Limits

Enforced per IP address and API token combination.

| Endpoint | Requests/Minute |
|----------|-----------------|
| General | 5000 |
| actions/agents | 100 |
| admin/users | 500 |
| audit_logs | 1000 |
| records | 400 |
| tokens | 2500 |

## Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | Success | Request completed |
| 401 | Unauthorized | Invalid or expired API token |
| 404 | Not found | Resource does not exist, or token lacks permissions (Tines returns 404 for underprivileged tokens) |
| 429 | Rate limited | Back off and retry after the rate limit window resets |
| 5xx | Server error | Retry with exponential backoff |

## Authentication Methods

### x-user-token Header (Primary)

```bash
curl -s -f -H 'x-user-token: '"$TINES_API_TOKEN"'' "${TINES_BASE_URL}/info"
```

### Authorization Bearer Header (Alternative)

```bash
curl -s -f -H "Authorization: Bearer $TINES_API_TOKEN" "${TINES_BASE_URL}/info"
```

Both header formats are supported across all Tines API endpoints.

## Token Management

- API tokens are created in Tines under **Settings > API keys**
- Tokens can have different permission levels (member, admin)
- Admin-level tokens required for `/admin/*` endpoints
- Tokens do not expire automatically but can be revoked
