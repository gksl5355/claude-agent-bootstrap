# Team Orchestrator v1.0 — Product Requirements Document

## Vision

**From "team spawner" to "intelligence and assurance layer."**

Today: spawn agents, hope they do a good job.
v1.0: spawn agents, **know** whether they did a good job.

### One-liner
> Give it a task → analyzes codebase → predicts risk → proposes the right team → executes with scope control → reports confidence.

---

## Problem Statement

Claude Code Agent Teams are powerful but opaque:
1. **No pre-analysis** — users spawn teams blindly without understanding impact or risk
2. **No post-evaluation** — no way to know if agents stayed in scope, broke things, or produced quality code
3. **No audit trail** — runs vanish after completion, no learning possible
4. **No enforcement** — MECE ownership is a prompt instruction, not a code-enforced boundary

Competitors (OMC 8.7k★, OMO 37.7k★) focus on more agents, more skills, more speed.
Nobody focuses on: **"Can you trust what the agents produced?"**

---

## Target User

Claude Code power users who:
- Use Agent Teams (Max/Team plan)
- Run `/spawn-team` for non-trivial tasks
- Want to ship agent-produced code with confidence
- Value transparency over magic

---

## Features (priority order)

### F1: Run Artifacts
**The data layer. Everything else depends on this.**

Every `/spawn-team` run produces a structured artifact directory:

```
.claude/runs/{run-id}/
├── plan.yml          # What was planned (team, tasks, scope, ownership)
├── events.yml        # Timeline of what happened (appended during run)
├── report.yml        # Final summary (generated at completion)
└── decisions.yml     # Key decisions made during run (debate results, escalations)
```

#### plan.yml (written at spawn time)
```yaml
run_id: "2026-03-07-001"
timestamp: "2026-03-07T14:30:00Z"
project: "/home/user/my-app"
task: "Add user authentication with JWT"
complexity: MEDIUM
score: 8

team:
  - name: auth-be
    role: backend
    model: sonnet
    owns: ["src/auth/**", "src/middleware/auth.ts"]
  - name: auth-fe
    role: frontend
    model: sonnet
    owns: ["src/pages/login/**", "src/components/auth/**"]
  - name: unit-tester
    role: tester
    model: haiku
    owns: []

ownership_manifest:
  "src/auth/**": auth-be
  "src/pages/login/**": auth-fe
  "src/middleware/auth.ts": auth-be
  shared: ["src/types/auth.ts", "src/config/jwt.ts"]
  shared_owner: leader
```

#### events.yml (appended during run)
```yaml
events:
  - ts: "14:30:05"
    type: agent_spawned
    agent: auth-be
    model: sonnet

  - ts: "14:32:10"
    type: task_assigned
    agent: auth-be
    task: "Implement JWT middleware"
    accepts: "vitest auth middleware 5 tests PASS"

  - ts: "14:45:30"
    type: agent_done
    agent: auth-be
    status: DONE
    files_changed: ["src/auth/jwt.ts", "src/middleware/auth.ts"]

  - ts: "14:46:00"
    type: scope_violation
    agent: auth-be
    file: "src/config/database.ts"
    action: reverted

  - ts: "14:50:00"
    type: test_result
    agent: unit-tester
    target: auth-be
    result: FAIL
    detail: "jwt.verify - expected 200, got 401"

  - ts: "14:55:00"
    type: test_result
    agent: unit-tester
    target: auth-be
    result: PASS
    retry: 1
```

#### report.yml (written at run completion)
```yaml
run_id: "2026-03-07-001"
duration_minutes: 28
status: COMPLETED

agents:
  - name: auth-be
    tasks_completed: 3
    tasks_failed: 0
    retries: 1
    files_changed: ["src/auth/jwt.ts", "src/middleware/auth.ts", "src/auth/types.ts"]
  - name: auth-fe
    tasks_completed: 2
    tasks_failed: 0
    retries: 0
    files_changed: ["src/pages/login/index.tsx", "src/components/auth/LoginForm.tsx"]
  - name: unit-tester
    tests_run: 12
    tests_passed: 12
    tests_failed: 0

scope_violations: 1
debate_triggered: false
escalations: 0
```

