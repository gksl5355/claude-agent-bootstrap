---
name: spawn-team
description: This skill should be used when the user asks to "create a team", "spawn a team", "start team agents", "set up a dev team", or wants to begin parallel development with Claude Code Agent Teams. Analyzes the project, detects domains, and spawns an optimized team of agents dynamically.
argument-hint: "[project path]"
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(codex *), Bash(find *), Bash(wc *), Bash(sg *), Task, TaskCreate, TaskUpdate, TaskList, TeamCreate, SendMessage, AskUserQuestion
---

# Spawn Team

프로젝트를 분석하여 도메인 기반으로 최적화된 Claude Code Agent Teams를 동적 구성하고 운영한다.

## Step 1: 프로젝트 분석

프로젝트 루트를 스캔하여 다음을 파악한다:

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

### 1-3. 규모 산정

각 도메인의 파일 수를 세어 규모 판단:
- 소 도메인 (파일 1~3개) → 인접 도메인과 병합 후보
- 중 도메인 (파일 4~9개) → 독립 에이전트 1명
- 대 도메인 (파일 10+개) → 독립 에이전트 1명 (필요 시 분할 제안)

### 1-4. 전체 규모

```
소규모: 소스 < 10파일, 도메인 1~2개
중규모: 소스 10~30파일, 도메인 2~4개
대규모: 소스 30+파일, 도메인 4+개
```

## Step 2: 팀 구성 제안 (동적)

분석 결과를 바탕으로 팀을 구성한다. **고정 프리셋이 아니라 프로젝트에 맞춰 동적 생성.**

### 구성 규칙

**개발 에이전트:**
- 도메인당 1명 기본 (BE/FE 각각)
- 소 도메인은 인접 도메인과 병합 제안
- 에이전트 총 수 5명 이하 권장 (쿼터)
- 도메인이 많으면 소규모 도메인을 병합하여 5 이내로
- 대규모 프로젝트에서 설계 복잡 시 planner(sonnet) 1명 추가

**테스터:**
- 소/중규모: unit-tester(haiku) 1명 (시나리오는 겸하거나 Leader/Codex)
- 대규모: unit-tester(haiku) 1 + scenario-tester(haiku) 1

**워크트리:**
- 에이전트 3명 이상 → isolated (자동)
- 에이전트 2명 이하 → shared (자동)

### 구성 예시

소규모 (TODO앱, 도메인 1~2):
```
fullstack(sonnet) 1 + unit-tester(haiku) 1
워크트리: shared
```

중규모 (task-manager, 도메인 3):
```
auth-be(sonnet) + tasks-be(sonnet) + projects-be(sonnet)
dashboard-fe(sonnet)
unit-tester(haiku) 1
워크트리: isolated
```

대규모 (이커머스, 도메인 6+):
```
planner(sonnet) 1
auth-be + products-be + orders-be + payments-be (소규모 도메인 병합)
catalog-fe + checkout-fe + admin-fe (소규모 도메인 병합)
unit-tester(haiku) + scenario-tester(haiku)
워크트리: isolated
```

## Step 3: 사용자 확인

AskUserQuestion으로 다음을 확인:

**질문 1**: 팀 구성 확인
- 분석 결과와 추천 팀 구성 표시
- 도메인별 에이전트 목록 + 담당 파일 범위
- 병합된 도메인 설명
- 옵션: 추천대로 / 조정

**질문 2**: Codex 활성화
- "Codex CLI를 교차 리뷰/코딩 보조로 사용할까요?"
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

프롬프트에 반드시 포함:
- 담당 파일 범위 (구체적 glob 패턴)
- **팀 전체 멤버 목록** (피어 직접 통신용): `팀 멤버: auth-be, tasks-be, unit-tester, ...`
- **서브에이전트 탐색 지시** (규모 기반 동적 결정):
  - 소규모 (담당 파일 ≤ 5개): 생략 — "담당 파일이 적으니 직접 Read하세요."
  - 중규모 (담당 파일 6~15개): Explore 서브에이전트 + Grep/ast-grep 병행
  - 대규모 (담당 파일 16+개): 필수 — Explore → ast-grep 구조 파악 → 필요 파일만 Read

