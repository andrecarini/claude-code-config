---
name: sandbox
description: Prepares a project for running Claude Code in an isolated Docker dev container. Builds the image, configures git auth, and sets up the launcher. Use when the user wants to containerize a project, set up a sandbox, or run dev tooling safely.
user-invocable: true
host-only: true
allowed-tools: Bash, Read, Write, Edit, Glob, AskUserQuestion
---

Prepare the current project for running Claude Code in a sandboxed Docker container.
Do everything end-to-end — build the image, set up the project, configure git access.
Skip any step that is already done. At the end, output the launch command.

The container-config lives at `~/.claude/claude-code-config/container-config/`.
The container has its own CLAUDE.md and settings.json mounted by the launcher scripts — do NOT ask the user about adding container instructions to the project CLAUDE.md.

## Step 1: Verify container-config exists

```bash
ls "$HOME/.claude/claude-code-config/container-config/Dockerfile" 2>/dev/null && echo "OK" || echo "MISSING"
```

If MISSING, tell the user the container config repo hasn't been set up yet (they need to install it first — see the repo README) and **stop**.

Also verify the sandbox-specific `claude.json` exists (skips onboarding inside containers):

```bash
ls "$HOME/.claude/claude-code-config/container-config/claude.json" 2>/dev/null && echo "CLAUDE_JSON_OK" || echo "CLAUDE_JSON_MISSING"
```

If MISSING, create it:

```json
{
  "hasCompletedOnboarding": true,
  "lastOnboardingVersion": "99.0.0",
  "numStartups": 1,
  "hasSeenTasksHint": true,
  "hasSeenStashHint": true
}
```

## Step 2: Build Docker image if needed

```bash
docker image inspect claude-sandbox:latest > /dev/null 2>&1 && echo "EXISTS" || echo "MISSING"
```

If MISSING, build it:

```bash
HOST_VERSION="$(claude --version 2>/dev/null | awk '{print $1}')"
docker build --build-arg "CLAUDE_VERSION=$HOST_VERSION" -t "claude-sandbox:$HOST_VERSION" -t "claude-sandbox:latest" "$HOME/.claude/claude-code-config/container-config"
```

## Step 3: Create .claude-data directory

```bash
mkdir -p .claude-data
```

## Step 4: Update .gitignore

Check and add entries as needed. Run all checks in parallel:

```bash
grep -q "\.claude-data" .gitignore 2>/dev/null && echo "CLAUDE_DATA_OK" || echo "CLAUDE_DATA_NEEDS"
grep -q "deploy_key" .gitignore 2>/dev/null && echo "DEPLOY_KEY_OK" || echo "DEPLOY_KEY_NEEDS"
```

Append any missing entries to `.gitignore`. Create the file if it doesn't exist.

## Step 5: Git access setup (auto-detect, minimal questions)

The launcher scripts support two auth methods:
- **PAT via GIT_ASKPASS** (for HTTPS remotes) — files: `.claude-data/git-askpass.sh`, `.claude-data/git-pat`
- **Deploy key via GIT_SSH_COMMAND** (for SSH remotes) — file: `deploy_key` in project root

**Check what's already configured:**

```bash
[ -f .claude-data/git-askpass.sh ] && echo "PAT_AUTH_OK" || echo "NO_PAT"
[ -f deploy_key ] && echo "DEPLOY_KEY_OK" || echo "NO_DEPLOY_KEY"
git remote get-url origin 2>/dev/null || echo "NO_REMOTE"
```

**Decision logic:**
- If `PAT_AUTH_OK` or `DEPLOY_KEY_OK` → git auth is configured, **skip entirely**.
- If no auth is configured and the remote is HTTPS:
  - Check if a global PAT exists at `~/.claude/.claude-data/git-pat` or similar locations.
  - If found, copy it and create the askpass script automatically (no questions).
  - If not found, ask the user via AskUserQuestion for their GitHub fine-grained PAT.
  - Create `.claude-data/git-pat` with the token and `.claude-data/git-askpass.sh`:
    ```bash
    #!/bin/bash
    cat /home/claude/.claude/git-pat
    ```
