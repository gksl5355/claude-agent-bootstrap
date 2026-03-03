---
name: spawn-team
description: This skill should be used when the user asks to "create a team", "spawn a team", "start team agents", "set up a dev team", or wants to begin parallel development with Claude Code Agent Teams. Analyzes the project, detects domains, and spawns an optimized team of agents dynamically.
argument-hint: "[project path]"
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(codex *), Bash(find *), Bash(wc *), Bash(sg *), Task, TaskCreate, TaskUpdate, TaskList, TeamCreate, TeamDelete, SendMessage, AskUserQuestion
---

# Spawn Team

프로젝트를 분석하여 도메인 기반으로 최적화된 Claude Code Agent Teams를 동적 구성하고 운영한다.

## Step 0: 의도 분류 & 명확화

작업 유형과 범위를 빠르게 파악하여 이후 전략을 결정한다. **빠르게 — 대부분 추가 질문 없이 통과.**

### 0-1. 사전 스캔 (자동, 질문 없음)

프로젝트 루트를 빠르게 확인:
- package.json / requirements.txt / go.mod 등 → 기술 스택 힌트
- 디렉토리 구조 (src/, app/, lib/) → 규모 추정
- .git 여부 → worktree 가능 여부

### 0-2. 조건부 질문 (필요 시만)

**케이스 A — 구조 비표준 (모노레포, 단일 파일 등):**
```
AskUserQuestion: "주요 도메인을 지정해주세요. (예: auth, products, orders)"
```

**케이스 B — 요청이 모호 ("이 프로젝트 좀 개선해줘" 등 구체성 부족):**
```
AskUserQuestion:
  "이건 뭔가요?
   1) 새 기능 추가  2) 버그 수정  3) 리팩터링  4) 조사/분석"
```

**케이스 C — 명확한 경우 (대부분):**
→ 추가 질문 없이 바로 Step 1.

### 0-3. Output

```
task_type: FEATURE | BUG_FIX | REFACTOR | RESEARCH | AUTO
clarity: HIGH | MEDIUM | LOW
→ Step 1로 진행
```

## Step 1: 프로젝트 분석

프로젝트 루트를 스캔한다. **1-1과 1-2는 독립적이므로 동시에 실행.**

### 1-1. 기술 스택

package.json, requirements.txt, go.mod, Cargo.toml 등에서 기술 스택 파악.

### 1-2. 도메인 감지 + 구조 타입 판단

**도메인 감지:**

BE: `routes/`, `controllers/`, `services/`, `handlers/` 내 파일명으로 추출
FE: `pages/`, `views/` 내 파일명/폴더명으로 추출

**→ 감지 후 즉시 구조 타입 판단 (소유 모델 결정):**

```
[A] 도메인 디렉토리 구조 ← 기본 경로
    src/auth/**, src/products/** 처럼 도메인별 디렉토리가 있거나
    신규 프로젝트라 그렇게 만들 수 있는 경우
    → 에이전트가 디렉토리 단위 소유 (경계 = 디렉토리)

[B] 평면 구조 ← 폴백
    src/services/auth.ts, src/routes/auth.ts 처럼 기능별 디렉토리
    → 파일 레벨 MECE 매니페스트 사용 (각 파일을 에이전트에 명시 할당)

[C] 구조 불명확 / 레거시 ← architect-agent 온디맨드 스폰
    도메인 경계가 파악 불가하거나 파일이 도메인 구분 없이 혼재
    → architect-agent가 먼저 디렉토리 구조 제안 + 리팩터 후 [A]로 진행
```

**감지 실패 시** (모노레포, 비표준 구조):
- AskUserQuestion으로 도메인 + 소유 모델 직접 지정 요청
- 또는 fullstack 1명이 전체 담당

### 1-3. 도메인 규모 판단 → 소유권 매니페스트 생성

각 도메인의 파일 수를 세어 규모 판단:
- 소 도메인 (파일 1~3개) → 인접 도메인과 병합 후보
- 중 도메인 (파일 4~9개) → 독립 에이전트 1명
- 대 도메인 (파일 10+개) → 독립 에이전트 1명 (필요 시 분할 제안)

