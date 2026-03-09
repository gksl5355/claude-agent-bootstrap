# /doctor Guide

## Overview

`/doctor` validates your environment for Claude Code Agent Teams and offers to patch settings automatically.

## Usage

```
/doctor
```

## Checks

| # | Check | Required |
|---|-------|----------|
| 1 | Claude Code version | Yes |
| 2 | tmux installed | Yes (for model routing) |
| 3 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | Yes |
| 4 | `CLAUDE_CODE_TEAMMATE_COMMAND` points to executable | Yes |
| 5 | `teammateMode: "tmux"` in settings.json | Yes |
| 6 | Codex CLI | Optional |
| 7 | git available | Yes (for worktree) |
| 8 | `CLAUDE_CODE_SUBAGENT_MODEL` set | Optional |

## Output

```
=== Team Orchestrator Health Check ===
  ✓ Claude Code 2.1.71
  ✓ tmux 3.3a
  ✓ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
  ✓ CLAUDE_CODE_TEAMMATE_COMMAND=/home/user/.claude/teammate.sh
  ✓ teammateMode=tmux
  ✗ Codex CLI not found (optional)
  ✓ git 2.43.0
  ✓ CLAUDE_CODE_SUBAGENT_MODEL=haiku
```

## Settings Patch

If required settings are missing, `/doctor` proposes a patch:

```
Settings patch needed:
  + CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"
  + teammateMode: "tmux"

Apply? [y/n]
```

On confirm:
1. Backs up `~/.claude/settings.json` to `~/.claude/settings.json.bak`
2. Merges required keys
3. Writes updated settings

## When to Run

- After initial `./install.sh`
- After Claude Code updates
- When Agent Teams aren't working as expected
- Before first `/spawn-team` on a new machine
