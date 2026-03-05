# Team Orchestrator

[🇰🇷 한국어](README.ko.md)

![Version](https://img.shields.io/badge/version-0.5.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-Agent_Teams-purple)
[![GitHub Release](https://img.shields.io/github/v/release/gksl5355/claude-agent-bootstrap)](https://github.com/gksl5355/claude-agent-bootstrap/releases)

**Dynamically compose and operate Claude Code Agent Teams tailored to your project — from analysis to merge.**

```
/spawn-team
→ Detected 3 domains (auth, products, orders)
→ Complexity: MEDIUM
→ Spawned 4 agents: auth-be, products-be, orders-be, unit-tester
→ Implement → Test → Fix → Retest → Merge
→ Done.
```

## Quick Start

```bash
git clone https://github.com/gksl5355/claude-agent-bootstrap.git
cd claude-agent-bootstrap
./install.sh
```

Then **start Claude Code inside tmux** (required for model routing):

```bash
tmux new-session -s dev
claude
```

Then in Claude Code:

```
/spawn-team
```

<details>
<summary>Manual install / selective install</summary>

**All skills:**

```bash
mkdir -p ~/.claude/skills
for skill in spawn-team debate ralph hud configure-notifications; do
  ln -sf "$(pwd)/.claude/skills/$skill" ~/.claude/skills/$skill
done
```

**Selective** (spawn-team is always recommended):

```bash
mkdir -p ~/.claude/skills
ln -sf "$(pwd)/.claude/skills/spawn-team" ~/.claude/skills/spawn-team
ln -sf "$(pwd)/.claude/skills/debate" ~/.claude/skills/debate
```

| Skill | Standalone | Dependency |
|-------|-----------|------------|
| `spawn-team` | Yes | None (core) |
| `debate` | Yes | None |
| `ralph` | No | spawn-team required |
| `hud` | Yes | None |
| `configure-notifications` | Yes | None |

</details>

**Requirements:**

- **Claude Max** (Agent Teams support)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json`
- **tmux** — team agents must run inside a tmux session for model routing to work
  - Anthropic's own documentation recommends tmux as the preferred entry point for agent teams (split-pane mode)
  - Without tmux: agents run in-process and the model wrapper is bypassed — all agents default to Opus
  - Install: `sudo apt install tmux` (Ubuntu) / `brew install tmux` (macOS)
- Codex CLI (optional — for `/debate` and final review)

<details>
<summary>Settings example</summary>

`~/.claude/settings.json`:

```jsonc
{
  "teammateMode": "tmux",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)"
    ]
  },
  "model": "sonnet"
}
```

</details>

**Uninstall:**

```bash
rm ~/.claude/skills/{spawn-team,debate,ralph,hud,configure-notifications}
```

---

## Why?

Claude Code Agent Teams are powerful, but manual setup requires many decisions — agent count, roles, file ownership, failure handling, when to plan vs. just code.

**Team Orchestrator automates all of this.** It reads your project, scores complexity, composes the right-sized team, and runs a feedback loop until done.

- **Simple → fast.** Zero questions, straight to execution.
- **Medium → scoped.** One round of scope confirmation (IN/OUT/DEFER).
- **Complex → planned.** Structured interview → Wave decomposition → completion criteria.
- **Failures → escalated.** Retry → debugger → circuit breaker → human. No infinite loops.
- **Tokens → respected.** 5-agent cap. Haiku where possible. Explore before expensive models.

---

## Features

### Automatic (zero config)

| Feature | Description |
|---------|-------------|
| **Domain detection** | Extracts domains from project structure (routes/, services/, pages/) |
| **Structure classification** | [A] Domain dirs / [B] Flat / [C] Legacy — auto-detected |
| **Complexity scoring** | Domains + file scale + dependencies + structure → SIMPLE / MEDIUM / COMPLEX |
| **Dynamic team composition** | 1–5 agents auto-determined with model routing |
| **MECE ownership** | Each file belongs to exactly one agent. Boundary violations auto-reverted |
| **Feedback loop** | Implement → Test → Fix → Retest — automatic |
| **Circuit breaker** | 2 failures → debugger → still failing → user escalation |
| **Worktree merge** | Per-agent isolated worktree + sequential merge + boundary check |

### Opt-in

| Feature | Trigger | Description |
|---------|---------|-------------|
| **Planning** | COMPLEX auto or "plan this" | Structured interview → Wave decomposition → completion criteria |
| **Scope lock** | MEDIUM+ auto | IN/OUT/DEFER confirmed, warnings on scope creep |
| **Debate** | `/debate` or risk 6+ | Codex xhigh adversarial architecture review (2 rounds max) |
| **Codex review** | Post-merge | xhigh read-only cross-review |
| **Ralph** | `/ralph` | PRD-driven completion — doesn't stop until all stories pass |
| **HUD** | `/hud` | Real-time team progress in status bar |
| **Notifications** | `/configure-notifications` | Telegram / Discord / Slack alerts |

---

## How It Works

### Flow

```
Step 0   Intent classification     Clarify if ambiguous (1-2 questions). Usually auto-pass.
Step 1   Project analysis          Tech stack + domain detection + structure type [A/B/C]
Step 2   Team proposal             Agent count + model + worktree mode
Step 2B  Complexity scoring        Auto-score → SIMPLE / MEDIUM / COMPLEX
Step 2.5 Scope confirmation        IN/OUT/DEFER user check (MEDIUM+)
Step 3   Planning                  Interview + Wave decomposition + criteria (COMPLEX only)
Step 4   User approval             Final sign-off on team + plan
Step 5   Spawn                     Create agents + MECE prompts
Step 6   Standby                   "Ready"
Step 7   Execution loop            Implement → Test → Feedback → Merge → Codex review
```

### Complexity Paths

| Complexity | Score | Path | Approx. |
|------------|-------|------|---------|
| SIMPLE | 4–6 | 0→1→2→2B→4→5→6→7 | ~1 min |
| MEDIUM | 7–9 | + Step 2.5 (scope) | ~3 min |
| COMPLEX | 10+ | + Step 2.5 + 3 (planning) | ~10 min |

### Model Routing

| Role | Model | Rationale |
|------|-------|-----------|
| All team agents (fullstack, BE/FE, planner, architect) | **Sonnet** | Cost-efficient, sufficient reasoning |
| Tests, debug, build fixes (sub-agents) | Haiku | Lightweight, self-spawned |
| Final review, design critique | Codex xhigh | Independent perspective |

### Team Shapes

```
Small  (1–2):  fullstack(sonnet) + unit-tester(haiku)
Medium (3–4):  domain be/fe(sonnet) × N + unit-tester(haiku)
Large  (5):    planner(sonnet) + domain(sonnet) × 2 + unit-tester + scenario-tester(haiku)
```

---

## Skills

| Skill | Trigger | Role |
|-------|---------|------|
| [`/spawn-team`](.claude/skills/spawn-team/SKILL.md) | "set up a team", "spawn team" | Core orchestrator — analyze → plan → compose → execute |
| [`/debate`](.claude/skills/debate/SKILL.md) | "debate", "architecture review" | Codex xhigh adversarial review (standalone or within spawn-team) |
| [`/ralph`](.claude/skills/ralph/SKILL.md) | "don't stop", "ralph" | PRD-driven completion loop |
| [`/hud`](.claude/skills/hud/SKILL.md) | "hud setup" | Claude Code status bar |
| [`/configure-notifications`](.claude/skills/configure-notifications/SKILL.md) | "configure notifications" | Telegram / Discord / Slack |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Skill not found: spawn-team" | Check `ls -la ~/.claude/skills/spawn-team`. If missing, re-run `./install.sh` |
| Permission denied | Add `"Skill(spawn-team)"` to `~/.claude/settings.json` permissions |
| Agent Teams not working | Verify Claude Max + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| Agents running as Opus | You must run Claude Code inside tmux. `tmux new-session -s dev && claude` |
| Model wrapper not intercepting | Check `cat /tmp/claude-wrapper.log` — should show args with model swap |
| Codex exec failure | Auto-skipped. Install: `npm install -g @openai/codex` |
| Agent idle | Normal. Only consumes quota on message receipt. Zero cost while idle. |

---

## Acknowledgments

Built on ideas and patterns from these projects:

| Project | Adopted | Their Strength |
|---------|---------|----------------|
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) by @Yeachan-Heo | Magic Keyword intent detection, ralph/HUD/notification originals | Intent detection & natural language interface |
| [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) by @code-yeongyu | Planning Triad (Metis→Prometheus→Momus), Wave decomposition, 4-criteria verification | Plan decomposition & verification |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic | Agent Teams API, Plan Mode, worktree isolation | Foundation platform |
| [Codex CLI](https://github.com/openai/codex) by OpenAI | ExecPlan pattern, Decision Log, xhigh reasoning | Independent review & analysis |
| [OpenCode](https://github.com/opencode-ai/opencode) | swarm_decompose, agent role specialization | Agent role separation |

---

## License

MIT
