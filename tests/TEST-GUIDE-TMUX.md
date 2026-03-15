# Test Guide: tmux Environment

teammate.sh 모델 라우팅이 tmux 환경에서 올바르게 작동하는지 검증.
tmux split-pane 모드에서의 스폰, 모델 제어, zombie 정리 포함.

---

## 사전 조건

```bash
# 1. teammate.sh 설치 확인
ls -la ~/.claude/teammate.sh
# -> 실행 가능한 파일이어야 함

# 2. settings.json 확인 (tmux 모드로 변경 필요)
# teammateMode를 "tmux"로 변경:
#   "teammateMode": "tmux"
grep -E "teammateMode|TEAMMATE_COMMAND|AGENT_TEAMS" ~/.claude/settings.json

# 3. tmux 안에서 실행 중인지 확인
echo $TMUX
# -> 값이 있어야 함

# 4. tmux 세션 깨끗한지 확인
tmux list-sessions
# -> claude-* 세션이 현재 세션 외에 없어야 함
```

---

## Test Matrix

| ID | 테스트 | 검증 대상 | 예상 결과 |
|----|--------|----------|----------|
| T1 | Sonnet 1-agent spawn | teammate.sh 호출 + 모델 | log에 model=claude-sonnet-4-6 |
| T2 | Haiku signal spawn | signal file 기반 라우팅 | log에 model=claude-haiku-4-5 |
| T3 | 3-agent parallel spawn | 병렬 스폰 + 모델 정확성 | 3개 에이전트 각각 올바른 model |
| T4 | Pane count limit | 3번째 이후 에이전트 스폰 | "Could not determine pane count" 에러 없음 |
| T5 | Zombie 정리 | 세션 종료 후 잔류 | 이전 세션의 pane/session 없음 |
| T6 | Claude 종료 후 정리 | Leader 종료 시 | Agent pane 잔류 여부 확인 |

---

## Test T1: Sonnet 1-Agent Spawn

```bash
# 1. 환경 준비
rm -f /tmp/claude-teammate.log /tmp/claude-team-model*
# zombie 세션 정리
tmux list-sessions | grep "claude-" | grep -v "$(tmux display-message -p '#{session_name}')" | cut -d: -f1 | xargs -I{} tmux kill-session -t {} 2>/dev/null

# 2. tmux 안에서 Claude Code 시작
claude

# 3. Claude 안에서 입력:
#    "테스트 팀 만들어줘. 에이전트 1명, 이름은 sonnet-test. 아무 작업 없이 바로 종료."

# 4. Claude 종료 후 확인
cat /tmp/claude-teammate.log
tmux list-panes -a
```

### 예상 결과
```
2026-03-06 HH:MM:SS TEAMMATE agent=sonnet-test model=claude-sonnet-4-6
```

### 실제 결과
```
(여기에 기록)
```

### 판정
- [ ] PASS: log에 `model=claude-sonnet-4-6` 확인
- [ ] FAIL: log 파일 없음
- [ ] FAIL: `model=claude-opus-4-6`

---

## Test T2: Haiku Signal Spawn

```bash
# 1. 환경 준비
rm -f /tmp/claude-teammate.log /tmp/claude-team-model*
echo "claude-haiku-4-5" > /tmp/claude-team-model-haiku-test

# 2. Claude Code 시작
claude

# 3. Claude 안에서:
#    "테스트 팀, 에이전트 1명 이름 haiku-test. 바로 종료."

# 4. 확인
cat /tmp/claude-teammate.log
```

### 예상 결과
```
... TEAMMATE agent=haiku-test model=claude-haiku-4-5
```

### 실제 결과
```
(여기에 기록)
```

### 판정
- [ ] PASS: `model=claude-haiku-4-5`
- [ ] FAIL: signal file 미읽음

---

## Test T3: 3-Agent Parallel Spawn

```bash
# 1. 환경 준비
rm -f /tmp/claude-teammate.log /tmp/claude-team-model*
echo "claude-haiku-4-5" > /tmp/claude-team-model-unit-tester

# 2. Claude Code 시작
claude

# 3. Claude 안에서:
#    "3명 팀: fe-dev(Sonnet) + be-dev(Sonnet) + unit-tester(Haiku).
#     바로 종료해."

# 4. 확인
cat /tmp/claude-teammate.log
tmux list-panes -a
```

### 예상 결과
```
... TEAMMATE agent=fe-dev model=claude-sonnet-4-6
... TEAMMATE agent=be-dev model=claude-sonnet-4-6
... TEAMMATE agent=unit-tester model=claude-haiku-4-5
```

### 실제 결과
```
(여기에 기록)
```

### 판정
- [ ] PASS: 3개 모두 올바른 모델
- [ ] FAIL: 3번째 스폰 실패 ("Could not determine pane count")
- [ ] FAIL: 모델 불일치

---

## Test T4: Pane Count Limit (이전 에러 재현 확인)

T3에서 3개 에이전트 스폰 성공 여부로 판정.

### 판정
- [ ] PASS: 3개 모두 스폰 성공 (pane count 에러 없음)
- [ ] FAIL: "Could not determine pane count" 에러 발생

---

## Test T5: Zombie 세션 정리

```bash
# 1. T1 또는 T3 완료 후 Claude 종료
# 2. 새로운 Claude 세션 시작 전에 확인
tmux list-sessions
tmux list-panes -a
```

### 판정
- [ ] PASS: 이전 팀의 pane/session이 남아있지 않음
- [ ] FAIL: Agent pane이 남아있음 (zombie)
  - 이 경우: spawn-team Step 0 cleanup 또는 TeammateIdle hook 필요

---

## Test T6: Leader 종료 시 Agent 정리

```bash
# 1. T3 상태에서 Leader만 /exit 또는 Ctrl+C
# 2. 즉시 확인
tmux list-panes -a | grep -v "$(tmux display-message -p '#{session_name}')"
ps aux | grep "[c]laude.*--agent" | wc -l
```

### 판정
- [ ] PASS: Agent pane/프로세스 자동 종료
- [ ] FAIL: Agent가 zombie로 남음
  - 필요 조치: SessionEnd hook + TeammateIdle hook 설정

---

## 빠른 자동 확인

```bash
./tests/test-spawn-integration.sh --check
```

---

## 결론

| 결과 | 조치 |
|------|------|
| T1-T6 모두 PASS | tmux 모드 정상. zombie 관리 불필요. |
| T1 PASS + T3 FAIL (pane count) | zombie 세션 정리 후 재시도. 3+ agent시 주의. |
| T5/T6 FAIL (zombie) | TeammateIdle hook 설정 + SessionEnd cleanup 필요. |
| T1 FAIL (log 없음) | TEAMMATE_COMMAND 미작동. teammate.sh 경로/권한 확인. |

---

## tmux vs bash 비교 판정

두 가이드 모두 완료 후:

| 기준 | bash (in-process) | tmux (split-pane) |
|------|-------------------|-------------------|
| 모델 제어 | B1 결과 | T1 결과 |
| Haiku 지원 | B2 결과 | T2 결과 |
| 병렬 스폰 | B3 결과 | T3 결과 |
| Zombie 없음 | B4 결과 | T5/T6 결과 |
| 시각적 모니터링 | 불가 | 가능 |

**최종 선택 기준**: 모델 제어 + Zombie 관리. 둘 다 PASS면 bash 선호 (단순).
