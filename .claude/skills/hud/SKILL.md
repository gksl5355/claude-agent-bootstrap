---
name: hud
description: Configure the Claude Code status line (HUD) to show spawn-team status — active agents, task progress, context usage.
triggers:
  - "hud setup"
  - "configure hud"
  - "status line setup"
  - "statusline"
---

# HUD: spawn-team 상태 표시줄

Claude Code 하단 상태 표시줄에 팀 상태를 표시한다.
약 300ms마다 자동 업데이트.

**표시 정보:**
- 활성 팀 에이전트 수 + 이름
- TaskList 진행률 (완료/전체)
- 컨텍스트 사용률
- 백그라운드 작업 수
- 현재 프로젝트명

---

## Step 1: 설치

### 1-1. HUD 스크립트 생성

```bash
mkdir -p ~/.claude/hud
```

`~/.claude/hud/team-hud.mjs` 생성:

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

### 1-2. settings.json에 statusline 등록

`~/.claude/settings.json`에 추가:

```json
{
  "statusline": {
    "left": "node ~/.claude/hud/team-hud.mjs",
    "refreshIntervalMs": 300
  }
}
```

기존 settings.json이 있으면 merge:
```bash
# 기존 설정 읽기 후 statusline 필드 추가
SETTINGS=~/.claude/settings.json
if [ -f "$SETTINGS" ]; then
  jq '.statusline = {"left": "node ~/.claude/hud/team-hud.mjs", "refreshIntervalMs": 300}' \
    "$SETTINGS" > /tmp/settings-new.json && mv /tmp/settings-new.json "$SETTINGS"
else
  echo '{"statusline": {"left": "node ~/.claude/hud/team-hud.mjs", "refreshIntervalMs": 300}}' > "$SETTINGS"
fi
```

---

## Step 2: 프리셋 선택

AskUserQuestion:
**"어떤 정보를 표시할까요?"**
1. **Minimal** — `team:name | tasks:2/5`
2. **Focused (기본값)** — `team:name | tasks:2/5 | running:1 | agents:3`
3. **Full** — Focused + 에이전트별 상세 상태

---

## Step 3: 색상 설정 (선택)

상태에 따른 색상:
- Green: 정상 (tasks running)
- Yellow: 경고 (circuit breaker 발동, 에러)
- Red: 위험 (팀 없음, 에이전트 0명)

---

## Step 4: 확인

```
HUD 설정 완료.

스크립트: ~/.claude/hud/team-hud.mjs
갱신 주기: 300ms
표시: team | tasks | agents

Claude Code를 재시작하면 상태 표시줄이 활성화됩니다.
```

---

## 참고

오리지널 omc HUD (더 많은 기능):
- https://github.com/Yeachan-Heo/oh-my-claudecode/tree/main/skills/hud
- Ralph 루프 상태, PRD ID, 백그라운드 작업 수 등 추가 정보 표시
- 설치: omc --setup 후 /oh-my-claudecode:hud setup
