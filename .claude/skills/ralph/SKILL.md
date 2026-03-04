---
name: ralph
description: PRD-driven persistence loop that keeps working until all tasks in prd.json pass verification. Use when user wants guaranteed completion ("don't stop", "keep going until done"). Integrates with spawn-team's team approach.
triggers:
  - "ralph"
  - "don't stop"
  - "keep going until done"
  - "must complete"
  - "finish this completely"
---

# Ralph: 팀 기반 지속 실행 루프

spawn-team과 통합된 PRD 주도 완료 보장. 모든 user story가 검증 통과할 때까지 반복.

**사용:** "끝날 때까지 멈추지 마", "반드시 완료" / spawn-team 이후 "ralph 모드로 완료까지"
**미사용:** 단발성 수정, 수동 제어, 탐색/설계 (먼저 spawn-team planner)

## Step 1: PRD 설정

prd.json 없으면 생성:
```json
{
  "version": 1, "project": "{name}", "createdAt": "{ts}",
  "stories": [{
    "id": "S01", "name": "{story}", "description": "{what}",
    "acceptanceCriteria": ["{구체적 테스트 가능 기준}"],
    "assignedTo": null, "passes": false
  }]
}
```

**검증 기준 필수**: ❌ "구현 완료" → ✅ "vitest auth 12개 PASS" / "`GET /api/products` 200+목록" / "재고 음수 시 400"
팀 없으면 → /spawn-team 먼저.

## Step 2: 루프

```
while (passes:false 존재):
  미완료 최우선 스토리 → Step 3 → Step 4
  통과 → passes:true → 다음
  실패 → spawn-team §7-2 피드백 루프 (2회→debugger→circuit breaker)
```

## Step 3: 구현 위임

담당 에이전트에게 SendMessage:
```
[Ralph - Story {ID}] 구현: {description}
기준: 1. {criterion-1}  2. {criterion-2}
완료 시 TaskUpdate(completed) + 보고.
```
독립 스토리 병렬 위임. 의존성 → blockedBy.

## Step 4: 검증 (신선한 증거 필수)

unit-tester에게: 각 criterion 실제 실행 결과 보고. "아마 작동" 불가.
통과 → prd.json `passes:true`. 실패 → spawn-team §7-2 적용.

## Step 5: PRD 완료 체크

`jq '[.stories[]|select(.passes==false)]|length' prd.json` → 0이면 Step 6, 아니면 Step 2.

## Step 6: 아키텍트 검토

- 소규모(변경<10파일): Leader 직접
- 중/대규모(10+): Codex xhigh read-only
통과 → Step 7. 실패 → 피드백 → 재구현 → Step 4.

## Step 7: 완료

```
Ralph 완료 ✓
스토리: ✅ S01: {name} / ✅ S02: {name} ...
검증: unit-tester {N}개 PASS | 아키텍트: {방식} 통과
팀 종료: shutdown_request → TeamDelete
```

## 운영 규칙

- scope reduction 금지. 테스트 삭제 금지.
- 같은 스토리 3회 실패 → circuit breaker → 사용자 에스컬레이션.
- 독립 스토리 병렬 위임 (순차 처리 금지). 검증은 항상 실제 실행 기반.
