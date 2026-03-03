---
name: spawn-team
description: This skill should be used when the user asks to "create a team", "spawn a team", "start team agents", "set up a dev team", or wants to begin parallel development with Claude Code Agent Teams. Analyzes the project, detects domains, and spawns an optimized team of agents dynamically.
argument-hint: "[project path]"
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(codex *), Bash(find *), Bash(wc *), Bash(sg *), Task, TaskCreate, TaskUpdate, TaskList, TeamCreate, TeamDelete, SendMessage, AskUserQuestion
---

# Spawn Team

프로젝트를 분석하여 도메인 기반으로 최적화된 Claude Code Agent Teams를 동적 구성하고 운영한다.

## Step 1: 프로젝트 분석

프로젝트 루트를 스캔하여 다음을 파악한다.

### 1-1. 기술 스택

package.json, requirements.txt, go.mod, Cargo.toml 등에서 기술 스택 파악.

### 1-2. 도메인 감지

BE 도메인 감지:
- `routes/`, `controllers/`, `services/`, `handlers/` 내 파일명으로 추출
- 예: routes/auth.ts, routes/tasks.ts → 도메인: auth, tasks

FE 도메인 감지:
- `pages/`, `views/` 내 파일명 또는 폴더명으로 추출
- `components/` 는 보조 (도메인 판단에 직접 사용하지 않음)
- 예: pages/LoginPage.tsx, pages/DashboardPage.tsx → 도메인: auth, dashboard

**감지 실패 시** (모노레포, 비표준 구조, 위 패턴 없음):
- AskUserQuestion으로 도메인 직접 지정 요청
- 또는 fullstack 1명이 전체 담당 (사용자 선택)

### 1-3. 도메인 규모 판단

각 도메인의 파일 수를 세어 규모 판단:
- 소 도메인 (파일 1~3개) → 인접 도메인과 병합 후보
- 중 도메인 (파일 4~9개) → 독립 에이전트 1명
- 대 도메인 (파일 10+개) → 독립 에이전트 1명 (필요 시 분할 제안)

## Step 2: 팀 구성 제안 (동적)

분석 결과를 바탕으로 팀을 구성한다. **고정 프리셋이 아니라 프로젝트에 맞춰 동적 생성.**

### 구성 규칙

**에이전트 수 기준 (5명 상한 엄수):**

```
소규모 (1~2명):
  fullstack(sonnet) 1 + unit-tester(haiku) 1
  워크트리: shared

중규모 (3~4명):
  도메인별 be/fe(sonnet) + unit-tester(haiku) 1
  워크트리: isolated

대규모 (5명, 상한):
  planner(sonnet) 1
  + 도메인 에이전트(sonnet) — 병합하여 2명 이내
  + unit-tester(haiku) + scenario-tester(haiku)
  워크트리: isolated
```

- 도메인이 많으면 소규모 도메인 병합 → 5명 이내로
- planner와 scenario-tester 둘 다 필요하면 5명 상한 재확인 후 하나 제거
- 워크트리: 에이전트 3명 이상 → isolated, 2명 이하 → shared

**구성 예시**

소규모 (TODO앱):
```
fullstack(sonnet) 1 + unit-tester(haiku) 1  → 총 2명
워크트리: shared
```

중규모 (task-manager, 도메인 3):
```
auth-be(sonnet) + tasks-be(sonnet)  → 소규모 도메인 병합
dashboard-fe(sonnet)
unit-tester(haiku)
→ 총 4명, 워크트리: isolated
```

대규모 (이커머스, 도메인 6+):
```
planner(sonnet) 1
core-be(sonnet) — auth+products 병합
orders-be(sonnet) — orders+payments 병합
unit-tester(haiku) + scenario-tester(haiku)
→ 총 5명, 워크트리: isolated
```

## Step 3: 사용자 확인

AskUserQuestion으로 다음을 확인:

**질문 1**: 팀 구성 확인
- 분석 결과와 추천 팀 구성 표시
- 에이전트별 담당 파일 범위
- 병합된 도메인 설명
- 옵션: 추천대로 / 조정

**질문 2**: Codex 활성화
- "Codex CLI를 머지 전 최종 리뷰에 사용할까요?"
- 옵션: 사용 / 사용 안 함

## Step 4: 팀 스폰

### 4-1. 팀 생성

TeamCreate로 팀을 생성한다.

### 4-2. 에이전트 스폰

각 에이전트를 Task로 스폰한다:
- `subagent_type: "general-purpose"`
- `team_name: "{team-name}"`
- `name: "{domain}-{role}"` (예: auth-be, dashboard-fe, unit-tester)
- `model: "sonnet"` (개발자) 또는 `"haiku"` (테스터)
- `isolation: "worktree"` (isolated 모드 시)
- `run_in_background: true` (병렬 스폰)

**스폰 부분 실패 시** (일부 에이전트만 생성됨):
- TeamDelete로 전체 롤백
- 사용자에게 알림 후 재시도 제안

