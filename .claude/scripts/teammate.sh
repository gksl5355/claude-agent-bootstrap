#!/bin/bash
# teammate.sh — Team agent model wrapper
#
# Reads an optional signal file for per-spawn model selection.
# Default = Sonnet. For Haiku, write signal before spawn.
# Works in both tmux and in-process modes.
#
# Signal file paths (checked in order):
#   /tmp/claude-team-model-{agent-name}  (agent-specific, race-safe)
#   /tmp/claude-team-model               (generic fallback)
#
# Usage in SKILL.md:
#   Sonnet: no signal needed (default)
#   Haiku:  echo "claude-haiku-4-5" > /tmp/claude-team-model-{agent-name}

# 1. Extract agent name from args (--agent-name <name>)
AGENT_NAME=""
PREV=""
for arg in "$@"; do
    if [[ "$PREV" == "--agent-name" ]]; then
        AGENT_NAME="$arg"
        break
    fi
    PREV="$arg"
done

# 2. Read signal file (agent-specific > generic > default Sonnet)
MODEL="claude-sonnet-4-6"
if [ -n "$AGENT_NAME" ] && [ -f "/tmp/claude-team-model-${AGENT_NAME}" ]; then
    VAL=$(cat "/tmp/claude-team-model-${AGENT_NAME}")
    rm -f "/tmp/claude-team-model-${AGENT_NAME}"
    case "$VAL" in
        claude-opus-4-6|claude-sonnet-4-6|claude-haiku-4-5) MODEL="$VAL" ;;
    esac
elif [ -f "/tmp/claude-team-model" ]; then
    VAL=$(cat "/tmp/claude-team-model")
    rm -f "/tmp/claude-team-model"
    case "$VAL" in
        claude-opus-4-6|claude-sonnet-4-6|claude-haiku-4-5) MODEL="$VAL" ;;
    esac
fi

# 3. Log for debugging/verification
echo "$(date '+%Y-%m-%d %H:%M:%S') TEAMMATE agent=${AGENT_NAME:-unknown} model=$MODEL" >> /tmp/claude-teammate.log

# 4. Strip existing --model flags, then force selected model
args=()
skip_next=false
for arg in "$@"; do
    if $skip_next; then skip_next=false; continue; fi
    if [[ "$arg" == "--model" ]]; then skip_next=true; continue; fi
    if [[ "$arg" == --model=* ]]; then continue; fi
    args+=("$arg")
done

exec claude "${args[@]}" --model "$MODEL"
