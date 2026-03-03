# Debate Mode 설계 초안 v1

## 목적
기획/아키텍처 결정 전, Leader(Sonnet+thinking)의 설계안을 Codex xhigh가 적대적으로 검토하여
blind spot을 제거하고 더 나은 결정을 도출한다.

## 트리거
- 사용자가 명시적으로 "debate", "아키텍처 토론", "검토해줘" 요청 시
- Leader 판단: 기술 선택지가 여러 개이고 선택 근거가 불명확할 때

## 참여자
- **Proposer**: Leader (Sonnet+thinking) — 설계안 초안 작성
- **Critic**: Codex exec xhigh — 비판적 검토 (코드 수정 권한 없음, read-only)
- **Judge**: Leader — 최종 합성 및 결정

## 라운드 구조 (최대 2라운드)

### Round 1
1. Leader가 설계안 작성 (아래 형식 준수)
2. Codex에 설계안 전송:
   ```
   codex exec -c model_reasoning_effort=xhigh -s read-only -C {project-path} \
     "다음 설계안을 비판적으로 검토하라.
      약점, 대안, 엣지케이스, 오버엔지니어링, 구현 불가능한 부분을 지적하라.
      수용 가능한 비판은 [ACCEPT], 트레이드오프는 [TRADEOFF], 블로커는 [BLOCK] 표시.
      설계안: {design}"
   ```
3. Leader가 Codex 비판 분석:
   - [BLOCK] → 설계 수정 후 Round 2
   - [ACCEPT] 다수 + [BLOCK] 없음 → 조기 종료 (1라운드로 충분)
   - [TRADEOFF] 만 있으면 → 근거 문서화 후 종료

### Round 2 (Round 1에서 [BLOCK] 있을 시)
4. Leader가 [BLOCK] 반영하여 설계 수정
5. Codex 재검토 (동일 포맷)
6. Leader 최종 판단:
   - [BLOCK] 해소됨 → 채택
   - [BLOCK] 지속 → AskUserQuestion으로 에스컬레이션

## 설계안 입력 형식 (Proposer 준수)
```
## 결정 대상
{무엇을 결정하는가}

## 컨텍스트
{프로젝트 현황, 제약조건}

## 제안 방향
{채택하려는 방향과 근거}

## 고려한 대안
{검토한 대안과 기각 이유}

## 우려사항 (자기검열)
{스스로 의심되는 부분}
```

## 출력 형식
```
## Debate 결과

채택 결정: {최종 선택}

수용된 Codex 비판:
- {비판 1} → {어떻게 반영}
- {비판 2} → {어떻게 반영}

반박한 Codex 비판:
- {비판 X} → {반박 근거}

최종 근거: {왜 이 결정인가}
```

## 비용 추정
- Codex xhigh 1회 호출: 중간 규모 문서 기준 ~5-10분
- 총 라운드: 1-2회 (2라운드 초과 금지)
- 대상: 기획/아키텍처 결정만. 일반 버그 수정 X.

## 제약
- Codex가 미설치/오류 시: Leader 단독 결정 + 경고 출력
- 2라운드 후에도 [BLOCK] 지속 시: 사용자 에스컬레이션 (무한 루프 금지)
- 코드 구현 도중 debate X (기획 단계 전용)
