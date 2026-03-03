# Team Orchestrator

## 목표

프로젝트를 분석해 도메인 기반 팀을 동적 구성하고, 피드백 루프로 완료까지 운영하는 오케스트레이터.

**환경**: Claude Max (Agent Teams, teammateMode: tmux)
**구현체**: `.claude/skills/spawn-team/SKILL.md`
**외부 의존**: 없음 (필요한 것만 선택적으로 가져옴)

### omc 관계

fork도 플러그인도 아님. 파일 단위로 선택 참조.

```
가져올 것 (파일만):
  ralph/SKILL.md   → 복사 후 내 피드백 루프에 맞게 수정 (Phase 3)
  hud/omc-hud.mjs  → 그대로 사용 (Phase 3)

참고만:
  configure-notifications/SKILL.md (Phase 3)

내 것 그대로:
  spawn-team/SKILL.md — 이미 핵심 구현됨, 계속 발전
```

---

## 단계 로드맵

```
Phase 1 — MVP
  동적 팀 구성 + 피드백 루프 + Codex 최종 리뷰 1회
  → 안정적으로 작동하는 오케스트레이터 확보

Phase 2 — 안정화
  isolated 워크트리 / 부분 실패 롤백 / 라우팅 기준 명확화

Phase 3 — 확장
  ralph 통합 / HUD / Notification (omc 파일 가져옴)
```

---

## 1. 모델 라우팅

```
태스크 특성                          → 모델
────────────────────────────────────────────
반복적, 기계적, 테스트               → Haiku
일반 구현                            → Sonnet
설계 / 아키텍처 / 복잡한 판단        → Sonnet + extended thinking
리뷰 / 독립 분석 / 컨텍스트 분리     → Codex (codex exec)
```

**Codex 호출 조건 (명시적)**
- 코드/보안 리뷰
- 설계 비판
- Claude 쿼터 부족으로 구현 위임
- 컨텍스트 오염을 명시적으로 피해야 할 때

Codex는 팀 멤버 아님. 필요 시 `codex exec`으로 동적 호출.

**Codex 실패 시**: 경고 후 스킵, 전체 플로우 중단 없음. Leader가 직접 리뷰로 대체.

---

## 2. 팀 구성 (동적)

### 2.1 에이전트 역할

| 역할 | 모델 | 책임 |
|---|---|---|
| leader | Sonnet + thinking (메인 세션) | 분석, 분배, 조율, 최종 판단 |
| planner | Sonnet + thinking | 아키텍처 설계 (대규모만) |
| {domain}-be | Sonnet | 도메인별 백엔드 구현 |
| {domain}-fe | Sonnet | 도메인별 프론트엔드 구현 |
| fullstack | Sonnet | BE+FE 겸용 (소규모) |
| unit-tester | Haiku | 단위 테스트 — 코드 수정 X |
| scenario-tester | Haiku | 유저 플로우/API 흐름 — 코드 수정 X |
| debugger | Haiku | 온디맨드 버그 분석 — 코드 수정 X, 팀 멤버 아님 |
| build-fixer | Haiku | 온디맨드 빌드 오류 수정 — 팀 멤버 아님 |

### 2.2 도메인 감지

```
BE: routes/, controllers/, services/, handlers/ 파일명 → 도메인
FE: pages/, views/ 파일명/폴더명 → 도메인

소 도메인 (1~3파일) → 인접 도메인 병합 제안
중 도메인 (4~9파일) → 독립 에이전트 1명
대 도메인 (10+파일) → 독립 에이전트 1명

감지 실패 (모노레포, 비표준 구조):
  → 사용자에게 도메인 직접 지정 요청
  → 또는 fullstack 1명이 전체 담당
```

### 2.3 규모별 구성

에이전트 수 기준으로 통일. **상한 5명 엄수.**

```
소규모 (1~2명):
  fullstack(Sonnet) 1 + unit-tester(Haiku) 1
  워크트리: shared

중규모 (3~4명):
  도메인별 be/fe(Sonnet) + unit-tester(Haiku) 1
  워크트리: isolated

대규모 (5명, 상한):
  planner(Sonnet+thinking) 1
  + 도메인 에이전트(Sonnet) — 병합하여 3명 이내
  + unit-tester(Haiku) + scenario-tester(Haiku)
  워크트리: isolated

도메인 많을 때: 소규모 도메인 병합 → 5명 이내로
planner + scenario-tester 둘 다 필요하면 5명 상한 재확인 후 하나 제거
```

---

## 3. 에이전트 생명주기 & 자원 관리

### 3.1 idle 비용

Agent Teams는 **메시지 받을 때만** 쿼터 소모. idle 유지 자체는 비용 없음.
불필요한 메시지 왕복이 진짜 비용 → 피어 직접 통신으로 Leader 경유 최소화.

### 3.2 피어 직접 통신 — 상태 일관성 규칙

```
피어끼리 직접 가능:
  인터페이스/API 타입 협의 (BE ↔ FE)
  버그 리포트 전달 (tester → 도메인 에이전트)
  환경 설정 질문

반드시 Leader 경유:
  공유 파일 수정 승인
  도메인 경계를 넘는 결정 (스키마/API 계약 변경)
  작업 완료/실패 최종 보고

→ 피어 협의 = 세부 기술
  결정권 = Leader
  상태 truth = Leader의 TaskList
```

