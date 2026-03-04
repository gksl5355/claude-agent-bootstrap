---
name: debate
description: 아키텍처/설계 결정을 Codex xhigh로 적대적 검토. 단독 사용 또는 spawn-team 내에서 트리거. "debate", "아키텍처 토론", "설계 검토" 시 사용.
triggers:
  - "debate"
  - "아키텍처 토론"
  - "설계 검토"
  - "design review"
allowed-tools: Read, Glob, Grep, Bash(codex *), Bash(cat > /tmp/debate*), AskUserQuestion
---

# Debate Mode — 아키텍처 결정 적대적 검토

설계안을 Codex xhigh가 적대적으로 검토하여 blind spot 제거.

**호출:** `/debate "JWT vs Session Auth"` (단독) 또는 spawn-team 하드/소프트 트리거 시 자동 진입.
단독 모드: argument 있으면 결정 대상으로 사용, 없으면 AskUserQuestion으로 수집.

## Step 1: 진입 판단

**하드 트리거 (무조건):** irreversible=true (DB 스키마, 외부 API, 인증) 또는 영향범위=3 (전체 시스템).
**소프트 트리거 (위험도 6+):** 사용자 명시 요청 또는 기술 선택지 2개+ & 팀 전체 영향.

**위험도 점수 (각 1-3, 합산):**

| 축 | 1 | 2 | 3 |
|----|---|---|---|
| 불확실성 | 검증된 패턴 | 일부 불확실 | 실험적 |
| 영향 범위 | 단일 서비스 | 2개 도메인 이하 | 전체 시스템 |
| 복잡도 | 단순 | 중간 | 크로스 레이어 |

- 6-7점 → Leader Judge (근거 문서화) / 8-9점·하드 → 사용자 Judge
- 영향범위=3 또는 irreversible=true → 점수 무관 하드 적용. 이견 시 높은 점수 채택.

## Step 2: 설계안 작성

### 필수 필드
```
## 결정 대상: {무엇을}
## 컨텍스트: {현황 3문장 이내}
## 제안 방향: {방향+근거}
## 대안: {기각 이유 한 줄씩}
## 비기능: 성능/{X} | 비용/{X} | 보안/{X} | 가용성/{X} | 롤백/{X}
## 위험도: 불확실성:{1-3} 영향:{1-3} 복잡도:{1-3} = {합}/9 | irreversible:{bool}
## 우려사항: {자기검열}
```

토큰 규칙: 목표 1500자, 최대 3000자. 초과 시 핵심(결정대상/비기능/위험도)만 포함.

## Step 3: Codex 비판

### CLI (파일 기반 — 쉘 깨짐 방지)
```bash
cat > /tmp/debate-input.md << 'DEBATE_EOF'
{설계안}
DEBATE_EOF

codex exec -c model_reasoning_effort=xhigh -s read-only \
  "$(cat /tmp/debate-input.md)" 2>&1
```

### Critic 출력 강제 포맷
```
[BLOCK|TRADEOFF|ACCEPT] {분류}: {한 줄 요약}
- 문제/영향/근거/수정안/미반영 리스크
```

- **BLOCK**: 핵심 요구 미충족, 출시 불가 (데이터 정합성, 보안, SLO)
- **TRADEOFF**: 충족하나 비용/복잡도 증가
- **ACCEPT**: 즉시 반영 가능한 개선

포맷 미준수 → 1회 재질의. 근거 없는 비판 → 기각 가능. BLOCK 기각 이견 → 사용자 에스컬레이션.

## Step 4: 라운드 처리 (최대 2 + 예외 1)

**R1**: 설계→Codex→BLOCK 없으면 조기 종료 / BLOCK 있으면 R2.
**R2**: BLOCK 반영+검증 계획→재검토→해소 시 Judge / 지속 시 AskUserQuestion.
- R2 범위: **기존 BLOCK 해소만 판정**. 새 이슈는 TRADEOFF로 문서화.
- 새 이슈를 BLOCK으로 올리려면 설계 전제 변경 필요 (예외 R3).

**R3 (예외)**: 새 제약/사실로 전제 변경 시만. 그 외 → AskUserQuestion 에스컬레이션.

## Step 5: Judge 결정

6-7점→Leader / 8-9·하드→사용자 / BLOCK 기각 이견→사용자.

BLOCK 지속 시 AskUserQuestion: "1) Leader 직접 결정 2) 방향 재검토 3) 추가 라운드 (새 증거만)" 기본값: 2.

## Step 6: 결과 문서화

```
## Debate 결과 (Round {N})
채택: {선택} | 위험도: {X}/9 irreversible:{bool} → Judge: Leader/사용자
수용: [{분류}] {비판} → {반영} | 검증: {방법}
반박: [{분류}] {비판} → {근거}
미결 TRADEOFF: [{분류}] {내용} → {감수 이유}
근거: {왜 이 결정인가}
```

단독 모드 시 `/tmp/debate-result-{timestamp}.md`에 저장.

## Codex 불가 시 fallback

- 소프트(6-7): 경고 후 Leader 자체 검토
- 하드·8+: AskUserQuestion → "1) Leader 검토(리스크 감수) 2) 사용자 직접 3) 보류"

## 운영 규칙

- Codex 입력 3000자 이내. 라운드 상한 2+예외1.
- 진입: 하드 또는 6+. 무한루프 금지.
- 참여자: Proposer(Leader/사용자) → Critic(Codex) → Judge(위험도 기반).