#### decisions.yml (written when decisions occur)
```yaml
decisions:
  - ts: "14:35:00"
    type: scope_lock
    detail: "IN: auth module, login page. OUT: registration, OAuth."

  - ts: "14:46:00"
    type: scope_violation_revert
    agent: auth-be
    file: "src/config/database.ts"
    reason: "Outside owned scope"
```

### F2: Quality & Confidence Harness
**The centerpiece differentiator.**

After run completion, automatically evaluate:

| Check | Method | Weight |
|-------|--------|--------|
| Scope compliance | Compare changed files vs ownership manifest | High |
| Test coverage | All acceptance criteria have PASS evidence | High |
| Build integrity | Post-merge build succeeds | High |
| Retry burden | High retry count = low confidence | Medium |
| Scope violations | Count of out-of-scope edits (even if reverted) | Medium |
| Escalation count | How many times human intervened | Low |
| Debate alignment | If debate occurred, was result followed | Low |

Output: confidence score (0-100) with evidence breakdown.

```yaml
# Appended to report.yml
confidence:
  score: 82
  grade: B
  breakdown:
    scope_compliance: 95    # 1 violation, reverted
    test_evidence: 100      # All criteria have PASS
    build_integrity: 100    # Build passes
    retry_burden: 70        # 1 retry on auth-be
    escalations: 100        # None
  flags:
    - "auth-be touched src/config/database.ts (reverted) — review recommended"
  verdict: "Ship with review of auth-be scope boundary"
```

### F3: Impact & Risk Brief
**Pre-spawn intelligence.**

Before spawning agents, analyze the task against the codebase:

```
/spawn-team "Add JWT authentication"
  ↓
Impact & Risk Brief:
  Impacted modules: src/auth/**, src/middleware/**, src/config/jwt.ts
  Likely test areas: tests/auth/**, tests/e2e/login.spec.ts
  Risk factors:
    - src/middleware/auth.ts has 5 contributors in 30 days (hotspot)
    - tests/e2e/login.spec.ts failed 2x in recent runs (flaky)
  Recommended team: 2 sonnet (be + fe) + 1 haiku (tester)
  Estimated scope: ~150 LOC across 6 files
```

Implementation: heuristics-first using git log, git blame, imports, file structure.
No ML, no external services.

### F4: /spawn-team --preview
**Show before spend.**

Runs F1 plan generation + F3 risk brief WITHOUT spawning agents.
User reviews, adjusts, then confirms to proceed.

```
/spawn-team --preview "Add JWT authentication"

=== PREVIEW (no agents spawned) ===
Complexity: MEDIUM (score 8)
Team: auth-be(sonnet), auth-fe(sonnet), unit-tester(haiku)
Ownership: [manifest]
Risk brief: [F3 output]
Estimated token cost: ~$1.50

Proceed? [y/n/adjust]
```

### F5: Ownership Enforcement + Anti-Pattern Detection
**Code-enforced, not prompt-requested.**

#### Ownership Enforcement
1. Generate ownership manifest in plan.yml (F1)
2. During run: Leader checks `git diff --name-only` per agent against manifest
3. Out-of-scope files → auto-revert + log scope_violation event
4. Post-merge: final `git diff --name-only` vs manifest → flag any leaks

Already partially described in current SKILL.md §8-4. Difference: deterministic check + artifact logging, not just prompt instruction.

#### Anti-Pattern Detection (v1.0 scope)

Integrated into the execution loop, not a separate subsystem. Each detection has a severity:
- **block**: deterministic, trust-breaking → auto-revert or halt
- **pause**: dangerous but may be legitimate → escalate to Leader/user
- **warn**: smell, not proof → log + confidence penalty

