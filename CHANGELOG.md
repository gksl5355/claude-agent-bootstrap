# Changelog

All notable changes to this project will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## [0.3.0] - 2026-03-04

### Added
- **Opus 모델 라우팅**: COMPLEX 작업 시 Leader/planner/architect-agent에 Opus 투입 (Perplexity Computer Meta Router + opusplan 하이브리드 전략 차용)
- **런타임 토큰 절약 지침**: 에이전트 공통 헤더에 DCP(Dynamic Context Pruning) 원칙 반영 — 반복 Read 금지, output 핵심 추출, 탐색/구현 분리 (oh-my-opencode DCP 차용)
- **CHANGELOG.md**: 릴리즈 노트 시작
- **tests/test-skills.sh**: SKILL.md 기능 완전성 검증 테스트 (98+ 체크포인트)

### Changed
- **spawn-team**: 751줄 → 253줄 (66% 감소). 모든 기능 유지, 노이즈만 제거
  - Phase 1: 예시 3개→테이블, 설명→압축 규칙 (OMC Ecomode + CLAUDE.md <200줄 가이드 참조)
  - Phase 2: debate 중복→참조, 프롬프트 5개→공통 헤더+역할 테이블 (oh-my-opencode-slim 참조)
  - Phase 3: Step 3 계획 수립 인라인 압축, 조건부 섹션 최적화
  - Phase 4: 런타임 토큰 절약 지침 추가 (OMO DCP 차용)
- **debate**: 241줄 → 111줄 (54% 감소). 프로토콜 100% 보존
- **ralph**: 185줄 → 83줄 (55% 감소). spawn-team 참조 방식 유지
- **모델 라우팅**: 3단(Haiku/Sonnet/Codex) → 4단(Haiku/Sonnet/**Opus**/Codex), 복잡도 연동

### Performance
- 스킬 합계: 1,524줄 → 788줄 (**55% 토큰 감소**)
- 기능 검증: 98개 체크포인트, CRITICAL 누락 0건
- 성능 향상 근거: context noise 감소 → LLM 지시 따름 향상 (Claude 연구: 40% noise↓ = 40% 환각↓)

### References
- oh-my-claudecode Ecomode: 30-50% 토큰 절감
- oh-my-opencode Dynamic Context Pruning: 중복 제거/output truncation
- oh-my-opencode-slim: 토큰 민감 최적화 포크
- Claude Code context editing: 84% 토큰 감소 연구
- Perplexity Computer: 19모델 Meta Router (Opus 오케스트레이터)
- opusplan 하이브리드: Plan→Opus, Execution→Sonnet
- Agentic Plan Caching (NeurIPS 2025): planning 50% 절감 (장기 목표)
- Full research: RESEARCH_TOKEN_EFFICIENCY.md

## [0.2.0] - 2026-03-03

### Added
- **Planning 강화**: 의도 분류(Step 0), 복잡도 판단(Step 2B), 범위 확인(Step 2.5), 계획 수립(Step 3)
- **debate 스킬**: 독립 분리 + 전역 배포
- 복잡도 분기: SIMPLE(빠르게) / MEDIUM(범위 확인) / COMPLEX(전체 계획)

### References
- oh-my-opencode, oh-my-claudecode, Claude Code, CodeX, OpenCode 5개 도구 분석

## [0.1.0] - 2026-03-02

### Added
- spawn-team: 동적 팀 구성 + 피드백 루프
- ralph: PRD 기반 완료 보장
- hud: 상태 표시줄
- configure-notifications: Telegram/Discord/Slack 알림
- install.sh: 자동 설치 스크립트
- README.md: 오픈소스 문서