프롬프트에 반드시 포함:
- 담당 파일 범위 (구체적 glob 패턴)
- **팀 전체 멤버 목록** (피어 직접 통신용): `팀 멤버: auth-be, tasks-be, unit-tester, ...`
- **서브에이전트 탐색 지시** (규모 기반, 프롬프트에 아래 텍스트 중 하나를 직접 삽입):

  [소규모 — 담당 파일 ≤ 5개 시 삽입]:
  ```
  담당 파일이 적으므로 직접 Read 후 구현하세요. Grep으로 타입 확인 후 진행.
  ```

  [중규모 — 담당 파일 6~15개 시 삽입]:
  ```
  구현 전 이 순서로 파악하세요:
  1. Task(subagent_type="Explore")로 담당 범위 스캔 (파일 목록, 주요 export)
  2. Grep 또는 sg(ast-grep)으로 관련 타입/인터페이스 검색
  3. 필요한 파일만 Read
  ```

  [대규모 — 담당 파일 16+개 시 삽입]:
  ```
  구현 전 반드시 이 순서로 파악하세요 (순차 읽기 금지):
  1. Task(subagent_type="Explore")로 담당 범위 전체 스캔
  2. sg(ast-grep)으로 구조 파악: 인터페이스, export 함수, 클래스 목록
     예: sg -p 'export function $F($_$$)' --lang ts src/server/
  3. Grep으로 텍스트 검색 보완
  4. 실제 수정할 파일만 Read
  ```

### 4-3. 에이전트 프롬프트

**도메인 개발 에이전트 (BE):**
```
당신은 {domain} 도메인 백엔드 개발자({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}  ← 피어 직접 통신용 (예: auth-be, tasks-be, unit-tester)

담당 파일 범위:
{file-list}

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}

## 구현 규칙
- 담당 파일 범위만 수정. 다른 도메인 파일 절대 수정 금지.
- 공유 파일(shared/, types 등)은 읽기만. 수정 필요 시 Leader에게 요청.
- 구현 완료 → TaskUpdate 상태 변경 + Leader에게 SendMessage 보고.
- 막히면 2~3회 자체 시도 후 Leader에게 요청.
- 테스터 버그 리포트 수신 → 수정 후 재보고.

## 피어 직접 통신
- 인터페이스 충돌 협의, 공유 타입 영향도 확인 → 관련 에이전트에게 직접 SendMessage
  예: tasks-be가 Task 타입 변경 시 → auth-be에게 먼저 직접 확인
- 세부 기술 협의는 피어끼리 직접. Leader에게는 완료/이슈만 보고.
- 공유 파일 수정 승인은 여전히 Leader에게.
```

**도메인 개발 에이전트 (FE):**
```
당신은 {domain} 도메인 프론트엔드 개발자({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}  ← 피어 직접 통신용

담당 파일 범위:
{file-list}

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}

## 구현 규칙
- 담당 파일 범위만 수정. 다른 도메인 파일 절대 수정 금지.
- 공유 파일(shared/, types, utils 등)은 읽기만. 수정 필요 시 Leader에게 요청.
- Tailwind CSS로 스타일링 (프로젝트에 Tailwind 있을 시).
- 구현 완료 → TaskUpdate 상태 변경 + Leader에게 SendMessage 보고.
- 막히면 2~3회 자체 시도 후 Leader에게 요청.
- 테스터 버그 리포트 수신 → 수정 후 재보고.

## 피어 직접 통신
- API 응답 구조 확인, 타입 불일치 협의 → 해당 BE 에이전트에게 직접 SendMessage
  예: dashboard-fe가 API 응답 타입 불명확 → tasks-be에게 직접 질문
- 세부 기술 협의는 피어끼리 직접. Leader에게는 완료/이슈만 보고.
```

**unit-tester:**
```
당신은 유닛 테스터({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}  ← 피어 직접 통신용
테스트 프레임워크: {test-framework}

역할: 각 모듈/함수가 정상 작동하는지 단위 테스트 작성 및 실행.

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}

## 테스트 규칙
- Leader 지시 → 해당 코드 단위 테스트 작성 및 실행.
- 외부 의존성(DB, API)은 모킹.
- PASS → Leader에게 "PASS: {테스트 수} 통과" 보고.
- FAIL → Leader + 해당 도메인 에이전트에게 직접 구체적 리포트 전송:
  - 실패한 테스트명
  - 예상값 vs 실제값
  - 해당 파일:라인
  - 재현 방법
- 코드를 직접 수정하지 않는다. 버그는 리포트만.

## 피어 직접 통신
- 버그 발견 시 → Leader 보고 + 해당 에이전트에게 동시 SendMessage
- 테스트 환경 설정 질문 → 해당 도메인 에이전트에게 직접 질문 가능
```

**scenario-tester:**
```
당신은 시나리오 테스터({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}

역할: 전체 유저 플로우 / API 흐름이 올바르게 동작하는지 시나리오 기반 테스트.

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}

## 테스트 규칙
- 전체 구현 완료 후 Leader 지시로 시작.
- 유저 시나리오 정의 (예: "회원가입 → 로그인 → 프로젝트 생성 → 태스크 추가")
- 시나리오 단계별 동작 검증.
- 실패 시 어느 단계에서 실패했는지 Leader + 해당 에이전트에게 보고.
- 코드를 직접 수정하지 않는다.
```

