# Team Orchestrator v1.0 — Product Requirements Document

> Revised 2026-03-08. Pivoted from original F1-F8 plan.
> GPT-5.4 ecosystem studied for design inspiration (compaction → state.yml, tool_search → efficiency).
> Platform remains Claude Code. Features dropped for scope, not platform overlap.

---

## Vision

**From "team spawner" to "efficient team runtime with learning."**

Today: spawn agents, hope they work, no memory of past runs.
v1.0: spawn agents with efficient state → learn from each run → improve the next.

### One-liner
> Spawn a team → efficient state management → per-run judgment → experience accumulates → next spawn is smarter.

---

## Problem Statement

Claude Code Agent Teams are powerful but:
1. **No state efficiency** — agents re-read everything every checkpoint, wasting tokens
2. **No per-run judgment** — no way to know if this run went well or poorly
3. **No learning** — past run failures don't inform future spawns
4. **No lifecycle management** — finished agents leave zombie processes and disk waste

Competitors (OMC, OMO, SuperClaude) focus on more agents, more skills, more speed.
Nobody focuses on: **"Learn from every run. Get better each time."**

---

## Target User

Claude Code power users who:
- Use Agent Teams (Max/Team plan)
- Run `/spawn-team` for non-trivial tasks
- Want each run to be better than the last
- Value efficiency and measurement over feature count

---

## Features

### F1: Run Artifacts + State Layer + Lifecycle
**The data layer. Everything else depends on this.**

Every `/spawn-team` run produces:

```
.claude/runs/{run-id}/
├── plan.yml        # Team composition, tasks, ownership (written at spawn)
├── state.yml       # Compressed current state (Leader writes, agents read)
├── events.yml      # Full event log (append-only, audit + recovery)
└── report.yml      # Final results + per-run judgment (written at completion)
```

#### Single-writer guarantee

**Leader is the only writer.** Agents are read-only.

```
Leader writes:  state.yml (overwrite), events.yml (append)
Agents read:    state.yml (only), plan.yml (once at start)
Nobody reads:   events.yml during execution (post-run + recovery only)
```

No concurrent write problem. No transactions needed.

#### state.yml — compressed working memory

Leader overwrites state.yml on every state change using atomic rename:

```bash
# Atomic write pattern (prevents agents from reading partial file)
cat > state.yml.tmp << 'EOF'
... yaml content ...
EOF
sync state.yml.tmp
mv state.yml.tmp state.yml    # atomic on same filesystem
```

```yaml
run_id: "2026-03-08-001"
state_version: 14                # monotonic, incremented each write
phase: EXECUTING                  # PLANNING | EXECUTING | MERGING | COMPLETED | ABORTED
updated_at: "14:45:30"

agents:
  auth-be: WORKING                # SPAWNED | WORKING | DONE | MERGED | CLEANED | FAILED
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
  - "JWT payload: {sub, iat, exp}, 1h expiry"

key_decisions:
  - "Scope: auth only (no OAuth)"
  - "bcrypt for password hashing"

next:
  - "auth-be token refresh completion"
  - "unit-tester test start"

scope_violations: 1
```

~35-50 lines. Agents read this instead of hundreds of lines of events.yml.

#### events.yml — append-only audit log + recovery source

Every meaningful state change is also logged as an immutable event:

```yaml
events:
  - seq: 1
    ts: "14:30:05"
    type: agent_spawned
    agent: auth-be
    model: sonnet

  - seq: 5
    ts: "14:35:00"
    type: decision_promoted           # enables recovery of shared_contracts
    detail: "POST /api/auth/login → {token, refreshToken}"

  - seq: 8
    ts: "14:45:30"
    type: agent_done
    agent: auth-be
    status: DONE
    files_changed: ["src/auth/jwt.ts", "src/middleware/auth.ts"]

  - seq: 9
    ts: "14:46:00"
    type: scope_drift                 # not pre-defined rule, just observed problem
    agent: auth-be
    file: "src/config/database.ts"
    action: reverted

  - seq: 12
    ts: "14:50:00"
    type: contract_published          # enables recovery of shared_contracts
    detail: "JWT payload: {sub, iat, exp}, 1h expiry"
```

Event types for recovery: `decision_promoted`, `contract_published`, `blocked`, `unblocked`.
If state.yml is lost, coarse last-known state can be rebuilt from events.yml.
Exact live state (in-flight messages, agent liveness) is NOT recoverable — documented as advisory.

#### Communication protocol

```
SendMessage (tmux) = ephemeral hint ("check state.yml")
state.yml          = authority (Leader-managed, persistent decisions)
events.yml         = audit trail (immutable record)

When agents reach agreement via SendMessage:
  1. Agent reports to Leader
  2. Leader updates state.yml (shared_contracts, key_decisions)
  3. Leader appends decision_promoted event to events.yml
  4. Other agents see it next time they read state.yml
```

SendMessage is best-effort. Messages can be lost or reordered.
Authoritative decisions exist only in state.yml/events.yml.

