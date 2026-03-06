#!/bin/bash
# test-spawn-integration.sh — Integration test for team agent spawning
# Tests whether CLAUDE_CODE_TEAMMATE_COMMAND is invoked in the current mode.
#
# Usage:
#   ./tests/test-spawn-integration.sh [--setup-only]
#
# --setup-only: prepare environment and print instructions (don't spawn)
#
# After running, check results with:
#   ./tests/test-spawn-integration.sh --check
set -euo pipefail

LOG="/tmp/claude-teammate.log"
SETTINGS="$HOME/.claude/settings.json"

case "${1:-}" in
    --setup-only)
        echo "=== Integration Test Setup ==="
        rm -f "$LOG" /tmp/claude-team-model /tmp/claude-team-model-*

        MODE=$(grep -o '"teammateMode":\s*"[^"]*"' "$SETTINGS" 2>/dev/null | grep -o '"[^"]*"$' | tr -d '"')
        CMD=$(grep -o '"CLAUDE_CODE_TEAMMATE_COMMAND":\s*"[^"]*"' "$SETTINGS" 2>/dev/null | grep -o '"[^"]*"$' | tr -d '"')
        TEAMS=$(grep -o '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS":\s*"[^"]*"' "$SETTINGS" 2>/dev/null | grep -o '"[^"]*"$' | tr -d '"')
        IN_TMUX=$([[ -n "${TMUX:-}" ]] && echo "yes" || echo "no")

        echo ""
        echo "Environment:"
        echo "  teammateMode:    ${MODE:-not set}"
        echo "  TEAMMATE_CMD:    ${CMD:-not set}"
        echo "  AGENT_TEAMS:     ${TEAMS:-not set}"
        echo "  Inside tmux:     $IN_TMUX"
        echo "  Claude version:  $(claude --version 2>/dev/null || echo 'unknown')"
        echo "  Log file:        $LOG (cleared)"
        echo ""
        echo "Ready. Start a new Claude Code session and run:"
        echo ""
        echo '  "1명짜리 테스트 팀 만들어. 에이전트 이름은 model-test로 해. 아무 작업 없이 바로 종료해."'
        echo ""
        echo "Then check results:"
        echo "  ./tests/test-spawn-integration.sh --check"
        ;;

    --check)
        echo "=== Integration Test Results ==="
        echo ""

        MODE=$(grep -o '"teammateMode":\s*"[^"]*"' "$SETTINGS" 2>/dev/null | grep -o '"[^"]*"$' | tr -d '"')
        IN_TMUX=$([[ -n "${TMUX:-}" ]] && echo "yes" || echo "no")

        echo "Mode: ${MODE:-auto} | tmux: $IN_TMUX"
        echo ""

        if [ ! -f "$LOG" ]; then
            echo "  FAIL  teammate.sh was NOT invoked (log file missing)"
            echo ""
            echo "  Conclusion: CLAUDE_CODE_TEAMMATE_COMMAND is NOT used in this mode."
            echo "  teammate.sh model routing does NOT work here."
            echo ""
            echo "  If teammateMode=in-process:"
            echo "    -> Agents likely spawned with leader's model (Opus)"
            echo "    -> Switch to teammateMode=tmux for model control"
            echo "  If teammateMode=tmux:"
            echo "    -> Check CLAUDE_CODE_TEAMMATE_COMMAND path is correct"
            exit 1
        fi

        echo "Log contents:"
        cat "$LOG"
        echo ""

        ENTRIES=$(wc -l < "$LOG")
        echo "  [$ENTRIES agent(s) spawned via teammate.sh]"
        echo ""

        # Check each entry
        ALL_OK=true
        while IFS= read -r line; do
            agent=$(echo "$line" | grep -oP 'agent=\K\S+')
            model=$(echo "$line" | grep -oP 'model=\K\S+')

            case "$model" in
                claude-sonnet-4-6)
                    printf "  \033[32mPASS\033[0m  %s -> Sonnet\n" "$agent" ;;
                claude-haiku-4-5-20251001)
                    printf "  \033[32mPASS\033[0m  %s -> Haiku\n" "$agent" ;;
                claude-opus-4-6)
                    printf "  \033[31mFAIL\033[0m  %s -> Opus (model override not working!)\n" "$agent"
                    ALL_OK=false ;;
                *)
                    printf "  \033[33mWARN\033[0m  %s -> %s (unexpected model)\n" "$agent" "$model"
                    ALL_OK=false ;;
            esac
        done < "$LOG"

        echo ""
        if $ALL_OK; then
            printf "\033[32mSUCCESS: teammate.sh model routing works in %s mode\033[0m\n" "${MODE:-auto}"
        else
            printf "\033[31mFAILED: Model override not working correctly\033[0m\n"
        fi

        echo ""
        echo "=== Haiku Signal Test ==="
        echo "To test Haiku routing, run in Claude Code:"
        echo '  "Haiku 모델로 haiku-test라는 에이전트 1명 스폰해줘"'
        echo "Before spawning, the SKILL.md should write:"
        echo '  echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model-haiku-test'
        echo "Then --check again."
        ;;

    --clean)
        rm -f "$LOG" /tmp/claude-team-model /tmp/claude-team-model-*
        echo "Cleaned test artifacts"
        ;;

    *)
        echo "Usage:"
        echo "  $0 --setup-only   Prepare environment, print instructions"
        echo "  $0 --check        Check test results after spawning"
        echo "  $0 --clean        Clean up test artifacts"
        ;;
esac
