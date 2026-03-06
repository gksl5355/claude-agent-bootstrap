#!/bin/bash
# test-teammate-unit.sh — Automated unit tests for teammate.sh
# Tests model selection, signal files, argument stripping, parallel safety.
# Uses a mock claude binary to capture arguments without spawning real sessions.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEAMMATE="$REPO/.claude/scripts/teammate.sh"
PASS=0 FAIL=0 TOTAL=0

# ── Setup: mock claude binary ─────────────────────────────────────────────
MOCK_DIR=$(mktemp -d)
trap "rm -rf '$MOCK_DIR' /tmp/test-par-* /tmp/claude-team-model /tmp/claude-team-model-* /tmp/claude-teammate.log" EXIT

cat > "$MOCK_DIR/claude" << 'MOCK'
#!/bin/bash
# Mock claude: just output the --model value to stdout
for ((i=1; i<=$#; i++)); do
    if [[ "${!i}" == "--model" ]]; then
        j=$((i+1)); echo "${!j}"; exit 0
    fi
done
MOCK
chmod +x "$MOCK_DIR/claude"

# ── Helpers ────────────────────────────────────────────────────────────────
assert_model() {
    local name="$1" expected="$2"; shift 2
    TOTAL=$((TOTAL+1))
    local actual
    actual=$(PATH="$MOCK_DIR:$PATH" "$TEAMMATE" "$@" 2>/dev/null) || true
    if [[ "$actual" == "$expected" ]]; then
        printf "  \033[32mPASS\033[0m  %s\n" "$name"
        PASS=$((PASS+1))
    else
        printf "  \033[31mFAIL\033[0m  %s  (expected=%s actual=%s)\n" "$name" "$expected" "$actual"
        FAIL=$((FAIL+1))
    fi
}

assert_file() {
    local name="$1" path="$2" should_exist="$3"
    TOTAL=$((TOTAL+1))
    if { [[ "$should_exist" == "yes" ]] && [[ -f "$path" ]]; } || \
       { [[ "$should_exist" == "no" ]] && [[ ! -f "$path" ]]; }; then
        printf "  \033[32mPASS\033[0m  %s\n" "$name"
        PASS=$((PASS+1))
    else
        printf "  \033[31mFAIL\033[0m  %s  (file %s, expected=%s)\n" "$name" \
            "$([ -f "$path" ] && echo 'exists' || echo 'missing')" "$should_exist"
        FAIL=$((FAIL+1))
    fi
}

clean() { rm -f /tmp/claude-team-model /tmp/claude-team-model-* /tmp/claude-teammate.log; }

# ── Tests ──────────────────────────────────────────────────────────────────
echo "=== teammate.sh Unit Tests ==="
echo ""

# --- Group 1: Model Selection ---
echo "[1/5] Model Selection"
clean
assert_model "T01 Default (no signal) -> Sonnet" "claude-sonnet-4-6" \
    --agent-name t01

echo "claude-sonnet-4-6" > /tmp/claude-team-model
assert_model "T02 Generic signal Sonnet" "claude-sonnet-4-6" \
    --agent-name t02

echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model
assert_model "T03 Generic signal Haiku" "claude-haiku-4-5-20251001" \
    --agent-name t03

echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model-t04
assert_model "T04 Agent-specific signal Haiku" "claude-haiku-4-5-20251001" \
    --agent-name t04

echo ""

# --- Group 2: Priority & Fallback ---
echo "[2/5] Priority & Fallback"
echo "claude-sonnet-4-6" > /tmp/claude-team-model
echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model-t05
assert_model "T05 Agent-specific > generic" "claude-haiku-4-5-20251001" \
    --agent-name t05
assert_file "T06 Generic preserved when specific used" "/tmp/claude-team-model" "yes"
rm -f /tmp/claude-team-model

echo "invalid-model-xyz" > /tmp/claude-team-model
assert_model "T07 Invalid signal -> Sonnet fallback" "claude-sonnet-4-6" \
    --agent-name t07

echo "" > /tmp/claude-team-model
assert_model "T08 Empty signal -> Sonnet fallback" "claude-sonnet-4-6" \
    --agent-name t08

echo ""

# --- Group 3: Signal Lifecycle ---
echo "[3/5] Signal Lifecycle"
echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model-t09
PATH="$MOCK_DIR:$PATH" "$TEAMMATE" --agent-name t09 >/dev/null 2>&1
assert_file "T09 Agent-specific signal consumed" "/tmp/claude-team-model-t09" "no"

echo "claude-sonnet-4-6" > /tmp/claude-team-model
PATH="$MOCK_DIR:$PATH" "$TEAMMATE" --agent-name t10 >/dev/null 2>&1
assert_file "T10 Generic signal consumed" "/tmp/claude-team-model" "no"

echo ""

# --- Group 4: Argument Handling ---
echo "[4/5] Argument Handling"
clean
assert_model "T11 --model opus stripped -> Sonnet" "claude-sonnet-4-6" \
    --agent-name t11 --model claude-opus-4-6

assert_model "T12 --model between other args" "claude-sonnet-4-6" \
    --agent-id id1 --model claude-opus-4-6 --agent-name t12 --team-name test

echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model-t13
assert_model "T13 Signal + opus stripped -> Haiku" "claude-haiku-4-5-20251001" \
    --agent-name t13 --model claude-opus-4-6

assert_model "T14 No --agent-name arg" "claude-sonnet-4-6" \
    --agent-id some-id --team-name test

echo ""

# --- Group 5: Parallel Safety ---
echo "[5/5] Parallel Safety (3 agents simultaneous)"
clean
echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model-par-a
echo "claude-sonnet-4-6"         > /tmp/claude-team-model-par-b
echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model-par-c

(PATH="$MOCK_DIR:$PATH" "$TEAMMATE" --agent-name par-a 2>/dev/null > /tmp/test-par-a) &
(PATH="$MOCK_DIR:$PATH" "$TEAMMATE" --agent-name par-b 2>/dev/null > /tmp/test-par-b) &
(PATH="$MOCK_DIR:$PATH" "$TEAMMATE" --agent-name par-c 2>/dev/null > /tmp/test-par-c) &
wait

for pair in "par-a:claude-haiku-4-5-20251001" "par-b:claude-sonnet-4-6" "par-c:claude-haiku-4-5-20251001"; do
    name="${pair%%:*}"
    expected="${pair#*:}"
    actual=$(cat "/tmp/test-$name" 2>/dev/null | tr -d '\n')
    TOTAL=$((TOTAL+1))
    if [[ "$actual" == "$expected" ]]; then
        printf "  \033[32mPASS\033[0m  T15-%s parallel -> %s\n" "$name" "${expected##*-}"
        PASS=$((PASS+1))
    else
        printf "  \033[31mFAIL\033[0m  T15-%s parallel (expected=%s actual=%s)\n" "$name" "$expected" "$actual"
        FAIL=$((FAIL+1))
    fi
done

# Verify all signal files consumed
ALL_CONSUMED=true
for agent in par-a par-b par-c; do
    [ -f "/tmp/claude-team-model-$agent" ] && ALL_CONSUMED=false
done
TOTAL=$((TOTAL+1))
if $ALL_CONSUMED; then
    printf "  \033[32mPASS\033[0m  T16 All parallel signals consumed\n"
    PASS=$((PASS+1))
else
    printf "  \033[31mFAIL\033[0m  T16 Some parallel signals not consumed\n"
    FAIL=$((FAIL+1))
fi

# --- Group 6: Logging ---
echo ""
echo "[Bonus] Logging"
clean
rm -f /tmp/claude-teammate.log
PATH="$MOCK_DIR:$PATH" "$TEAMMATE" --agent-name log-test 2>/dev/null >/dev/null
TOTAL=$((TOTAL+1))
if [ -f /tmp/claude-teammate.log ] && grep -q "agent=log-test model=claude-sonnet-4-6" /tmp/claude-teammate.log; then
    printf "  \033[32mPASS\033[0m  T17 Log entry written with correct format\n"
    PASS=$((PASS+1))
else
    printf "  \033[31mFAIL\033[0m  T17 Log entry missing or malformed\n"
    FAIL=$((FAIL+1))
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
if [ $FAIL -eq 0 ]; then
    printf "\033[32mAll %d tests passed\033[0m\n" "$TOTAL"
else
    printf "\033[31m%d/%d passed, %d failed\033[0m\n" "$PASS" "$TOTAL" "$FAIL"
fi
echo "========================================"
exit $FAIL
