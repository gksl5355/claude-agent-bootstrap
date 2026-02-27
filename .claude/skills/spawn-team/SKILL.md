---
name: spawn-team
description: This skill should be used when the user asks to "create a team", "spawn a team", "start team agents", "set up a dev team", or wants to begin parallel development with Claude Code Agent Teams. Analyzes the project and spawns an optimized team of agents.
argument-hint: "[preset or project path]"
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(codex *), Task, TaskCreate, TaskUpdate, TaskList, TeamCreate, SendMessage, AskUserQuestion
---

# Spawn Team

Claude Code Agent Teams를 활용하여 프로젝트에 최적화된 개발 팀을 구성하고 스폰한다.

## 프리셋

```
minimal     — fullstack(sonnet) 1 + tester(haiku) 1  → 소규모, 버그 수정
balanced    — be(sonnet) 1 + fe(sonnet) 1 + tester(haiku) 1  → 중규모 균형
be-heavy    — planner(sonnet) 1 + be(sonnet) 2 + fe(sonnet) 1 + tester(haiku) 1  → BE 중심
fe-heavy    — planner(sonnet) 1 + be(sonnet) 1 + fe(sonnet) 2 + tester(haiku) 1  → FE 중심
custom      — 사용자 정의
```

## 실행 흐름

### Step 1: 인자 확인

`$ARGUMENTS`가 프리셋 이름이면 Step 3으로 건너뛴다.
인자가 없거나 프로젝트 경로면 Step 2로 진행한다.

### Step 2: 프로젝트 분석 → 프리셋 추천

프로젝트 루트를 스캔하여 다음을 파악한다:

1. **기술 스택**: package.json, requirements.txt, go.mod, Cargo.toml 등
2. **디렉토리 구조**: src/, api/, pages/, components/, server/, client/ 등
3. **규모 추정**: 주요 소스 파일 수
4. **기존 테스트**: test/, __tests__/, spec/ 존재 여부

판단 기준:
- 소규모 (소스 < 10파일) + 단순 작업 → `minimal`
- BE 파일 비중 > 60% → `be-heavy`
- FE 파일 비중 > 60% → `fe-heavy`
- 균형 또는 풀스택 → `balanced`
- 병렬 가능성 낮음 (순차 의존 높음) → `minimal` 유지

### Step 3: 팀 구성 제안

AskUserQuestion을 사용하여 다음을 확인한다:

**질문 1**: 프리셋 선택
- 추천 프리셋과 근거를 설명
- 옵션: 추천 프리셋 / 다른 프리셋 / custom

**질문 2**: Codex 활성화 여부
- "Codex CLI를 교차 리뷰/코딩 보조로 사용할까요?"
- 옵션: 사용 / 사용 안 함
- Codex 사용 시 Leader가 필요할 때 `codex exec`로 호출

### Step 4: 팀 스폰

승인 받으면 다음 순서로 실행한다:

1. **TeamCreate**: 팀 생성
   ```
   team_name: "{project-name}-team"
   ```

2. **TaskCreate**: 프리셋에 정의된 각 역할별 태스크 생성

3. **Task**: 각 역할별 에이전트 스폰
   - `subagent_type: "general-purpose"`
   - `team_name: "{team-name}"`
   - `name: "{role}{number}"` (예: be1, fe1, tester1)
   - `isolation: "worktree"` (isolated 모드 시)
   - 에이전트 프롬프트에 역할별 지시 포함 (아래 참조)

4. 모든 에이전트 스폰 완료 확인

### Step 5: 작업 대기

"팀 준비 완료" 메시지와 함께 다음을 표시한다:
- 스폰된 에이전트 목록 (이름, 역할, 모델)
- Codex 활성화 여부
- "작업을 지시해주세요."

사용자가 작업을 지시하면:
1. 작업을 독립 태스크로 분해 (파일/모듈 경계 기준)
2. 의존성 파악 → blockedBy 설정
3. 역할에 맞는 에이전트에 SendMessage로 할당
4. 에이전트 완료 보고 → tester 검증 → 리뷰 → 머지

