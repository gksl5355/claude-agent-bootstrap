# Team Orchestrator v1.0 — Technical Requirements Document

> Implementation-level spec. Read PRD first for context.
> TRD answers: "exactly how to build it"

---

## Project Boundary

| Scope | Project 1 (this repo) | Project 2 (separate repo) |
|-------|----------------------|---------------------------|
| Technology | Shell + SKILL.md (no servers, no DBs) | GraphDB + Vector DB + LLM API |
| State | YAML files in `.claude/runs/` | Cross-run retrieval + embedding |
| Patterns | Bottom-up from run data via Forge | Automated analysis + auto-retirement |
| Learning | Forge.db Q-value EMA | Full memory system |
| Token tracking | Not available (Claude Code limitation) | Proxy-based measurement |

---

## F1: Run Artifacts — Schemas

### Directory convention
```
{project-root}/.claude/runs/{YYYY-MM-DD-NNN}/
├── plan.yml
├── state.yml
├── events.yml
└── report.yml
```

`NNN` = zero-padded sequence per day (001, 002, ...).
Leader creates dir at spawn time.
`latest` symlink: `ln -sfn {run-id} .claude/runs/latest`

### state.yml — atomic write protocol

**CRITICAL**: Never write state.yml in-place. Always use atomic rename.

```bash
# Leader writes state.yml:
cat > .claude/runs/${RUN_ID}/state.yml.tmp << 'EOF'
... yaml content ...
EOF
sync .claude/runs/${RUN_ID}/state.yml.tmp
mv .claude/runs/${RUN_ID}/state.yml.tmp .claude/runs/${RUN_ID}/state.yml
```

`state_version` field is monotonically incremented on each write.
Agents can detect stale reads by checking version.

### state.yml schema
```yaml
run_id: "2026-03-08-001"
state_version: 14                  # monotonic counter
phase: EXECUTING                    # PLANNING | EXECUTING | MERGING | COMPLETED | ABORTED
updated_at: "2026-03-08T14:45:30Z"

agents:
  auth-be: WORKING                  # SPAWNED | WORKING | DONE | MERGED | CLEANED | FAILED
  auth-fe: DONE
  unit-tester: SPAWNED

completed:
  - "JWT middleware implementation"
  - "Login page component"

in_progress:
  - agent: auth-be
    task: "Token refresh logic"

blocked:
  - agent: unit-tester
    waiting_for: auth-be
    reason: "JWT module not ready"

shared_contracts:
  - "POST /api/auth/login → {token, refreshToken}"

key_decisions:
  - "Scope: auth only (no OAuth)"

next:
  - "auth-be token refresh"
  - "unit-tester test start"

scope_violations: 1
```

### plan.yml schema (written once at spawn)
```yaml
run_id: "2026-03-08-001"
timestamp: "2026-03-08T14:30:00Z"
project: "/home/user/my-app"
task: "Add JWT authentication"
complexity: MEDIUM                  # SIMPLE | MEDIUM | COMPLEX
score: 8                            # 4-12

team:
  - name: auth-be
    role: backend
    model: sonnet
    owns: ["src/auth/**", "src/middleware/auth.ts"]
  - name: unit-tester
    role: tester
    model: haiku
    owns: []

ownership_manifest:
  "src/auth/**": auth-be
  "src/middleware/auth.ts": auth-be
  shared: ["src/types/auth.ts"]
  shared_owner: leader
```

### events.yml schema (append-only)
```yaml
events:
  - seq: 1
    ts: "14:30:05"
    type: agent_spawned
    agent: auth-be
    model: sonnet

  - seq: 2
    ts: "14:30:06"
    type: agent_spawned
    agent: unit-tester
    model: haiku

  - seq: 3
    ts: "14:32:10"
    type: task_assigned
    agent: auth-be
    task: "Implement JWT middleware"

  - seq: 4
    ts: "14:35:00"
    type: decision_promoted
    detail: "POST /api/auth/login → {token, refreshToken}"

  - seq: 5
    ts: "14:45:30"
    type: agent_done
    agent: auth-be
    status: DONE
    files_changed: ["src/auth/jwt.ts", "src/middleware/auth.ts"]

  - seq: 6
    ts: "14:46:00"
    type: scope_drift
    agent: auth-be
    file: "src/config/database.ts"
    action: reverted

  - seq: 7
    ts: "14:50:00"
    type: test_result
    agent: unit-tester
    target: auth-be
    result: PASS
    retry: 0
```

Event types:
- Lifecycle: `agent_spawned`, `task_assigned`, `agent_done`, `wave_complete`
- State: `decision_promoted`, `contract_published`, `blocked`, `unblocked`
- Problems: `scope_drift`, `test_result` (FAIL), `escalation`

