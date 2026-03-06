#!/bin/bash
# Claude Code Model Override Wrapper
#
# WHY THIS EXISTS:
#   Claude Code passes a model flag when spawning team agents.
#   This wrapper intercepts the --model argument and substitutes it with
#   Sonnet (default) or Haiku (via signal file) before the real binary runs.
#   Expected to become unnecessary once Anthropic exposes agent model config.
#
# HOW IT WORKS:
#   1. install.sh moves the real binary to <version>.real
#   2. This script takes its place at the versioned path
#   3. Claude Code calls this with --model {some-model}
#   4. The wrapper replaces the --model value and exec's the real binary
#   5. Claude Code never knows the difference
#
# SELF-AWARE REAL PATH:
#   REAL is derived from the wrapper's own location — no hardcoded paths.
#   Works regardless of how Claude Code calls the binary (PATH or absolute).
#
# MODEL SELECTION:
#   Default: claude-sonnet-4-6
#   Per-spawn override: write model ID to /tmp/claude-team-model before Agent spawn.
#   File is consumed after one use (one-shot signal).
#
#   Sonnet (coding, planning, multi-file):
#     echo "claude-sonnet-4-6" > /tmp/claude-team-model
#
#   Haiku (tests, linting, repetitive checks):
#     echo "claude-haiku-4-5-20251001" > /tmp/claude-team-model

# Resolve own path through symlinks, append .real → sibling real binary
REAL="$(readlink -f "$0").real"

# Log every invocation for debugging
echo "$(date '+%Y-%m-%d %H:%M:%S') WRAPPER args: $*" >> /tmp/claude-wrapper.log

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

# Swap --model value regardless of what Claude Code passes
ARGS=()
SWAPPED=false
NEXT_IS_MODEL=false
for arg in "$@"; do
    if $NEXT_IS_MODEL; then
        ARGS+=("$TARGET")
        SWAPPED=true
        ORIGINAL="$arg"
        NEXT_IS_MODEL=false
    elif [ "$arg" = "--model" ]; then
        ARGS+=("$arg")
        NEXT_IS_MODEL=true
    else
        ARGS+=("$arg")
    fi
done

if $SWAPPED; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') MODEL SWAP: $ORIGINAL → $TARGET" >> /tmp/claude-wrapper.log
fi

exec "$REAL" "${ARGS[@]}"