### 3.3 종료 조건 (AND)

```
1. 모든 TaskList 항목 completed
2. unit-tester PASS (flaky 의심 시 재실행 1회)
3. scenario-tester PASS (있을 때)
4. Codex 리뷰 완료 (활성화 시)

→ Leader가 일괄 shutdown_request 전송
→ TeamDelete  ← allowed-tools에 포함 필수

예외:
  쿼터 임계치 도달 → 즉시 사용자 알림 → 판단 후 종료/에이전트 수 축소
```

### 3.4 피드백 루프

```
에이전트 구현 완료
  → TaskUpdate(completed) + Leader 보고
  → Leader → unit-tester에게 테스트 지시
  → unit-tester:
       PASS → Leader 보고 ("PASS: N 통과")
       FAIL → Leader 보고 + 해당 에이전트에게 직접 SendMessage (동시)
         → 에이전트 수정 → unit-tester 재검증
         → 2회 반복 후 FAIL
           → debugger 온디맨드 스폰
               Task(name="debugger", model="haiku", run_in_background=false)
               "분석만, 코드 수정 금지. {리포트 전문}"
               → 결과를 에이전트에게 전달 → 수정 → 재검증
               → debugger 자동 종료
           → debugger 후에도 FAIL
               [circuit breaker] Leader 직접 개입 or 사용자 에스컬레이션
               무한 루프 없이 중단

빌드 오류:
  → build-fixer 온디맨드 스폰 (haiku)
  → 해결 후 자동 종료
  → build-fixer 실패 → Leader 직접 개입 or 사용자 에스컬레이션
```

---

## 4. Codex 연동

### 4.1 호출 시점

| 시점 | 명령 | 트리거 |
|---|---|---|
| 머지 전 최종 리뷰 | `codex exec -c model_reasoning_effort=xhigh -s read-only` | 전체 구현 완료 (1회) |
| 보안 리뷰 | `codex exec -c model_reasoning_effort=xhigh -s read-only` | 사용자 요청 or 보안 민감 코드 |
| 설계 비판 | `codex exec -c model_reasoning_effort=xhigh -s read-only` | planner 결과물 검토 |
| 독립 구현 | `codex exec -c model_reasoning_effort=high -s workspace-write` | Claude 쿼터 부족 |

```
xhigh → 중요 리뷰/비판에만
high  → 독립 구현 위임
매 커밋마다 X → 머지 전 최종 1회만
```

---

## 5. /spawn-team 스킬 동작

```
Step 1: 프로젝트 분석
  기술 스택, 도메인 감지, 에이전트 수 산정

Step 2: 팀 구성 제안
  도메인 목록 + 담당 파일 범위 + 모델 표시
  감지 실패 시 사용자에게 직접 지정 요청

Step 3: 사용자 확인
  팀 구성 승인/조정
  Codex 리뷰 활성화 여부

Step 4: 팀 스폰
  TeamCreate
  에이전트 스폰 (background 병렬)
  워크트리 설정 (에이전트 3+ → isolated)
  스폰 부분 실패 → 전체 롤백 + 사용자 알림

Step 5: 작업 지시 대기
  "팀 준비 완료. 작업을 지시해주세요."

Step 6: 실행 & 피드백 루프 (§3.4)

Step 7: 종료 (§3.3 조건 충족 시)
  shutdown_request 일괄 → TeamDelete
```

---

## 6. 구현 범위

### Phase 1 — MVP (지금)

SKILL.md 수정:
- [ ] allowed-tools에 `TeamDelete` 추가
- [ ] 에이전트 5명 상한 + 대규모 예시 통일
- [ ] 워크트리 기준 단일화 (에이전트 수 기준)
- [ ] Codex 정책 단일화 (머지 전 1회)
- [ ] circuit breaker 추가
- [ ] 감지 실패 fallback
- [ ] 스폰 부분 실패 롤백
- [ ] Codex degrade 전략

테스트:
- [ ] 피드백 루프 (tester → 에이전트 → 수정 → 재검증)
- [ ] circuit breaker (2회 FAIL → debugger → 에스컬레이션)
- [ ] Codex 최종 리뷰 플로우

### Phase 2 — 안정화

- [ ] isolated 워크트리 + 충돌 롤백
- [ ] 모델 라우팅 기준 구체화
- [ ] 도메인 간 공유 타입/스키마 변경 플로우
- [ ] flaky test 처리 (재실행 1회)

### Phase 3 — 확장

- [ ] ralph/SKILL.md 가져와서 피드백 루프에 통합
- [ ] HUD (omc-hud.mjs 그대로)
- [ ] Notification (configure-notifications 참고)

---

## 기술 배경

- Agent Teams 팀원 1명 ≈ 7x 쿼터 소모
- idle 상태 = 쿼터 소모 없음 (메시지 받을 때만)
- teammateMode: "tmux" 설정 완료
- CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1" 활성화
- Codex CLI: `codex exec`, reasoning minimal|low|medium|high|xhigh
- omc 참조: `Yeachan-Heo/oh-my-claudecode` (파일 단위 선택 사용)
