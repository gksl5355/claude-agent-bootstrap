# Configuration Guide

Settings available after installing Team Orchestrator.

---

## Required Settings

### `~/.claude/settings.json`

```jsonc
{
  "teammateMode": "tmux",
  "env": {
    // Enable Agent Teams (required)
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    // Model routing script installed by install.sh (required for Haiku routing)
    "CLAUDE_CODE_TEAMMATE_COMMAND": "/home/you/.claude/teammate.sh"
  },
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)"
    ]
  }
}
```

> **Note:** `teammateMode` must be at the top level, not inside `env`.

---

## Optional Settings

### All skills

```jsonc
{
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)",
      "Skill(ralph)",
      "Skill(doctor)"
    ]
  }
}
```

### Haiku sub-agents

```jsonc
{
  "env": {
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  }
}
```

Reduces cost for sub-agents (debugger, build-fixer). Without this, sub-agents use the Leader's model.

### Codex CLI

Used for Debate Mode and final review. Auto-skipped if not installed.

```bash
npm install -g @openai/codex
```

---

## Per-project Override

Override global settings in `.claude/settings.json` at the project root:

```jsonc
// your-project/.claude/settings.json
{
  "permissions": {
    "allow": [
      "Skill(spawn-team)"
      // debate disabled for this project
    ]
  }
}
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Yes | Set to `"1"`. Enables Agent Teams. |
| `CLAUDE_CODE_TEAMMATE_COMMAND` | Yes (for model routing) | Path to `teammate.sh`. Installed by `install.sh`. |
| `CLAUDE_CODE_SUBAGENT_MODEL` | No | Set to `"haiku"` to use Haiku for sub-agents. |

---

## Directory Structure

After installation, `~/.claude/` layout:

```
~/.claude/
├── skills/
│   ├── spawn-team → {repo}/.claude/skills/spawn-team  (symlink)
│   ├── debate     → {repo}/.claude/skills/debate      (symlink)
│   └── ralph      → {repo}/.claude/skills/ralph       (symlink)
├── teammate.sh     (model routing script)
├── settings.json   (user settings)
├── teams/          (runtime — active team info)
└── tasks/          (runtime — task lists)
```
