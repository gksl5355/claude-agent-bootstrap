# Team Orchestrator v1.0 — Silo Implementation Spec

> 각 Claude Code 세션이 독립적으로 구현할 수 있도록 세션별 완전 스펙을 정의.
> 세션 간 파일 충돌 없음이 보장되어야 한다.

---

## 전체 세션 맵

```
Wave 1 (병렬 실행 가능)
  Session A ─── Silo 1A: F1 Run Artifacts (spawn-team/SKILL.md)
              ── Silo 1C: Worktree gaps (spawn-team/SKILL.md, 1A 완료 후)
  Session B ─── Silo 1B: F6 Doctor (doctor/SKILL.md, 신규)

Wave 2 (Wave 1 완료 후, 병렬 실행 가능)
  Session C ─── Silo 2A: F3 Impact Brief (spawn-team/SKILL.md)
              ── Silo 2B: F2 Confidence (spawn-team/SKILL.md, 2A 완료 후)
              ── Silo 2C: F5 Ownership + AP (spawn-team/SKILL.md, 2B 완료 후)
  Session D ─── Silo 2D: Tests F2/F3/F5 (tests/integration/, 독립)

Wave 3 (Wave 2 완료 후, 병렬 실행 가능)
  Session E ─── Silo 3A: F4 Preview (spawn-team/SKILL.md)
              ── Silo 3B: F7 Debate gate (debate/SKILL.md + spawn-team, 3A 완료 후)
  Session F ─── Silo 3C: F8 Ralph + E2E (ralph/SKILL.md + tests/fixtures/, 독립)
  Session G ─── Silo 3D: Docs cleanup (docs/, README.md, 독립)
```

**파일 소유권 원칙:**
- `spawn-team/SKILL.md` → 한 번에 하나의 세션만. Wave 내에서도 순차.
- `doctor/SKILL.md` → Session B 독점
- `debate/SKILL.md` → Session E (Silo 3B) 독점
- `ralph/SKILL.md` → Session F 독점
- `tests/` → Session D (integration/) + Session F (fixtures/) — 다른 하위 디렉터리

---

## Wave 1

---

### Silo 1A — F1: Run Artifacts
**Session**: A (Wave 1, 첫 번째)
**담당 기능**: F1 (plan.yml / events.yml / report.yml / decisions.yml)

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/spawn-team/SKILL.md` — §7 (Spawn Team) + §8 (Execution) + §8.5 (Completion) |
| **생성** | 없음 (YAML은 실행 시 생성, 스키마는 SKILL.md에 명시) |
| **금지** | 다른 모든 파일 |

#### SKILL.md 수정 범위
- **§7-1 (Spawn Team)**: plan.yml 작성 로직 추가
  - run_id 생성 (`date +%Y-%m-%d`-NNN)
  - `.claude/runs/{run-id}/` 디렉터리 생성
  - plan.yml 작성 (team, ownership_manifest, complexity, score)
  - `latest` symlink 업데이트
- **§8-1 (Task Distribution)**: events.yml에 `task_assigned` 이벤트 추가
- **§8-2 (Progress Updates)**: events.yml에 `agent_done`, `wave_complete` 이벤트 추가
- **§8-3 (Test Loop)**: events.yml에 `test_result` 이벤트 추가
- **§8.5 (Completion)**: report.yml 작성 로직 추가 (F2 confidence 블록 제외 — Silo 2B 담당)
- **decisions.yml**: scope_lock, scope_violation_revert 이벤트 작성 위치 명시

#### 수용 기준 (Acceptance)
```bash
# 1. spawn 후 plan.yml 존재
ls {project}/.claude/runs/$(date +%Y-%m-%d)-001/plan.yml

# 2. plan.yml에 필수 키 존재
grep -E "run_id|team|ownership_manifest|complexity" plan.yml

# 3. events.yml이 agent_done 시점에 업데이트됨
grep "agent_done" events.yml

# 4. report.yml이 completion 시 생성됨 (confidence 블록 없어도 OK)
grep "status: COMPLETED" report.yml
```

#### 팀 스폰 제안
```
artifacts-writer (sonnet) — SKILL.md §7+§8+§8.5 작성
section-reviewer (haiku)  — 작성된 내용 검증
```

---

### Silo 1B — F6: Doctor
**Session**: B (Wave 1, Session A와 병렬)
**담당 기능**: F6 (/doctor command)

#### 파일
| 작업 | 파일 |
|------|------|
| **생성** | `.claude/skills/doctor/SKILL.md` (신규) |
| **금지** | 다른 모든 파일 |

#### SKILL.md 내용 (신규 파일)
`/doctor` 스킬이 해야 할 것:
1. 환경 체크 8개 항목 (TRD.md §F6 참조)
2. 결과 출력 (`✓` / `✗` + 이유)
3. settings.json 패치 제안 → `y/n` 확인 후 적용
4. 패치 전 백업: `~/.claude/settings.json.bak`
5. 패치 실패 시 백업에서 복구

#### 수용 기준
```bash
# /doctor 실행 시 출력에 다음 포함 여부
# ✓ Claude Code
# ✓ tmux
# ✓ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
# ✓ CLAUDE_CODE_TEAMMATE_COMMAND
# ✗ 또는 ✓ Codex CLI
```

#### 팀 스폰 제안
```
doctor-writer (sonnet) — SKILL.md 작성
```

---

### Silo 1C — Worktree Gap Fix
**Session**: A (Wave 1, Silo 1A 완료 후)
**담당 기능**: spawn-team/SKILL.md worktree 3개 갭 수정

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/spawn-team/SKILL.md` — §7-1, §8-4, §8-5 |
| **금지** | 다른 모든 파일 |