**Step 1의 최종 출력: 소유권 매니페스트 (구조 타입에 따라 형식 다름)**

```
[A] 도메인 디렉토리:
  products-be: src/products/**
  orders-be:   src/orders/**
  공유(Leader): src/types/**, src/utils/**

[B] 평면 구조:
  products-be: src/services/products.ts, src/routes/products.ts
  orders-be:   src/services/orders.ts, src/routes/orders.ts
  공유(Leader): src/types/index.ts
```

- 각 파일/디렉토리는 정확히 1개 항목에만 귀속
- 공유 파일/디렉토리는 Leader 소유 → 에이전트 수정 시 Leader 승인 필요
- 이 매니페스트가 Step 4 확인 → Step 5 에이전트 프롬프트로 그대로 흘러감

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

### 모델 선택 기준

| 태스크 특성 | 모델 |
|------------|------|
| 테스트 실행, 버그 분석, 빌드 수정 | Haiku |
| 일반 도메인 구현 (BE/FE) | Sonnet |
| 아키텍처 설계 (planner, architect-agent) | Sonnet |
| 리뷰 / 독립 분석 / 컨텍스트 분리 | Codex (codex exec) |

- **Haiku**: unit-tester, scenario-tester, debugger, build-fixer (분석/테스트 전용)
- **Sonnet**: fullstack, {domain}-be/fe, planner, architect-agent (구현)
- **Codex**: 머지 전 최종 리뷰 / 보안 리뷰 / 설계 비판 (항상 read-only, 팀 멤버 아님)

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

## Step 2B: 복잡도 판단 (자동)

Step 1-2 결과로 작업 복잡도를 **자동 평가**하여 계획 수립 필요성을 결정한다.

### 점수 산정 (사용자 질문 없음)

| 기준 | 1점 | 2점 | 3점 |
|------|-----|-----|-----|
| 도메인 수 | 1개 | 2-3개 | 4개+ |
| 파일 규모 | ≤10개 | 11-50개 | 51개+ |
| 도메인 간 의존성 | 독립적 | 낮음 (일부 공유) | 높음 (상호 의존) |
| 구조 타입 | [A] 명확 (1점) | [B] 평면 (2점) | [C] 불명확 (2점) |

### 분류

```
합계 4-6점  → SIMPLE:  바로 Step 4 (사용자 확인)
합계 7-9점  → MEDIUM:  Step 2.5 (범위 확인) → Step 4
합계 10-11점 → COMPLEX: Step 2.5 → Step 3 (계획 수립) → Step 4

자동 COMPLEX 판정 (점수 무관):
  - 사용자가 "계획해줘" / "plan" 명시
  - 구조 [C] (레거시/불명확)
  - Step 0에서 clarity=LOW 판정
```

### 사용자 오버라이드

```
AskUserQuestion:
  "복잡도: {SIMPLE|MEDIUM|COMPLEX}. 이대로 진행할까요?
   1) 이대로 진행 (Recommended)
   2) 계획 수립 후 진행
   3) 범위 조정 필요"
```

## Step 2.5: 범위 확인 (MEDIUM / COMPLEX만)

MEDIUM 이상일 때 범위(IN/OUT/DEFER)를 명시하여 작업 경계를 잠근다.

### Step 1 결과에서 자동 생성

```
IN (포함):
  - 감지된 모든 도메인 + 파일: {domain-list}
  - 공유 파일 (필요 시): src/types/**, src/utils/**

OUT (제외):
  - 외부 시스템 (결제 API 등) — 모킹만
  - 배포 파이프라인 (CI/CD)
  - 성능 최적화 (인덱싱, 캐싱)

DEFER (나중에):
  - 감지됐지만 우선순위 낮은 도메인
  - 국제화, 고급 검색 등
```

### 사용자 확인 (1회)

```
AskUserQuestion:
  "범위 확인:
   ✓ IN: {list}
   ✗ OUT: {list}
   ? DEFER: {list}

   1) 맞음 → 진행 (Recommended)
   2) 조정할 항목 있음"
```

조정 시 → 추가 AskUserQuestion으로 수정 후 재확인.

### 범위 잠금

