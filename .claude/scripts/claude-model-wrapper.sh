#!/bin/bash
# Claude Code Model Override Wrapper
#
# WHY THIS EXISTS:
#   Claude Code hardcodes --model claude-opus-4-6 when spawning team agents.
#   No settings file or config can override this. This wrapper sits in front
#   of the real claude binary and swaps the model argument before it reaches
#   the real binary.
#
# HOW IT WORKS (step by step):
#   1. install.sh renames the real claude binary reference to claude.real
#   2. This script takes its place as "claude"
#   3. When Claude Code spawns a team agent, it calls "claude --model claude-opus-4-6 ..."
#   4. This script receives those arguments
#   5. It loops through them, finds claude-opus-4-6, replaces with target model
#   6. Calls claude.real with the modified arguments
#   7. Claude Code never knows the difference
#
# MODEL SELECTION:
#   Default: claude-sonnet-4-6
#   Per-spawn override: write model ID to /tmp/claude-team-model before Agent call.
#   File is deleted after one use (one-shot signal).
#
#   Sonnet (complex coding, planning):
#     echo "claude-sonnet-4-6" > /tmp/claude-team-model
#
#   Haiku (simple tests, linting, repetitive tasks):
#     echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model

REAL="$HOME/.local/bin/claude.real"

# Read one-shot model signal
SIGNAL="/tmp/claude-team-model"
TARGET="claude-sonnet-4-6"  # default

if [ -f "$SIGNAL" ]; then
    VAL=$(cat "$SIGNAL")
    rm -f "$SIGNAL"
    case "$VAL" in
        claude-sonnet-4-6|claude-haiku-4-5-20251001)
            TARGET="$VAL"
            ;;
    esac
fi

# Swap model argument
ARGS=()
for arg in "$@"; do
    case "$arg" in
        claude-opus-4-6) ARGS+=("$TARGET") ;;
        *)               ARGS+=("$arg")    ;;
    esac
done

exec "$REAL" "${ARGS[@]}"
