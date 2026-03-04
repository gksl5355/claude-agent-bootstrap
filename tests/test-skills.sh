#!/bin/bash
# SKILL.md 기능 완전성 검증 테스트
# 각 스킬 파일에 필수 섹션/키워드가 존재하는지 확인

set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")/../.claude/skills" && pwd)"
PASS=0
FAIL=0
TOTAL=0

check() {
  local file="$1" pattern="$2" desc="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qiP "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "        pattern: $pattern"
    echo "        file: $file"
  fi
}

check_absent() {
  local file="$1" pattern="$2" desc="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qiP "$pattern" "$file" 2>/dev/null; then
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (should NOT exist)"
  else
    PASS=$((PASS + 1))
  fi
}

echo "=== spawn-team SKILL.md ==="
ST="$SKILLS_DIR/spawn-team/SKILL.md"

# --- Frontmatter ---
check "$ST" "^name: spawn-team" "frontmatter: name"
check "$ST" "allowed-tools:" "frontmatter: allowed-tools"

# --- Step 0 ---
check "$ST" "Step 0.*의도 분류" "Step 0 존재"
check "$ST" "task_type.*FEATURE" "Step 0 output: task_type"
check "$ST" "clarity.*HIGH" "Step 0 output: clarity"

# --- Step 1 ---
check "$ST" "Step 1.*프로젝트 분석" "Step 1 존재"
check "$ST" "\[A\].*도메인 디렉토리" "구조 타입 [A]"
check "$ST" "\[B\].*평면 구조" "구조 타입 [B]"
check "$ST" "\[C\].*불명확" "구조 타입 [C]"
check "$ST" "소유권 매니페스트" "소유권 매니페스트"
check "$ST" "MECE" "MECE 원칙"

# --- Step 2 ---
check "$ST" "Step 2.*팀 구성" "Step 2 존재"
check "$ST" "5명 상한" "5명 상한 규칙"
check "$ST" "fullstack.*sonnet" "소규모 구성"

# --- Model routing ---
check "$ST" "Opus.*COMPLEX" "Opus: COMPLEX 전용"
check "$ST" "Sonnet.*구현" "Sonnet: 기본 구현"
check "$ST" "Haiku.*tester" "Haiku: 테스터"
check "$ST" "Codex.*xhigh.*리뷰" "Codex: 리뷰"
check "$ST" "복잡도별 모델 승격" "복잡도별 모델 승격 섹션"
check "$ST" "SIMPLE.*Opus.*금지" "SIMPLE: Opus 금지"

# --- Step 2B ---
check "$ST" "Step 2B.*복잡도" "Step 2B 존재"
check "$ST" "4-6.*SIMPLE" "SIMPLE 임계값"
check "$ST" "7-9.*MEDIUM" "MEDIUM 임계값"
check "$ST" "10-11.*COMPLEX" "COMPLEX 임계값"
check "$ST" "자동 COMPLEX" "자동 COMPLEX 트리거"

# --- Step 2.5 ---
check "$ST" "Step 2.5.*범위" "Step 2.5 존재"
check "$ST" "IN.*OUT.*DEFER" "IN/OUT/DEFER"
check "$ST" "범위 잠금" "범위 잠금"

# --- Step 3 ---
check "$ST" "Step 3.*계획" "Step 3 존재"
check "$ST" "SIMPLE.*MEDIUM.*건너" "SIMPLE/MEDIUM 스킵"
check "$ST" "Wave 1.*기초" "Wave 1"
check "$ST" "Wave 2.*핵심" "Wave 2"
check "$ST" "Wave 3.*통합" "Wave 3"
check "$ST" "Wave 4.*검증" "Wave 4"
check "$ST" "Wave 5.*최종" "Wave 5"

# --- Step 4 ---
check "$ST" "Step 4.*사용자 확인" "Step 4 존재"
check "$ST" "AskUserQuestion.*2" "AskUserQuestion 2개"
check "$ST" "Codex 활성화" "Codex 활성화 질문"

# --- Step 5 ---
check "$ST" "Step 5.*팀 스폰" "Step 5 존재"
check "$ST" "공통 헤더" "공통 헤더"
check "$ST" "domain.*-be" "역할: BE"
check "$ST" "domain.*-fe" "역할: FE"
check "$ST" "unit-tester" "역할: unit-tester"
check "$ST" "scenario-tester" "역할: scenario-tester"
check "$ST" "fullstack" "역할: fullstack"
check "$ST" "코드 수정 금지" "테스터 수정 금지"
check "$ST" "worktree" "worktree 지원"

# --- Phase 4: 런타임 토큰 절약 ---
check "$ST" "런타임 토큰 절약" "Phase 4: 런타임 섹션"
check "$ST" "반복 Read 금지" "Phase 4: 반복 Read 방지"
check "$ST" "핵심만 추출" "Phase 4: output 핵심 추출"
check "$ST" "탐색.*구현.*섞지" "Phase 4: 탐색/구현 분리"
check "$ST" "파일 15개 초과" "Phase 4: 에이전트 파일 읽기 한도"
check "$ST" "500줄" "탐색: 대형 파일 wc -l 사전 확인"
check "$ST" "offset.*limit|limit.*offset" "탐색: offset+limit 부분 읽기"