Step 2.5 확인 후 범위 변경 시도 시 경고:
```
"범위가 변경됐습니다. 재평가하시겠어요?
 1) 재평가  2) 현재 팀으로 진행"
```

## Step 3: 계획 수립 (COMPLEX만)

작업을 구체적 계획으로 전환하여 팀 실행 시 방향 불일치를 방지한다.
**COMPLEX 또는 사용자 요청 시에만 실행. SIMPLE/MEDIUM은 이 단계를 건너뛴다.**

### 3-1. 구조화 인터뷰 (3~5개 질문)

사용자에게 순차적으로 묻는다. **각 질문은 짧게, AskUserQuestion 사용.**

```
Q1 핵심 목표: "최종 목표가 뭔가요? 1-2문장으로."
Q2 성공 기준: "성공 기준 3개 (측정 가능하게). 예: 'API 완성', '테스트 90%' 등."
Q3 제약사항: "제약이 있나요? (시간, 기술 제한 등) 없으면 '없음'."
Q4 위험 요소: "잘못되면 뭐가 깨질까요? 심각한 것 3개까지."
Q5 순서 선호: "단계 순서가 있나요? 없으면 팀이 최적 순서 결정."
```

### 3-2. Wave 분해 (자동 생성)

인터뷰 응답 + Step 1 소유권 매니페스트 기반으로 실행 파도를 자동 구성:

```
Wave 1 (병렬): 기초 — 타입 정의, DB 스키마, 공유 인터페이스
Wave 2 (병렬): 핵심 구현 — 각 도메인 독립 로직
Wave 3 (순차): 통합 — 도메인 간 API 연결, 공유 파일 수정
Wave 4 (병렬): 검증 — unit-test + scenario-test
Wave 5: 최종 — Codex 리뷰 + 머지
```

각 Wave 에:
- 병렬 가능 태스크 그룹
- 의존성 명시 (Wave N은 Wave N-1 완료 필요)
- 담당 에이전트 지정 (소유권 매니페스트 기반)
- 완료 조건

### 3-3. 도메인별 완료 기준 (자동 생성)

사용자 성공 기준(Q2)을 도메인별로 분배:

```
products-be:
  ✓ CRUD 엔드포인트 작동
  ✓ 단위 테스트 PASS
  ✓ 에러 응답 형식 통일

orders-be:
  ✓ 주문 생성/조회/취소 작동
  ✓ products-be 통합 검증
```

### 3-4. 계획 검증 (자동 체크)

```
✓ 각 Wave 완료 조건이 측정 가능한가?
✓ 순환 의존성 없는가?
✓ 한 에이전트에 태스크 >10개 아닌가?
✓ 위험 요소(Q4)가 완료 기준에 반영됐는가?

위반 시 → AskUserQuestion: "경고: {list}. 수정할까요, 이대로 진행할까요?"
```

### 3-5. 계획 확인

```
AskUserQuestion:
  "계획 완성:
   목표: {goal}
   Wave: {count}개, 태스크 {total}개
   성공 기준: {criteria}

   1) 승인 → Step 4로 (Recommended)
   2) 수정하기 → Q1부터 재시작"
```

## Step 4: 사용자 확인

팀 구성과 (있으면) 계획을 최종 승인한다.

AskUserQuestion으로 다음을 확인:

**질문 1**: 팀 구성 확인
- 분석 결과와 추천 팀 구성 표시
- 에이전트별 담당 파일 범위
- 병합된 도메인 설명
- (COMPLEX 시) 계획 Wave 요약 포함
- 옵션: 추천대로 / 조정

**질문 2**: Codex 활성화
- "Codex CLI를 머지 전 최종 리뷰에 사용할까요?"
- 옵션: 사용 / 사용 안 함

## Step 5: 팀 스폰

### 5-1. 팀 생성

TeamCreate로 팀을 생성한다.

### 5-2. 에이전트 스폰

각 에이전트를 Task로 스폰한다:
- `subagent_type: "general-purpose"`
- `team_name: "{team-name}"`
- `name: "{domain}-{role}"` (예: auth-be, dashboard-fe, unit-tester)
- `model: "sonnet"` (개발자) 또는 `"haiku"` (테스터)
- `isolation: "worktree"` (isolated 모드 시) ← **git 저장소 필수. 비git 프로젝트는 silent fallback으로 같은 디렉토리에서 작업함**
- `run_in_background: true` (병렬 스폰)

