# Configuration Guide

Team Orchestrator 설치 후 설정 옵션.

---

## 필수 설정

### `~/.claude/settings.json`

```jsonc
{
  "env": {
    // Agent Teams 활성화 (필수)
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    // tmux 기반 에이전트 모드 (필수)
    "teammateMode": "tmux"
  },
  "permissions": {
    "allow": [
      // 핵심 스킬 (필수)
      "Skill(spawn-team)",
      "Skill(debate)"
    ]
  }
}
```

---

## 선택 설정

### 전체 스킬 활성화

```jsonc
{
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)",
      "Skill(ralph)",
      "Skill(hud)",
      "Skill(configure-notifications)"
    ]
  }
}
```

### Codex CLI

Debate Mode와 최종 리뷰에 사용. 없어도 자동 스킵됨.

```bash
npm install -g @openai/codex
```

### HUD (상태 표시줄)

```bash
/hud
# → ~/.claude/hud/team-hud.mjs 생성 + settings.json statusline 설정
```

### 알림 (Telegram/Discord/Slack)

```bash
/configure-notifications
# → 플랫폼 선택 + 토큰/웹훅 설정
```

---

## 프로젝트별 오버라이드

프로젝트 루트의 `.claude/settings.json`에서 전역 설정을 오버라이드할 수 있다.

```jsonc
// your-project/.claude/settings.json
{
  "permissions": {
    "allow": [
      "Skill(spawn-team)"
      // 이 프로젝트에서는 debate 비활성화
    ]
  }
}
```

---

## 환경 변수

| 변수 | 필수 | 설명 |
|------|------|------|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Yes | "1"로 설정. Agent Teams 기능 활성화. |
| `teammateMode` | Yes | "tmux". 에이전트 실행 모드. |

---

## 디렉토리 구조

설치 후 `~/.claude/` 구조:

```
~/.claude/
├── skills/
│   ├── spawn-team → {repo}/.claude/skills/spawn-team  (symlink)
│   ├── debate     → {repo}/.claude/skills/debate      (symlink)
│   ├── ralph      → {repo}/.claude/skills/ralph       (symlink)
│   ├── hud        → {repo}/.claude/skills/hud         (symlink)
│   └── configure-notifications → ...                   (symlink)
├── settings.json   (사용자 설정)
├── teams/          (런타임 - 활성 팀 정보)
├── tasks/          (런타임 - 태스크 목록)
└── hud/            (HUD 설정 시 생성)
    └── team-hud.mjs
```
