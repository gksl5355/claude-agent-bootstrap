# Workflow Guide

Step-by-step execution flow for Team Orchestrator.

---

## Full Flow Diagram

```
User: /spawn-team [task]
        │
        ▼
┌─ Step 0: Init ─────────────────────────────────┐
│  Tool preload + orphan cleanup + stack scan     │
└────────────────────────────────────────────────┘
        │
        ▼
┌─ Step 1: Project Analysis ─────────────────────┐
│  1-1. Tech stack detection (parallel)           │
│  1-2. Domain detection + structure type         │
│  1-3. Context Map generation (rg scan)          │
└────────────────────────────────────────────────┘
        │
        ▼
┌─ Step 2: Task-Based Routing ───────────────────┐
│  N_parallel = tasks that can run in parallel    │
│  N_files    = files to create or modify         │
│                                                  │
│  N_parallel < 3 AND N_files < 5                 │
│    → SINGLE AGENT (auto-route)                  │
│                                                  │
│  N_parallel ≥ 3 OR N_files ≥ 5                  │
│    → TEAM (continue to Step 3+)                 │
│                                                  │
│  explicit plan / structure [C]                   │
│    → TEAM (COMPLEX path)                        │
└────────────────────────────────────────────────┘
        │
   ┌────┴────────────────────┐
   │                         │
SINGLE AGENT              TEAM
   │                         │
   ▼                    ┌────┴────────────────┐
Spawn 1 agent           │   MEDIUM / COMPLEX  │
Execute directly         │                     │
Done (no run artifacts)  ▼                     ▼
                      MEDIUM              COMPLEX
                      Step 3              Step 3
                      (scope)         +   Step 4
                         │              (planning)
                         └──────┬────────────┘
                                │
                                ▼
                    ┌─ Step 5: Team Proposal ──────────┐
                    │  Agent count + models + worktree  │
                    └──────────────────────────────────┘
                                │
                                ▼
                    ┌─ Step 6: User Confirm ────────────┐
                    │  Team + plan sign-off             │
                    └──────────────────────────────────┘
                                │
                                ▼
                    ┌─ Step 7: Spawn ───────────────────┐
                    │  Preview check → experience brief  │
                    │  → run init → agents               │
                    └──────────────────────────────────┘
                                │
                                ▼
                    ┌─ Step 8: Execution Loop ──────────┐
                    │  Implement → Test → Fix → Merge   │
                    │  → report.yml + summary.yml        │
                    └──────────────────────────────────┘
```

---

## Routing Rules

### Single Agent (auto-route)

When task is small enough:
- One short message to user: "→ Routing to single agent (faster, lower token cost)."
- One general-purpose Agent spawned, no TeamCreate, no run artifacts
- `--team` flag forces team mode regardless of size

### Team Paths

| Level | Condition | Steps |
|-------|-----------|-------|
| MEDIUM | 3 ≤ N_parallel or N_files ≥ 5 | Step 3 (scope confirm) |
| COMPLEX | Large N / explicit plan / structure [C] | Step 3 + Step 4 (Wave planning) |

---

## Context Map (Step 1-3)

Before any agents are spawned, Leader builds a compact codebase snapshot using `rg` (ripgrep):

```bash
rg --files --sort path | head -80              # file tree
rg --type py "^(class|def )" --with-filename  # symbol overview
find . -name "*.py" | xargs wc -l | sort -rn  # LOC per file
```

Output (~60 lines) is injected verbatim into every agent prompt.
Agents skip re-exploration for files already in the Context Map.

---

## Scope Confirmation (Step 3, MEDIUM/COMPLEX)

One `AskUserQuestion`:
- **IN**: domains/files in scope
- **OUT**: external systems (mock only), CI/CD, performance tuning
- **DEFER**: low-priority domains

Scope locked after confirmation. Change attempts trigger a warning.

---

## Planning (Step 4, COMPLEX only)

### Structured Interview (3-5 questions)
1. Core objective
2. 3 measurable success criteria
3. Constraints
4. Risks
5. Ordering preference

### Wave Decomposition

```
Wave 1 (parallel): Foundation — types, schemas, shared interfaces
Wave 2 (parallel): Core — domain logic per agent
Wave 3 (sequential): Integration — cross-domain
Wave N (parallel): Verification — tests
Wave Final: merge
```

Each task has: `Task / Accepts (testable) / BlockedBy`.

---

## Execution Loop (Step 8)

### Normal path

```
Agent implements
  → unit-tester verifies
    → PASS → next task
```

### Failure path

```
FAIL (1st)
  → unit-tester reports directly to agent + Leader
  → agent fixes → re-verify

FAIL (2nd)
  → agent self-spawns debugger sub-agent (Haiku, read-only)
  → findings relayed → agent fixes → re-verify

FAIL (3rd, post-debugger)
  → circuit breaker: AskUserQuestion
    1) Leader intervenes directly
    2) Skip this feature
    3) Abort run
```

### Debate auto-trigger

Debate Mode (`/debate`) auto-triggered on:
- DB schema changes (irreversible)
- External API contract changes (irreversible)
- Risk score 6+ issue

---

## Agent Roles

| Role | Model | Edits | Notes |
|------|-------|-------|-------|
| Leader (this session) | Sonnet | Shared files only | State authority |
| `{domain}-be/fe` | Sonnet | Own domain only | MECE boundary enforced |
| `fullstack` | Sonnet | Full scope | Small tasks only |
| `unit-tester` | Haiku | Test files only | No implementation edits |
| `scenario-tester` | Haiku | Test files only | E2E flow validation |
| `debugger` | Haiku | None | On-demand, analysis only |
| `build-fixer` | Haiku | Build files scoped | On-demand |
| `architect` | Sonnet | Structure refactor | Structure [C] only |

---

## Example Scenarios

### Scenario 1: Simple task (single agent auto-route)

```
/spawn-team "Add /health endpoint to server.py"

Analysis: 1 task, 2 files → SINGLE AGENT
→ Routing to single agent (faster, lower token cost).
Agent implements, tests, done.
```

### Scenario 2: TODO App (TEAM MEDIUM)

```
/spawn-team "Build todo API + frontend + tests"

Analysis: 3 parallel tasks, 6+ files → TEAM
→ fullstack-be(sonnet) + fullstack-fe(sonnet) + unit-tester(haiku)
→ Scope confirm → spawn → done
```

### Scenario 3: E-commerce (TEAM COMPLEX)

```
/spawn-team "E-commerce backend: auth + products + orders + tests"

Analysis: 4+ parallel domains, 15+ files → TEAM COMPLEX
→ Scope confirm → planning interview → Wave 3 decomposition
→ products-be(sonnet) + users-be(sonnet) + orders-be(sonnet) + unit-tester(haiku)
→ Wave-gated execution → done
```