| ID | Anti-pattern | Detection | Severity | Check point |
|----|-------------|-----------|----------|-------------|
| AP001 | Out-of-scope edit | `git diff --name-only` vs ownership manifest | block | checkpoint, agent_done, pre_merge |
| AP002 | Shared file edit without decision | touches shared file, no `decisions.yml` entry | pause | agent_done, pre_merge |
| AP003 | Role leakage | tester/debugger/read-only agent writes files | block | agent_done |
| AP005 | Done without evidence | task DONE but no PASS event for accepts criteria | block | pre_merge |
| AP006 | Retry thrash | same task fails 2+ times | pause | test_result |
| AP007 | Test evasion | diff adds `.skip`, `xdescribe`, `eslint-disable`, `ts-ignore`, `\|\| true` | pause | agent_done, pre_merge |
| AP008 | Stale merge | agent branch behind leader after other merges | pause | pre_merge |

Detection shell patterns:
```bash
# AP001/AP003: scope check
git -C "$wt" diff --name-only "$base" | grep -vE "$owned_pattern"

# AP007: test evasion
git -C "$wt" diff -U0 "$base" | grep -E '^\+.*(\.skip\(|describe\.only\(|xdescribe\(|eslint-disable|ts-ignore|\|\| true)'

# AP008: stale check
git -C "$wt" merge-base --is-ancestor HEAD "$leader_head"
```

Anti-pattern hits are logged as events in `events.yml`:
```yaml
- ts: "14:46:00"
  type: anti_pattern
  rule: AP007
  agent: auth-be
  severity: pause
  detail: "Added .skip() to 2 test cases"
  action: escalated_to_leader
  verdict: null    # filled post-run: true_positive | false_positive | accepted_risk
```

#### Anti-pattern promotion pipeline (3-layer)

Not all failures become enforced rules. Promotion requires meeting 2+ criteria:
- **Recurrence**: same failure ≥2 times
- **Severity**: data loss, mass edits, deploy failure risk
- **Confidence**: root cause clearly verified
- **Scope**: applies repo-wide (not one directory only)

```
Layer 1: Raw failure log     → all events.yml anti_pattern entries
Layer 2: Candidate           → recurrence or high-severity entries
Layer 3: Enforced (current)  → AP001-AP008 in this PRD
```

Post-run: Leader marks each anti_pattern event verdict manually.
Confidence harness (F2) reads anti-pattern hit counts from events.yml for scoring.

> **P1/P2 boundary**: verdict field is stored in P1 (YAML). Cross-run FP analysis and auto-severity adjustment → Project 2 scope.

### F6: doctor command
**Environment validation and safe setup.**

```
/doctor

=== Team Orchestrator Health Check ===
  ✓ Claude Code 2.1.71
  ✓ tmux 3.3a
  ✓ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
  ✓ CLAUDE_CODE_TEAMMATE_COMMAND=/home/th/.claude/teammate.sh
  ✓ teammateMode=tmux
  ✗ Codex CLI not found (optional — /debate won't work)

Settings patch needed:
  + CLAUDE_CODE_SUBAGENT_MODEL: "haiku"

Apply? [y/n]
```

### F7: /debate as decision gate
**Auto-trigger, not side command.**

Enhance existing debate skill:
- Integrate into spawn-team flow: if F3 risk brief flags auth/schema/API/cross-cutting → auto-enter debate before spawning
- Log debate result to decisions.yml (F1)
- Confidence harness (F2) checks debate alignment

### F8: Ralph hardening + E2E tests
- prd.json → durable state (survive session restart)
- Evidence-backed acceptance (no "probably works")
- 3-5 fixture repos for automated E2E validation
- Mark beta until state management is real

---

## Architecture

### Principles
1. **No new infrastructure** — no servers, no databases, no npm packages to install
2. **YAML for all structured data** — machine-parseable, human-readable, future UI-friendly
3. **Skills are the interface** — all features are skills or skill enhancements
4. **Inline artifact I/O** — spawn-team skill (the main Claude session orchestrating the run) writes artifacts directly during execution. No separate server, hook process, or daemon.
5. **Backward compatible** — existing `/spawn-team` works without artifacts (graceful degradation)

