# Test Guide: bash에서 tmux 모드 동작 확인

`teammateMode: "tmux"` 설정 상태에서 **tmux 밖(plain bash)**에서 Claude Code를 실행했을 때의 동작 검증.

---

## 목적

tmux 모드가 tmux 환경 없이도 동작하는지, 또는 graceful fallback이 되는지 확인.

---

## 사전 조건

```bash
# 1. tmux 밖에서 실행 중인지 확인
echo $TMUX
# -> 값이 비어야 함 (tmux 밖)

# 2. settings.json 확인
grep -E "teammateMode|TEAMMATE_COMMAND" ~/.claude/settings.json
# -> teammateMode: "tmux", TEAMMATE_COMMAND 설정됨

# 3. 로그/signal 정리
rm -f /tmp/claude-teammate.log /tmp/claude-team-model*
```

---

## Test BT1: tmux 밖에서 1-agent 스폰

```bash
# 1. tmux 밖 터미널에서 Claude Code 시작
claude

# 2. Claude 안에서:
#    "테스트 팀 만들어줘. 에이전트 1명, 이름은 bash-tmux-test. 바로 종료."

# 3. 결과 확인
cat /tmp/claude-teammate.log
```

### 예상 시나리오

| 시나리오 | 증상 | 의미 |
|----------|------|------|
| A. 정상 스폰 | 로그에 model 찍힘 + 에이전트 응답 | tmux 밖에서도 TEAMMATE_COMMAND 호출됨 |
| B. tmux 세션 자동 생성 | 새 tmux 세션 생겨남 + 에이전트 작동 | Claude Code가 tmux 세션을 알아서 만듦 |
| C. 스폰 실패 에러 | 에러 메시지 출력 | tmux 필수 의존성 확인 |
| D. in-process fallback | 로그 없음, 에이전트는 작동 | tmux 없으면 자동으로 in-process 전환 |

### 실제 결과

```
(여기에 기록)
```

### 판정

- [ ] A: tmux 밖에서도 TEAMMATE_COMMAND 작동
- [ ] B: tmux 자동 생성 → 사실상 tmux 필수
- [ ] C: 스폰 실패 → tmux 필수 (에러 메시지 확인)
- [ ] D: in-process fallback → 모델 라우팅 불가

---

## Test BT2: Haiku signal (시나리오 A/B인 경우만)

BT1이 시나리오 A 또는 B인 경우만 진행.

```bash
# 1. signal 준비
echo "claude-haiku-4-5" > /tmp/claude-team-model-haiku-bash-test

# 2. Claude 안에서:
#    "테스트 팀, 에이전트 1명 이름 haiku-bash-test. 바로 종료."

# 3. 확인
cat /tmp/claude-teammate.log
```

### 실제 결과

```
(여기에 기록)
```

### 판정

- [ ] PASS: `model=claude-haiku-4-5`
- [ ] FAIL: signal file 미읽음

---

## 결론 기록

| 항목 | 결과 |
|------|------|
| tmux 밖 + tmux 모드 | (A/B/C/D 중 기록) |
| TEAMMATE_COMMAND 호출 여부 | (예/아니오) |
| 모델 라우팅 가능 여부 | (예/아니오) |
| tmux 필수 의존성 확정 | (예/아니오) |

**결론에 따른 조치:**
- A/B → install.sh/README에 tmux 선택적으로 표기 가능
- C → tmux 필수 의존성 명시, 에러 메시지 가이드 추가
- D → in-process fallback 문서화, 모델 라우팅 제한 안내
