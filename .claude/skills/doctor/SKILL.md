---
name: doctor
description: Checks the environment for Claude Code Agent Teams prerequisites. Reports pass/fail for each check, proposes settings patches, and applies them after user confirmation.
triggers:
  - "doctor"
  - "/doctor"
  - "check environment"
  - "환경 확인"
  - "닥터"
allowed-tools: Bash(claude *), Bash(tmux *), Bash(which *), Bash(git *), Bash(jq *), Bash(codex *), Bash(test *), Bash(cp *), Bash(echo *), Bash(python3 *), Bash(curl *), Read, Edit, AskUserQuestion
---

## Purpose

Verify host environment for Claude Code Agent Teams. Output ✓/✗ report, offer to patch settings.json.

## Step 0: Read settings.json

Read `~/.claude/settings.json` via Read tool. Check jq: `which jq 2>/dev/null`. Fallback: python3 or grep.

## Step 1: Run All Checks (parallel)

| # | Check | Pass | Fail | Patchable |
|---|-------|------|------|-----------|
| 1 | `claude --version` | exits 0 | not found | No |
| 2 | `tmux -V` | exits 0 | not found | No |
| 3 | AGENT_TEAMS flag | env=1 or settings has it | missing | Yes: `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"` |
| 4 | TEAMMATE_COMMAND | path set + executable | missing/not exec | No (run install.sh) |
| 5 | teammateMode | ="tmux" | other | Yes: `teammateMode="tmux"` |
| 6 | `codex --version` | found | ⚠ only (optional) | No |
| 7 | `git --version` | exits 0 | not found | No |
| 8 | SUBAGENT_MODEL | ="haiku" | ⚠ if unset | Yes: `env.CLAUDE_CODE_SUBAGENT_MODEL="haiku"` |
| 9 | MiniMax config | config + key + API reachable | ⚠ only (optional) | No |

Checks 6, 8, 9 are never ✗ — ⚠ only.

## Step 2: Print Report

```
Claude Code Agent Teams — Environment Check
============================================
  ✓ Claude Code        {version}
  ✗ tmux               not found
  ...
Result: {N} pass, {N} fail, {N} warn
```

## Step 3: Patch (if patchable fails/warns)

1. Show proposed patch
2. AskUserQuestion: "Apply? (y/n)"
3. If yes: `cp ~/.claude/settings.json ~/.claude/settings.json.bak` → Read → Edit (merge keys, preserve existing)
4. If no: "No changes made."

Non-patchable guidance:
| Check | Fix |
|-------|-----|
| Claude Code | https://docs.anthropic.com/en/docs/claude-code |
| tmux | `sudo apt install tmux` / `brew install tmux` |
| TEAMMATE_COMMAND | Run `./install.sh` from project root |
| git | `sudo apt install git` / `brew install git` |

## Rules

- All checks before printing. Never modify settings without confirmation. Always backup first.
- Codex/subagent/MiniMax never ✗. Missing settings.json → offer to create as `{}`.