### Component Map

```
User
  │
  ├─ /spawn-team ──────────────── Skill (enhanced)
  │    ├─ --preview mode (F4)
  │    ├─ Impact & Risk Brief (F3)
  │    ├─ plan.yml writer (F1)
  │    ├─ events.yml appender (F1)
  │    ├─ Ownership enforcement (F5)
  │    ├─ Debate gate (F7)
  │    └─ report.yml + confidence (F1, F2)
  │
  ├─ /doctor ──────────────────── Skill (new)
  │    └─ Environment check + settings patch
  │
  ├─ /debate ──────────────────── Skill (enhanced)
  │    └─ decisions.yml writer
  │
  └─ /ralph ───────────────────── Skill (enhanced)
       └─ prd.json durability + evidence
```

### Storage Layout

```
{project-root}/
└── .claude/
    └── runs/
        ├── latest → symlink to most recent run
        ├── 2026-03-07-001/
        │   ├── plan.yml
        │   ├── events.yml
        │   ├── report.yml
        │   └── decisions.yml
        └── 2026-03-07-002/
            └── ...
```

### Data Flow

```
[Pre-spawn]
  git analysis ─→ F3 Impact Brief
  F3 + user task ─→ F4 Preview
  user confirms ─→ F1 plan.yml written

[During run]
  agent events ─→ F1 events.yml (appended)
  scope checks ─→ F5 enforcement ─→ events.yml
  debate ─→ F7 gate ─→ decisions.yml

[Post-run]
  all artifacts ─→ F2 confidence scoring
  F2 output ─→ F1 report.yml (with confidence block)
  report ─→ user
```

---

## Repo Structure (target)

```
.claude/
├── skills/
│   ├── spawn-team/
│   │   ├── SKILL.md          # Enhanced with F1-F5, F7
│   │   └── prompts.md        # Unchanged
│   ├── debate/
│   │   └── SKILL.md          # Enhanced with F7 gate + decisions.yml
│   ├── ralph/
│   │   └── SKILL.md          # Enhanced with F8 durability
│   └── doctor/
│       └── SKILL.md          # New (F6)
├── scripts/
│   └── teammate.sh           # Unchanged
└── settings.local.json

docs/
├── getting-started.md        # Installation + quick start (user-facing)
├── guide/
│   ├── spawn-team.md         # Usage guide
│   ├── debate.md             # Usage guide
│   └── doctor.md             # Usage guide
└── internal/
    ├── PRD.md                # This file
    └── ARCHITECTURE.md       # Detailed technical decisions (if needed)

tests/
├── unit/
│   └── test-teammate-unit.sh     # Existing
├── integration/
│   └── test-spawn-integration.sh # Existing
│   └── test-confidence-scoring.sh # New (F2)
│   └── test-ownership-guard.sh   # New (F5)
└── fixtures/                 # New (F8), minimal skeleton apps
    ├── simple-app/           # SIMPLE complexity fixture (~5 files)
    ├── medium-app/           # MEDIUM complexity fixture (~10 files)
    └── complex-app/          # COMPLEX complexity fixture (~15 files)

install.sh                    # Updated (add doctor skill symlink)
README.md                     # Updated
README.ko.md                  # Updated
```

---

## Implementation Order

### Dependency Graph

```
F6 (doctor) ──────────────────────────── standalone
F1 (run artifacts) ──┬── F2 (confidence) ──── F7 (debate gate)
                     ├── F3 (impact brief) ── F4 (--preview)
                     ├── F5 (ownership)
                     └────────────────────── F8 (ralph + E2E)
```

### Execution Plan

Each Wave = one session. Within each Wave, only file-independent work runs in parallel.
spawn-team/SKILL.md is the single largest edit target — concurrent edits to it are forbidden.

**Wave 1: Foundation**