# --- 컨텍스트 관리 ---
check "$ST" "상태: DONE" "보고 포맷: DONE"
check "$ST" "ERR:" "보고 포맷: FAIL ERR 블록"
check "$ST" "Leader 보고 포맷" "Leader 보고 포맷 섹션"
check "$ST" "COMPLEX.*Wave|MEDIUM.*에이전트" "복잡도별 요약 분기"
check "$ST" "1500자" "중간 요약 상한"
check "$ST" "SIMPLE.*생략" "SIMPLE 요약 생략"
check "$ST" "numstat" "머지 전 numstat 확인"
check "$ST" "Leader 읽기" "Leader 읽기 가이드라인"

# --- Step 6 ---
check "$ST" "Step 6.*작업 지시" "Step 6 존재"

# --- Step 7 ---
check "$ST" "Step 7.*실행.*피드백" "Step 7 존재"
check "$ST" "circuit.breaker" "circuit breaker"
check "$ST" "debugger.*스폰" "debugger 스폰"
check "$ST" "build-fixer" "build-fixer"
check "$ST" "architect-agent" "architect-agent"
check "$ST" "shutdown_request.*TeamDelete" "종료 프로토콜"

# --- Debate Mode ---
check "$ST" "Debate Mode" "Debate Mode 섹션"
check "$ST" "debate/SKILL.md.*참조" "debate 참조 링크"
check "$ST" "irreversible" "하드 트리거: irreversible"

# --- 운영 규칙 ---
check "$ST" "운영 규칙" "운영 규칙 섹션"
check "$ST" "idle.*비용.*없" "idle 비용 없음"
check "$ST" "1명.*7x" "쿼터 비율"

echo ""
echo "=== debate SKILL.md ==="
DB="$SKILLS_DIR/debate/SKILL.md"

check "$DB" "^name: debate" "frontmatter: name"
check "$DB" "Step 1.*진입" "Step 1 진입 판단"
check "$DB" "하드 트리거" "하드 트리거"
check "$DB" "소프트 트리거" "소프트 트리거"
check "$DB" "불확실성.*영향.*복잡도" "위험도 3축"
check "$DB" "6-7.*Leader" "6-7점 Leader Judge"
check "$DB" "8-9.*사용자" "8-9점 사용자 Judge"
check "$DB" "Step 2.*설계안" "Step 2 설계안"
check "$DB" "1500자.*3000자" "토큰 제한"
check "$DB" "Step 3.*Codex" "Step 3 Codex 비판"
check "$DB" "/tmp/debate-input" "파일 기반 전달"
check "$DB" "BLOCK.*TRADEOFF.*ACCEPT" "3단 분류"
check "$DB" "Step 4.*라운드" "Step 4 라운드"
check "$DB" "예외.*R3" "예외 R3"
check "$DB" "BLOCK.*해소만" "R2 범위 제한"
check "$DB" "Step 5.*Judge" "Step 5 Judge"
check "$DB" "Step 6.*결과" "Step 6 문서화"
check "$DB" "fallback" "Codex 불가 fallback"
check "$DB" "무한루프 금지" "무한루프 방지"

echo ""
echo "=== ralph SKILL.md ==="
RL="$SKILLS_DIR/ralph/SKILL.md"

check "$RL" "^name: ralph" "frontmatter: name"
check "$RL" "prd.json" "PRD 파일"
check "$RL" "acceptanceCriteria" "acceptance criteria"
check "$RL" "passes.*false" "passes 필드"
check "$RL" "vitest|GET.*api|400" "구체적 검증 예시"
check "$RL" "Step 2.*루프" "Step 2 루프"
check "$RL" "spawn-team.*7-2|§7-2" "spawn-team 피드백 참조"
check "$RL" "Step 3.*위임" "Step 3 위임"
check "$RL" "병렬 위임" "병렬 위임"
check "$RL" "Step 4.*검증" "Step 4 검증"
check "$RL" "신선한 증거|실제 실행" "신선한 증거"
check "$RL" "Step 5.*완료" "Step 5 완료 체크"
check "$RL" "Step 6.*(아키텍트|검토)" "Step 6 아키텍트 검토"
check "$RL" "Codex.*xhigh" "Codex 리뷰"
check "$RL" "Step 7.*완료" "Step 7 완료"
check "$RL" "scope reduction 금지|scope.*reduction.*금지" "scope reduction 금지"
check "$RL" "테스트 삭제 금지|테스트.*삭제.*금지" "테스트 삭제 금지"
check "$RL" "3회.*circuit|circuit breaker" "3회 circuit breaker"
check "$RL" "순차.*금지|순차 처리 금지" "순차 처리 금지"

echo ""
echo "=== 바이트 크기 검증 ==="
for skill in spawn-team debate ralph; do
  bytes=$(wc -c < "$SKILLS_DIR/$skill/SKILL.md")
  TOTAL=$((TOTAL + 1))
  # 원본 대비 40-70% 감소 범위인지 확인 (너무 작으면 누락, 너무 크면 압축 실패)
  case $skill in
    spawn-team) min=8000; max=15000 ;;  # 원본 28055
    debate)     min=3000; max=6000 ;;   # 원본 8444
    ralph)      min=2000; max=4000 ;;   # 원본 5047
  esac
  if [ "$bytes" -ge "$min" ] && [ "$bytes" -le "$max" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $skill 크기 ${bytes}B (기대: ${min}-${max}B)"
  fi
done

echo ""
echo "==============================="
echo "총 ${TOTAL}개 테스트 | PASS: ${PASS} | FAIL: ${FAIL}"
echo "==============================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  echo "ALL TESTS PASSED"
  exit 0
fi
