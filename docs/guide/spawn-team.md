# /spawn-team Guide

## Overview

`/spawn-team` is the core orchestrator skill. It analyzes your project, composes a team of Claude Code agents, and runs them through implementation, testing, and merging.

## Workflow

```
Step 0   Init              Tool preload + cleanup + auto-detect
Step 1   Project analysis   Tech stack + domains + structure type
Step 2   Complexity score   → SIMPLE (4-6) / MEDIUM (7-9) / COMPLEX (10+)
Step 3   Scope confirm      IN/OUT/DEFER (MEDIUM+ only)
Step 4   Planning           Interview + Waves (COMPLEX only)
Step 5   Team proposal      Agents + models + ownership
Step 6   User confirm       Final sign-off
Step 7   Spawn              Preview → experience brief → run init → agents
Step 8   Execution          State management → implement → test → merge → report
```

## Complexity Paths

| Level | Score | What happens |
|-------|-------|-------------|
| SIMPLE | 4-6 | Zero questions. Straight to team proposal → spawn → done |
| MEDIUM | 7-9 | One scope confirmation (IN/OUT/DEFER), then spawn |
| COMPLEX | 10+ | Structured interview → Wave plan → completion criteria → spawn |

## Team Composition

Hard cap: **5 agents**. Flexible composition adapted to the task.

| Model | Used for |
|-------|---------|
| Sonnet | Planning, complex coding, multi-file work |
| Haiku | Tests, linting, format checks, sub-agents |
| Codex xhigh | Debate + final review (read-only) |

3+ agents automatically use worktree isolation.

## Preview Mode

```
/spawn-team --preview "Add payment processing"
```

Shows plan + team + experience brief without creating agents or run directories. Options: proceed / adjust / cancel.

## Experience Brief

If `summary.yml` exists from past runs, spawn shows:
- Patterns with 3+ occurrences (scope drift, retry issues)
- Proven team configs for similar complexity
- Average duration and success rate

## Run Artifacts

Each run creates `.claude/runs/{YYYY-MM-DD-NNN}/`:

- **plan.yml** — team composition, ownership manifest, complexity
- **state.yml** — compressed current state (atomic writes, single-writer)
- **events.yml** — append-only audit log with sequential event IDs
- **report.yml** — per-run judgment (success_rate, retry_rate, violations)

## State Management

During execution, Leader manages state through three layers:

| Layer | Purpose | Guarantee |
|-------|---------|-----------|
| SendMessage | Real-time hints | Best-effort, can be lost |
| state.yml | Current decisions & status | Authoritative, atomic writes |
| events.yml | Audit trail | Immutable, append-only |

Agents read `state.yml` only. Never `events.yml` during execution.

## Lifecycle

```
Agent:  SPAWNED → WORKING → DONE → MERGED → CLEANED
Run:    ACTIVE → COMPLETED → ARCHIVED (7d)
```

Cleanup: worktree removed, tmux pane killed, state frozen.
Runs older than 7 days auto-archived to `.claude/runs/archive/`.