**worktree 전제조건 체크 (스폰 전):**
```bash
git -C {project-path} rev-parse --is-inside-work-tree 2>/dev/null
# 실패 시 → isolated 불가. 경고 출력 후 shared 모드로 전환.
# 경계는 프롬프트 지시(담당 파일 범위)로만 집행.
```

**스폰 부분 실패 시** (일부 에이전트만 생성됨):
- TeamDelete로 전체 롤백
- 사용자에게 알림 후 재시도 제안

프롬프트에 반드시 포함:
- 담당 파일 범위 (구체적 glob 패턴)
- **팀 전체 멤버 목록** (피어 직접 통신용): `팀 멤버: auth-be, tasks-be, unit-tester, ...`
- **서브에이전트 탐색 지시** (담당 파일 수 기준, 프롬프트에 아래 텍스트 중 하나를 직접 삽입):

  [담당 파일 ≤ 5개]:
  ```
  담당 파일이 적으므로 직접 Read 후 구현하세요. Grep으로 타입 확인 후 진행.
  ```

  [담당 파일 6~15개]:
  ```
  구현 전 이 순서로 파악하세요:
  1. Task(subagent_type="Explore")로 담당 범위 스캔 (파일 목록, 주요 export)
  2. Grep 또는 sg(ast-grep)으로 관련 타입/인터페이스 검색
  3. 필요한 파일만 Read
  ```

  [담당 파일 16+개]:
  ```
  구현 전 반드시 이 순서로 파악하세요 (순차 읽기 금지):
  1. Task(subagent_type="Explore")로 담당 범위 전체 스캔
  2. sg(ast-grep)으로 구조 파악: 인터페이스, export 함수, 클래스 목록
     예: sg -p 'export function $F($_$$)' --lang ts src/server/
  3. Grep으로 텍스트 검색 보완
  4. 실제 수정할 파일만 Read
  ```

- **(COMPLEX 시) Wave 정보**: "Wave 1 담당: {tasks}. Wave 1 완료 후 Wave 2 시작."

### 5-3. 에이전트 프롬프트

모든 에이전트 프롬프트에 아래 **공통 헤더**를 먼저 삽입한 뒤, 역할별 섹션을 추가한다.

**[공통 헤더]**
```
프로젝트: {project-path}
팀 멤버: {team-members}  ← 피어 직접 통신용 (예: auth-be, tasks-be, unit-tester)

## 담당 파일 범위 (MECE — 수정 가능 파일 전체 목록)
담당: {file-list}
금지: 담당 목록 외 모든 파일 (읽기는 가능, 수정 금지)

⚠ 경계 규칙:
- 공유 파일(types/, utils/, shared/) 수정 필요 → 즉시 중단 후 Leader 승인 요청
- 담당 범위 외 파일 수정 감지 시 → 즉시 revert 후 Leader 보고
- 구현 시작 전: Leader에게 "담당 파일 확인: {파일 목록}" 메시지 전송 필수

## 코드 탐색 전략 (토큰 효율화)
{explore-strategy}

## 피어 통신 원칙
- 세부 기술 협의(타입 충돌, API 응답 구조 등)는 관련 에이전트에게 직접 SendMessage.
- Leader에게는 완료/이슈만 보고. 결정권과 상태 truth는 Leader.
- 공유 파일 수정은 반드시 Leader 경유. 동시 수정 절대 금지.
```

---

**도메인 개발 에이전트 (BE):**
```
{공통 헤더}

당신은 {domain} 도메인 백엔드 개발자({name})입니다.

담당 파일 범위:
{file-list}

## 구현 규칙
- 담당 파일 범위만 수정. 다른 도메인 파일 절대 수정 금지.
- 구현 완료 → TaskUpdate(completed) + Leader에게 SendMessage 보고.
- 막히면 2~3회 자체 시도 후 Leader에게 요청.
- 테스터 버그 리포트 수신 → 수정 후 재보고.
```

