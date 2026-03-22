# Tines Best Practices

Operational guidelines for building reliable, maintainable, and secure Tines workflows.

## Naming Conventions

| Entity | Pattern | Examples |
|--------|---------|----------|
| Stories | `verb-noun` describing the mission | `enrich-ioc`, `triage-phishing-report`, `onboard-employee` |
| Actions | Verb describing the step | `Receive Alert`, `Lookup in VirusTotal`, `Notify On-Call`, `Is Critical?` |
| Credentials | `service-purpose` | `slack-bot-token`, `jira-api-key`, `virustotal-api-key` |
| Resources | `purpose-descriptive` | `severity-mapping`, `escalation-contacts`, `allowed-domains-list` |
| Tags | Lowercase, hyphenated | `phishing`, `incident-response`, `soc-tier-1` |

### Action Naming Tips

- Webhooks: `Receive {noun}` — `Receive Alert`, `Receive Form Submission`
- HTTP Requests: `{Verb} in {Service}` — `Lookup in VirusTotal`, `Create Ticket in Jira`
- Conditions: Question form — `Is Critical?`, `Has IOC?`, `User Exists?`
- Transforms: `Normalize {noun}` or `Build {noun}` — `Normalize Alert`, `Build Slack Message`
- Emails: `Notify {audience}` — `Notify On-Call`, `Notify Manager`
- Send to Story: `{Verb} via Sub-Story` — `Enrich via Sub-Story`, `Remediate via Sub-Story`

## Error Handling

### Emit Failure Events

Always set `emit_failure_event: true` on HTTP Request actions. This emits an event on HTTP errors instead of halting the story.

```json
{
  "url": "https://api.example.com/endpoint",
  "method": "get",
  "emit_failure_event": "true"
}
```

### Branch After API Calls

Place a Condition (Trigger) after every HTTP Request to check for success vs failure:

```
HTTP Request → Condition: "API Succeeded?"
                ├─ Yes → continue normal flow
                └─ No  → error handling branch
```

Check the status code:

```json
{
  "rules": [
    {
      "type": "field==value",
      "value": "200",
      "path": "<<get_user.status>>"
    }
  ]
}
```

### Retry Patterns

Use `retry_on_status` for transient failures:

```json
{
  "retry_on_status": "429,500,502,503,504"
}
```

For more complex retry logic, use Send to Story with a delay:

```
Main Story → Send to Story (retry handler)
                 └─ Delay 30s → Re-attempt HTTP Request → Check success
                                                            ├─ Yes → return result
                                                            └─ No  → increment counter → retry or escalate
```

### Catch-All Branches

Add a catch-all Condition at the end of branching logic to handle unexpected values:

```
Condition: Is Critical?   → critical path
Condition: Is High?       → high path
Condition: Is Medium?     → medium path
Event Transform: Default  → low/unknown path (catch-all)
```

## Workflow Design Patterns

### Fan-Out / Fan-In

Split an array into individual events, process each, then collect results.

```
Event Transform (explode) → Process Each Item → Event Transform (implode)
```

- Use `explode` mode on the array field
- Each element becomes a separate event flowing through downstream actions
- Use `implode` mode to collect processed results back into a single event

### Polling Loop

Use a scheduled Webhook or HTTP Request to periodically check for new data.

```
HTTP Request (scheduled) → Condition: New Items? → Process Items
                                └─ No → end (wait for next schedule)
```

Set `schedule` on the first action to trigger at an interval (e.g. every 5 minutes).

### Approval Gate (Human-in-the-Loop)

Pause workflow execution until a human approves or rejects.

```
Build Approval Request → Send Email/Slack with Approve/Reject links
    → Webhook (receives approval callback)
        → Condition: Approved?
            ├─ Yes → continue
            └─ No  → notify requester
```

### Error Escalation

Progressively escalate failures through notification tiers.

```
HTTP Request (emit_failure_event: true)
    → Condition: Success?
        ├─ Yes → continue
        └─ No  → Log Error
              → Condition: Retry Count < 3?
                  ├─ Yes → Send to Story (retry)
                  └─ No  → Notify On-Call → Create Incident Ticket
```

