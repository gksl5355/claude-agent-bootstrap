# Team Orchestrator — 1단계 코어

## 목표

`/spawn-team` 스킬로 프로젝트에 최적화된 Claude Code Agent Teams를 동적으로 구성하고 운영한다.

**환경**: Claude Max (Agent Teams, teammateMode: tmux)
**구현체**: `.claude/skills/spawn-team/SKILL.md`
**선택 확장**: Codex CLI (ChatGPT Plus) — enabled/disabled

---

## 1. 팀 구성 (동적)

### 1.1 역할

| 역할 | 모델 | 책임 |
|---|---|---|
| leader | opus (메인 세션) | 분석, 분배, 조율, 최종 판단 |
| planner | sonnet | 아키텍처 설계, 기술 스펙 (대규모 시) |
| {domain}-be | sonnet | 도메인별 백엔드 구현 |
| {domain}-fe | sonnet | 도메인별 프론트엔드 구현 |
| fullstack | sonnet | BE+FE 겸용 (소규모, 도메인 분리 불필요 시) |
| unit-tester | haiku | 단위 테스트: 함수/모듈이 정상 작동하는가 |
| scenario-tester | haiku | 시나리오 테스트: 유저 플로우/API 흐름이 맞는가 |
| worker | haiku | 단순/반복 (보일러플레이트, 마이그레이션) |

- leader = 메인 세션 (스폰 X)
- opus는 leader뿐, 나머지 sonnet/haiku

### 1.2 동적 팀 구성

고정 프리셋 대신, **프로젝트 분석 결과로 팀을 동적 생성**한다.

```
프로젝트 스캔 결과:
  도메인 수, 파일 수, BE/FE 비율, 기술 스택

→ 자동 결정:
  - 에이전트 수 = 감지된 도메인 수 기반
  - BE/FE 분리 = 도메인별 파일 규모 기반
  - 테스터 수/종류 = 테스트 필요 범위 기반
  - 워크트리 = 에이전트 수 기반 (3+ → isolated)
```

### 1.3 도메인 감지

```
스캔 대상:
  BE: routes/, controllers/, services/, handlers/ 파일명으로 도메인 추출
  FE: pages/, components/ 폴더 or 파일명으로 도메인 추출

예시 (task-manager-app):
  BE 도메인: auth, tasks, projects
  FE 도메인: auth(login), dashboard, board

도메인이 작으면 (파일 2~3개) → 인접 도메인과 병합
도메인이 크면 (파일 10+) → 독립 에이전트
```

### 1.4 구성 가이드라인

```
소규모 (소스 < 10파일, 도메인 1~2개):
  fullstack(sonnet) 1 + unit-tester(haiku) 1
  워크트리: shared

중규모 (10~30파일, 도메인 2~4개):
  도메인별 be/fe(sonnet) + unit-tester(haiku) 1
  워크트리: isolated

대규모 (30+파일, 도메인 4+개):
  도메인별 be/fe(sonnet) + planner(sonnet) 1
  + unit-tester(haiku) 1 + scenario-tester(haiku) 1
  워크트리: isolated

에이전트 총 수 5명 이하 권장 (쿼터)
도메인 수 > 5면 → 소규모 도메인 병합하여 5 이내로
```

### 1.5 테스터 역할 분리

| 테스터 | 담당 | 시점 |
|---|---|---|
| **unit-tester** | 함수/모듈 단위 테스트. 코드가 작동하는가? | 각 에이전트 구현 완료 시 |
| **scenario-tester** | API 흐름, 유저 시나리오 테스트. 전체가 맞게 돌아가는가? | 전체 구현 완료 후 |

```
소규모: unit-tester 1명이 둘 다 겸함
중규모: unit-tester 1명 (시나리오는 Leader or Codex)
대규모: unit-tester 1 + scenario-tester 1 분리
```

