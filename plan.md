# Team Orchestrator — 1단계 코어

## 목표

`/spawn-team` 스킬 하나로 프로젝트에 맞는 Claude Code Agent Teams를 빠르게 구성하고 운영한다.

**환경**: Claude Max (Agent Teams, teammateMode: tmux)
**구현체**: `.claude/skills/spawn-team/SKILL.md`
**선택 확장**: Codex CLI (ChatGPT Plus) — enabled/disabled 설정

---

## 1. 팀 구성

### 1.1 역할

| 역할 | 모델 | 책임 |
|---|---|---|
| leader | opus (메인 세션) | 분석, 분배, 조율, 최종 판단 |
| planner | sonnet | 아키텍처 설계, 기술 스펙 구체화 |
| be | sonnet | 백엔드 구현 |
| fe | sonnet | 프론트엔드 구현 |
| fullstack | sonnet | BE+FE 겸용 (소규모) |
| tester | haiku | 테스트 작성, 검증 |
| worker | haiku | 단순/반복 작업 |

- leader = 메인 세션 (스폰 X)
- opus 에이전트는 leader뿐, 나머지 sonnet/haiku

### 1.2 프리셋

```jsonc
{
  "minimal": {
    // 소규모. 버그 수정, 간단 기능
    "fullstack": { "count": 1, "model": "sonnet" },
    "tester": { "count": 1, "model": "haiku" }
    // 에이전트 2 + leader = 3 세션
  },
  "balanced": {
    // 중규모 균형
    "be": { "count": 1, "model": "sonnet" },
    "fe": { "count": 1, "model": "sonnet" },
    "tester": { "count": 1, "model": "haiku" }
    // 에이전트 3 + leader = 4 세션
  },
  "be-heavy": {
    // 백엔드 중심
    "planner": { "count": 1, "model": "sonnet" },
    "be": { "count": 2, "model": "sonnet" },
    "fe": { "count": 1, "model": "sonnet" },
    "tester": { "count": 1, "model": "haiku" }
    // 에이전트 5 + leader = 6 세션
  },
  "fe-heavy": {
    // 프론트엔드 중심
    "planner": { "count": 1, "model": "sonnet" },
    "be": { "count": 1, "model": "sonnet" },
    "fe": { "count": 2, "model": "sonnet" },
    "tester": { "count": 1, "model": "haiku" }
  },
  "custom": {
    // 사용자 정의
  }
}
```

### 1.3 팀 구성 판단

Leader가 `/spawn-team` 실행 시:

```
1. 프로젝트 스캔 (파일 구조, 기술 스택, 규모)
2. 판단:
   - 소규모 (< 10파일) → minimal
   - BE 중심 → be-heavy
   - FE 중심 → fe-heavy
   - 균형 → balanced
   - 병렬 가능성 낮으면 → minimal 유지
3. 사용자에게 제안 → 승인/수정 → 스폰
```

---

## 2. 태스크 분배

### 2.1 기본 규칙

```
1. 작업을 독립 단위로 분해 (파일/모듈 경계)
2. 의존성 있으면 blockedBy, 없으면 병렬
3. 역할에 맞는 에이전트에 할당
4. 에이전트가 막히면 → Leader에게 보고 → 재할당 or 힌트
5. 완료 → tester 검증 → Leader 리뷰 → 머지
```

### 2.2 워크트리

- 기본: isolated (에이전트별 독립 워크트리)
- 소규모: shared도 가능
- 머지: tester 통과 → Leader 승인 → 머지

---

## 3. Codex 연계 (선택)

### 3.1 설정

```jsonc
// /spawn-team 실행 시 물어봄: "Codex 사용할까요?"
{
  "codex": {
    "enabled": true,        // false면 Codex 관련 전부 스킵
    "defaultReasoning": "high",
    "reviewReasoning": "xhigh"
  }
}
```

### 3.2 사용 방식

1단계에서는 **Leader가 직접 호출** (가장 단순):

```
Leader가 필요할 때:
├── 머지 전 교차 리뷰: codex exec -c model_reasoning_effort=xhigh "리뷰..."
├── 독립 코딩 태스크: codex exec -c model_reasoning_effort=high "구현..."
└── 빠른 검증: codex exec -c model_reasoning_effort=low "확인..."
```

프록시 에이전트, 서브에이전트 구조는 **1단계 실행 후 필요성 판단**.

### 3.3 Codex CLI 참고

```bash
codex exec "프롬프트"                              # 기본
codex exec -c model_reasoning_effort=xhigh "..."   # reasoning 설정
codex exec -s read-only "..."                      # 읽기 전용
codex exec -s workspace-write "..."                # 쓰기 허용
codex exec -C /path "..."                          # 작업 디렉토리
```

---

## 4. /spawn-team 스킬 동작

```
사용자: /spawn-team

1. 프로젝트 분석
   - 디렉토리 구조, package.json, 기술 스택 파악

2. 팀 구성 제안
   - "BE 중심 프로젝트로 판단됩니다. be-heavy 프리셋 추천:"
   - 역할 목록 + 모델 + 인원 표시
   - "Codex 교차 리뷰 활성화할까요?"

3. 사용자 승인
   - 승인 → 스폰 시작
   - 수정 → 조정 후 재제안

4. 팀 스폰
   - TeamCreate
   - 역할별 TaskCreate (에이전트 정의)
   - Task (에이전트 스폰, team_name 지정)
   - 워크트리 설정

5. 작업 시작 대기
   - "팀 준비 완료. 작업을 지시해주세요."
   - 사용자가 작업 지시 → Leader가 태스크 분해 & 분배
```

---

## 5. 구현 범위

### 지금 만들 것
- [ ] `.claude/skills/spawn-team/SKILL.md`
- [ ] 프리셋 정의 (minimal, balanced, be-heavy, fe-heavy)
- [ ] 실제 팀 스폰 테스트

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
