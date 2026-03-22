# Tines Agent Skills

Agent skills for building, reviewing, and managing automations on the [Tines](https://www.tines.com/) workflow automation platform. Compatible with Claude Code, Cursor, Codex, Windsurf, GitHub Copilot, and other AI agents.

## Getting Started

### Option 1: Claude Code Plugin (Recommended)

```bash
claude plugin marketplace add https://github.com/jamesagarside/tines-agent-skills
claude plugin install tines@tines-agent-skills
```

### Option 2: NPX Skills CLI

```bash
npx skills add jamesagarside/tines-agent-skills
```

Install specific skills:
```bash
npx skills add jamesagarside/tines-agent-skills@tines-cases
npx skills add jamesagarside/tines-agent-skills --skill 'tines-*'
```

### Option 3: Bash Installer

```bash
git clone https://github.com/jamesagarside/tines-agent-skills.git
cd tines-agent-skills
./scripts/install-skills.sh add -a claude-code
```

Other agents:
```bash
./scripts/install-skills.sh add -a cursor
./scripts/install-skills.sh add -a windsurf
./scripts/install-skills.sh add -a github-copilot
```

Install specific skills only:
```bash
./scripts/install-skills.sh add -a claude-code -s 'tines-cases'
```

List available skills:
```bash
./scripts/install-skills.sh list
```

### Configuration

#### Option A: Credentials File (Recommended)

Ask your agent: *"Configure my Tines credentials"* — or create the file manually:

```bash
mkdir -p ~/.tines && chmod 700 ~/.tines
cat > ~/.tines/credentials << 'EOF'
current = default

[default]
tenant_url = https://your-tenant.tines.com
api_token = your-api-token
EOF
chmod 600 ~/.tines/credentials
```

Multiple profiles are supported. The `current` attribute controls which profile is active:

```ini
current = default

[default]
tenant_url = https://your-tenant.tines.com
api_token = your-api-token

[staging]
tenant_url = https://staging.tines.com
api_token = staging-token
```

Switch profiles by asking your agent: *"Switch to the staging profile"* — or override with `TINES_PROFILE=staging` for one-off commands.

#### Option B: Environment Variables

```bash
export TINES_TENANT_URL="https://your-tenant.tines.com"
export TINES_API_TOKEN="your-api-token"
```

Environment variables always take priority over the credentials file.

**Creating an API token:** In Tines, go to **Settings > API keys** (under Access & security) and create a new key.

Verify your connection by asking your agent: *"Check my Tines connection"*

### API Wrapper Script

A standalone shell script handles credential resolution and API calls, so agents don't need to assemble multi-line bash for every request:

```bash
# API calls
bash scripts/tines-api.sh GET /stories?per_page=500 | jq '.stories[] | {id, name}'
bash scripts/tines-api.sh GET /cases --paginate | jq '.[].name'
bash scripts/tines-api.sh POST /stories/import @story.json | jq .
bash scripts/tines-api.sh PATCH /cases/123 '{"status": "closed"}' | jq .

# Profile management
bash scripts/tines-api.sh profiles          # list all profiles
bash scripts/tines-api.sh switch staging    # switch active profile
bash scripts/tines-api.sh test              # test connection
```

To allow API calls without per-command approval in Claude Code, add to your `.claude/settings.json`:

```json
"permissions": { "allow": ["Bash(bash scripts/tines-api.sh:*)"] }
```

## Available Skills

<!-- BEGIN-SKILL-TABLE -->
| Skill | Description |
|---|---|
| **Workflow Skills** | |
| [`tines-build`](skills/tines/tines-build/SKILL.md) | Build stories from descriptions — design workflows, select action types, configure formulas, produce export-ready JSON |
| [`tines-review`](skills/tines/tines-review/SKILL.md) | Review stories for quality — audit naming, error handling, security, formula correctness |
| [`tines-audit`](skills/tines/tines-audit/SKILL.md) | Audit a tenant — find unused credentials, stale stories, orphaned resources, generate health report |
| **API Skills** | |
| [`tines-auth`](skills/tines/tines-auth/SKILL.md) | Configure credentials, validate API connection, manage profiles, check tenant status |
| [`tines-stories`](skills/tines/tines-stories/SKILL.md) | List, create, update, delete, export/import stories; view runs and events |
| [`tines-actions`](skills/tines/tines-actions/SKILL.md) | Manage actions within stories; view logs, events; re-emit events; clear memory |
| [`tines-cases`](skills/tines/tines-cases/SKILL.md) | Full case management — comments, tasks, files, notes, metadata, linked cases, PDF export |
| [`tines-records`](skills/tines/tines-records/SKILL.md) | CRUD records, manage record types and views |
| [`tines-credentials`](skills/tines/tines-credentials/SKILL.md) | Manage credentials (AWS, HTTP, JWT, OAuth, Text) and shared resources |
| [`tines-admin`](skills/tines/tines-admin/SKILL.md) | User management, audit logs, job monitoring, teams, folders, system health |
<!-- END-SKILL-TABLE -->

## Supported Agents

| Agent | Install Directory |
|-------|-------------------|
| Claude Code | `.claude/skills` |
| Cursor | `.agents/skills` |
| Codex | `.agents/skills` |
| OpenCode | `.agents/skills` |
| Windsurf | `.windsurf/skills` |
| GitHub Copilot | `.agents/skills` |
| Gemini CLI | `.agents/skills` |
| Roo | `.roo/skills` |
| Cline | `.agents/skills` |
| Pi | `.pi/agent/skills` |

## Usage Examples

```text
"Build me a story that triages phishing alerts from a webhook"
"Review story 42 for best practices"
"Audit my tenant for unused credentials"
"List all my Tines stories"
"Show me the actions in story 42"
"Create a new case called 'Phishing Investigation'"
"Add a comment to case 15: Initial triage complete"
"Export story 7 as JSON"
"Show me recent audit logs"
"What jobs are currently queued?"
"List all credentials in my tenant"
"Switch to the staging profile"
```

## Testing

### Structural Tests (no Tines tenant required)

Validates skill files for correct format, naming, security patterns, and consistency:

```bash
./tests/test-structural.sh               # Skill file format, security, consistency
./tests/test-domain-knowledge.sh         # Shared reference docs and cross-references
./tests/test-api-wrapper.sh             # API wrapper script (profiles, resolution, commands)
./tests/test-cross-skill.sh --dry-run    # Cross-skill consistency (structural checks only)
```

### Integration Tests (requires Tines tenant)

Runs against a live Tines tenant to verify API operations:

```bash
export TINES_TENANT_URL="https://your-tenant.tines.com"
export TINES_API_TOKEN="your-api-token"

./tests/test-integration.sh              # Run all tests
./tests/test-integration.sh auth         # Test auth only
./tests/test-integration.sh stories      # Test stories only
./tests/test-integration.sh --dry-run    # Preview without API calls
./tests/test-cross-skill.sh             # Cross-skill consistency (with API)
./tests/test-error-handling.sh          # Error handling and edge cases
./tests/test-lifecycle.sh               # Full resource lifecycle tests
./tests/test-pagination.sh             # Pagination behaviour validation
./tests/test-write-operations.sh       # Write operation tests
```

## Rate Limits

Rate limits are enforced per IP + API token combination:

| Endpoint | Requests/Minute |
|----------|-----------------|
| General | 5000 |
| actions | 100 |
| admin/users | 500 |
| audit_logs | 1000 |
| records | 400 |

Skills include rate limit awareness and will warn before batch operations that may hit limits.

## Security

- API tokens are **never** echoed or logged in command output
- Credential secret values are **never** displayed — only metadata (name, type, team)
- Destructive operations (delete, clear memory) require explicit confirmation
- Tines returns 404 (not 403) for underprivileged tokens — by design to prevent resource discovery

## Skill Structure

Skills follow the [agentskills.io](https://agentskills.io) open standard. Each skill directory contains:

```text
skills/tines/
├── shared/                              # Domain knowledge (loaded on-demand)
│   ├── common-patterns.md              # Auth, pagination, errors, rate limits
│   ├── action-types.md                 # All 8 Tines action types with schemas
│   ├── formulas.md                     # Formula syntax + 200+ function reference
│   ├── story-schema.md                 # Story export/import JSON schema
│   └── best-practices.md              # Naming, error handling, security, patterns
├── tines-build/                        # Workflow skills
│   ├── SKILL.md
│   └── references/api-reference.md
├── tines-review/
│   ├── SKILL.md
│   └── references/api-reference.md
├── tines-audit/
│   ├── SKILL.md
│   └── references/api-reference.md
├── tines-auth/                         # API skills
│   ├── SKILL.md
│   └── references/api-reference.md
├── tines-stories/
│   ├── SKILL.md
│   └── references/api-reference.md
└── ... (actions, cases, records, credentials, admin)
```

**SKILL.md** contains scope, jobs to be done, prerequisites, core operations, and cross-skill routing. **references/** contains API specs and extended examples. **shared/** contains domain knowledge that workflow skills reference when building, reviewing, or auditing automations.

```yaml
---
name: skill-name
description: What this skill does and when to activate it
metadata:
  author: jamesagarside
  version: "0.5.0"
---
```

## License

MIT