**테스터는 코드를 수정하지 않는다.**
- 버그 발견 → Leader에게 구체적 리포트 (파일, 라인, 증상, 재현 방법)
- Leader → 해당 도메인 에이전트에게 수정 지시
- 에이전트 수정 → 테스터 재검증

---

## 2. 에이전트 생명주기 & 운영

### 2.1 생명주기

```
스폰 → 태스크 수행 → 완료 보고 → 대기 (종료 X)
                                      │
                        ┌─────────────┤
                        ▼             ▼
                   새 태스크 할당   테스터 피드백
                   (다음 작업)     (버그 수정)
                        │             │
                        └─────────────┘
                              │
                         전체 통과
                              │
                         일괄 종료
```

**핵심: 전체 작업이 끝날 때까지 에이전트를 종료하지 않는다.**
- 구현 완료 후 idle → 다음 태스크 or 버그 수정 대기
- 테스터 피드백 루프가 끝나야 종료
- 쿼터 부족 시에만 조기 종료

### 2.2 피드백 루프

```
1. 에이전트 구현 완료 → Leader에게 보고
2. Leader → unit-tester에게 해당 코드 테스트 지시
3. unit-tester 결과:
   - PASS → 다음 단계
   - FAIL → Leader에게 리포트
     → Leader가 해당 에이전트에게 수정 지시 (리포트 포함)
     → 에이전트 수정 → unit-tester 재검증
     → 2~3회 반복 후에도 실패 → Leader가 직접 개입 or 에스컬레이션
4. 전체 unit 통과 → scenario-tester (있으면)
5. scenario 통과 → Codex 리뷰 (있으면) → Leader 최종 머지
```

### 2.3 워크트리

```
에이전트 3명 이상 → isolated (자동)
에이전트 2명 이하 → shared (자동)
도메인 기반 배치 시 → isolated 강력 권장

isolated 모드:
  - 에이전트별 독립 워크트리 + 브랜치
  - 머지: tester 통과 → Leader 승인 → main에 머지
  - 충돌 시: Leader가 분석 → 해당 에이전트에게 수정 지시
```

### 2.4 태스크 분배

```
도메인 기반 배치 시:
  - 도메인 = 태스크 (자동 매핑)
  - 각 에이전트는 자기 도메인 파일만 수정
  - Leader의 분배 부담 최소화

역할 기반 배치 시 (소규모):
  - Leader가 작업을 독립 단위로 분해
  - 파일/모듈 경계 기준
  - 의존성 → blockedBy, 독립 → 병렬
```

---

## 3. Codex 연계 (선택)

### 3.1 활성화

```
/spawn-team 실행 시 질문: "Codex 사용할까요?"
  - 사용 → 리뷰 + 코딩 보조 활성화
  - 사용 안 함 → Codex 관련 전부 스킵
```

### 3.2 사용 시점

```
Leader가 Codex를 호출하는 시점:

1. 머지 전 교차 리뷰 (필수급)
   - 에이전트가 짠 코드를 다른 관점에서 검증
   - codex exec -c model_reasoning_effort=xhigh -s read-only "리뷰..."

2. 독립 코딩 태스크 (쿼터 유동적)
   - Claude 에이전트 대신 Codex가 구현
   - codex exec -c model_reasoning_effort=high -s workspace-write "구현..."

3. 설계 비판 (planner 있을 때)
   - planner의 설계안을 Codex가 비판
   - codex exec -c model_reasoning_effort=xhigh -s read-only "비판..."

4. 시나리오 검증 (scenario-tester 대안)
   - scenario-tester 대신 Codex가 시나리오 점검
   - codex exec -c model_reasoning_effort=high -s read-only "시나리오 검증..."
```

### 3.3 쿼터 관리

```
- Plus 쿼터는 빡빡 → 고가치 작업에만
- 매 커밋 리뷰 X → 머지 전 최종 리뷰에만
- xhigh는 중요 리뷰/비판에만, 일반은 high/medium
- Claude 쿼터 부족 시 → Codex 비중 ↑ (유동적)
```

---

