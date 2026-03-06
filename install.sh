#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/.claude/skills"
SCRIPTS_DIR="$SCRIPT_DIR/.claude/scripts"
TARGET_DIR="$HOME/.claude/skills"
SETTINGS_FILE="$HOME/.claude/settings.json"
VERSION_DIR="$HOME/.local/share/claude/versions"

SKILLS=(spawn-team debate ralph)

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

# ── 2. Teammate model wrapper ─────────────────────────────────────────────
echo "[2/4] Installing teammate model wrapper..."
TEAMMATE_SRC="$SCRIPTS_DIR/teammate.sh"
TEAMMATE_DST="$HOME/.claude/teammate.sh"

if [ -f "$TEAMMATE_SRC" ]; then
  cp "$TEAMMATE_SRC" "$TEAMMATE_DST"
  chmod +x "$TEAMMATE_DST"
  echo "  ✓ teammate.sh → ~/.claude/teammate.sh"
else
  echo "  ✗ $TEAMMATE_SRC not found — skipping"
fi

# Migrate: remove old versioned binary wrapper (if exists)
for real_bin in "$VERSION_DIR"/*.real 2>/dev/null; do
  [ -f "$real_bin" ] || continue
  base="${real_bin%.real}"
  if [ -f "$base" ] && head -1 "$base" 2>/dev/null | grep -q '^#!'; then
    echo "  ℹ Removing old binary wrapper: $(basename "$base")"
    mv "$real_bin" "$base"
    echo "  ✓ Restored $(basename "$base") to original binary"
  fi
done
[ -L "$HOME/.local/bin/claude.real" ] && rm "$HOME/.local/bin/claude.real" && echo "  ✓ Removed stale claude.real symlink"

# Point main symlink to latest version
VER=$(ls "$VERSION_DIR" 2>/dev/null | sort -V | tail -1)
if [ -n "$VER" ]; then
  ln -sf "$VERSION_DIR/$VER" "$HOME/.local/bin/claude"
  echo "  ✓ ~/.local/bin/claude → $VER"
fi

# Clean up old teammate-sonnet.sh
if [ -f "$HOME/.claude/teammate-sonnet.sh" ]; then
  echo "  ℹ Old teammate-sonnet.sh found — can be removed after verification"
fi
echo ""

# ── 3. settings.json ───────────────────────────────────────────────────────
echo "[3/4] Checking settings.json..."
REQUIRED_SETTINGS='{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_TEAMMATE_COMMAND": "'"$TEAMMATE_DST"'",
    "CLAUDE_CODE_SUBAGENT_MODEL": "haiku"
  },
  "permissions": {
    "allow": [
      "Skill(spawn-team)",
      "Skill(debate)"
    ]
  }
}'

if [ -f "$SETTINGS_FILE" ]; then
  echo "  ✓ $SETTINGS_FILE exists"
  if ! grep -q "CLAUDE_CODE_TEAMMATE_COMMAND" "$SETTINGS_FILE"; then
    echo "  ⚠ Missing CLAUDE_CODE_TEAMMATE_COMMAND — add manually:"
    echo "$REQUIRED_SETTINGS"
  fi
  if grep -q "teammate-sonnet" "$SETTINGS_FILE"; then
    echo "  ⚠ Old teammate-sonnet.sh reference. Update to: $TEAMMATE_DST"
  fi
else
  echo "  ✗ Not found. Creating..."
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

if [ -f "$TEAMMATE_DST" ] && [ -x "$TEAMMATE_DST" ]; then
  echo "  ✓ teammate.sh: installed"
else
  echo "  ✗ teammate.sh: not found or not executable"
  OK=false
fi

echo ""
if $OK; then
  echo "=== Installation complete ==="
  echo ""
  echo "Usage:"
  echo "  /spawn-team    — Spawn a team for your project"
  echo "  /debate        — Architecture review with Codex xhigh"
  echo "  /ralph         — PRD-based completion guarantee"
  echo ""
  echo "Model control:"
  echo "  Default = Sonnet (no action needed)"
  echo "  Haiku:  echo \"claude-haiku-4-5-20251001\" > /tmp/claude-team-model-{agent-name}"
else
  echo "=== Installation had issues — check output above ==="
  exit 1
fi