### 4-3. 에이전트 프롬프트

**도메인 개발 에이전트 (BE):**
```
당신은 {domain} 도메인 백엔드 개발자({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}  ← 피어 직접 통신용 (예: auth-be, tasks-be, unit-tester)

담당 파일 범위:
{file-list}

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}  ← Leader가 규모에 따라 아래 중 하나를 삽입:

[소규모] 담당 파일이 적으니 직접 Read하세요. Grep으로 타입 확인 후 진행.

[중/대규모] 구현 전 이 순서로 파악한다:
1. Task(subagent_type="Explore")로 담당 범위 빠르게 스캔
   예: "src/server/services/auth* 파일 목록과 주요 export/함수 시그니처 파악해줘"
2. 구조 파악이 필요하면 ast-grep(sg) 우선, 텍스트 검색은 Grep:
   - 인터페이스/함수 시그니처: sg -p 'interface $NAME { $$$}' --lang ts src/shared/
   - export 함수 목록: sg -p 'export const $F = $_' --lang ts src/server/
   - 타입 검색: Grep("type TaskStatus|TaskPriority", "src/shared/")
3. 파악한 파일 중 실제 수정할 파일만 Read (전체 순차 읽기 금지)

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
{explore-strategy}  ← Leader가 규모에 따라 삽입

[소규모] 직접 Read 후 진행. Grep으로 API 타입 확인.

[중/대규모] 구현 전 이 순서로 파악한다:
1. Task(subagent_type="Explore")로 담당 범위 빠르게 스캔
   예: "src/client/pages/Dashboard* 컴포넌트 구조와 사용 중인 hooks/types 파악해줘"
2. 구조 파악은 ast-grep(sg) 우선, 텍스트 검색은 Grep:
   - 컴포넌트 props 타입: sg -p 'interface $Props { $$$}' --lang tsx src/client/
   - hook export 목록: sg -p 'export function $F($_$$)' --lang ts src/client/hooks/
   - API 클라이언트: Grep("export.*fetch|useQuery|useMutation", "src/client/")
3. 파악한 파일 중 실제 수정할 파일만 Read

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
{explore-strategy}  ← Leader가 규모에 따라 삽입

[소규모] 직접 Read 후 테스트 작성.

[중/대규모] 테스트 대상 파악 시:
1. Task(subagent_type="Explore")로 테스트 대상 파일 구조 스캔
   예: "auth 도메인 서비스/컨트롤러 파일의 public 함수 목록 파악해줘"
2. ast-grep으로 테스트할 함수/클래스 목록 추출:
   - export 함수: sg -p 'export function $F($_$$)' --lang ts src/server/services/
   - export 클래스: sg -p 'export class $C { $$$}' --lang ts src/server/
3. 실제 테스트할 함수만 Read (전체 읽기 금지)

## 테스트 규칙
- Leader 지시 → 해당 코드 단위 테스트 작성 및 실행.
- 외부 의존성(DB, API)은 모킹.
- PASS → Leader에게 "PASS: {테스트 수} 통과" 보고.
- FAIL → Leader + **해당 도메인 에이전트에게 직접** 구체적 리포트 전송:
  - 실패한 테스트명
  - 예상값 vs 실제값
  - 해당 파일:라인
  - 재현 방법
- **코드를 직접 수정하지 않습니다.** 버그는 리포트만.

## 피어 직접 통신
- 버그 발견 시 → Leader 보고 + 해당 에이전트에게 동시 SendMessage (이슈 빠른 전달)
- 테스트 환경 설정 질문 → 해당 도메인 에이전트에게 직접 질문 가능
```