- If no auth is configured and the remote is SSH:
  - Ask the user via AskUserQuestion whether to generate a new deploy key, provide an existing one, or skip.
  - When a deploy key is configured (generated or provided), also create `.claude-data/git-ssh-command.sh`:
    ```bash
    #!/bin/bash
    exec ssh -i /project/deploy_key -o StrictHostKeyChecking=no "$@"
    ```
    The launcher uses this script as `GIT_SSH_COMMAND` inside the container.

## Step 6: Add `claude-sandbox` to PATH (first time only)

The launcher scripts live in `~/.claude/claude-code-config/container-config/bin/` (`claude-sandbox.sh` for Linux/macOS, `claude-sandbox.ps1` for Windows). The goal is to add this `bin/` directory to PATH so the scripts are directly invocable. **Never copy launcher files elsewhere** — always add the source directory to PATH so updates propagate automatically.

```bash
command -v claude-sandbox > /dev/null 2>&1 && echo "ON_PATH" || echo "NOT_ON_PATH"
```

If already on PATH, skip.

If NOT_ON_PATH, detect the OS:

```bash
uname -s 2>/dev/null || echo "Windows"
```

**Linux/macOS:**

Make the script executable and create an extensionless symlink:

```bash
chmod +x ~/.claude/claude-code-config/container-config/bin/claude-sandbox.sh
ln -sf claude-sandbox.sh ~/.claude/claude-code-config/container-config/bin/claude-sandbox
```

Add `bin/` to PATH by appending to the shell profile if not already present:

```bash
SHELL_RC="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.zshrc"
grep -q 'claude-code-config/container-config/bin' "$SHELL_RC" 2>/dev/null || echo 'export PATH="$HOME/.claude/claude-code-config/container-config/bin:$PATH"' >> "$SHELL_RC"
```

**Windows (MINGW/MSYS):**

Add the `bin/` directory to the **user-level** PATH via the Windows registry, if not already present:

```bash
BINDIR_WIN="$(cygpath -w "$HOME/.claude/claude-code-config/container-config/bin")"
CURRENT_PATH="$(powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('PATH','User')" | tr -d '\r')"
if echo "$CURRENT_PATH" | grep -qi 'container-config[/\\]bin\|container-config\\\\bin'; then
  echo "ALREADY_IN_PATH"
else
  powershell.exe -NoProfile -Command "[Environment]::SetEnvironmentVariable('PATH', '$BINDIR_WIN;' + [Environment]::GetEnvironmentVariable('PATH','User'), 'User')"
  echo "ADDED_TO_PATH"
fi
```

Also on Windows, ensure `.PS1` is in the user's `PATHEXT` so PowerShell scripts can be invoked by name:

```bash
CURRENT_PATHEXT="$(powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('PATHEXT','User')" | tr -d '\r')"
if echo "$CURRENT_PATHEXT" | grep -qi '\.PS1'; then
  echo "PATHEXT_OK"
else
  SYSTEM_PATHEXT="$(powershell.exe -NoProfile -Command "[Environment]::GetEnvironmentVariable('PATHEXT','Machine')" | tr -d '\r')"
  powershell.exe -NoProfile -Command "[Environment]::SetEnvironmentVariable('PATHEXT', '$SYSTEM_PATHEXT;.PS1', 'User')"
  echo "ADDED_PS1_TO_PATHEXT"
fi
```

Tell the user they need to **restart their terminal** (or open a new one) for the PATH and PATHEXT changes to take effect.

## Step 7: Output the launch command

Output:

> ✅ Project is ready for sandboxed Claude. Exit Claude and run:
>
> `claude-sandbox`
>
> (from this project directory)
>
> Claude will start with full autonomy inside an isolated container.
> Only your project files are accessible. Auth is read-only from your host config.
