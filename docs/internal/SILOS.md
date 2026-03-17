# Team Orchestrator v1.0 — Silo Implementation Spec

> Each Claude Code session implements independently.
> No file conflicts between sessions guaranteed.

## Pre-read order

1. `docs/internal/PRD.md` — What (features, requirements)
2. `docs/internal/TRD.md` — How (schemas, algorithms, protocols)
3. This file (SILOS.md) — Who/When/Which files

---

## Session Map

```
Wave 1 (parallel)
  Session A ─── Silo 1A: F1 Run Artifacts + State + Lifecycle
                         (spawn-team/SKILL.md)
  Session B ─── Silo 1B: F6 Doctor
                         (doctor/SKILL.md, new file)

Wave 2 (Wave 1 complete, sequential on SKILL.md)
  Session C ─── Silo 2A: F5 Pattern Detection (forge ingest)
              ── Silo 2B: F3 Experience Brief (after 2A)
              ── Silo 2C: F4 Preview Mode (after 2B)
                         (all in spawn-team/SKILL.md)

Wave 3 (Wave 2 complete, parallel)
  Session D ─── Silo 3A: Docs + README
  Session E ─── Silo 3B: F2-external benchmark (one-off)
```

### File ownership

```
spawn-team/SKILL.md  →  Session A (Wave 1) → Session C (Wave 2)
                         ONE writer at a time. Never concurrent.
doctor/SKILL.md      →  Session B only
docs/                →  Session D only
benchmarks/          →  Session E only
```

---

## Wave 1

### Silo 1A — F1: Run Artifacts + State + Lifecycle
**Session**: A
**Feature**: F1

#### Files
| Action | File |
|--------|------|
| **Modify** | `.claude/skills/spawn-team/SKILL.md` — §7 (Spawn) + §8 (Execution) + §8.5 (Completion) |
| **Forbidden** | All other files |

#### SKILL.md changes

**§7 (Spawn Team)** — add:
- Run directory creation: `.claude/runs/{YYYY-MM-DD-NNN}/`
- plan.yml writing (team, ownership_manifest, complexity, score)
- state.yml initialization (phase: PLANNING, state_version: 1)
- `latest` symlink update

**§8 (Execution)** — add:
- state.yml atomic write protocol (tmp + sync + mv)
- events.yml append on every event (with seq counter)
- Event types: agent_spawned, task_assigned, agent_done, decision_promoted, contract_published, scope_drift, blocked, unblocked, test_result
- Communication protocol: SendMessage = hint, state.yml = authority
- Agent reads state.yml only (never events.yml)

**§8.5 (Completion)** — add:
- report.yml writing (judgment: success_rate, retry_rate, violations, verdict)
- Lifecycle cleanup (worktree delete, tmux kill, state.yml freeze)
- Run archival (>7d → archive/)

#### Acceptance
```bash
# 1. plan.yml exists after spawn
test -f .claude/runs/$(date +%Y-%m-%d)-001/plan.yml

# 2. state.yml has required fields
grep -E "state_version|phase|agents" state.yml

# 3. events.yml has seq numbers
grep "seq:" events.yml

# 4. report.yml has judgment
grep "success_rate" report.yml

# 5. Atomic write (state.yml.tmp should NOT exist after write)
test ! -f state.yml.tmp
```

---

### Silo 1B — F6: Doctor
**Session**: B (parallel with A)
**Feature**: F6

#### Files
| Action | File |
|--------|------|
| **Create** | `.claude/skills/doctor/SKILL.md` (new) |
| **Forbidden** | All other files |

#### Content
- 8 environment checks (TRD §F6)
- Result output (✓/✗ + reason)
- Settings patch proposal → y/n → apply
- Backup before patch: `~/.claude/settings.json.bak`

#### Acceptance
```bash
# /doctor output includes check results
# ✓ Claude Code
# ✓ tmux
# ✓ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
```

---

## Wave 2

### Silo 2A — F5: Pattern Detection (via Forge)
**Session**: C (Wave 2, first)
**Prerequisite**: Wave 1 complete

#### Files
| Action | File |
|--------|------|
| **Modify** | `.claude/skills/spawn-team/SKILL.md` — §8.5 (Completion) enhancement |
| **Forbidden** | All other files |

#### SKILL.md changes

**§8.5 (Completion)** — add after report.yml:
- Call `forge ingest --auto` (via writeback.sh)
- Forge reads events.yml + report.yml from this run
- Forge extracts failures and updates Q-value EMA in forge.db
- Patterns emerge naturally from Forge learning

#### Acceptance
```bash
# writeback.sh calls forge ingest after run completion
grep "forge ingest" writeback.sh

# Forge database is updated
ls -l ~/.forge/forge.db
```

---

### Silo 2B — F3: Experience Brief
**Session**: C (after 2A)

#### SKILL.md changes

**§7 (Spawn Team)** — add before team proposal:
- Call `forge resume --team-brief`
- Include patterns and recommendations in spawn briefing to user
- Use for team composition recommendations

#### Acceptance
```bash
# When forge has patterns, spawn shows brief via `forge resume --team-brief`
# "Experience brief: ..."
# "Pattern: auth-be scope drift on database.ts (Q:0.7)"
```

---

### Silo 2C — F4: Preview Mode
**Session**: C (after 2B)

#### SKILL.md changes

**§7 (Spawn Team)** — add at entry:
- Detect `--preview` flag
- Run plan generation + experience brief
- Output preview (team, ownership, complexity, experience)
- Do NOT create run directory or spawn agents
- Ask user: proceed / adjust / cancel

#### Acceptance
```bash
# --preview shows plan without spawning
# No .claude/runs/ directory created
# No tmux sessions created
```

---

## Wave 3

### Silo 3A — Docs + README
**Session**: D (parallel)

#### Files
| Action | File |
|--------|------|
| **Modify** | `README.md`, `README.ko.md` |
| **Create** | `docs/getting-started.md` |
| **Create** | `docs/guide/spawn-team.md` |
| **Create** | `docs/guide/doctor.md` |
| **Forbidden** | `.claude/skills/`, `tests/`, `install.sh` |

---

### Silo 3B — F2-external Benchmark
**Session**: E (parallel, independent)

#### Files
| Action | File |
|--------|------|
| **Create** | `.claude/runs/benchmarks/` directory + results |
| **Create** | Benchmark script or skill (TBD) |
| **Forbidden** | `.claude/skills/spawn-team/`, docs/ |

#### Scope
- Select 3-5 public repos with reproducible issues
- Run each: single agent vs spawn-team
- Record: pass/fail, retries, wall_clock
- Generate comparison.yml

---

## Session Start Checklist

Before each session:
```bash
# 1. Current branch state
git status && git log --oneline -5

# 2. No changes outside my silo
git diff --name-only HEAD

# 3. Dependency silo complete (Wave 2+)
git log --oneline | grep "silo-1"
```

After each silo:
```bash
git add {silo-specific-files-only}
git commit -m "feat: silo {ID} — {feature name}"
```

---

## P1 / P2 Boundary

| Do NOT implement | Reason |
|-----------------|--------|
| GraphDB, Vector DB, embeddings | P2 scope |
| Cross-project pattern analysis | P2 scope (global) |
| Token tracking infrastructure | P2 scope (proxy needed) |
| Skill lifecycle management | P2 scope |
| Dashboard UI | P2 scope |
| New servers, daemons, background processes | Architecture violation |
| npm/pip package dependencies | Architecture violation |
| Pre-defined anti-pattern rules (AP001-AP008) | Replaced by bottom-up detection |
