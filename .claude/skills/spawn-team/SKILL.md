---
name: spawn-team
description: This skill should be used when the user asks to "create a team", "spawn a team", "start team agents", "set up a dev team", or wants to begin parallel development with Claude Code Agent Teams. Analyzes the project, detects domains, and spawns an optimized team of agents dynamically.
argument-hint: "[project path]"
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(codex *), Bash(find *), Bash(wc *), Bash(sg *), Task, TaskCreate, TaskUpdate, TaskList, TeamCreate, TeamDelete, SendMessage, AskUserQuestion
---

# Spawn Team

프로젝트를 분석하여 도메인 기반으로 최적화된 Claude Code Agent Teams를 동적 구성하고 운영한다.

## Step 0: 의도 분류 & 명확화

**빠르게 — 대부분 추가 질문 없이 통과.**

1. **사전 스캔** (자동): package.json/requirements.txt/go.mod → 스택, src/app/lib → 규모, .git → worktree 가능 여부
2. **조건부 질문** (필요 시만): 구조 비표준 → 도메인 지정 요청 / 요청 모호 → 유형 선택 / 명확 → 바로 Step 1
3. **Output**: `task_type: FEATURE|BUG_FIX|REFACTOR|RESEARCH|AUTO`, `clarity: HIGH|MEDIUM|LOW`

## Step 1: 프로젝트 분석

**1-1과 1-2는 동시 실행.**

### 1-1. 기술 스택
package.json, requirements.txt, go.mod, Cargo.toml 등에서 파악.

### 1-2. 도메인 감지 + 구조 타입

BE: routes/controllers/services/handlers 내 파일명. FE: pages/views 내 파일명.

**구조 타입 → 소유 모델:**

