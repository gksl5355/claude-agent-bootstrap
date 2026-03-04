# Team Orchestrator

![Version](https://img.shields.io/badge/version-0.4.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-Agent_Teams-purple)

**Claude Code Agent Teams를 프로젝트에 맞게 동적으로 구성하고, 완료까지 운영하는 오케스트레이터.**

> **v0.4.0** — 컨텍스트 overflow 방어: 에이전트 파일 한도 + Wave 요약 + Leader 읽기 예산 | [Releases](https://github.com/gksl5355/claude-agent-bootstrap/releases)

`/spawn-team` 한 마디면 프로젝트를 분석하고, 도메인을 감지하고, 에이전트를 구성하고, 구현-테스트-머지까지 피드백 루프를 돌린다.

```
/spawn-team
→ 도메인 3개 감지 (auth, products, orders)
→ 복잡도 MEDIUM 판정
→ 에이전트 4명 구성: auth-be, products-be, orders-be, unit-tester
→ 작업 지시 → 구현 → 테스트 → 버그 수정 → 재검증 → 머지
→ 끝.
```

---

## Why?

Claude Code Agent Teams는 강력하지만, 직접 구성하려면 결정할 게 많다:
- 에이전트 몇 명? 누가 뭘 담당?
- 파일 소유권은? 충돌은?
- 테스트 실패하면? 계속할까 멈출까?
- 복잡한 작업인데 계획 없이 바로 코딩해도 될까?

**Team Orchestrator는 이 결정들을 자동화한다.** 프로젝트 구조를 읽고, 복잡도를 판단하고, 적절한 크기의 팀을 구성하고, 피드백 루프를 운영한다. 단순한 작업은 빠르게, 복잡한 작업은 계획부터.

---

## 영감 & 참고

이 프로젝트는 다섯 가지 도구의 전략을 연구하고 각각의 강점을 선택적으로 통합했다:

| 도구 | 가져온 것 | 원본 강점 |
|------|-----------|-----------|
| [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) | Planning Triad 구조 (Metis→Prometheus→Momus), Wave 기반 분해, 4-criteria 검증 | 계획 분해 & 검증 최강 |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | Magic Keyword 기반 의도 탐지, 복잡도 기반 에이전트 스케일링, ralph/HUD/Notification 원본 | 의도 탐지 & 자연어 인터페이스 최강 |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Agent Teams API, Plan Mode, worktree isolation | 기반 플랫폼 |
| [Codex CLI](https://github.com/openai/codex) | ExecPlan 패턴, Decision Log, xhigh reasoning | 독립 리뷰 & 분석 |
| [OpenCode](https://github.com/opencode-ai/opencode) | swarm_decompose, agent role specialization | 에이전트 역할 분리 |

**핵심 결합**: oh-my-opencode의 계획 분해 + oh-my-claudecode의 의도 탐지 = 하이브리드 Planning.

---

## 방향 & 철학

### 1. 단순한 건 빠르게, 복잡한 건 철저하게

모든 작업에 15개 질문을 던지지 않는다. 복잡도를 자동 판단하고:
- **SIMPLE** → 질문 0개, 바로 팀 스폰
- **MEDIUM** → 범위(IN/OUT) 확인 1회
- **COMPLEX** → 구조화 인터뷰 + Wave 분해 + 완료 기준

### 2. 계획은 가이드, 족쇄가 아니다

COMPLEX 작업에서도 계획은 팀의 방향을 잡아주는 것이지, 줄줄이 따라야 하는 체크리스트가 아니다. 에이전트는 의존성만 지키면 Wave 순서를 조정할 수 있다.

### 3. 경계는 엄격하게, 소통은 자유롭게

각 에이전트는 자기 파일만 수정한다 (MECE 소유권). 하지만 기술 협의는 에이전트끼리 직접 한다. Leader는 결정권만 갖고, 병목이 되지 않는다.

### 4. 실패에 단계적으로 대응

```
테스트 실패 → 에이전트 재시도 (2회)
  → debugger 온디맨드 분석
    → circuit breaker → 사용자 에스컬레이션
```
무한 루프 없이, 단계적으로 대응하다가 안 되면 사람에게 넘긴다.

### 5. 토큰은 비싸다

에이전트 1명 ≈ 7× 쿼터. 그래서 5명 상한을 엄수하고, Haiku로 할 수 있는 건 Haiku로 하고, Explore 서브에이전트로 먼저 파악한 뒤 비싼 모델로 구현한다.

---

## 기능

### 자동으로 되는 것 (설정 불필요)

| 기능 | 설명 |
|------|------|
| **도메인 감지** | 프로젝트 구조에서 도메인을 자동 추출 (routes/, services/, pages/ 등) |
| **구조 타입 판단** | [A] 도메인 디렉토리 / [B] 평면 구조 / [C] 레거시 자동 분류 |
| **복잡도 판단** | 도메인 수 + 파일 규모 + 의존성 + 구조로 SIMPLE/MEDIUM/COMPLEX 자동 점수 |
| **팀 동적 구성** | 복잡도에 따라 1~5명 에이전트 자동 결정, 모델 자동 라우팅 |
| **MECE 소유권** | 각 파일은 정확히 1개 에이전트에 귀속. 경계 위반 시 자동 revert |
| **피드백 루프** | 구현→테스트→수정→재검증 자동 반복 |
| **Circuit Breaker** | 2회 실패 → debugger → 그래도 실패 → 사용자 에스컬레이션 |
| **Worktree 머지** | 에이전트별 isolated worktree + 순차 머지 + 경계 위반 체크 |
| **Codex 장애 대응** | Codex 미설치/실패 시 자동 스킵, 플로우 중단 없음 |

### 원하면 사용하는 것 (옵트인)

| 기능 | 트리거 | 설명 |
|------|--------|------|
| **계획 수립** | COMPLEX 자동 or "계획해줘" | 구조화 인터뷰 → Wave 분해 → 도메인별 완료 기준 |
| **범위 잠금** | MEDIUM+ 자동 | IN/OUT/DEFER 목록 확인 후 실행 중 범위 변경 경고 |
| **Debate Mode** | `/debate` or 자동 (위험도 6+) | Codex xhigh 적대적 아키텍처 검토 |
| **Codex 최종 리뷰** | Step 4에서 활성화 | 머지 후 xhigh read-only 교차 검토 1회 |
| **Ralph 모드** | `/ralph` | PRD 기반 완료 보장 — 모든 스토리 PASS까지 멈추지 않음 |
| **HUD** | `/hud` | 상태 표시줄에 팀 진행률 실시간 표시 |
| **알림** | `/configure-notifications` | Telegram/Discord/Slack으로 이벤트 알림 |
| **Plan Mode 게이트** | 에이전트 3명+ 시 자동 | 구현 전 계획 승인 (경계 위반 방지) |

---

## 스킬 목록

| 스킬 | 트리거 | 역할 |
|------|--------|------|
| [`/spawn-team`](.claude/skills/spawn-team/SKILL.md) | "팀 구성해줘", "spawn team" | 핵심 오케스트레이터 — 분석→Planning→구성→실행 |
| [`/debate`](.claude/skills/debate/SKILL.md) | "debate", "아키텍처 토론" | Codex xhigh 적대적 검토 (단독 or spawn-team 내) |
| [`/ralph`](.claude/skills/ralph/SKILL.md) | "끝날 때까지", "ralph" | PRD 기반 완료 보장 루프 |
| [`/hud`](.claude/skills/hud/SKILL.md) | "hud setup" | Claude Code 상태 표시줄 |
| [`/configure-notifications`](.claude/skills/configure-notifications/SKILL.md) | "알림 설정" | Telegram / Discord / Slack 알림 |

---

## 설치

### 자동 (권장)

```bash
git clone https://github.com/gksl5355/claude-agent-bootstrap.git
cd claude-agent-bootstrap
./install.sh
```

### 수동 (전체)

```bash
git clone https://github.com/gksl5355/claude-agent-bootstrap.git
cd claude-agent-bootstrap

mkdir -p ~/.claude/skills
for skill in spawn-team debate ralph hud configure-notifications; do
  ln -sf "$(pwd)/.claude/skills/$skill" ~/.claude/skills/$skill
done
```

### 수동 (선택)

원하는 스킬만 골라서 설치할 수 있다. `spawn-team`은 핵심이므로 항상 포함 권장.

```bash
# 예: spawn-team + debate만 설치
mkdir -p ~/.claude/skills
ln -sf "$(pwd)/.claude/skills/spawn-team" ~/.claude/skills/spawn-team
ln -sf "$(pwd)/.claude/skills/debate" ~/.claude/skills/debate
```

| 스킬 | 독립 사용 | 의존성 |
|------|-----------|--------|
| `spawn-team` | O | 없음 (핵심) |
| `debate` | O | 없음 (단독 or spawn-team 내) |
| `ralph` | X | spawn-team 필요 |
| `hud` | O | 없음 |
| `configure-notifications` | O | 없음 |

### 설정

`~/.claude/settings.json`:

```jsonc
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "teammateMode": "tmux"
  },
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)"
    ]
  }
}
```

### 요구사항

- **Claude Max** (Agent Teams 지원)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Codex CLI (선택 — `/debate`, 최종 리뷰 시)

### 제거

```bash
rm ~/.claude/skills/{spawn-team,debate,ralph,hud,configure-notifications}
```

---

## 작동 방식

### 전체 플로우

```
Step 0   의도 분류       모호하면 1-2개 질문. 대부분 자동 통과.
Step 1   프로젝트 분석    기술 스택 + 도메인 감지 + 구조 타입 [A/B/C]
Step 2   팀 구성 제안     에이전트 수 + 모델 + 워크트리 모드
Step 2B  복잡도 판단     자동 점수 → SIMPLE / MEDIUM / COMPLEX
Step 2.5 범위 확인       IN/OUT/DEFER 사용자 확인 (MEDIUM+)
Step 3   계획 수립       인터뷰 + Wave 분해 + 완료 기준 (COMPLEX만)
Step 4   사용자 확인     팀 + 계획 최종 승인
Step 5   팀 스폰        에이전트 생성 + MECE 프롬프트
Step 6   작업 지시 대기   "준비 완료"
Step 7   실행 루프       구현 → 테스트 → 피드백 → 머지 → Codex 리뷰
```

### 복잡도별 경로

| 복잡도 | 점수 | 경로 | 소요 |
|--------|------|------|------|
| SIMPLE | 4-6 | 0→1→2→2B→4→5→6→7 | ~1분 |
| MEDIUM | 7-9 | +Step 2.5 (범위 확인) | ~3분 |
| COMPLEX | 10-11 | +Step 2.5+3 (계획 수립) | ~10분 |

### 에이전트 구성

```
소규모 (1~2명):  fullstack(sonnet) + unit-tester(haiku)
중규모 (3~4명):  도메인 be/fe(sonnet) × N + unit-tester(haiku)
대규모 (5명):    planner(sonnet) + 도메인(sonnet) × 2 + unit-tester + scenario-tester(haiku)
```

### 모델 라우팅

| 역할 | 모델 | 이유 |
|------|------|------|
| 테스트, 디버그, 빌드 수정 | Haiku | 비용 효율 |
| 도메인 구현 (BE/FE) | Sonnet | 균형 |
| 아키텍처 설계 (MEDIUM 이하) | Sonnet | 고급 추론 |
| Leader, planner, architect (COMPLEX) | **Opus** | 깊은 추론 필요 |
| 최종 리뷰, 설계 비판 | Codex xhigh | 독립적 관점 |

### Debate Mode

아키텍처 결정에 Codex xhigh로 적대적 검토. 2라운드 상한.

```
하드 트리거: DB 스키마, 외부 API 계약, 인증 방식 (비가역 결정)
소프트 트리거: 위험도 6+ (불확실성 + 영향범위 + 복잡도)
```

- Round 1: 설계 제출 → Codex 비판 (BLOCK/TRADEOFF/ACCEPT)
- Round 2: BLOCK 해소 검증만. 신규 이슈는 TRADEOFF로 (무한 비판 방지)
- BLOCK 이견 → 사용자 에스컬레이션

---

## 구조

```
.claude/skills/
├── spawn-team/              # 핵심 — Planning + 팀 구성 + 피드백 루프
│   └── SKILL.md
├── debate/                  # 적대적 아키텍처 검토
│   └── SKILL.md
├── ralph/                   # PRD 완료 보장
│   └── SKILL.md
├── hud/                     # 상태 표시줄
│   └── SKILL.md
└── configure-notifications/ # 외부 알림
    └── SKILL.md

install.sh                   # 자동 설치
README.md                    # 이 파일
```

---

## 트러블슈팅

| 문제 | 해결 |
|------|------|
| "Skill not found: spawn-team" | `ls -la ~/.claude/skills/spawn-team` 확인. 없으면 `./install.sh` 재실행 |
| Permission denied | `~/.claude/settings.json`에 `"Skill(spawn-team)"` 허용 추가 |
| Agent Teams 안 됨 | Claude Max 확인 + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 설정 |
| Codex exec 실패 | 자동 스킵됨. 설치: `npm install -g @openai/codex` |
| 에이전트 idle 상태 | 정상. 메시지 받을 때만 쿼터 소모. 비용 없음. |

---

## Releases

**[GitHub Releases](https://github.com/gksl5355/claude-agent-bootstrap/releases)**

---

## 감사

이 프로젝트는 다음 프로젝트들의 아이디어와 패턴에서 많은 영감을 받았습니다:

- **[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode)** by @Yeachan-Heo — ralph, HUD, notification 원본 + Magic Keyword 의도 탐지
- **[oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)** by @code-yeongyu — Planning Triad (Metis/Prometheus/Momus) + Wave 분해 + Momus 검증
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** by Anthropic — Agent Teams 플랫폼
- **[Codex CLI](https://github.com/openai/codex)** by OpenAI — ExecPlan + xhigh reasoning
- **[OpenCode](https://github.com/opencode-ai/opencode)** — swarm_decompose + agent specialization

---

## License

MIT
