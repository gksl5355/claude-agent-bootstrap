#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/.claude/skills"
TARGET_DIR="$HOME/.claude/skills"
SETTINGS_FILE="$HOME/.claude/settings.json"
WRAPPER_SRC="$SCRIPT_DIR/.claude/scripts/claude-model-wrapper.sh"
VERSION_DIR="$HOME/.local/share/claude/versions"

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
echo "  Claude Code hardcodes claude-opus-4-6 when spawning team agents."
echo "  The wrapper intercepts spawns at the versioned binary path and"
echo "  substitutes Sonnet or Haiku before the real binary runs."
echo ""

# Detect current Claude version directory
VER=$(ls "$VERSION_DIR" 2>/dev/null | grep -v '\.real' | sort -V | tail -1)

if [ -z "$VER" ]; then
  echo "  ✗ Claude binary not found in $VERSION_DIR — skipping wrapper install"
  echo "    Install Claude Code first, then re-run this script."
  WRAPPER_SKIPPED=true
else
  VERSIONED_BIN="$VERSION_DIR/$VER"
  VERSIONED_REAL="$VERSION_DIR/$VER.real"
  echo "  Detected Claude version: $VER"

  if [ -f "$VERSIONED_REAL" ]; then
    # Already wrapped — update wrapper content only
    echo "  ℹ Wrapper already installed. Updating wrapper script."
    cp "$WRAPPER_SRC" "$VERSIONED_BIN"
    chmod +x "$VERSIONED_BIN"
    echo "  ✓ Wrapper updated at $VERSIONED_BIN"
  else
    # First install: move real binary aside, install wrapper in its place
    mv "$VERSIONED_BIN" "$VERSIONED_REAL"
    cp "$WRAPPER_SRC" "$VERSIONED_BIN"
    chmod +x "$VERSIONED_BIN"
    echo "  ✓ $VER.real → real binary"
    echo "  ✓ $VER     → wrapper (intercepts all agent spawns)"
  fi

  # Keep ~/.local/bin/claude pointing to the wrapper
  ln -sf "$VERSIONED_BIN"  "$HOME/.local/bin/claude"
  ln -sf "$VERSIONED_REAL" "$HOME/.local/bin/claude.real"
  echo "  ✓ ~/.local/bin/claude → wrapper"
  echo ""
  echo "  NOTE: If Claude Code updates to a new version, re-run ./install.sh"
  echo "  to reinstall the wrapper at the new versioned path."

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
  if [ -f "$VERSIONED_REAL" ] && [ -x "$VERSIONED_BIN" ] && head -1 "$VERSIONED_BIN" | grep -q '^#!'; then
    echo "  ✓ model wrapper: active (team agents will spawn as Sonnet)"
  else
    echo "  ✗ model wrapper: not active — check $VERSIONED_BIN"
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
