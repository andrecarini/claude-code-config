#!/bin/bash
set -e

PROJECT_PATH="${1:-$(pwd)}"
PROJECT_NAME="$(basename "$PROJECT_PATH" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
CLAUDE_HOST_CONFIG="$HOME/.claude"
CONTAINER_CONFIG="$CLAUDE_HOST_CONFIG/container-config"

# --- Auto-setup if needed ---

NEEDS_SETUP=false

if ! docker image inspect claude-sandbox > /dev/null 2>&1; then
  NEEDS_SETUP=true
fi

if [ ! -d "$PROJECT_PATH/.claude-data" ]; then
  NEEDS_SETUP=true
fi

if [ "$NEEDS_SETUP" = true ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║  First-time setup needed for this project.       ║"
  echo "║  Launching Claude to configure interactively...  ║"
  echo "║  Run /sandbox when Claude starts.                ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  cd "$PROJECT_PATH"
  claude
  # After user exits Claude, verify setup completed
  if [ ! -d "$PROJECT_PATH/.claude-data" ]; then
    echo "Setup was not completed (.claude-data not found). Aborting."
    exit 1
  fi
fi

# --- Launch container ---

EXTRA_ENV=()
if [ -f "$PROJECT_PATH/deploy_key" ]; then
  EXTRA_ENV+=(-e 'GIT_SSH_COMMAND=ssh -i /project/deploy_key -o StrictHostKeyChecking=no')
fi

docker run --rm -it \
  --name "claude-${PROJECT_NAME}" \
  --hostname "claude-sandbox" \
  "${EXTRA_ENV[@]}" \
  -v "$PROJECT_PATH:/project" \
  -v "$PROJECT_PATH/.claude-data:/home/claude/.claude" \
  -v "$CLAUDE_HOST_CONFIG/.credentials.json:/home/claude/.claude/.credentials.json:ro" \
  -v "$CONTAINER_CONFIG/CLAUDE.md:/home/claude/.claude/CLAUDE.md:ro" \
  -v "$CONTAINER_CONFIG/settings.json:/home/claude/.claude/settings.json:ro" \
  -v "$CLAUDE_HOST_CONFIG/statusline.pl:/home/claude/.claude/statusline.pl:ro" \
  -v "$CLAUDE_HOST_CONFIG/skills/refresh:/home/claude/.claude/skills/refresh:ro" \
  -v "claude-npm-cache:/home/claude/.npm" \
  -v "claude-pip-cache:/home/claude/.cache/pip" \
  claude-sandbox
