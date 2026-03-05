---
name: hud
description: Configure the Claude Code status line (HUD) to show spawn-team status — active agents, task progress, context usage.
triggers:
  - "hud setup"
  - "configure hud"
  - "status line setup"
  - "statusline"
---

# HUD: spawn-team Status Bar

Display team status in the Claude Code bottom status bar.
Auto-refreshes approximately every 300ms.

**Displays:**
- Active team agent count + names
- TaskList progress (completed/total)
- Context usage
- Background task count
- Current project name

---

## Step 1: Install

### 1-1. Create HUD Script

```bash
mkdir -p ~/.claude/hud
```

Create `~/.claude/hud/team-hud.mjs`:

```javascript
#!/usr/bin/env node
import { readFileSync, existsSync, readdirSync } from 'fs';
import { join, basename } from 'path';
import { homedir } from 'os';

const CLAUDE_DIR = join(homedir(), '.claude');
const TASKS_DIR = join(CLAUDE_DIR, 'tasks');
const TEAMS_DIR = join(CLAUDE_DIR, 'teams');

function getTeamStatus() {
  if (!existsSync(TEAMS_DIR)) return null;
  const teams = readdirSync(TEAMS_DIR).filter(f => f.endsWith('.json'));
  if (teams.length === 0) return null;

  try {
    const teamFile = join(TEAMS_DIR, teams[0]);
    const team = JSON.parse(readFileSync(teamFile, 'utf8'));
    const teamName = team.name || teams[0].replace('.json', '');
    const members = team.members || [];
    return { name: teamName, memberCount: members.length, members };
  } catch { return null; }
}

function getTaskProgress(teamName) {
  if (!teamName) return null;
  const taskDir = join(TASKS_DIR, teamName);
  if (!existsSync(taskDir)) return null;

  try {
    const files = readdirSync(taskDir).filter(f => f.endsWith('.json'));
    let total = 0, completed = 0, inProgress = 0;
    for (const f of files) {
      const task = JSON.parse(readFileSync(join(taskDir, f), 'utf8'));
      total++;
      if (task.status === 'completed') completed++;
      else if (task.status === 'in_progress') inProgress++;
    }
    return { total, completed, inProgress };
  } catch { return null; }
}

function main() {
  const team = getTeamStatus();
  if (!team) {
    process.stdout.write('no active team');
    return;
  }

  const tasks = getTaskProgress(team.name);
  const parts = [`team:${team.name}`];

  if (tasks) {
    parts.push(`tasks:${tasks.completed}/${tasks.total}`);
    if (tasks.inProgress > 0) parts.push(`running:${tasks.inProgress}`);
  }

  parts.push(`agents:${team.memberCount}`);
  process.stdout.write(parts.join(' | '));
}

main();
```

### 1-2. Register statusline in settings.json

Add to `~/.claude/settings.json`:

```json
{
  "statusline": {
    "left": "node ~/.claude/hud/team-hud.mjs",
    "refreshIntervalMs": 300
  }
}
```

Merge into existing settings.json:
```bash
SETTINGS=~/.claude/settings.json
if [ -f "$SETTINGS" ]; then
  jq '.statusline = {"left": "node ~/.claude/hud/team-hud.mjs", "refreshIntervalMs": 300}' \
    "$SETTINGS" > /tmp/settings-new.json && mv /tmp/settings-new.json "$SETTINGS"
else
  echo '{"statusline": {"left": "node ~/.claude/hud/team-hud.mjs", "refreshIntervalMs": 300}}' > "$SETTINGS"
fi
```

---

## Step 2: Preset Selection

AskUserQuestion:
**"Which level of detail should the HUD display?"**
1. **Minimal** — `team:name | tasks:2/5`
2. **Focused (default)** — `team:name | tasks:2/5 | running:1 | agents:3`
3. **Full** — Focused + per-agent detailed status

---

## Step 3: Color Configuration (optional)

Status-based colors:
- Green: normal (tasks running)
- Yellow: warning (circuit breaker fired, errors)
- Red: critical (no team, 0 agents)

---

## Step 4: Confirmation

```
HUD setup complete.

Script: ~/.claude/hud/team-hud.mjs
Refresh interval: 300ms
Display: team | tasks | agents

Restart Claude Code to activate the status bar.
```

---

## Reference

Original omc HUD (more features):
- https://github.com/Yeachan-Heo/oh-my-claudecode/tree/main/skills/hud
- Additional info: Ralph loop state, PRD ID, background task count
- Install: omc --setup then /oh-my-claudecode:hud setup
