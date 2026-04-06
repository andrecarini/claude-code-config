#!/bin/bash
set -e

PROJECT_PATH="${1:-$(pwd)}"
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"  # absolute path
PROJECT_NAME="$(basename "$PROJECT_PATH" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
CLAUDE_HOST_CONFIG="$HOME/.claude"
CONTAINER_CONFIG="$CLAUDE_HOST_CONFIG/claude-code-config/container-config"
LAUNCHER_DIR="$PROJECT_PATH/.claude-data/.launcher"

# --- Auto-setup if needed ---

if [ ! -d "$PROJECT_PATH/.claude-data" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════╗"
  echo "║  First-time setup needed for this project.       ║"
  echo "║  Launching Claude to configure interactively...  ║"
  echo "║  Run /sandbox when Claude starts.                ║"
  echo "╚══════════════════════════════════════════════════╝"
  echo ""
  cd "$PROJECT_PATH"
  claude
  if [ ! -d "$PROJECT_PATH/.claude-data" ]; then
    echo "Setup was not completed (.claude-data not found). Aborting."
    exit 1
  fi
fi

# --- Ensure launcher metadata dir exists ---
mkdir -p "$LAUNCHER_DIR"

# --- Get host Claude Code version ---
HOST_VERSION="$(claude --version 2>/dev/null | awk '{print $1}')"

# --- Build image if needed ---
build_image() {
  echo "Building claude-sandbox image with Claude Code v${HOST_VERSION}..."
  docker build \
    --build-arg "CLAUDE_VERSION=${HOST_VERSION}" \
    -t "claude-sandbox:${HOST_VERSION}" \
    -t "claude-sandbox:latest" \
    "$CONTAINER_CONFIG"
}

if ! docker image inspect claude-sandbox:latest > /dev/null 2>&1; then
  build_image
fi

# --- Generate container name ---
if [ -f "$LAUNCHER_DIR/container-name" ]; then
  CONTAINER_NAME="$(cat "$LAUNCHER_DIR/container-name")"
else
  # Short hash of absolute project path to avoid collisions
  PATH_HASH="$(echo -n "$PROJECT_PATH" | md5sum | cut -c1-8)"
  CONTAINER_NAME="claude-${PROJECT_NAME}-${PATH_HASH}"
  echo "$CONTAINER_NAME" > "$LAUNCHER_DIR/container-name"
fi

# --- Staleness check ---
STALE_REASONS=""

if [ -f "$LAUNCHER_DIR/claude-version" ]; then
  CONTAINER_VERSION="$(cat "$LAUNCHER_DIR/claude-version")"
  if [ "$HOST_VERSION" != "$CONTAINER_VERSION" ]; then
    STALE_REASONS="${STALE_REASONS}  - Claude Code version mismatch: container has v${CONTAINER_VERSION}, host has v${HOST_VERSION}\n"
  fi
fi

if [ -f "$LAUNCHER_DIR/container-created" ]; then
  CREATED="$(cat "$LAUNCHER_DIR/container-created")"
  CREATED_TS="$(date -d "$CREATED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$CREATED" +%s 2>/dev/null || echo 0)"
  NOW_TS="$(date +%s)"
  AGE_DAYS=$(( (NOW_TS - CREATED_TS) / 86400 ))
  if [ "$AGE_DAYS" -gt 7 ]; then
    STALE_REASONS="${STALE_REASONS}  - Container is ${AGE_DAYS} days old (base OS packages may be outdated)\n"
  fi
fi

if [ -n "$STALE_REASONS" ]; then
  echo ""
  echo "⚠️  Container may be stale:"
  echo -e "$STALE_REASONS"
  echo "Options:"
  echo "  [r] Rebuild — fresh container with Claude Code v${HOST_VERSION}"
  echo "  [c] Continue as-is"
  echo ""
  read -r -p "Choice [r/c]: " CHOICE
  if [ "$CHOICE" = "r" ] || [ "$CHOICE" = "R" ]; then
    # Remove old container if it exists
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    build_image
    # Clear container name so a new one is created below
    rm -f "$LAUNCHER_DIR/container-name"
    PATH_HASH="$(echo -n "$PROJECT_PATH" | md5sum | cut -c1-8)"
    CONTAINER_NAME="claude-${PROJECT_NAME}-${PATH_HASH}"
    echo "$CONTAINER_NAME" > "$LAUNCHER_DIR/container-name"
  fi
fi

# --- Build skill mounts (filter out host-only skills) ---
SKILL_MOUNTS=()
for skill in "$CLAUDE_HOST_CONFIG/claude-code-config/skills/"*/; do
  [ -d "$skill" ] || continue
  SKILL_NAME="$(basename "$skill")"
  if ! grep -q 'host-only: true' "$skill/SKILL.md" 2>/dev/null; then
    SKILL_MOUNTS+=(-v "$skill:/home/claude/.claude/skills/$SKILL_NAME:ro")
  fi
done

# --- Extra env for deploy key ---
EXTRA_ENV=()
if [ -f "$PROJECT_PATH/deploy_key" ]; then
  EXTRA_ENV+=(-e 'GIT_SSH_COMMAND=ssh -i /project/deploy_key -o StrictHostKeyChecking=no')
fi

# --- PAT auth support ---
EXTRA_MOUNTS=()
if [ -f "$PROJECT_PATH/.claude-data/git-askpass.sh" ]; then
  EXTRA_MOUNTS+=(-v "$PROJECT_PATH/.claude-data/git-askpass.sh:/home/claude/.claude/git-askpass.sh:ro")
  EXTRA_ENV+=(-e "GIT_ASKPASS=/home/claude/.claude/git-askpass.sh")
  EXTRA_MOUNTS+=(-v "$PROJECT_PATH/.claude-data/git-pat:/home/claude/.claude/git-pat:ro")
fi

# --- Launch or reattach ---
if docker inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
  # Container exists — reattach
  echo "Reattaching to existing container: $CONTAINER_NAME"
  docker start -ai "$CONTAINER_NAME"
else
  # Create new container
  echo "Creating new container: $CONTAINER_NAME"

  # Save metadata
  echo "$HOST_VERSION" > "$LAUNCHER_DIR/claude-version"
  date -u +"%Y-%m-%dT%H:%M:%S" > "$LAUNCHER_DIR/container-created"

  docker create -it \
    --name "$CONTAINER_NAME" \
    --hostname "claude-sandbox" \
    "${EXTRA_ENV[@]}" \
    -v "$PROJECT_PATH:/project" \
    -v "$PROJECT_PATH/.claude-data:/home/claude/.claude" \
    -v "$LAUNCHER_DIR:/home/claude/.claude/.launcher:ro" \
    -v "$CLAUDE_HOST_CONFIG/.credentials.json:/home/claude/.claude/.credentials.json:ro" \
    -v "$CONTAINER_CONFIG/CLAUDE.md:/home/claude/.claude/CLAUDE.md:ro" \
    -v "$CONTAINER_CONFIG/settings.json:/home/claude/.claude/settings.json:ro" \
    -v "$CLAUDE_HOST_CONFIG/claude-code-config/scripts/statusline.pl:/home/claude/.claude/statusline.pl:ro" \
    "${SKILL_MOUNTS[@]}" \
    "${EXTRA_MOUNTS[@]}" \
    claude-sandbox:latest

  docker start -ai "$CONTAINER_NAME"
fi