#### report.yml — per-run judgment (internal)

```yaml
run_id: "2026-03-08-001"
duration_minutes: 28
status: COMPLETED

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
  success_rate: 1.0               # tasks_completed / total_tasks
  retry_rate: 0.33                # tasks_with_retries / total_tasks
  scope_violations: 1
  escalations: 0
  verdict: "Clean run. 1 scope drift (reverted)."
```

This is the **internal** judgment — per-run, automatic, always generated.

#### Lifecycle management

```
Agent lifecycle (within run):
  SPAWNED → WORKING → DONE → MERGED → CLEANED
                        ↓
                      FAILED → RETRIED (max 2) → ESCALATED

Run lifecycle:
  ACTIVE → COMPLETED → ARCHIVED (7d auto)
              ↓
           ABORTED → CLEANED
```

Cleanup triggers:
- agent DONE + merged → worktree delete, tmux pane kill
- run COMPLETED → state.yml frozen, events.yml closed
- run >7d → `.claude/runs/{id}/` → `.claude/runs/archive/`

#### Constraints
- **Agent cap: 5** (Leader bottleneck above this)
- **state.yml write: atomic rename only** (never in-place overwrite)
- **events.yml: append-only** (never delete or modify entries)

---

### F3: Experience-based Briefing (NEW direction)
**Past runs inform future spawns. Not prediction — experience.**

Old F3 was git heuristic analysis (blame, log). Killed — too speculative.
New F3: read summary.yml from past runs and brief the spawn.

```
/spawn-team "Add payment processing"
  ↓
Experience brief (from summary.yml):
  "Recent patterns in this project:
   - auth-be drifted to database.ts 3 times (scope issue)
   - MEDIUM tasks: sonnet 2 + haiku 1 had best success rate
   - Average run: 22 min, 1.2 retries
   Recommendations:
   - Explicitly exclude database.ts from auth-be scope
   - Consider splitting database work to separate agent"
```

Implementation: read `.claude/runs/summary.yml` at spawn time.
No git analysis, no ML. Just structured recall of past run data.

---

### F4: /spawn-team --preview
**Show before spend.**

Runs plan generation WITHOUT spawning agents.
User reviews, adjusts, then confirms to proceed.
If F3 data exists, includes experience brief.

```
/spawn-team --preview "Add JWT authentication"

=== PREVIEW (no agents spawned) ===
Complexity: MEDIUM (score 8)
Team: auth-be(sonnet), auth-fe(sonnet), unit-tester(haiku)
Ownership: [manifest]

Experience (last 5 runs):
  - auth-be scope drift: 2 occurrences on database.ts
  - Recommended: exclude database.ts from auth-be

Proceed? [y/n/adjust]
```

---

### F5: Bottom-up Pattern Detection (NEW direction)
**No pre-defined rules. Problems emerge from data.**

Old F5 was AP001-AP008 hard-coded rules. Killed — over-engineered.
New F5: observe problems → record → if repeated → auto-warn.

```
Run 1: auth-be edits database.ts (not in scope) → Leader logs it
Run 2: auth-be edits database.ts again → logged, pattern tagged
Run 3: spawn time → auto-warning "auth-be has scope drift on database.ts"
```

#### summary.yml (auto-aggregated from recent runs)

```yaml
project: "/home/user/my-app"
runs_analyzed: 10
last_updated: "2026-03-10"

patterns:
  - type: scope_drift
    agent: auth-be
    file: "src/config/database.ts"
    occurrences: 3
    first_seen: "2026-03-08-001"
    last_seen: "2026-03-10-002"
    action: warn_on_spawn

  - type: retry_heavy
    agent: unit-tester
    avg_retries: 2.3
    occurrences: 4
    action: note

  - type: team_success
    config: "sonnet:2 + haiku:1"
    complexity: MEDIUM
    success_rate: 0.85
    occurrences: 6
    action: recommend

stats:
  avg_duration_min: 22
  avg_success_rate: 0.82
  avg_retries: 1.2
  most_common_team: "sonnet:2 + haiku:1"
```

How patterns are promoted:
```
Occurrence 1:  logged in events.yml only
Occurrence 2+: tagged as pattern in summary.yml
Pattern with 3+ occurrences: action = warn_on_spawn (shown in F3/F4)
```

No pre-defined rule IDs. No hard-coded detection scripts.
Patterns emerge from actual run data. Leader tags them naturally.

---

### F6: Doctor
**Environment validation and safe setup.**

```
/doctor

=== Team Orchestrator Health Check ===
  ✓ Claude Code 2.1.74
  ✓ tmux 3.3a
  ✓ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
  ✓ CLAUDE_CODE_TEAMMATE_COMMAND=/home/user/.claude/teammate.sh
  ✓ teammateMode=tmux
  ✗ Codex CLI not found (optional)

Settings patch needed:
  + CLAUDE_CODE_SUBAGENT_MODEL: "haiku"

Apply? [y/n]
```

---

