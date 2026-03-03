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

spawn-team의 팀 오케스트레이션과 통합된 PRD 주도 완료 보장 시스템.
모든 user story가 검증 통과할 때까지 팀을 유지하며 반복한다.

**언제 사용:**
- "끝날 때까지 멈추지 마", "반드시 완료", "계속 진행"
- 검증 기준이 명확하고 완료 보장이 필요한 태스크
- spawn-team 이후 "이제 ralph 모드로 완료까지" 패턴

**언제 사용 안 함:**
- 빠른 단발성 수정
- 사용자가 수동 제어를 원할 때
- 탐색/설계 단계 (먼저 spawn-team의 planner 사용)

---

## Step 1: PRD 설정

### 1-1. prd.json 생성 또는 읽기

```bash
PRD_FILE="{project-path}/prd.json"
```

기존 prd.json이 없으면 생성:

```json
{
  "version": 1,
  "project": "{project-name}",
  "createdAt": "{timestamp}",
  "stories": [
    {
      "id": "S01",
      "name": "{story-name}",
      "description": "{what needs to be built}",
      "acceptanceCriteria": [
        "{specific, testable criterion 1}",
        "{specific, testable criterion 2}"
      ],
      "assignedTo": null,
      "passes": false
    }
  ]
}
```

### 1-2. 검증 기준 구체화 (중요)

**자동 생성된 기준은 반드시 구체적으로 다듬는다.**

❌ 나쁜 예: "구현이 완료되었다"
✅ 좋은 예: "vitest 실행 시 auth 관련 12개 테스트 전부 PASS"
✅ 좋은 예: "`/api/products` GET 엔드포인트가 200 반환하고 활성 상품 목록 포함"
✅ 좋은 예: "재고 음수 입력 시 400 에러 반환"

### 1-3. 팀 확인

spawn-team으로 이미 팀이 구성되어 있는지 확인.
없으면 → 먼저 /spawn-team 실행 후 돌아올 것.

---

## Step 2: 루프 — 미완료 스토리 선택

```
while (미완료 스토리 존재):
  1. prd.json에서 passes: false인 최우선 스토리 선택
  2. Step 3: 구현 위임
  3. Step 4: 검증
  4. 통과 → passes: true 업데이트 → 다음 스토리
  5. 실패 → 피드백 후 재구현 (spawn-team 피드백 루프 §6-2 적용)
```

---

## Step 3: 팀에 구현 위임

해당 스토리를 담당 에이전트에게 SendMessage:

```
[Ralph Loop - Story {ID}]
구현할 내용: {description}
검증 기준:
  1. {criterion-1}
  2. {criterion-2}

완료 시 TaskUpdate(completed) + Leader에게 보고.
```

독립 스토리는 병렬 위임. 의존성 있으면 blockedBy 설정.

---

## Step 4: 검증 (신선한 증거 필수)

unit-tester에게 검증 지시:

```
Story {ID} 검증:
검증 기준:
  1. {criterion-1} → [테스트 실행 명령]
  2. {criterion-2} → [확인 방법]

각 기준에 대해 실제 실행 결과 포함하여 보고.
```

**검증 통과 기준:**
- 각 acceptance criteria를 테스트 실행 결과로 실증
- "잘 돼보임", "아마 작동할 것" 같은 추정 불가
- 실제 output, pass/fail count 포함

**통과 시**: prd.json의 해당 스토리 `passes: true` 업데이트
**실패 시**: spawn-team의 피드백 루프 §6-2 적용 (2회 시도 → debugger → circuit breaker)

---

## Step 5: PRD 완료 체크

```bash
# 모든 스토리 passes: true?
jq '[.stories[] | select(.passes == false)] | length' prd.json
# 0이면 → Step 6 (아키텍트 검토)
# 아니면 → Step 2로 돌아감
```

---

## Step 6: 아키텍트 검토

모든 스토리 완료 후 최종 검토.

**검토 방식 (복잡도 기준):**
- 소규모 (변경 파일 < 10개): Leader 직접 검토
- 중규모 (10~30개): Codex xhigh read-only 리뷰
- 대규모 (30+개): Codex xhigh + Leader 검토

```bash
# Codex 검토 (중/대규모)
codex exec -c model_reasoning_effort=xhigh -s read-only -C {project-path} \
  "다음 PRD 스토리들이 모두 구현되었는지 검토해라: {story-list}"
```

**검토 통과 → Step 7 (완료)**
**검토 실패 → 해당 에이전트에 피드백 → 재구현 → Step 4로**

---

## Step 7: 완료

```
Ralph 완료 ✓

완료된 스토리:
  ✅ S01: {name}
  ✅ S02: {name}
  ...

검증 방식: unit-tester {N}개 테스트 PASS
아키텍트 검토: {방식} — 통과

팀 종료하려면: 팀 에이전트에게 shutdown_request 전송 후 TeamDelete
```

---

## 운영 규칙

- **scope reduction 금지**: 기준 충족이 어렵다고 acceptance criteria를 낮추지 않음
- **테스트 삭제 금지**: 테스트를 지워서 PASS 만들기 불가
- **무한 루프 방지**: 같은 스토리 3회 실패 → circuit breaker → 사용자 에스컬레이션
- **병렬 우선**: 독립 스토리는 동시 위임, 절대 순차 처리하지 않음
- **신선한 증거**: 검증은 항상 실제 실행 결과 기반. 이전 실행 결과 재사용 금지
