# Team Orchestrator

[🇺🇸 English](README.md)

![Version](https://img.shields.io/badge/version-0.5.3-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-Agent_Teams-purple)
[![GitHub Release](https://img.shields.io/github/v/release/gksl5355/claude-agent-bootstrap)](https://github.com/gksl5355/claude-agent-bootstrap/releases)

**Claude Code Agent Teams를 프로젝트에 맞게 동적으로 구성하고, 완료까지 운영하는 오케스트레이터.**

```
/spawn-team
→ 도메인 3개 감지 (auth, products, orders)
→ 복잡도 MEDIUM 판정
→ 에이전트 4명 구성: auth-be, products-be, orders-be, unit-tester
→ 작업 지시 → 구현 → 테스트 → 버그 수정 → 재검증 → 머지
→ 끝.
```

## Quick Start

```bash
git clone https://github.com/gksl5355/claude-agent-bootstrap.git
cd claude-agent-bootstrap
./install.sh
```

그 다음 Claude Code에서:

```
/spawn-team
```

## Release

버전 태그를 푸시하면 GitHub Release가 자동 생성/업데이트됩니다:

```bash
git tag v0.5.4
git push origin v0.5.4
```

<details>
<summary>수동 설치 / 선택 설치</summary>

**전체 설치:**

```bash
mkdir -p ~/.claude/skills
for skill in spawn-team debate ralph; do
  ln -sf "$(pwd)/.claude/skills/$skill" ~/.claude/skills/$skill
done
```

**선택 설치** (spawn-team은 항상 권장):

```bash
mkdir -p ~/.claude/skills
ln -sf "$(pwd)/.claude/skills/spawn-team" ~/.claude/skills/spawn-team
ln -sf "$(pwd)/.claude/skills/debate" ~/.claude/skills/debate
```

| 스킬 | 독립 사용 | 의존성 |
|------|-----------|--------|
| `spawn-team` | O | 없음 (핵심) |
| `debate` | O | 없음 |
| `ralph` | X | spawn-team 필요 |

</details>

**요구사항:**

- **Claude Max** (Agent Teams 지원)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (`~/.claude/settings.json`)
- **tmux** (권장) — 모델 라우팅(Sonnet/Haiku)에는 `teammateMode: "tmux"` 필요
  - tmux 없이 실행하면: in-process 모드로 동작하고, `TEAMMATE_COMMAND`가 무시되어 Leader 모델로 실행됨
  - 설치: `sudo apt install tmux` (Ubuntu) / `brew install tmux` (macOS)
- Codex CLI (선택 — `/debate`, 최종 리뷰 시)

<details>
<summary>설정 예시</summary>

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

**제거:**

```bash
rm ~/.claude/skills/{spawn-team,debate,ralph}
rm ~/.claude/teammate.sh
```

---

## Why?

Claude Code Agent Teams는 강력하지만, 직접 구성하려면 결정할 게 많다 — 에이전트 수, 역할, 파일 소유권, 테스트 실패 시 대응, 복잡한 작업의 계획 수립...

**Team Orchestrator는 이 결정들을 자동화한다.** 프로젝트 구조를 읽고, 복잡도를 판단하고, 적절한 크기의 팀을 구성하고, 피드백 루프를 운영한다.

- **단순한 건 빠르게.** 질문 0개, 바로 실행.
- **중간 복잡도 → 범위 확인.** IN/OUT/DEFER 1회.
- **복잡한 건 철저하게.** 구조화 인터뷰 → Wave 분해 → 완료 기준.
- **실패는 단계적으로.** 재시도 → debugger → circuit breaker → 사람에게 에스컬레이션. 무한 루프 없음.
- **토큰은 비싸다.** 5명 상한. Haiku로 할 수 있는 건 Haiku로. Explore 먼저, 비싼 모델은 나중에.

---

## Features

### 자동 (설정 불필요)

| 기능 | 설명 |
|------|------|
| **도메인 감지** | 프로젝트 구조에서 도메인 자동 추출 (routes/, services/, pages/) |
| **구조 타입 판단** | [A] 도메인 디렉토리 / [B] 평면 구조 / [C] 레거시 자동 분류 |
| **복잡도 판단** | 도메인 수 + 파일 규모 + 의존성 + 구조 → SIMPLE/MEDIUM/COMPLEX 자동 점수 |
| **팀 동적 구성** | 복잡도에 따라 1~5명 에이전트 자동 결정, 모델 자동 라우팅 |
| **MECE 소유권** | 각 파일은 정확히 1개 에이전트에 귀속. 경계 위반 시 자동 revert |
| **피드백 루프** | 구현→테스트→수정→재검증 자동 반복 |
| **Circuit Breaker** | 2회 실패 → debugger → 그래도 실패 → 사용자 에스컬레이션 |
| **Worktree 머지** | 에이전트별 isolated worktree + 순차 머지 + 경계 위반 체크 |

### 옵트인

| 기능 | 트리거 | 설명 |
|------|--------|------|
| **계획 수립** | COMPLEX 자동 or "계획해줘" | 구조화 인터뷰 → Wave 분해 → 완료 기준 |
| **범위 잠금** | MEDIUM+ 자동 | IN/OUT/DEFER 확인, 실행 중 변경 경고 |
| **Debate** | `/debate` or 위험도 6+ | Codex xhigh 적대적 아키텍처 검토 (2라운드 상한) |
| **Codex 리뷰** | 머지 후 | xhigh read-only 교차 검토 |
| **Ralph** | `/ralph` | PRD 기반 완료 보장 — 모든 스토리 PASS까지 |

---

## How It Works

### 전체 플로우

```
Step 0   초기화         Tool preload + 정리 + 스택/규모 자동 감지.
Step 1   프로젝트 분석    기술 스택 + 도메인 감지 + 구조 타입 [A/B/C]
Step 2   복잡도 판단     자동 점수 → SIMPLE / MEDIUM / COMPLEX
Step 3   범위 확인       IN/OUT/DEFER 사용자 확인 (MEDIUM+ only)
Step 4   계획 수립       인터뷰 + Wave 분해 + 완료 기준 (COMPLEX만)
Step 5   팀 구성 제안     에이전트 수 + 모델 + 워크트리 모드
Step 6   사용자 확인     팀 + 계획 최종 승인
Step 7   팀 스폰        에이전트 생성 + MECE 프롬프트
Step 8   실행 루프       구현 → 테스트 → 피드백 → 머지 → Codex 리뷰
```

### 복잡도별 경로

| 복잡도 | 점수 | 경로 | 소요 |
|--------|------|------|------|
| SIMPLE | 4–6 | 0→1→2→5→6→7→8 | ~1분 |
| MEDIUM | 7–9 | + Step 3 (범위 확인) | ~3분 |
| COMPLEX | 10+ | + Step 3 + 4 (계획 수립) | ~10분 |

### 모델 라우팅

| 역할 | 모델 | 이유 |
|------|------|------|
| 팀 에이전트 전체 (fullstack, BE/FE, planner, architect) | **Sonnet** | 비용 효율 + 충분한 추론 |
| 테스트, 디버그, 빌드 수정 (서브에이전트) | Haiku | 경량, 자기 스폰 |
| 최종 리뷰, 설계 비판 | Codex xhigh | 독립적 관점 |

> **작동 방식:** `./install.sh`이 `teammate.sh`를 설치하고 `CLAUDE_CODE_TEAMMATE_COMMAND`를 settings.json에 설정한다. tmux 모드에서 Claude Code가 teammate를 스폰하면 `teammate.sh`가 호출되어 기본 `--model` 플래그를 Sonnet(기본) 또는 Haiku(signal file)로 교체한다. 바이너리 수정 없음.

### 에이전트 구성

```
소규모 (1~2명):  fullstack(sonnet) + unit-tester(haiku)
중규모 (3~4명):  도메인 be/fe(sonnet) × N + unit-tester(haiku)
대규모 (5명):    planner(sonnet) + 도메인(sonnet) × 2 + unit-tester + scenario-tester(haiku)
```

---

## Skills

| 스킬 | 트리거 | 역할 |
|------|--------|------|
| [`/spawn-team`](.claude/skills/spawn-team/SKILL.md) | "팀 구성", "spawn team" | 핵심 오케스트레이터 |
| [`/debate`](.claude/skills/debate/SKILL.md) | "debate", "아키텍처 토론" | Codex xhigh 적대적 검토 |
| [`/ralph`](.claude/skills/ralph/SKILL.md) | "끝날 때까지", "ralph" | PRD 완료 보장 |

---

## Troubleshooting

| 문제 | 해결 |
|------|------|
| "Skill not found: spawn-team" | `ls -la ~/.claude/skills/spawn-team` 확인. 없으면 `./install.sh` 재실행 |
| Permission denied | `~/.claude/settings.json`에 `"Skill(spawn-team)"` 허용 추가 |
| Agent Teams 안 됨 | Claude Max 확인 + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 설정 |
| 에이전트가 Opus/Leader 모델로 뜸 | `teammateMode: "tmux"` 확인 + tmux 안에서 실행. `cat /tmp/claude-teammate.log`로 모델 확인 |
| teammate.sh 미호출 | settings.json의 `CLAUDE_CODE_TEAMMATE_COMMAND`가 `~/.claude/teammate.sh`를 가리키는지 확인 |
| 설정 변경 후 모델 라우팅 안 됨 | settings.json은 세션 시작 시 고정됨. Claude Code 재시작 필요 |
| Codex exec 실패 | 자동 스킵됨. 설치: `npm install -g @openai/codex` |
| 에이전트 idle 상태 | 정상. 메시지 받을 때만 쿼터 소모. 비용 없음. |

---

## Acknowledgments

이 프로젝트는 다음 프로젝트들의 아이디어와 패턴에서 영감을 받았습니다:

| Project | Adopted | Their Strength |
|---------|---------|----------------|
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) by @Yeachan-Heo | Magic Keyword 의도 탐지, ralph 지속 루프 | 의도 탐지 & 자연어 인터페이스 |
| [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) by @code-yeongyu | Planning Triad (Metis→Prometheus→Momus), Wave 분해, 4-criteria 검증 | 계획 분해 & 검증 |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic | Agent Teams API, Plan Mode, worktree isolation | 기반 플랫폼 |
| [Codex CLI](https://github.com/openai/codex) by OpenAI | ExecPlan 패턴, Decision Log, xhigh reasoning | 독립 리뷰 & 분석 |
| [OpenCode](https://github.com/opencode-ai/opencode) | swarm_decompose, agent role specialization | 에이전트 역할 분리 |

---

## License

MIT