### F2-external: Benchmark (post-v1.0, one-off)
**Quantitative metrics for portfolio. Not a core runtime feature.**

Separate from the core runtime. Run once (or periodically) to produce numbers for README.

- Run tasks on public repos: single agent vs spawn-team
- Measure: pass@1, token ratio, retry count
- Output: benchmarks/comparison.yml
- Purpose: proof for external audience

Not part of the daily workflow. Not part of v1.0 success criteria.
Build after F1/F3/F4/F5/F6 are stable.

---

## Architecture

### Principles
1. **No new infrastructure** — no servers, no databases, no npm packages
2. **YAML for all structured data** — files are the database for P1
3. **Skills are the interface** — all features are skills or skill enhancements
4. **Single-writer** — Leader writes state.yml + events.yml. Agents read only.
5. **Atomic writes** — state.yml via tmp + sync + mv. Never in-place overwrite.
6. **WAL pattern** — events.yml is the source of truth (append-only log); state.yml is a derived materialized view (rebuildable from events).
7. **Bottom-up patterns** — no pre-defined rules. Problems emerge from data.
8. **Experience over prediction** — past run data, not git heuristics.

### Storage Layout

```
{project-root}/
└── .claude/
    └── runs/
        ├── latest → symlink to most recent run
        ├── summary.yml             # Aggregated patterns from recent runs (F5)
        ├── {run-id}/
        │   ├── plan.yml
        │   ├── state.yml
        │   ├── events.yml
        │   └── report.yml
        └── archive/                # runs >7d
```

### Data Flow

```
[Pre-spawn]
  summary.yml exists? → F3 experience brief
  --preview? → show plan + brief, exit
  user confirms → plan.yml written, state.yml initialized

[During run]
  Leader:
    events.yml ← append (every event, including decision_promoted)
    state.yml  ← atomic overwrite (every state change)
  Agents:
    state.yml  → read (checkpoint)
    plan.yml   → read (once at start)
  Communication:
    SendMessage → ephemeral hint
    state.yml   → authoritative decisions

[Post-run]
  state.yml → phase: COMPLETED, frozen
  report.yml written (judgment: success_rate, retries, violations)
  summary.yml updated (aggregate patterns from this run + recent history)
  lifecycle cleanup (worktree, tmux, archival)

[Benchmark mode — separate, one-off]
  public repo tasks → single vs team → benchmarks/comparison.yml
```

---

## Implementation Plan

### Wave 1: Foundation (parallel)

| Track | Work | Files | Parallel? |
|-------|------|-------|-----------|
| 1A | F1: artifacts + state.yml + lifecycle + report judgment | spawn-team/SKILL.md | Yes |
| 1B | F6: doctor | doctor/SKILL.md (new) | Yes (independent) |

Acceptance:
- plan.yml + state.yml at spawn, events.yml during run, report.yml at completion
- state.yml atomic write (tmp + mv)
- Lifecycle cleanup on finish
- /doctor validates environment

### Wave 2: Learning + Polish (sequential on SKILL.md)

| Track | Work | Files | Parallel? |
|-------|------|-------|-----------|
| 2A | F5: summary.yml generation from run data | spawn-team/SKILL.md | First |
| 2B | F3: experience brief at spawn time | spawn-team/SKILL.md | After 2A |
| 2C | F4: --preview mode | spawn-team/SKILL.md | After 2B |

Acceptance:
- summary.yml auto-generated after each run
- Patterns detected (2+ occurrences)
- Experience brief shown at spawn (when data exists)
- --preview shows plan + brief without spawning

### Wave 3: Docs + Benchmark

| Track | Work | Files |
|-------|------|-------|
| 3A | README update | README.md, README.ko.md |
| 3B | Internal docs update | TRD.md, SILOS.md |
| 3C | F2-external benchmark run | benchmarks/ |

---

## Success Criteria

v1.0 is done when:
1. Every run produces plan + state + events + report in `.claude/runs/{id}/`
2. state.yml is the primary state source during execution (agents never read events.yml)
3. Atomic write for state.yml (tmp + sync + mv)
4. report.yml includes per-run judgment (success_rate, retries, violations)
5. summary.yml auto-aggregates patterns from recent runs
6. Experience brief shown at spawn when past data exists
7. `--preview` shows plan + brief without spawning
8. Lifecycle cleanup: finished agents cleaned, runs archived after 7d
9. `/doctor` validates environment and patches settings
10. Agent cap: 5 hard limit

---

## Out of Scope (v1.0)

- F2-external benchmark → post-v1.0 (one-off for portfolio)
- Localhost UI / dashboard → P2
- GraphDB / vector storage → P2
- Cross-session memory / learning → P2
- ML-based prediction → experience data only
- Ralph hardening → post-v1.0
- Debate auto-gate → post-v1.0
- Provider-agnostic support → Claude Code only
- Skill/tool lifecycle management → P2
- Token tracking infrastructure → P2 (Claude Code doesn't expose tokens natively)