#### 수정 내용 (TRD.md §Worktree Gap Fixes 참조)
- §7-1: `isolation: "worktree"` 조건부 추가 (3+ agents)
- §8-4: 머지 순서 + git 명령 명시
- §8-5: `git worktree prune` + stale branch 정리

#### 수용 기준
- §7-1에 worktree 조건 분기 존재
- §8-4에 명시적 git merge 순서 존재
- §8-5에 cleanup 단계 존재

---

## Wave 2

---

### Silo 2A — F3: Impact & Risk Brief
**Session**: C (Wave 2, 첫 번째)
**전제조건**: Wave 1 완료

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/spawn-team/SKILL.md` — §1 (Project Analysis) 신규 서브섹션 |
| **금지** | 다른 모든 파일 |

#### SKILL.md 수정 범위
§1에 새 서브섹션 `1-4. Impact & Risk Brief` 추가:
- git analysis 명령 (TRD.md §F3 참조)
- 출력 포맷 (Impacted modules / Risk factors / Recommended team / Risk level)
- SIMPLE complexity → brief 스킵, MEDIUM/COMPLEX → 출력

#### 수용 기준
```bash
# MEDIUM/COMPLEX 작업 시 다음 출력 포함 여부
# "Impact & Risk Brief:"
# "Impacted modules:"
# "Risk factors:"
# "Risk level: MEDIUM|HIGH"
```

---

### Silo 2B — F2: Confidence Scoring
**Session**: C (Wave 2, Silo 2A 완료 후)
**전제조건**: Silo 2A 완료 (§8.5에 report.yml 기본 구조 있어야 함)

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/spawn-team/SKILL.md` — §8.5 (Completion) confidence 블록 추가 |
| **금지** | 다른 모든 파일 |

#### SKILL.md 수정 범위
§8.5에 confidence 계산 로직 추가:
- 5개 check 계산 (TRD.md §F2 참조)
- anti_pattern_penalty 계산
- grade 판정 (A/B/C/D/F)
- report.yml confidence 블록 작성

#### 수용 기준
```bash
# report.yml에 confidence 블록 존재
grep -E "score:|grade:|breakdown:" report.yml
```

---

### Silo 2C — F5: Ownership Enforcement + Anti-Pattern
**Session**: C (Wave 2, Silo 2B 완료 후)

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/spawn-team/SKILL.md` — §8-4 (Merge Protocol) 강화 |
| **금지** | 다른 모든 파일 |

#### SKILL.md 수정 범위
§8-4에 추가:
- AP001-AP008 탐지 명령 (TRD.md §F5 참조)
- hook point별 실행 시점
- anti_pattern 이벤트 events.yml 기록
- verdict: null 필드 추가

#### 수용 기준
```bash
# test evasion (AP007) 탐지
echo "test.skip('foo', () => {})" >> tests/foo.test.ts
# → events.yml에 anti_pattern AP007 기록되어야 함

# scope violation (AP001) 탐지
# → 소유권 밖 파일 수정 시 events.yml에 scope_violation 기록
```

---

### Silo 2D — Integration Tests (F2/F3/F5)
**Session**: D (Wave 2, Session C와 병렬)

#### 파일
| 작업 | 파일 |
|------|------|
| **생성** | `tests/integration/test-confidence-scoring.sh` |
| **생성** | `tests/integration/test-ownership-guard.sh` |
| **생성** | `tests/integration/test-impact-brief.sh` |
| **금지** | `tests/unit/`, `tests/fixtures/`, 다른 모든 파일 |

#### 수용 기준
```bash
bash tests/integration/test-confidence-scoring.sh  # exit 0
bash tests/integration/test-ownership-guard.sh     # exit 0
bash tests/integration/test-impact-brief.sh        # exit 0
```

---

## Wave 3

---

### Silo 3A — F4: Preview Mode
**Session**: E (Wave 3, 첫 번째)
**전제조건**: Wave 2 완료

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/spawn-team/SKILL.md` — §0 (Init) 앞에 --preview gate 추가 |
| **금지** | 다른 모든 파일 |