## 역할별 에이전트 프롬프트

에이전트 스폰 시 prompt에 포함할 내용:

**planner**:
```
당신은 planner입니다. 아키텍처 설계와 기술 스펙 구체화를 담당합니다.
- Leader의 지시에 따라 설계 문서를 작성합니다
- 구현 에이전트들이 따를 수 있는 구체적인 스펙을 만듭니다
- 설계 결정의 근거를 함께 기록합니다
- 완료 시 Leader에게 SendMessage로 보고합니다
```

**be**:
```
당신은 백엔드 개발자입니다. 서버, API, DB, 비즈니스 로직을 구현합니다.
- 할당된 태스크만 집중하여 구현합니다
- 구현 완료 시 TaskUpdate로 상태 변경하고 Leader에게 보고합니다
- 막히면 2~3회 자체 해결 시도 후 Leader에게 도움을 요청합니다
- 다른 에이전트의 파일을 수정하지 않습니다
```

**fe**:
```
당신은 프론트엔드 개발자입니다. UI, 인터랙션, 스타일을 구현합니다.
- 할당된 태스크만 집중하여 구현합니다
- 구현 완료 시 TaskUpdate로 상태 변경하고 Leader에게 보고합니다
- 막히면 2~3회 자체 해결 시도 후 Leader에게 도움을 요청합니다
- 다른 에이전트의 파일을 수정하지 않습니다
```

**fullstack**:
```
당신은 풀스택 개발자입니다. 백엔드와 프론트엔드를 모두 담당합니다.
- 할당된 태스크만 집중하여 구현합니다
- 구현 완료 시 TaskUpdate로 상태 변경하고 Leader에게 보고합니다
- 막히면 2~3회 자체 해결 시도 후 Leader에게 도움을 요청합니다
```

**tester**:
```
당신은 테스터입니다. 테스트 작성과 품질 검증을 담당합니다.
- 구현 에이전트가 완료 보고하면 해당 코드의 테스트를 작성/실행합니다
- 테스트 통과 시 Leader에게 보고합니다
- 테스트 실패 시 구체적인 실패 내용과 함께 Leader에게 보고합니다
- 기존 테스트가 깨지지 않았는지도 확인합니다
```

**worker**:
```
당신은 워커입니다. 단순/반복 작업을 빠르게 처리합니다.
- 보일러플레이트, 마이그레이션, 파일 정리 등을 담당합니다
- 할당된 태스크를 빠르게 완료하고 Leader에게 보고합니다
```

## Codex 사용 (활성화 시)

Leader가 직접 Bash로 호출한다:

```bash
# 머지 전 교차 리뷰
codex exec -c model_reasoning_effort=xhigh -s read-only "다음 코드를 리뷰해라: ..."

# 독립 코딩 태스크
codex exec -c model_reasoning_effort=high -s workspace-write "구현해라: ..."

# 빠른 검증
codex exec -c model_reasoning_effort=low -s read-only "확인해라: ..."
```

사용 시점:
- 머지 전 중요 코드 교차 리뷰
- Claude 에이전트와 다른 관점이 필요할 때
- 독립적인 코딩 태스크 (쿼터 상황 고려)

## 운영 규칙

- **쿼터 인식**: 에이전트 1명 ≈ 7x 토큰 소모. 5명 이하 권장.
- **opus는 Leader뿐**: 나머지는 sonnet/haiku로 쿼터 절약.
- **에이전트가 막히면**: 2~3회 자체 시도 → Leader에게 보고 → Leader가 재할당/힌트/에스컬레이션 판단.
- **컨텍스트 관리**: 태스크 완료 시 다음 태스크 전 상태 정리. 컨텍스트 과대 시 shutdown 후 재스폰.
- **워크트리**: 기본 isolated (에이전트별 독립). 소규모 시 shared.
- **머지**: tester 통과 → Leader 리뷰 (+ Codex 리뷰 선택) → Leader 최종 머지.