**도메인 개발 에이전트 (FE):**
```
{공통 헤더}

당신은 {domain} 도메인 프론트엔드 개발자({name})입니다.

담당 파일 범위:
{file-list}

## 구현 규칙
- 담당 파일 범위만 수정. 다른 도메인 파일 절대 수정 금지.
- Tailwind CSS로 스타일링 (프로젝트에 Tailwind 있을 시).
- 구현 완료 → TaskUpdate(completed) + Leader에게 SendMessage 보고.
- 막히면 2~3회 자체 시도 후 Leader에게 요청.
- 테스터 버그 리포트 수신 → 수정 후 재보고.
```

**unit-tester:**
```
{공통 헤더}

당신은 유닛 테스터({name})입니다.
테스트 프레임워크: {test-framework}

역할: 각 모듈/함수가 정상 작동하는지 단위 테스트 작성 및 실행.

## 테스트 규칙
- Leader 지시 → 해당 코드 단위 테스트 작성 및 실행.
- 외부 의존성(DB, API)은 모킹.
- PASS → Leader에게 "PASS: {테스트 수} 통과" 보고.
- FAIL → Leader 보고 + 해당 도메인 에이전트에게 직접 SendMessage (동시):
  - 실패한 테스트명
  - 예상값 vs 실제값
  - 해당 파일:라인
  - 재현 방법
- 코드를 직접 수정하지 않는다.
```

**scenario-tester:**
```
{공통 헤더}

당신은 시나리오 테스터({name})입니다.

역할: 전체 유저 플로우 / API 흐름이 올바르게 동작하는지 시나리오 기반 테스트.

## 테스트 규칙
- 전체 구현 완료 후 Leader 지시로 시작.
- Leader가 제공한 유저 시나리오를 단계별로 검증.
  예: "회원가입 → 로그인 → 프로젝트 생성 → 태스크 추가"
- FAIL → 어느 단계에서 실패했는지 Leader + 해당 에이전트에게 보고.
  형식: 단계명, 기대 동작, 실제 동작, 재현 방법
- 코드를 직접 수정하지 않는다.
```

**fullstack (소규모):**
```
{공통 헤더}

당신은 풀스택 개발자({name})입니다.
모든 BE + FE 코드를 담당합니다.

## 구현 규칙
- 구현 완료 → TaskUpdate(completed) + Leader에게 보고.
- 막히면 2~3회 자체 시도 후 Leader에게 요청.
- 테스터 버그 리포트 수신 → 수정 후 재보고.
```

## 도메인 경계 & Worktree 머지 프로토콜

Step 1-4에서 생성한 MECE 매니페스트를 기반으로 경계를 집행하고 머지 충돌을 방지한다.

### Plan Mode 승인 게이트 (에이전트 3명+, 도메인 의존성 높을 시 권장)

에이전트를 `mode: "plan"` 으로 스폰 → 구현 계획 제출 → Leader 검토 후 승인:

```
plan_approval_response 판단 기준:
  ✅ 담당 파일 범위 내에서만 수정 계획
  ✅ 공유 파일 무단 수정 계획 없음
  ✅ 타 도메인 API 계약 변경 없음
  ❌ 위 위반 시 → approve: false + 구체적 피드백 전달
```

### Worktree 머지 전 경계 위반 체크

각 에이전트 워크트리 머지 전 Leader가 필수 확인:

```bash
# 에이전트가 담당 범위 외 파일을 수정했는지 확인
git -C {worktree-path} diff --name-only main | grep -vE "{domain-file-pattern}"
# 결과가 있으면 → 해당 에이전트에게 revert 지시 후 재확인
```

### Worktree 머지 순서 (순차 실행 — 병렬 머지 금지)

```
1. 공유 파일 변경 먼저 (types/, utils/) — Leader 직접 처리
2. 의존성이 낮은 도메인 (독립적 BE/FE 서비스)
3. 의존성이 높은 도메인 (다른 서비스를 import하는 쪽)
4. 테스트 코드 마지막
```

각 머지 후 빌드 확인 → FAIL → build-fixer 투입 후 다음 단계.

### 머지 충돌 발생 시