#### SKILL.md 수정 범위
`/spawn-team --preview "task"` 진입 시:
1. F3 Impact Brief 실행
2. plan.yml 생성 (dry-run, 실제 `.claude/runs/`에는 쓰지 않음 또는 preview/ 서브디렉터리)
3. 팀 구성 제안 출력
4. "Proceed? [y/n/adjust]" → y면 실제 spawn, n이면 중단

#### 수용 기준
```bash
# --preview 실행 시 에이전트 스폰 없이 출력만
/spawn-team --preview "Add login page"
# → "=== PREVIEW ===" 포함 출력
# → 실제 tmux 세션 생성 없음
```

---

### Silo 3B — F7: Debate Gate
**Session**: E (Wave 3, Silo 3A 완료 후)

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/debate/SKILL.md` — decisions.yml 기록 추가 |
| **수정** | `.claude/skills/spawn-team/SKILL.md` — §7 pre-spawn gate 추가 |
| **금지** | 다른 모든 파일 |

#### 수정 범위
- debate/SKILL.md: 토론 결과를 decisions.yml에 기록하는 단계 추가
- spawn-team/SKILL.md §7: F3 risk level HIGH 또는 auth/schema/API 변경 감지 시 자동 debate 진입

#### 수용 기준
- Risk level HIGH 작업 → debate 자동 제안
- debate 결과 → decisions.yml에 `debate_result` 타입 엔트리 생성

---

### Silo 3C — F8: Ralph + E2E Fixtures
**Session**: F (Wave 3, Session E와 병렬)

#### 파일
| 작업 | 파일 |
|------|------|
| **수정** | `.claude/skills/ralph/SKILL.md` — prd.json 내구성 강화 |
| **생성** | `tests/fixtures/simple-app/` (5-7 files skeleton) |
| **생성** | `tests/fixtures/medium-app/` (10-12 files skeleton) |
| **생성** | `tests/fixtures/complex-app/` (15-18 files skeleton) |
| **금지** | `tests/integration/`, `tests/unit/`, 다른 모든 파일 |

#### Fixture 요구사항
각 fixture app:
- `package.json` 또는 해당 스택 manifest
- `src/` 디렉터리 구조
- 기본 테스트 파일
- SIMPLE/MEDIUM/COMPLEX 복잡도를 유발하는 도메인 수 반영

#### 수용 기준
```bash
# 각 fixture에서 spawn-team 실행 후
# .claude/runs/{id}/plan.yml 생성 확인
# complexity가 예상 레벨로 감지되는지 확인
```

---

### Silo 3D — Docs Cleanup
**Session**: G (Wave 3, 독립)

#### 파일
| 작업 | 파일 |
|------|------|
| **생성** | `docs/getting-started.md` |
| **생성** | `docs/guide/spawn-team.md` |
| **생성** | `docs/guide/debate.md` |
| **생성** | `docs/guide/doctor.md` |
| **수정** | `README.md` — v1.0 기능 반영 |
| **수정** | `README.ko.md` — v1.0 기능 반영 |
| **이동** | `docs/CONFIGURATION.md` → `docs/guide/configuration.md` |
| **이동** | `docs/WORKFLOW.md` → `docs/guide/workflow.md` |
| **금지** | `.claude/skills/`, `tests/`, `install.sh` |

#### 수용 기준
- README.md에 v1.0 features 섹션 (confidence harness, doctor, preview) 존재
- `docs/getting-started.md`에 설치 + 퀵스타트 포함

---

## 세션 시작 체크리스트

각 세션 시작 전 확인:
```bash
# 1. 현재 branch 상태
git status
git log --oneline -5

# 2. 내 silo 파일 이외 변경 없음 확인
git diff --name-only HEAD

# 3. 의존 silo 완료 여부 (Wave 2+ 경우)
# Wave 2 세션: Wave 1 커밋 확인
git log --oneline | grep "silo-1"
```

각 silo 완료 후:
```bash
git add {silo-specific-files-only}
git commit -m "feat: silo {ID} — {feature name}"
```

---

## P1 / P2 경계 — 세션이 넘지 말아야 할 선

| 구현하지 말 것 | 이유 |
|----------------|------|
| Vector embedding / semantic search | Project 2 |
| Cross-run FP rate 자동 분석 | Project 2 |
| Skill lifecycle (promotion, retirement) | Project 2 |
| GraphDB 연동 | Project 2 |
| LLM API 직접 호출 (Claude API 외) | Project 2 |
| 새로운 서버/데몬/백그라운드 프로세스 | 아키텍처 원칙 위반 |
| npm/pip 패키지 의존성 추가 | 아키텍처 원칙 위반 |
