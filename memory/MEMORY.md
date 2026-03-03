# Team Orchestrator — 핵심 기억

## 프로젝트 위치
- 스킬: `/home/gksl5355/prj/01.team-orchestrator/.claude/skills/spawn-team/SKILL.md`
- 설계 문서: `/home/gksl5355/prj/01.team-orchestrator/plan.md`
- Debate 설계: `/home/gksl5355/prj/01.team-orchestrator/debate-design-final.md`

## 핵심 결정사항

### 에이전트 구성
- 5명 상한 엄수 (에이전트 1명 ≈ 7x 쿼터)
- 소규모: fullstack + unit-tester (shared worktree)
- 중규모: 도메인-be/fe + unit-tester (isolated worktree)
- 대규모: planner + 도메인×2 + unit-tester + scenario-tester (isolated worktree)

### Worktree & MECE 경계 (2026-03)
- 파일 소유권은 에이전트 스폰 전 매니페스트로 확정 (MECE)
- 공유 파일(types/, utils/) → Leader 직접 관리, 동시 수정 금지
- 머지 전 경계 위반 체크: `git diff --name-only main | grep -vE {domain-pattern}`
- 머지 순서: 공유 → 코어 BE → 비코어 BE → FE → 테스트 (순차, 병렬 금지)
- 에이전트 3명+, 의존성 높을 시: Plan Mode 승인 게이트 권장

### Debate Mode (Codex xhigh, 2라운드 상한)
- 하드 트리거: irreversible=true 또는 영향범위=3 → 무조건 debate
- 소프트 트리거: 위험도 합계 6+ (불확실성+영향범위+복잡도, 각 1-3점)
- Critic 강제 포맷: [BLOCK|TRADEOFF|ACCEPT] / 문제/영향/근거/수정안/미반영 리스크
- CLI: `/tmp/debate-input.md` 임시 파일 방식 (인라인 문자열 깨짐 방지)
- BLOCK 기각 이견 시 → 자동 사용자 에스컬레이션 (Leader 단독 결정 금지)
- Judge: 6-7점 = Leader, 8-9점/하드 트리거 = 사용자 (AskUserQuestion)

### Codex 연동
- 머지 전 최종 리뷰 1회만 (매 커밋 X)
- `codex exec -c model_reasoning_effort=xhigh -s read-only`
- 실패 시 스킵 + 경고 (전체 플로우 중단 X)

### 피드백 루프 & 회로 차단기
- FAIL 2회 → debugger 온디맨드 스폰 (haiku, 분석만)
- debugger 후에도 FAIL → AskUserQuestion 에스컬레이션 (무한 루프 금지)
- 빌드 오류 → build-fixer 온디맨드 스폰 (haiku)

### 피어 통신 원칙
- 세부 기술 협의(타입 충돌, API 구조) → 피어 직접 SendMessage
- 공유 파일 수정, 완료/실패 보고, 도메인 경계 결정 → 반드시 Leader 경유
- 상태 truth = Leader의 TaskList

## 테스트 결과 (검증 완료)
- test-task-manager: 2명 팀, 4버그 수정, 29/29 PASS
- test-ecommerce: 5명 팀, 8버그 수정, 28/28 unit + 4/4 scenario PASS
- Debate: debate-design v1 → v2 → v3 (Codex xhigh 2라운드)
- test-domain-dir: [A] 도메인 디렉토리, 13/13 PASS
- test-legacy-team: [B] 평면구조 + Plan Mode 게이트 E2E, 13/13 PASS (Codex xhigh 리뷰 포함)
- test-monolith: [C] architect-agent E2E — app.ts 단일파일 → 도메인 디렉토리 구조, 4/4 PASS

## 실전에서 발견된 패턴
- idle 에이전트: 명시적 Bash 명령어 포함한 SendMessage로 깨워야 함
- 크로스 도메인 연쇄 버그: products.findById() 수정이 orders BUG도 자동 해소
- idempotency 체크 순서: order.status 체크 전에 processedKeys 체크해야 함
