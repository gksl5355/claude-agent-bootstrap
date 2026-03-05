#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/.claude/skills"
TARGET_DIR="$HOME/.claude/skills"
SETTINGS_FILE="$HOME/.claude/settings.json"
CLAUDE_BIN="$HOME/.local/bin/claude"
CLAUDE_REAL="$HOME/.local/bin/claude.real"
WRAPPER_SRC="$SCRIPT_DIR/.claude/scripts/claude-model-wrapper.sh"

SKILLS=(spawn-team debate ralph hud configure-notifications)

echo "=== Team Orchestrator Installer ==="
echo ""

# ── 1. Skill symlinks ──────────────────────────────────────────────────────
echo "[1/4] Creating skill symlinks..."
mkdir -p "$TARGET_DIR"
for skill in "${SKILLS[@]}"; do
  [ -L "$TARGET_DIR/$skill" ] && rm "$TARGET_DIR/$skill"
  ln -sf "$SKILLS_DIR/$skill" "$TARGET_DIR/$skill"
  echo "  ✓ $skill"
done
echo ""

# ── 2. Model wrapper ───────────────────────────────────────────────────────
echo "[2/4] Installing model override wrapper..."
echo "  Claude Code hardcodes Opus for team agents. The wrapper intercepts"
echo "  the spawn call and replaces the model argument with Sonnet (or Haiku)."
echo "  Requires teammateMode=tmux — without it, agents run in-process and"
echo "  bypass this wrapper entirely."
echo ""

if [ ! -f "$CLAUDE_BIN" ] && [ ! -L "$CLAUDE_BIN" ]; then
  echo "  ✗ claude binary not found at $CLAUDE_BIN — skipping wrapper install"
  echo "    Install Claude Code first, then re-run this script."
  WRAPPER_SKIPPED=true
else
  # Already wrapped?
  if [ -f "$CLAUDE_REAL" ]; then
    echo "  ℹ Wrapper already installed (claude.real exists). Updating wrapper script."
    cp "$WRAPPER_SRC" "$CLAUDE_BIN"
    chmod +x "$CLAUDE_BIN"
    echo "  ✓ Wrapper updated"
  else
    # First install: preserve original, install wrapper
    REAL_PATH=$(readlink -f "$CLAUDE_BIN")
    echo "  Real binary: $REAL_PATH"

    # Create claude.real → actual binary
    ln -sf "$REAL_PATH" "$CLAUDE_REAL"
    echo "  ✓ claude.real → $REAL_PATH"

    # Replace claude with wrapper
    rm -f "$CLAUDE_BIN"
    cp "$WRAPPER_SRC" "$CLAUDE_BIN"
    chmod +x "$CLAUDE_BIN"
    echo "  ✓ claude → wrapper (calls claude.real internally)"
  fi

  # Verify wrapper calls claude.real (not itself)
  if grep -q 'claude.real' "$CLAUDE_BIN"; then
    echo "  ✓ Wrapper verified"
  else
    echo "  ✗ Wrapper looks wrong — check $CLAUDE_BIN"
  fi
  WRAPPER_SKIPPED=false
fi
echo ""

# ── 3. settings.json ───────────────────────────────────────────────────────
echo "[3/4] Checking settings.json..."
REQUIRED_SETTINGS='{
  "teammateMode": "tmux",
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)"
    ]
  },
  "model": "sonnet"
}'

if [ -f "$SETTINGS_FILE" ]; then
  echo "  ✓ $SETTINGS_FILE exists"
  if ! grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$SETTINGS_FILE"; then
    echo "  ⚠ Missing CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS — add it manually:"
    echo "$REQUIRED_SETTINGS"
  fi
else
  echo "  ✗ Not found. Creating with required settings..."
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo "$REQUIRED_SETTINGS" > "$SETTINGS_FILE"
  echo "  ✓ Created $SETTINGS_FILE"
fi
echo ""

# ── 4. Verify ──────────────────────────────────────────────────────────────
echo "[4/4] Verifying..."
OK=true
for skill in "${SKILLS[@]}"; do
  if [ -L "$TARGET_DIR/$skill" ] && [ -d "$TARGET_DIR/$skill" ]; then
    echo "  ✓ skill: $skill"
  else
    echo "  ✗ skill: $skill — symlink broken"
    OK=false
  fi
done

if [ "$WRAPPER_SKIPPED" = false ]; then
  if [ -f "$CLAUDE_REAL" ] && [ -x "$CLAUDE_BIN" ]; then
    echo "  ✓ model wrapper: active (team agents will spawn as Sonnet)"
  else
    echo "  ✗ model wrapper: not active"
    OK=false
  fi
fi

echo ""
if $OK; then
  echo "=== Installation complete ==="
  echo ""
  echo "IMPORTANT: Always run Claude Code inside tmux."
  echo "  Team agents only use Sonnet/Haiku (not Opus) when spawned from a tmux session."
  echo "  Without tmux, the model wrapper is bypassed and agents default to Opus."
  echo ""
  echo "  tmux new-session -s dev"
  echo "  claude"
  echo ""
  echo "Usage:"
  echo "  /spawn-team    — Spawn a team for your project"
  echo "  /debate        — Architecture review with Codex xhigh"
  echo "  /ralph         — PRD-based completion guarantee"
  echo ""
  echo "Model control (before each Agent spawn in SKILL.md):"
  echo "  Sonnet: echo \"claude-sonnet-4-6\"         > /tmp/claude-team-model"
  echo "  Haiku:  echo \"claude-haiku-4-5-20251001\" > /tmp/claude-team-model"
  echo ""
  echo "To uninstall wrapper:"
  echo "  rm ~/.local/bin/claude && mv ~/.local/bin/claude.real ~/.local/bin/claude"
else
  echo "=== Installation had issues — check output above ==="
  exit 1
fi
