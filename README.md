# Team Orchestrator

[🇰🇷 한국어](README.ko.md)

![Version](https://img.shields.io/badge/version-0.5.3-blue)
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

Then in Claude Code:

```
/spawn-team
```

<details>
<summary>Manual install / selective install</summary>

**All skills:**

```bash
mkdir -p ~/.claude/skills
for skill in spawn-team debate ralph; do
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

</details>

**Requirements:**

- **Claude Max** (Agent Teams support)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json`
- **tmux** (recommended) — model routing (Sonnet/Haiku) requires `teammateMode: "tmux"`
  - Without tmux: agents run in-process, `TEAMMATE_COMMAND` is ignored, all agents use the Leader's model
  - Install: `sudo apt install tmux` (Ubuntu) / `brew install tmux` (macOS)
- Codex CLI (optional — for `/debate` and final review)

<details>
<summary>Settings example</summary>

`~/.claude/settings.json`:

```jsonc
{
  "teammateMode": "tmux",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_TEAMMATE_COMMAND": "/home/you/.claude/teammate.sh",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  },
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)"
    ]
  }
}
```

</details>

**Uninstall:**

```bash
rm ~/.claude/skills/{spawn-team,debate,ralph}
rm ~/.claude/teammate.sh
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

---

## How It Works

### Flow

```
Step 0   Init                      Tool preload + cleanup + auto-detect stack/scale.
Step 1   Project analysis          Tech stack + domain detection + structure type [A/B/C]
Step 2   Complexity scoring        Auto-score → SIMPLE / MEDIUM / COMPLEX
Step 3   Scope confirmation        IN/OUT/DEFER user check (MEDIUM+ only)
Step 4   Planning                  Interview + Wave decomposition + criteria (COMPLEX only)
Step 5   Team composition          Agent count + model + worktree mode
Step 6   User confirmation         Final sign-off on team + plan
Step 7   Spawn                     Create agents + MECE prompts
Step 8   Execution loop            Implement → Test → Feedback → Merge → Codex review
```

### Complexity Paths

| Complexity | Score | Path | Approx. |
|------------|-------|------|---------|
| SIMPLE | 4–6 | 0→1→2→5→6→7→8 | ~1 min |
| MEDIUM | 7–9 | + Step 3 (scope) | ~3 min |
| COMPLEX | 10+ | + Step 3 + 4 (planning) | ~10 min |

### Model Routing

| Role | Model | Rationale |
|------|-------|-----------|
| All team agents (fullstack, BE/FE, planner, architect) | **Sonnet** | Cost-efficient, sufficient reasoning |
| Tests, debug, build fixes (sub-agents) | Haiku | Lightweight, self-spawned |
| Final review, design critique | Codex xhigh | Independent perspective |

> **How this works:** `./install.sh` installs `teammate.sh` and sets `CLAUDE_CODE_TEAMMATE_COMMAND` in settings.json. When Claude Code spawns a teammate in tmux mode, it calls `teammate.sh` which strips the default `--model` flag and substitutes Sonnet (default) or Haiku (via signal file). No binary modification needed.

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

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Skill not found: spawn-team" | Check `ls -la ~/.claude/skills/spawn-team`. If missing, re-run `./install.sh` |
| Permission denied | Add `"Skill(spawn-team)"` to `~/.claude/settings.json` permissions |
| Agent Teams not working | Verify Claude Max + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| Agents running as Opus/Leader model | Ensure `teammateMode: "tmux"` and run inside tmux. Check `cat /tmp/claude-teammate.log` for model entries |
| teammate.sh not called | Verify `CLAUDE_CODE_TEAMMATE_COMMAND` in settings.json points to `~/.claude/teammate.sh` |
| Model routing not working after settings change | Settings are locked at session start. Restart Claude Code for changes to take effect |
| Codex exec failure | Auto-skipped. Install: `npm install -g @openai/codex` |
| Agent idle | Normal. Only consumes quota on message receipt. Zero cost while idle. |

---

## Acknowledgments

Built on ideas and patterns from these projects:

| Project | Adopted | Their Strength |
|---------|---------|----------------|
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) by @Yeachan-Heo | Magic Keyword intent detection, ralph persistence loop | Intent detection & natural language interface |
| [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) by @code-yeongyu | Planning Triad (Metis→Prometheus→Momus), Wave decomposition, 4-criteria verification | Plan decomposition & verification |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic | Agent Teams API, Plan Mode, worktree isolation | Foundation platform |
| [Codex CLI](https://github.com/openai/codex) by OpenAI | ExecPlan pattern, Decision Log, xhigh reasoning | Independent review & analysis |
| [OpenCode](https://github.com/opencode-ai/opencode) | swarm_decompose, agent role specialization | Agent role separation |

---

## License

MIT