```
자동 해결 가능 → Leader가 직접 처리 후 계속
수동 판단 필요 → AskUserQuestion:
  "머지 충돌: {파일명}. 어느 쪽 변경을 기준으로 할까요?
   옵션: 1) {에이전트 A} 버전  2) {에이전트 B} 버전  3) 수동 병합"
```

### 공유 타입/스키마 변경 플로우

공유 파일(types/, utils/, shared/) 변경은 모든 에이전트에게 영향. 특별 절차 적용.

```
변경 요청 발생 시 (에이전트 → Leader 보고):

1. Leader가 변경 분석:
   - 비파괴적 (필드 추가, 새 타입) → 즉시 승인 가능
   - 파괴적 (필드 제거/타입 변경) → Debate 트리거 고려 (irreversible 성격)

2. 영향 에이전트 일시 중단 요청:
   SendMessage → 관련 에이전트: "공유 타입 변경 예정. 현재 작업 잠시 중단."

3. Leader가 직접 공유 파일 수정 (에이전트에게 위임 금지)

4. 변경 완료 후 영향 에이전트에게 알림:
   "공유 타입 변경 완료: {변경 내용}. 해당 부분 적용 후 작업 재개."

5. 모든 에이전트 적용 완료 확인 → unit-tester 재실행
```

## Step 6: 작업 지시 대기

팀 스폰 완료 후 표시:
```
팀 준비 완료.

에이전트:
  {name} ({model}) — {file-range}
  ...

Codex: 활성화 / 비활성화
워크트리: isolated / shared
복잡도: {SIMPLE|MEDIUM|COMPLEX}
범위: IN {count}개 도메인 / OUT {count}개 제외
계획: {Wave count}개 Wave (COMPLEX 시) / 없음

작업을 지시해주세요.
```

## Step 7: 실행 & 피드백 루프

사용자가 작업을 지시하면:

### 7-1. 태스크 분배
- 도메인 에이전트에게 SendMessage로 구현 지시
- 독립 도메인은 병렬, 의존 있으면 blockedBy
- **(COMPLEX 시) Wave 순서 준수**: Wave 1 완료 → Wave 2 시작. Wave 내 태스크는 병렬.

### 7-2. 구현 → 테스트 루프

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
               debugger 완료 → Leader가 결과를 해당 에이전트에게 SendMessage로 전달 → 에이전트 수정 → 재검증
               debugger 자동 종료 (팀 멤버 아님)
           → debugger 후에도 FAIL
               [circuit breaker] AskUserQuestion으로 사용자에게 상황 보고:
               "에이전트 수정 3회 + debugger 분석 후에도 실패. 선택: 1) Leader 직접 개입 2) 해당 기능 스킵 3) 중단"
               무한 루프 없이 중단
