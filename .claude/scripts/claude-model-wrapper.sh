#!/bin/bash
# Claude Code Model Override Wrapper
#
# WHY THIS EXISTS:
#   Claude Code hardcodes --model claude-opus-4-6 when spawning team agents.
#   No settings file or config can override this. This wrapper intercepts the
#   spawn call and substitutes Sonnet or Haiku before the real binary runs.
#   Expected to become unnecessary once Anthropic exposes agent model config.
#
# HOW IT WORKS:
#   1. install.sh moves the real binary to <version>.real
#   2. This script takes its place at the versioned path
#   3. Claude Code calls this with --model claude-opus-4-6 (its hardcoded value)
#   4. The wrapper swaps the model arg and exec's the real binary
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

# Swap model argument, log the effective model
ARGS=()
SWAPPED=false
for arg in "$@"; do
    case "$arg" in
        claude-opus-4-6)
            ARGS+=("$TARGET")
            SWAPPED=true
            ;;
        *) ARGS+=("$arg") ;;
    esac
done

if $SWAPPED; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') MODEL SWAP: claude-opus-4-6 → $TARGET" >> /tmp/claude-wrapper.log
fi

exec "$REAL" "${ARGS[@]}"