**scenario-tester:**
```
당신은 시나리오 테스터({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}

역할: 전체 유저 플로우 / API 흐름이 올바르게 동작하는지 시나리오 기반 테스트.

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}  ← Leader가 규모에 따라 삽입

[소규모] 직접 Read 후 시나리오 설계.

[중/대규모] 시나리오 설계 전:
1. Task(subagent_type="Explore")로 전체 라우트/API 엔드포인트 목록 파악
2. ast-grep으로 라우트 구조 추출:
   - sg -p 'router.$METHOD($PATH, $_$$)' --lang ts src/server/routes/
   - Grep("app.use|router.get|router.post", "src/server/")
3. 시나리오에 필요한 파일만 Read

## 테스트 규칙
- 전체 구현 완료 후 Leader 지시로 시작.
- 유저 시나리오 정의 후 (예: "회원가입 → 로그인 → 프로젝트 생성 → 태스크 추가")
- 시나리오 단계별 동작 검증.
- 실패 시 어느 단계에서 실패했는지 Leader + 해당 에이전트에게 보고.
- **코드를 직접 수정하지 않습니다.**
```

**fullstack (소규모):**
```
당신은 풀스택 개발자({name})입니다.
프로젝트: {project-path}
팀 멤버: {team-members}

모든 BE + FE 코드를 담당합니다.

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}  ← Leader가 규모에 따라 삽입

[소규모] 직접 Read 후 구현. (파일 수 적으므로 Explore 불필요)

[중/대규모] 구현 전:
1. Task(subagent_type="Explore")로 프로젝트 전체 구조 파악
   예: "src/ 디렉토리 구조, 기존 파일 목록, 주요 export 파악해줘"
2. Grep으로 관련 타입/인터페이스 검색
3. 필요한 파일만 Read

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
  auth-be (sonnet) — src/server/**/auth*
  tasks-be (sonnet) — src/server/**/task*
  dashboard-fe (sonnet) — src/client/pages/Dashboard*, src/client/components/Project*
  unit-tester (haiku)

Codex: 활성화 (머지 전 교차 리뷰)
워크트리: isolated

작업을 지시해주세요.
```

## Step 6: 실행 & 피드백 루프

사용자가 작업을 지시하면:

### 6-1. 태스크 분배
- 도메인 에이전트에게 SendMessage로 구현 지시
- 독립 도메인은 병렬, 의존 있으면 blockedBy

### 6-2. 구현 → 테스트 루프
```
에이전트 구현 완료
  → Leader가 unit-tester에게 테스트 지시
  → unit-tester 결과:
     PASS → 다음 에이전트 or 다음 단계
     FAIL → Leader에게 리포트
       → Leader가 해당 에이전트에게 수정 지시 (리포트 포함)
       → 에이전트 수정 → unit-tester 재검증
       → 2~3회 반복 후에도 실패 → Leader 직접 개입 or 사람에게 에스컬레이션
```

### 6-3. 전체 통과 후
- scenario-tester 실행 (있으면)
- Codex 교차 리뷰 (활성화 시)
  ```bash
  codex exec -c model_reasoning_effort=xhigh -s read-only -C {project-path} "다음 코드 변경사항을 리뷰해라: ..."
  ```
- Leader 최종 판단 → 머지

### 6-4. 종료
전체 작업 완료 → 모든 에이전트 일괄 shutdown (SendMessage type: shutdown_request)
팀 정리 (TeamDelete)

## 운영 규칙

- **에이전트 생명주기**: 전체 작업 끝날 때까지 종료하지 않음. idle이어도 유지.
- **쿼터 인식**: 에이전트 1명 ≈ 7x 소모. 5명 이하 권장. 쿼터 부족 시 즉시 축소.
- **opus는 Leader뿐**: 나머지 sonnet(개발) / haiku(테스트).
- **파일 격리**: 도메인 에이전트는 자기 도메인 파일만 수정. 공유 파일 수정 시 Leader 승인.
- **테스터는 수정 안 함**: 버그 리포트만. 수정은 해당 도메인 에이전트가.
- **Codex 리뷰**: 머지 전 최종 리뷰에만 (매 커밋마다 X). xhigh로 깊게.
- **토큰 효율화**: 에이전트는 구현 전 반드시 Explore 서브에이전트로 파악 먼저. 비싼 모델로 전체 파일 순차 읽기 금지.
- **피어 직접 통신**: 세부 기술 협의(인터페이스 충돌, API 타입 확인 등)는 에이전트끼리 직접 SendMessage. Leader는 완료/이슈 보고만 수신. Leader 경유 오버헤드 최소화.