```

### 7-2-c. 구조 [C] — architect-agent 온디맨드 스폰 (Step 1에서 판단, 코딩 전 1회)

```
Step 1-2에서 구조 타입 [C] (불명확/레거시) 판정 시:
  → architect-agent 온디맨드 스폰:
      Task(subagent_type="general-purpose", name="architect", model="sonnet",
           run_in_background=false)
      프롬프트: "다음 프로젝트의 도메인 디렉토리 구조를 설계하라:
                현재 구조: {현재 파일 목록}
                감지된 도메인: {domain-list}
                목표: 도메인별 디렉토리(src/auth/**, src/products/** 등) 제안
                출력: 1) 제안 구조 2) 이동할 파일 목록 3) import 경로 수정 계획
                직접 수정 금지 — 계획만 출력"
  → Leader가 계획 검토 → AskUserQuestion으로 사용자 승인
  → 승인 후 architect-agent가 실제 리팩터 실행 (파일 이동, import 수정)
  → 완료 후 자동 종료 → 구조 [A]로 진행
  → architect-agent 실패 → 구조 [B] (파일 레벨 MECE)로 폴백
```

### 7-2-b. 빌드 실패 시

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

### 7-3. 전체 통과 후

```
1. scenario-tester 실행 (있으면)
   FAIL → 해당 에이전트 수정 → 재검증. 통과 후에만 다음 단계로.
2. Worktree 머지 (isolated 모드 시):
   → "도메인 경계 & Worktree 머지 프로토콜" 참조
   → 경계 위반 체크 → 순차 머지 → 각 단계 빌드 확인
3. Codex 교차 리뷰 (활성화 시, 머지 후 1회):
     codex exec -c model_reasoning_effort=xhigh -s read-only -C {project-path} \
       "다음 코드 변경사항을 리뷰해라: ..."
   Codex 실패 (미설치/권한 오류/타임아웃):
     → 경고 출력 후 스킵. 전체 플로우 중단 X.
     → Leader가 직접 리뷰로 대체 또는 사용자에게 알림.
4. Leader 최종 판단 → 완료 보고
```

### 7-4. 종료

```
종료 조건 (AND):
  1. 모든 TaskList 항목 completed
  2. unit-tester PASS
     flaky 의심 시 (코드 변경 없이 재실행하면 결과가 달라짐):
       → 재실행 1회. PASS → 정상으로 간주. FAIL → circuit breaker 진입
  3. scenario-tester PASS (있을 때)
  4. Codex 리뷰 완료 (활성화 시)
  5. (COMPLEX 시) 모든 Wave 완료 + 도메인별 완료 기준 충족

→ 모든 에이전트 일괄 shutdown_request 전송
→ TeamDelete

예외:
  쿼터 임계치 도달 → 즉시 사용자 알림 → 판단 후 종료/에이전트 수 축소
```

## Debate Mode (아키텍처 결정 검토)

아키텍처/설계 결정을 Codex xhigh와 적대적으로 검토. blind spot 제거.

### 진입 조건

**하드 트리거 (무조건 debate):**
- `irreversible=true`: DB 스키마, 외부 API 계약, 인증 방식 등 되돌리기 어려운 결정
- `영향범위=3`: 전체 시스템 영향 (공용 타입, 공유 미들웨어, 배포 파이프라인)

**소프트 트리거 (위험도 합계 6+ 시):**
- 사용자 명시 요청 ("debate", "아키텍처 토론") — 일반 "검토해줘"는 해당 없음
- 기술 선택지 2개 이상 + 팀 전체 영향

**위험도 점수 (각 1-3점, 합산):**

| 축 | 1점 | 2점 | 3점 |
|----|-----|-----|-----|
| 불확실성 | 검증된 패턴 | 일부 불확실 | 실험적/전례 없음 |
| 영향 범위 | 단일 서비스 | 2개 도메인 이하 | 전체 시스템 |
| 복잡도 | 단순 구현 | 중간 | 크로스 레이어 |

- 합계 6-7점 → Leader Judge (근거 문서화)
- 합계 8-9점 또는 하드 트리거 → 사용자 최종 Judge (AskUserQuestion)
- 영향범위=3 또는 irreversible=true → 점수 무관 하드 트리거 적용

→ **조건 충족 시 debate 스킬의 프로토콜을 따른다.**

**상세 프로토콜**: `.claude/skills/debate/SKILL.md` 참조.

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
- **소유 모델**: [A] 도메인 디렉토리 (기본) / [B] 파일 레벨 (평면 구조 폴백) / [C] architect-agent 먼저 (레거시/불명확). Step 1-2에서 자동 판정.
- **MECE 경계**: 소유권 매니페스트는 Step 1-4에서 생성·확인. 각 파일/디렉토리는 정확히 1개 에이전트 소유. 경계 위반 시 즉시 revert.
- **Worktree 머지**: 순차 실행. 병렬 머지 금지. 공유 파일 먼저, 의존성 낮은 순. 머지 전 경계 위반 체크.
- **Plan Mode 게이트**: 에이전트 3명+, 도메인 의존성 높을 때 구현 전 계획 승인. approve: false + 피드백으로 방향 수정.
- **Debate**: 하드 트리거 또는 위험도 6+ 안건만. 2라운드 상한. BLOCK 이견 시 사용자 에스컬레이션. 무한 루프 금지.
- **Planning 게이트**: Step 2B 자동 복잡도 판단 → SIMPLE은 계획 없이 빠르게, COMPLEX만 Step 3 인터뷰. 단순 작업에 과도한 계획 강제 금지.
- **범위 잠금**: Step 2.5에서 확인한 IN/OUT/DEFER는 실행 중 변경 시 경고. 범위 추가 시 사용자 재확인 필수.