| Track | Work | Files touched | Parallel? |
|-------|------|---------------|-----------|
| 1A | F1: Run artifacts — plan.yml/events.yml/report.yml schema + writer logic | spawn-team/SKILL.md (§7 spawn + §8 execution + §8.5 completion) | Sequential |
| 1B | F6: doctor skill | doctor/SKILL.md (new file) | **Parallel with 1A** |
| 1C | SKILL.md worktree gap fix — add `isolation: "worktree"` to §7-1, merge mechanics to §8-4, cleanup to §8-5 | spawn-team/SKILL.md | **Sequential after 1A** |

Acceptance: `plan.yml` written at spawn, `events.yml` appended during run, `report.yml` at completion. `/doctor` validates environment.

**Wave 2: Intelligence layer**

| Track | Work | Files touched | Parallel? |
|-------|------|---------------|-----------|
| 2A | F3: Impact & Risk Brief — git analysis (blame, imports, history) + risk output | spawn-team/SKILL.md (§1 new subsection) | Sequential |
| 2B | F2: Confidence scoring — post-run evaluation + score in report.yml | spawn-team/SKILL.md (§8.5 enhancement) | **Sequential after 2A** |
| 2C | F5: Ownership enforcement — manifest generation + diff guard | spawn-team/SKILL.md (§8-4 enhancement) | **Sequential after 2B** |
| 2D | Tests for F2, F3, F5 | tests/integration/ (new files) | **Parallel with 2A-C** |

Acceptance: Risk brief before spawn, confidence score in report, out-of-scope edits detected + logged.

**Wave 3: User-facing + hardening**

| Track | Work | Files touched | Parallel? |
|-------|------|---------------|-----------|
| 3A | F4: --preview mode (wraps F3 + F1 plan, skips spawn) | spawn-team/SKILL.md (§0 new gate) | Sequential |
| 3B | F7: Debate auto-trigger (reads F3 risk) + decisions.yml | debate/SKILL.md + spawn-team/SKILL.md (§7) | **Sequential after 3A** |
| 3C | F8: Ralph durability + fixture repos + E2E tests | ralph/SKILL.md + tests/fixtures/ | **Parallel with 3A-B** |
| 3D | Docs + README cleanup | docs/, README.md, README.ko.md | **Parallel with 3A-B** |

Acceptance: `--preview` shows analysis without spawning, debate auto-triggers on high-risk, 3+ fixtures pass E2E.

### File ownership per Wave

```
spawn-team/SKILL.md  →  Wave 1 (1A, 1C) → Wave 2 (2A→2B→2C) → Wave 3 (3A→3B)
                         ONE writer at a time. Never concurrent.
doctor/SKILL.md      →  Wave 1 (1B only)
debate/SKILL.md      →  Wave 3 (3B only)
ralph/SKILL.md       →  Wave 3 (3C only)
tests/               →  Wave 2 (2D), Wave 3 (3C) — different subdirs, safe
docs/                →  Wave 3 (3D only)
```

### Phase 6 (post-v1.0): Localhost Dashboard UI

After v1.0 ships and `.claude/runs/` data accumulates:
- Lightweight local web server (single HTML + JS, no build step)
- Reads YAML artifacts from `.claude/runs/`
- Displays: run history, confidence trends, agent performance, scope violations
- Optional: `install.sh` adds `/dashboard` skill that starts the server
- Serves as visual demo for portfolio/README screenshots

---

## Success Criteria

v1.0 is done when:
1. Every `/spawn-team` run produces `.claude/runs/{id}/` with plan + events + report
2. Report includes confidence score with evidence breakdown
3. `--preview` shows analysis without spawning
4. Out-of-scope edits are detected and logged (enforcement)
5. `/doctor` validates environment and patches settings
6. 3+ fixture repos pass automated E2E validation
7. Stale docs cleaned up, README reflects v1.0 features

---

## Out of Scope (v1.0)

- Localhost UI / dashboard (build after data layer exists)
- GraphDB / vector storage (Project 2)
- Cross-session memory / learning (Project 2)
- ML-based prediction (heuristics only)
- MCP server / plugin marketplace packaging
- Provider-agnostic support (Claude Code only)