### Sub-Story Decomposition

Break large workflows into reusable sub-stories connected via Send to Story.

```
Main Story:
  Receive Alert → Normalize → Send to Story (Enrich IOC)
                                  → Send to Story (Check Reputation)
                                      → Merge Results → Decide Action

Sub-Story: Enrich IOC
  Webhook (entry) → Lookup VirusTotal → Lookup AbuseIPDB → Return Result (exit)
```

Benefits:
- Each sub-story is independently testable
- Shared enrichment logic reused across multiple parent stories
- Easier to maintain and version

## Security Practices

### Credential Management

| Do | Don't |
|----|-------|
| Use `<<CREDENTIAL.name>>` references | Hardcode API keys in action options |
| Scope credentials to the minimum required teams | Share credentials across all teams |
| Rotate credentials on a regular schedule | Use the same credential indefinitely |
| Use descriptive credential names | Name credentials `token1`, `key2` |
| Audit credential usage via the API | Assume credentials are only used where intended |

### Webhook Security

- Always set a `secret` on Webhook actions and validate it in the caller
- Use `access_control: "team"` or `"story"` to restrict who can invoke
- Set `rate_limit` to prevent abuse
- Validate incoming payloads with `match_rules` before processing

### Data Handling

- Never log sensitive data (PII, credentials, tokens) to story runs
- Set `log_to_story_run: false` on HTTP Requests that handle sensitive payloads
- Use Event Transforms to strip sensitive fields before passing downstream
- Set appropriate `keep_events_for` values — shorter retention for sensitive data

## Performance

### Story Size

- Keep stories under 50 actions — beyond that, decompose into sub-stories
- Large stories are harder to debug, slower to load in the UI, and riskier to edit

### Event Retention

| Use Case | Recommended Retention |
|----------|----------------------|
| Debugging / development | 7 days (`604800` seconds) |
| Production workflows | 1-3 days |
| Sensitive data workflows | Minimum needed, or 0 (team default) |
| High-volume ingestion | 1 day or less |

### Avoid Loops

- Never create circular links between actions — Tines does not support loops natively
- Use Send to Story with a counter for retry/loop behavior
- Always include a termination condition (max retries, timeout)

### Optimize API Calls

- Batch API requests where the target API supports it (e.g. bulk lookups)
- Cache results in Resources when the data changes infrequently
- Use `retry_on_status` instead of building manual retry loops
- Set `manual_time` (delay) on HTTP Requests to avoid rate limiting

### Send to Story Modes

| Mode | Behavior | Use When |
|------|----------|----------|
| `no_merge` | Fire-and-forget — parent continues immediately | Sub-story result not needed |
| `merge` | Parent waits for sub-story to complete and return data | Need enrichment result before continuing |

Choose `no_merge` for notifications, logging, and async tasks. Choose `merge` for enrichment, validation, and any step where the parent needs the result.

## Testing and Validation

### Manual Testing Checklist

1. Send a test event to the Webhook and verify it flows through all branches
2. Test each Condition branch with matching and non-matching data
3. Verify error handling by simulating API failures (invalid URL, bad credentials)
4. Check that Send to Story actions resolve correctly in both `merge` and `no_merge` modes
5. Confirm email/notification actions produce correct output

### Story Run Inspection

- Use the story run log to trace event flow action by action
- Check `status` on each action: `succeeded`, `failed`, `skipped`
- Verify that `emit_failure_event` branches are reachable
- Confirm that formulas resolve to expected values (check event payloads in the log)

### Pre-Deployment Checks

| Check | How |
|-------|-----|
| No hardcoded secrets | Search action options for API keys, tokens, passwords |
| All CREDENTIAL refs exist | List credentials on the target tenant |
| All RESOURCE refs exist | List resources on the target tenant |
| No disabled actions in the critical path | Review `disabled` flags |
| Event retention is set appropriately | Check `keep_events_for` on the story and individual actions |
| Send to Story targets are correct | Verify story URLs/IDs resolve |