`seq` field: monotonic sequence number. Enables recovery ordering.

Flush rule: each event appended immediately (not batched).

### report.yml schema (written at completion)
```yaml
run_id: "2026-03-08-001"
duration_minutes: 28
status: COMPLETED                    # COMPLETED | FAILED | ABORTED

agents:
  - name: auth-be
    tasks_completed: 3
    tasks_failed: 0
    retries: 1
    files_changed: ["src/auth/jwt.ts", "src/middleware/auth.ts"]
  - name: unit-tester
    tests_run: 12
    tests_passed: 12
    tests_failed: 0

judgment:
  success_rate: 1.0
  retry_rate: 0.33
  scope_violations: 1
  escalations: 0
  verdict: "Clean run. 1 scope drift (reverted)."
```

### Recovery spec

If state.yml is lost or corrupt:
1. Read events.yml sequentially by `seq`
2. Replay: agent_spawned → agents list, decision_promoted → shared_contracts, etc.
3. Result: coarse last-known state (which agents existed, what decisions were made)

**NOT recoverable**: exact in-flight tasks, SendMessage history, agent liveness.
Documented as advisory — these fields are best-effort after recovery.

---

## F3: Experience Brief — Data Source

### Commands (run at spawn time)
```bash
# Retrieve experience brief from Forge
forge resume --team-brief
```

No git analysis. No external API. Forge database provides learning from past runs.

### Output format (shown to user at spawn)
```
Experience brief (from recent runs):
  Patterns:
    - auth-be: scope drift on database.ts (3 occurrences) → excluding from scope
    - Best team for MEDIUM: sonnet:2 + haiku:1 (85% success)
  Stats:
    - Average duration: 22 min
    - Average success rate: 82%
```

---

## F5: Pattern Detection — Forge Learning

### When to ingest
After every run completion (before archival), Leader:
1. Calls `forge ingest --auto` via writeback.sh
2. Forge reads events.yml and report.yml
3. Extracts failures and learning events
4. Updates Q-value EMA in forge.db
5. Patterns emerge via failure model + Q-ranking

Learning is stored in Forge database (forge.db) with Q-value EMA tracking.

### Pattern discovery rules
```
Occurrence 1:     Failure record created with initial Q
Occurrence 2+:    Q-value updated via EMA: Q ← Q + α(r - Q)
Q-value >= 0.5:   Pattern appears in `forge resume --team-brief`
```

No pre-defined pattern IDs. No hard-coded detection.
Patterns emerge naturally from failure data and Q-ranking.

---

## F6: Doctor — Check List

```bash
# 1. Claude Code version
claude --version

# 2. tmux
tmux -V

# 3. CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

# 4. TEAMMATE_COMMAND file exists and is executable
test -x "$CLAUDE_CODE_TEAMMATE_COMMAND"

# 5. teammateMode in settings.json
jq '.teammateMode' ~/.claude/settings.json

# 6. Codex CLI (optional)
which codex && codex --version

# 7. git available
git --version

# 8. CLAUDE_CODE_SUBAGENT_MODEL
jq '.env.CLAUDE_CODE_SUBAGENT_MODEL' ~/.claude/settings.json
```

Settings patch: read `~/.claude/settings.json` → merge required keys → backup original → write.

---

## Communication Protocol

### Layers
```
Layer 1: SendMessage (tmux)
  - Best-effort, ephemeral
  - Can be lost or reordered
  - Use for: real-time coordination, status updates, quick questions
  - NOT authoritative

Layer 2: state.yml
  - Leader-managed, persistent
  - Atomic writes only
  - Use for: current state, decisions, contracts, blockers
  - Authoritative for "what is the current situation"

Layer 3: events.yml
  - Append-only, immutable
  - Use for: audit trail, recovery, post-run analysis
  - Authoritative for "what happened"
```

### Decision promotion flow
```
Agent A → SendMessage → Leader: "Let's use bcrypt"
Agent B → SendMessage → Leader: "Agreed"
Leader → state.yml: shared_contracts += "bcrypt for hashing"
Leader → events.yml: { type: decision_promoted, detail: "bcrypt for hashing" }
```

### Agent checkpoint flow
```
Agent reads state.yml:
  - "What phase are we in?"
  - "Am I blocked?"
  - "Any new shared contracts I should know about?"
  - "Any scope drift warnings?"
Agent does NOT read events.yml.
```

---

## Constraints

| Constraint | Value | Reason |
|-----------|-------|--------|
| Max agents | 5 | Leader bottleneck above this |
| state.yml write | atomic rename only | Prevent partial reads |
| events.yml | append-only | Auditability + recovery |
| Token tracking | NOT available in P1 | Claude Code doesn't expose tokens |
| DB | NOT used in P1 | Filesystem only, DB is P2 |
