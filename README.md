# Team Orchestrator

Claude Code Agent Teams를 프로젝트에 맞게 **동적으로 구성하고 완료까지 운영**하는 오케스트레이터 스킬 모음.

도메인 감지 → 팀 구성 → 구현 → 테스트 → 머지까지 피드백 루프 전체를 자동화한다.

---

## 스킬 목록

| 스킬 | 트리거 | 역할 |
|------|--------|------|
| [`/spawn-team`](.claude/skills/spawn-team/SKILL.md) | "팀 구성해줘", "spawn team" | 프로젝트 분석 → 팀 동적 구성 → 피드백 루프 운영 |
| [`/debate`](.claude/skills/debate/SKILL.md) | "debate", "아키텍처 토론", "설계 검토" | Codex xhigh 적대적 검토. 단독 또는 spawn-team 내 자동 트리거 |
| [`/ralph`](.claude/skills/ralph/SKILL.md) | "끝날 때까지 멈추지 마", "ralph" | PRD 기반 완료 보장 루프 (spawn-team 통합) |
| [`/hud`](.claude/skills/hud/SKILL.md) | "hud setup", "statusline" | Claude Code 상태 표시줄에 팀 진행률 표시 |
| [`/configure-notifications`](.claude/skills/configure-notifications/SKILL.md) | "알림 설정", "telegram" | 팀 이벤트 알림 (Telegram / Discord / Slack) |

---

## 설치

### 방법 1: 전역 설치 (권장)

```bash
# 1. 클론
git clone https://github.com/YOUR_USERNAME/team-orchestrator.git

# 2. 전역 스킬 디렉토리에 symlink
mkdir -p ~/.claude/skills
for skill in spawn-team debate ralph hud configure-notifications; do
  ln -s "$(pwd)/team-orchestrator/.claude/skills/$skill" ~/.claude/skills/$skill
done

# 3. 전역 settings에 권한 추가 (~/.claude/settings.json)
# "permissions.allow"에 추가:
#   "Skill(spawn-team)"
#   "Skill(debate)"

# 4. 환경 변수 (settings.json의 env)
#   "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
#   "teammateMode": "tmux"
```

모든 프로젝트에서 `/spawn-team`, `/debate` 등 바로 사용 가능.

### 방법 2: 프로젝트 로컬

```bash
# 프로젝트 .claude/skills/ 에 복사
cp -r team-orchestrator/.claude/skills/* your-project/.claude/skills/
```

---

## 빠른 시작

```
# 1. 프로젝트 디렉토리에서 실행
/spawn-team

# 2. 분석 결과 확인 후 팀 구성 승인
# 3. 작업 지시
"인증 기능과 상품 관리 API를 구현해줘"

# 4. 자동으로 돌아감
# 구현 → 테스트 → 버그 수정 → 재검증 → 머지

# 단독 설계 검토
/debate "JWT vs Session Auth"
```

---

## 핵심 설계

### 에이전트 구성 (5명 상한)

```
소규모 (1~2명): fullstack + unit-tester
중규모 (3~4명): 도메인 be/fe × N + unit-tester
대규모 (5명):   planner + 도메인×2 + unit-tester + scenario-tester
```

에이전트 1명 ≈ 7× 쿼터. 상한 엄수.

### 모델 라우팅

| 태스크 | 모델 |
|--------|------|
| 테스트, 버그 분석, 빌드 수정 | Haiku |
| 도메인 구현 (BE/FE) | Sonnet |
| 아키텍처 설계 | Sonnet |
| 최종 리뷰 / 보안 검토 | Codex (`codex exec -c model_reasoning_effort=xhigh`) |

### 프로젝트 구조 감지

```
[A] 도메인 디렉토리  →  src/auth/**, src/products/** 단위 소유 (기본)
[B] 평면 구조        →  파일 레벨 MECE 매니페스트 (폴백)
[C] 레거시/불명확    →  architect-agent가 먼저 도메인 디렉토리로 리팩터 후 [A]로
```

### MECE 파일 소유권

- 각 파일/디렉토리는 정확히 1개 에이전트에 귀속
- 공유 파일(`types/`, `utils/`) → Leader 직접 관리
- 경계 위반 시 즉시 revert

### 피드백 루프

```
구현 완료 → unit-tester 검증
  PASS → 다음 단계
  FAIL → 에이전트 수정 → 재검증
    2회 FAIL → debugger 온디맨드 분석
      debugger 후 FAIL → 사용자 에스컬레이션 (circuit breaker)
```

### Worktree 머지 (isolated 모드)

머지 순서: 공유 파일 → 의존성 낮은 도메인 → 의존성 높은 도메인 → 테스트
병렬 머지 금지. 각 단계 빌드 확인 후 진행.

### Debate Mode (`/debate`)

아키텍처 결정에 Codex xhigh로 적대적 검토. **단독 호출 또는 spawn-team 내 자동 트리거.**

| 트리거 | 기준 |
|--------|------|
| 하드 트리거 | DB 스키마, 외부 API 계약 등 비가역 결정 / 전체 시스템 영향 |
| 소프트 트리거 | 위험도 합계 6+ (불확실성 + 영향범위 + 복잡도, 각 1~3점) |

- 최대 2라운드 + 예외 1회. BLOCK 이견 → 사용자 에스컬레이션.
- Round 2는 기존 BLOCK 해소 검증만. 신규 이슈는 TRADEOFF로 문서화 (무한 비판 방지).
- Codex 불가 시 fallback: 경고 + 고위험 안건은 사용자 수동 검토 요청.
- 상세: [`.claude/skills/debate/SKILL.md`](.claude/skills/debate/SKILL.md)

---

## 테스트 결과

| 케이스 | 구조 | 결과 |
|--------|------|------|
| test-task-manager | [A] 도메인 디렉토리 | 29/29 PASS |
| test-ecommerce | [B] 평면 구조 | 28/28 unit + 4/4 scenario PASS |
| test-domain-dir | [A] 도메인 디렉토리 | 13/13 PASS |
| test-legacy-team | [B] 평면 구조 + Plan Mode 게이트 + Codex xhigh 리뷰 | 13/13 PASS |
| test-monolith | [C] → 단일 app.ts 84줄 → 도메인 디렉토리 리팩터 | 4/4 PASS |

---

## 환경 요구사항

- Claude Max (Agent Teams 활성화)
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- `teammateMode: "tmux"` (settings.json)
- Codex CLI (선택, `codex exec` 사용 시)

---

## 구조

```
.claude/skills/
├── spawn-team/             # 핵심 — 팀 구성 + 피드백 루프
│   └── SKILL.md
├── debate/                 # 아키텍처 결정 적대적 검토 (단독 호출 가능)
│   └── SKILL.md
├── ralph/                  # PRD 기반 완료 보장 루프
│   └── SKILL.md
├── hud/                    # Claude Code 상태 표시줄
│   └── SKILL.md
└── configure-notifications/ # Telegram / Discord / Slack 알림
    └── SKILL.md

plan.md                     # 설계 문서 + 로드맵
debate-design-final.md      # Debate Mode 설계 과정 기록
```

---

## 참고

- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) — ralph, HUD, configure-notifications 오리지널