**fullstack (소규모):**
```
당신은 풀스택 개발자({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}

모든 BE + FE 코드를 담당합니다.

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}

## 구현 규칙
- 구현 완료 → TaskUpdate 상태 변경 + Leader에게 보고.
- 막히면 2~3회 자체 시도 후 Leader에게 요청.
- 테스터 버그 리포트 수신 → 수정 후 재보고.
```

## Step 5: 작업 지시 대기

팀 스폰 완료 후 표시:
```
팀 준비 완료.

에이전트:
  {name} ({model}) — {file-range}
  ...

Codex: 활성화 / 비활성화
워크트리: isolated / shared

작업을 지시해주세요.
```

## Step 6: 실행 & 피드백 루프

사용자가 작업을 지시하면:

### 6-1. 태스크 분배
- 도메인 에이전트에게 SendMessage로 구현 지시
- 독립 도메인은 병렬, 의존 있으면 blockedBy

### 6-2. 구현 → 테스트 루프

```
에이전트 구현 완료 → TaskUpdate(completed) + Leader 보고
  → Leader가 unit-tester에게 테스트 지시
  → unit-tester:
       PASS → "PASS: N 통과" Leader 보고 → 다음 단계
       FAIL → Leader 보고 + 해당 에이전트에게 직접 SendMessage (동시)
         → 에이전트 수정 → unit-tester 재검증
         → 2회 반복 후에도 FAIL
           → debugger 온디맨드 스폰:
               Task(subagent_type="general-purpose", name="debugger", model="haiku",
                    run_in_background=false)
               프롬프트: "다음 버그를 분석하고 원인과 수정 방법을 제시하세요 (코드 수정 금지):
                         {unit-tester 리포트 전문}"
               debugger 완료 → 결과를 해당 에이전트에게 전달 → 에이전트 수정 → 재검증
               debugger 자동 종료 (팀 멤버 아님)
           → debugger 후에도 FAIL
               [circuit breaker] Leader 직접 개입 or 사용자 에스컬레이션
               무한 루프 없이 중단
```

### 6-2-b. 빌드 실패 시

```
빌드/컴파일 오류 감지
  → build-fixer 온디맨드 스폰:
      Task(subagent_type="general-purpose", name="build-fixer", model="haiku",
           run_in_background=false)
      프롬프트: "다음 빌드 오류를 분석하고 수정하세요:
                {오류 메시지 전문}
                수정 가능한 파일: {해당 도메인 파일 범위}"
      build-fixer 완료 → 자동 종료
  → build-fixer 실패 → Leader 직접 개입 or 사용자 에스컬레이션
```

### 6-3. 전체 통과 후

```
1. scenario-tester 실행 (있으면)
2. Codex 교차 리뷰 (활성화 시, 머지 전 1회):
     codex exec -c model_reasoning_effort=xhigh -s read-only -C {project-path} \
       "다음 코드 변경사항을 리뷰해라: ..."
   Codex 실패 (미설치/권한 오류/타임아웃):
     → 경고 출력 후 스킵. 전체 플로우 중단 X.
     → Leader가 직접 리뷰로 대체 또는 사용자에게 알림.
3. Leader 최종 판단 → 머지
```

### 6-4. 종료

```
종료 조건 (AND):
  1. 모든 TaskList 항목 completed
  2. unit-tester PASS
  3. scenario-tester PASS (있을 때)
  4. Codex 리뷰 완료 (활성화 시)

→ 모든 에이전트 일괄 shutdown_request 전송
→ TeamDelete

예외:
  쿼터 임계치 도달 → 즉시 사용자 알림 → 판단 후 종료/에이전트 수 축소
```

## 운영 규칙

- **에이전트 생명주기**: 전체 작업 끝날 때까지 종료하지 않음. idle이어도 유지.
- **idle 비용 없음**: Agent Teams는 메시지 받을 때만 쿼터 소모. idle 유지 자체는 비용 없음.
- **쿼터 인식**: 에이전트 1명 ≈ 7x 소모. 5명 이하 엄수. 쿼터 부족 시 즉시 축소.
- **모델**: leader = Sonnet+thinking(메인), 개발 = sonnet, 테스트 = haiku.
- **파일 격리**: 도메인 에이전트는 자기 도메인 파일만 수정. 공유 파일 수정 시 Leader 승인.
- **테스터는 수정 안 함**: 버그 리포트만. 수정은 해당 도메인 에이전트가.
- **피어 통신 원칙**: 세부 기술 협의는 에이전트끼리 직접. 결정권과 상태 truth는 Leader.
- **Codex**: 머지 전 최종 1회만. 매 커밋마다 X. 실패 시 스킵하고 계속 진행.
- **토큰 효율화**: 구현 전 Explore 서브에이전트로 파악 먼저. 비싼 모델로 순차 읽기 금지.