| 타입 | 조건 | 소유 모델 |
|------|------|----------|
| [A] 도메인 디렉토리 (기본) | src/auth/**, src/products/** | 디렉토리 단위 소유 |
| [B] 평면 구조 (폴백) | src/services/auth.ts 등 기능별 | 파일 레벨 MECE 매니페스트 |
| [C] 불명확/레거시 | 도메인 경계 파악 불가 | architect-agent 먼저 → [A] 전환 |

감지 실패 시: AskUserQuestion으로 직접 지정 또는 fullstack 1명 전담.

### 1-3. 도메인 규모 → 소유권 매니페스트

규모: 소(1-3파일)=병합 후보, 중(4-9)=독립 1명, 대(10+)=독립 1명(분할 제안).

**최종 출력** — 각 파일/디렉토리는 정확히 1개 항목 귀속, 공유는 Leader 소유:
```
products-be: src/products/**
orders-be:   src/orders/**
공유(Leader): src/types/**, src/utils/**
```

## Step 2: 팀 구성 제안 (동적)

**5명 상한 엄수. 프로젝트에 맞춰 동적 생성.**

| 규모 | 구성 | 워크트리 |
|------|------|---------|
| 소 (1-2명) | fullstack(sonnet) + unit-tester(haiku) | shared |
| 중 (3-4명) | 도메인별 be/fe(sonnet) + unit-tester(haiku) | isolated |
| 대 (5명 상한) | planner(sonnet) + 도메인(sonnet, 병합 2명 이내) + tester(haiku) ×2 | isolated |

도메인 많으면 소규모 병합. 워크트리: 3명+ → isolated, 2명 이하 → shared.

### 모델 선택 (복잡도 연동)

| 모델 | 용도 | 언제 |
|------|------|------|
| **Opus** | Leader 오케스트레이션, planner, architect-agent | COMPLEX 전용 |
| Sonnet | fullstack, {domain}-be/fe, planner(MEDIUM 이하) | 기본 구현 |
| Haiku | unit-tester, scenario-tester, debugger, build-fixer | 테스트/반복 |
| Codex xhigh | 머지 전 최종 리뷰 (read-only, 팀 멤버 아님) | 리뷰 1회 |

**복잡도별 모델 승격:**
- **SIMPLE**: Leader=Sonnet, 전원 Sonnet/Haiku. Opus 사용 금지 (비용 5x).
- **MEDIUM**: Leader=Sonnet+thinking, planner=Sonnet. Opus 불필요.
- **COMPLEX**: Leader=**Opus**, planner=**Opus**, architect-agent=**Opus**. 도메인 에이전트는 Sonnet 유지.
  - Opus 필수 근거: Wave 분해 + 5명 조율 + 도메인 간 의존성 판단은 깊은 추론 필요.
  - 도메인 에이전트(구현)는 Sonnet으로 충분 — Opus는 오케스트레이션에만.

## Step 2B: 복잡도 판단 (자동)

| 기준 | 1점 | 2점 | 3점 |
|------|-----|-----|-----|
| 도메인 수 | 1개 | 2-3개 | 4개+ |
| 파일 규모 | ≤10 | 11-50 | 51+ |
| 의존성 | 독립 | 낮음 | 높음 (상호 의존) |
| 구조 | [A]=1 | [B]=2 | [C]=2 |

```
4-6점  → SIMPLE:  바로 Step 4
7-9점  → MEDIUM:  Step 2.5 → Step 4
10-11점 → COMPLEX: Step 2.5 → Step 3 → Step 4
자동 COMPLEX: "계획해줘"/plan 명시, 구조 [C], clarity=LOW
```

사용자 오버라이드: "복잡도: {X}. 1) 진행 2) 계획 수립 3) 범위 조정"

## Step 2.5: 범위 확인 (MEDIUM/COMPLEX만)

Step 1에서 자동 생성 → AskUserQuestion 1회:
- **IN**: 감지된 도메인+파일+공유 / **OUT**: 외부 시스템(모킹만), CI/CD, 성능 / **DEFER**: 우선순위 낮은 도메인
- 확인 후 **범위 잠금**. 변경 시도 → 경고 + 재확인 필수.

## Step 3: 계획 수립 (COMPLEX만)

**SIMPLE/MEDIUM은 건너뛴다.**

### 3-1. 구조화 인터뷰 (AskUserQuestion, 3~5개)
Q1 핵심 목표(1-2문장) / Q2 성공 기준 3개(측정 가능) / Q3 제약사항 / Q4 위험 요소 / Q5 순서 선호

### 3-2. Wave 분해 (자동, 인터뷰+매니페스트 기반)
```
Wave 1(병렬): 기초 — 타입, 스키마, 공유 인터페이스
Wave 2(병렬): 핵심 — 각 도메인 독립 로직
Wave 3(순차): 통합 — 도메인 간 연결, 공유 파일
Wave 4(병렬): 검증 — unit + scenario test
Wave 5: 최종 — Codex 리뷰 + 머지
```
각 Wave: 병렬 태스크, 의존성, 담당 에이전트, 완료 조건.

### 3-3. 도메인별 완료 기준
Q2를 도메인별 분배 (구체적, 측정 가능).

### 3-4. 검증 + 확인
자동 체크: 측정 가능? 순환 의존? 에이전트당 ≤10태스크? 위험 반영?
위반 → AskUserQuestion. 최종 승인 후 Step 4.

## Step 4: 사용자 확인

AskUserQuestion 2개:
1. **팀 구성** — 에이전트별 담당 범위 (COMPLEX 시 Wave 요약 포함). 옵션: 추천대로 / 조정
2. **Codex 활성화** — 머지 전 최종 리뷰 사용 여부

## Step 5: 팀 스폰

### 5-1. TeamCreate → 5-2. 에이전트 스폰

각 에이전트: `subagent_type: "general-purpose"`, `team_name`, `name: "{domain}-{role}"`, `model`, `run_in_background: true`

**⚠ Worktree 규칙 (스폰 전 반드시 확인):**
1. 에이전트 3명 이상 → **반드시** `isolation: "worktree"` 설정. 생략 금지.
2. 에이전트 2명 이하 → shared (isolation 생략).
3. 스폰 전 `git rev-parse --is-inside-work-tree` 실행 → 실패 시 shared로 전환 + 사용자 알림.
4. worktree 사용 시 모든 에이전트에 동일하게 적용 (일부만 worktree 금지).

스폰 부분 실패: TeamDelete 롤백 → 알림 → 재시도 제안.

### 5-3. 에이전트 프롬프트

**[공통 헤더] — 모든 에이전트에 삽입:**
```
프로젝트: {project-path}
팀 멤버: {team-members}

## 담당 범위 (MECE)
담당: {file-list}
금지: 담당 외 수정 금지 (읽기 가능)

⚠ 경계: 공유 파일 수정 → Leader 승인 | 범위 외 수정 → revert+보고 | 시작 전 "담당 확인: {목록}" 전송

## 탐색 (토큰 효율화)
{≤5파일: 직접 Read+Grep | 6-15: Explore→Grep/sg→Read | 16+: Explore→sg→Grep→필요한 파일만 Read}

## 런타임 토큰 절약
- 같은 파일 반복 Read 금지 — 한 번 읽은 내용은 메모리에 유지하고 재사용.
- Tool output이 과도하게 길면 핵심만 추출 (전체 붙여넣기 금지).
- 에러 디버깅 시 전체 스택트레이스 대신 관련 라인만 인용.
- 구현 전 탐색(Explore/Grep)과 실제 구현을 한 턴에 섞지 말 것 — 탐색 완료 후 구현 시작.
- **파일 15개 초과 읽었으면 탐색 중단** → 파악 내용 요약 후 구현 시작. 막히면 Leader에게 보고.

## 피어 통신
세부 기술 → 관련 에이전트 직접 SendMessage. Leader에게는 완료/이슈만. 공유 파일 → Leader 경유.

## Leader 보고 포맷
DONE: `상태: DONE | 파일: {경로목록} | 요약: {변경 내용 1줄}`
FAIL/BLOCKED: 위 + `ERR: 테스트:{name} 기대:{x} 실제:{y} 위치:{file:line} 재현:{cmd}`
```

**[역할별 — 공통 헤더 뒤에 추가]:**

| 역할 | 프롬프트 |
|------|---------|
| {domain}-be | "당신은 {domain} BE 개발자({name}). 담당만 수정. 완료→TaskUpdate+보고. 2-3회 시도 후 Leader 요청. 테스터 리포트→수정→재보고." |
| {domain}-fe | 위 동일 + "Tailwind CSS (프로젝트에 있을 시)." |
| unit-tester | "테스트 프레임워크: {fw}. Leader 지시→단위 테스트 작성·실행. 외부 모킹. PASS→보고. FAIL→Leader+해당 에이전트 동시 보고 (테스트명/예상vs실제/파일:라인/재현법). **코드 수정 금지.**" |
| scenario-tester | "구현 완료 후 Leader 지시로 시작. 유저 시나리오 단계별 검증. FAIL→단계/기대/실제/재현법 보고. **코드 수정 금지.**" |
| fullstack | "BE+FE 전체 담당. 완료→TaskUpdate+보고. 2-3회 시도 후 Leader 요청." |

(COMPLEX 시) Wave 정보 추가: "Wave {N} 담당: {tasks}. 완료 후 다음 Wave."

## 도메인 경계 & Worktree 머지 프로토콜

### Plan Mode 승인 게이트 (3명+, 의존성 높을 시)
`mode: "plan"` 스폰 → 계획 제출 → Leader: 담당 내 수정? 공유 무단 없음? API 변경 없음? → approve/reject+피드백.

### Worktree 머지 (순차 — 병렬 금지)
```
머지 전: git diff --numstat main → 100+LOC 변경 파일은 hunk 직접 확인. git diff --name-only main | grep -vE "{pattern}" → 범위 외 → revert
순서: 1.공유(Leader 직접) → 2.독립 도메인 → 3.의존 높은 도메인 → 4.테스트
각 머지 후 빌드 확인 → FAIL → build-fixer
충돌: 자동→Leader 처리 / 수동→AskUserQuestion
```

### 공유 타입/스키마 변경
변경 분석(비파괴→승인, 파괴→Debate 고려) → 영향 에이전트 중단 → Leader 직접 수정 → 알림 → 적용 확인 → unit-tester 재실행.

## Step 6: 작업 지시 대기

```
팀 준비 완료.
에이전트: {name}({model}) — {range} ...
Codex: 활성화/비활성화 | 워크트리: isolated/shared
복잡도: {X} | 범위: IN {n} / OUT {n} | 계획: Wave {n}개 / 없음
작업을 지시해주세요.
```

## Step 7: 실행 & 피드백 루프

### 7-1. 태스크 분배
SendMessage로 지시. 독립=병렬, 의존=blockedBy. (COMPLEX) Wave 순서 준수.

### 7-1-b. Wave 전환 요약 (COMPLEX — Wave 완료 시 필수)
```
> /tmp/wave-{N}-summary.md (상한 1500자)
결정: {이번 Wave 결정사항}
미결: {미해결 이슈}
검증: PASS {n} / FAIL {n}
다음: {Wave N+1 목표}
```
이후 이전 Wave 대화 대신 이 파일을 참조 우선. 자가 체크: [ ] 1500자 이하 [ ] 전 에이전트 상태 포함 [ ] 미결 누락 없음

### 7-2. 구현 → 테스트 루프
```
에이전트 완료 → unit-tester 검증
  PASS → 다음 단계
  FAIL → Leader+에이전트 보고 → 수정 → 재검증
    2회 FAIL → debugger 스폰(haiku, 분석만, 수정 금지) → 결과 전달 → 수정
    debugger 후 FAIL → [circuit breaker] AskUserQuestion: "1) Leader 개입 2) 스킵 3) 중단"
```

### 7-2-b. 빌드 실패
build-fixer 스폰(haiku, 해당 도메인 범위). 실패 → Leader/에스컬레이션.

### 7-2-c. 구조 [C] — architect-agent (코딩 전 1회)
**opus** (레거시 구조 분석은 깊은 추론 필요), 디렉토리 구조 설계 → Leader 검토 → 사용자 승인 → 리팩터 → [A] 전환. 실패 → [B] 폴백.

### 7-3. 전체 통과 후
1. scenario-tester → FAIL → 수정 → 재검증
2. Worktree 머지 (위 프로토콜)
3. Codex 리뷰 (활성화 시 1회). 실패 → 스킵.
4. 완료 보고

### 7-4. 종료
조건(AND): TaskList 전체 completed + unit-tester PASS + scenario-tester PASS + Codex 완료 + (COMPLEX) Wave+기준 충족.
→ 전체 shutdown_request → TeamDelete. 쿼터 임계치 → 즉시 알림 → 축소/종료.

## Debate Mode

아키텍처/설계 결정을 Codex xhigh와 적대적 검토. **상세: `.claude/skills/debate/SKILL.md` 참조.**

진입: 하드(irreversible=true / 영향범위=3) 또는 소프트(위험도 6+). 합계 6-7→Leader Judge / 8-9·하드→사용자 Judge.

## 운영 규칙

- idle 비용 없음 (메시지 시만 소모). 에이전트 전체 끝까지 유지.
- 쿼터: 1명≈7x. 5명 이하 엄수.
- 모델: COMPLEX→Leader/planner/architect=**Opus**, MEDIUM 이하→Sonnet+thinking. 개발=sonnet, 테스트=haiku.
- 파일 격리: 자기 도메인만. 공유→Leader. MECE: 파일당 1에이전트. 위반→revert.
- 테스터: 리포트만, 수정 금지. 피어 통신: 기술→직접, 결정→Leader.
- Codex: 머지 전 1회. 실패→스킵.
- 토큰: Explore 먼저, 비싼 모델 순차 읽기 금지. 같은 파일 반복 Read 금지. Tool output 핵심만 추출.
- Worktree: 3명+ → **반드시 isolation: "worktree"**. 순차 머지. 병렬 금지. main 직접 작업 금지.
- Leader 읽기: DONE 건은 git diff --numstat 확인만. 고위험(공개 API·auth·payment·100+LOC·FAIL 후 수정)은 hunk 직접 확인.
- Planning: SIMPLE=계획 없이, COMPLEX만 인터뷰. 범위 잠금 후 변경→경고.
