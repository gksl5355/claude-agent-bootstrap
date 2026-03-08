# Getting Started

## Prerequisites

- **Claude Max** or **Team** plan (Agent Teams support required)
- **tmux** for model routing (Sonnet/Haiku per agent)
- **git** for worktree isolation

Verify with:
```
/doctor
```

## Installation

```bash
git clone https://github.com/gksl5355/claude-agent-bootstrap.git
cd claude-agent-bootstrap
./install.sh
```

`install.sh` does:
1. Symlinks skills (`spawn-team`, `debate`, `ralph`, `doctor`) to `~/.claude/skills/`
2. Installs `teammate.sh` to `~/.claude/`
3. Patches `~/.claude/settings.json` with required env vars

## First Run

```
/spawn-team
```

That's it. The orchestrator will:
1. Scan your project (stack, domains, structure)
2. Score complexity (SIMPLE / MEDIUM / COMPLEX)
3. Propose a team composition
4. Ask for confirmation
5. Spawn agents and run until done

## Preview Before Spending

```
/spawn-team --preview "Add JWT auth"
```

Shows the plan, team composition, and experience brief (if past runs exist) without spawning any agents.

## Run Artifacts

Every run produces files in `.claude/runs/{YYYY-MM-DD-NNN}/`:

| File | Purpose | Written |
|------|---------|---------|
| `plan.yml` | Team, ownership, complexity | Once at spawn |
| `state.yml` | Compressed current state | Atomically updated throughout |
| `events.yml` | Full event log (append-only) | Every state change |
| `report.yml` | Success rate, retries, verdict | At completion |

After multiple runs, `summary.yml` aggregates patterns:
- Recurring scope drift → auto-warned on next spawn
- Proven team configs → recommended
- Average stats (duration, success rate)

## Next Steps

- [Spawn Team Guide](guide/spawn-team.md) — detailed workflow
- [Doctor Guide](guide/doctor.md) — environment checks