## 4. /spawn-team 스킬 동작

```
사용자: /spawn-team

Step 1: 프로젝트 분석
  - 디렉토리 구조, 기술 스택, 파일 수
  - 도메인 감지 (routes, controllers, pages 기준)
  - BE/FE 비율 계산

Step 2: 팀 구성 제안 (동적)
  "4개 BE 도메인, 3개 FE 도메인 감지. 다음 팀을 추천합니다:"
  - auth-be (sonnet) — auth 관련
  - tasks-be (sonnet) — tasks 관련
  - projects-be (sonnet) — projects + notifications 병합
  - auth-fe (sonnet) — 로그인/회원가입
  - dashboard-fe (sonnet) — 대시보드/프로젝트목록/보드
  - unit-tester (haiku) — 단위 테스트
  - 워크트리: isolated
  "Codex 교차 리뷰 활성화할까요?"

Step 3: 사용자 승인/조정
  - "projects-be가 notifications도 하는 게 맞아?"
  - "FE는 2개로 충분할 것 같은데" → 조정

Step 4: 팀 스폰
  - TeamCreate
  - 도메인별 에이전트 스폰 (담당 파일 범위 프롬프트에 포함)
  - 워크트리 생성 (isolated)
  - 테스터 스폰

Step 5: 작업 지시 대기
  - "팀 준비 완료. 작업을 지시해주세요."
  - 사용자 작업 지시 → Leader가 도메인별 분배

Step 6: 실행 & 피드백 루프
  - 에이전트 병렬 구현
  - 완료 → unit-tester 검증
  - 실패 → 해당 에이전트 수정 → 재검증
  - 전체 통과 → Codex 리뷰 (활성화 시) → Leader 최종 머지

Step 7: 종료
  - 전체 머지 완료 → 에이전트 일괄 shutdown
```

---

## 5. 테스트에서 배운 것

### 첫 번째 테스트 (balanced, task-manager-app)

```
결과:
  be1 + fe1 병렬 구현 → tester1 순차 검증 → 26 테스트 통과

발견된 개선점:
  1. 에이전트를 너무 일찍 종료 → 피드백 루프 불가
  2. 테스터가 코드 수정까지 담당 → 역할 분리 필요
  3. Codex 리뷰 안 함 → 활용 플로우 부재
  4. 도메인 분리 안 함 → generic be/fe 비효율
  5. 워크트리 미사용 → 대규모 시 충돌 위험
  → 이번 업데이트에서 모두 반영
```

---

## 6. 구현 범위

### 완료
- [x] SKILL.md 초안
- [x] 첫 번째 테스트 (balanced preset)

### 완료된 테스트
- [x] 도메인 기반 팀 구성 테스트 (auth-be + tasks-projects-be)
- [x] Codex xhigh 교차 리뷰 테스트 (9개 보안 이슈 발견)
- [x] 공유 파일 수정 Leader 승인 플로우
- [x] 에이전트 idle 유지 + 작업 재할당 플로우

### 다음 테스트
- [ ] 피드백 루프 테스트 (tester → 에이전트 직접 SendMessage → 수정 → 재검증)
- [ ] 워크트리 isolated 모드 테스트
- [ ] Explore 서브에이전트 토큰 효율 측정 (before/after 비교)
- [ ] 피어 직접 통신 테스트 (FE가 BE에게 직접 API 타입 질문)

### 돌려보고 판단할 것
- Codex 프록시 에이전트 필요 여부
- 서브에이전트 전략
- 로깅/산출물 스펙
- 대시보드 데이터 계약
- 오픈소스 패키지 구조

---

## 기술 배경

- Agent Teams 팀원 1명 ≈ 7x 쿼터 소모
- teammateMode: "tmux" 설정 완료
- CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1" 활성화
- Codex CLI: `codex exec`, 모델 gpt-5.3-codex, reasoning minimal|low|medium|high|xhigh
- Plus에서 Spark(gpt-5.3-codex-spark) 사용 불가
