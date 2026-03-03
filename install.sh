#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/.claude/skills"
TARGET_DIR="$HOME/.claude/skills"
SETTINGS_FILE="$HOME/.claude/settings.json"

SKILLS=(spawn-team debate ralph hud configure-notifications)

echo "=== Team Orchestrator Installer ==="
echo ""

# 1. Create target directory
mkdir -p "$TARGET_DIR"

# 2. Create symlinks
echo "[1/3] Creating symlinks..."
for skill in "${SKILLS[@]}"; do
  if [ -L "$TARGET_DIR/$skill" ]; then
    rm "$TARGET_DIR/$skill"
  fi
  ln -sf "$SKILLS_DIR/$skill" "$TARGET_DIR/$skill"
  echo "  ✓ $skill → $TARGET_DIR/$skill"
done
echo ""

# 3. Check settings.json
echo "[2/3] Checking settings.json..."
if [ -f "$SETTINGS_FILE" ]; then
  echo "  ✓ $SETTINGS_FILE exists"
  echo ""
  echo "  Please ensure these entries are in your settings.json:"
else
  echo "  ✗ $SETTINGS_FILE not found"
  echo ""
  echo "  Create $SETTINGS_FILE with:"
fi

cat << 'SETTINGS'

  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
      "teammateMode": "tmux"
    },
    "permissions": {
      "allow": [
        "Skill(spawn-team)",
        "Skill(debate)"
      ]
    }
  }

SETTINGS

# 4. Verify
echo "[3/3] Verifying installation..."
OK=true
for skill in "${SKILLS[@]}"; do
  if [ -L "$TARGET_DIR/$skill" ] && [ -d "$TARGET_DIR/$skill" ]; then
    echo "  ✓ $skill"
  else
    echo "  ✗ $skill — symlink broken"
    OK=false
  fi
done

echo ""
if $OK; then
  echo "=== Installation complete ==="
  echo ""
  echo "Usage:"
  echo "  /spawn-team    — Start a team for your project"
  echo "  /debate        — Architecture review with Codex xhigh"
  echo "  /ralph         — PRD-based completion guarantee"
  echo ""
  echo "Requirements:"
  echo "  - Claude Max (Agent Teams enabled)"
  echo "  - CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in settings.json"
  echo "  - Codex CLI (optional, for /debate reviews)"
else
  echo "=== Installation had issues. Check symlinks above. ==="
  exit 1
fi
