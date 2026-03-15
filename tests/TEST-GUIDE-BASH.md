# Test Guide: Plain Bash (no tmux)

teammate.sh 모델 라우팅이 tmux 없이 plain bash에서도 작동하는지 검증.
성공 시 tmux 없이 팀 에이전트 사용 가능 (zombie 문제 없음).

---

## 사전 조건

```bash
# 1. teammate.sh 설치 확인
ls -la ~/.claude/teammate.sh
# -> 실행 가능한 파일이어야 함

# 2. settings.json 확인
grep -E "teammateMode|TEAMMATE_COMMAND|AGENT_TEAMS" ~/.claude/settings.json
# -> teammateMode: "in-process"
# -> CLAUDE_CODE_TEAMMATE_COMMAND: "~/.claude/teammate.sh"
# -> CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"

# 3. tmux 밖에서 실행 중인지 확인
echo $TMUX
# -> 비어있어야 함 (tmux 안에 있으면 exit로 나가기)
```

---

## Test Matrix

| ID | 테스트 | 검증 대상 | 예상 결과 |
|----|--------|----------|----------|
| B1 | Sonnet 1-agent spawn | teammate.sh 호출 여부 | log에 model=claude-sonnet-4-6 |
| B2 | Haiku signal spawn | signal file -> Haiku | log에 model=claude-haiku-4-5 |
| B3 | 2-agent parallel spawn | 병렬 스폰 시 model 정확성 | 각각 올바른 model |
| B4 | Agent 종료 | in-process 종료 시 자동 정리 | claude exit 후 자식 프로세스 없음 |

---

## Test B1: Sonnet 1-Agent Spawn

```bash
# 1. 환경 준비
rm -f /tmp/claude-teammate.log /tmp/claude-team-model*

# 2. tmux 밖에서 Claude Code 시작
claude

# 3. Claude 안에서 입력:
#    "테스트 팀 만들어줘. 에이전트 1명, 이름은 sonnet-test. 아무 작업 없이 바로 종료."

# 4. Claude 종료 후 확인
cat /tmp/claude-teammate.log
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
- [ ] FAIL: log 파일 없음 (teammate.sh 미호출)
- [ ] FAIL: `model=claude-opus-4-6` (모델 오버라이드 실패)

---

## Test B2: Haiku Signal Spawn

```bash
# 1. 환경 준비
rm -f /tmp/claude-teammate.log /tmp/claude-team-model*

# 2. Haiku signal 수동 작성 (Claude가 해야 하지만 수동 테스트)
echo "claude-haiku-4-5" > /tmp/claude-team-model-haiku-test

# 3. Claude Code 시작
claude

# 4. Claude 안에서 입력:
#    "테스트 팀, 에이전트 1명 이름 haiku-test. 바로 종료."

# 5. 확인
cat /tmp/claude-teammate.log
```

### 예상 결과
```
2026-03-06 HH:MM:SS TEAMMATE agent=haiku-test model=claude-haiku-4-5
```

### 실제 결과
```
(여기에 기록)
```

### 판정
- [ ] PASS: `model=claude-haiku-4-5`
- [ ] FAIL: `model=claude-sonnet-4-6` (signal 미읽음)

---

## Test B3: 2-Agent Parallel Spawn

```bash
# 1. 환경 준비
rm -f /tmp/claude-teammate.log /tmp/claude-team-model*
echo "claude-haiku-4-5" > /tmp/claude-team-model-tester

# 2. Claude Code 시작
claude

# 3. Claude 안에서 입력:
#    "2명 팀: coder(Sonnet) + tester(Haiku). 이름은 coder, tester. 바로 종료."

# 4. 확인
cat /tmp/claude-teammate.log
```

### 예상 결과
```
... TEAMMATE agent=coder model=claude-sonnet-4-6
... TEAMMATE agent=tester model=claude-haiku-4-5
```

### 실제 결과
```
(여기에 기록)
```

### 판정
- [ ] PASS: coder=Sonnet, tester=Haiku
- [ ] FAIL: 둘 다 같은 모델
- [ ] FAIL: log 비어있음

---

## Test B4: 프로세스 정리

```bash
# 1. B1 또는 B3 완료 후
# 2. Claude Code 종료 (Ctrl+C 또는 /exit)
# 3. 확인
ps aux | grep claude | grep -v grep
# -> claude 프로세스가 남아있으면 FAIL
```

### 판정
- [ ] PASS: Claude 종료 시 에이전트 프로세스도 종료됨 (zombie 없음)
- [ ] FAIL: 에이전트 프로세스가 남아있음

---

## 빠른 자동 확인

```bash
# 모든 테스트 후 한 번에 확인
./tests/test-spawn-integration.sh --check
```

---

## 결론

| 결과 | 조치 |
|------|------|
| B1-B4 모두 PASS | bash + in-process 채택. tmux 불필요. |
| B1 FAIL (log 없음) | in-process에서 TEAMMATE_COMMAND 미사용. tmux 모드 전환 필요. |
| B1 PASS + B2 FAIL | signal file 미읽음. teammate.sh 수정 필요. |
| B4 FAIL | in-process 종료 시 프로세스 미정리. cleanup hook 필요. |
