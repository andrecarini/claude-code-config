---
name: sandbox
description: Prepare a project for running Claude Code in an isolated Docker dev container and build the image if needed
user-invocable: true
host-only: true
allowed-tools: Bash, Read, Write, Edit, Glob, AskUserQuestion
---

Prepare the current project for running Claude Code in a sandboxed Docker container.
Do everything end-to-end — build the image, set up the project, configure git access.
At the very end, output a single command the user can copy-paste to launch the container.

## Step 1: Ensure Docker image exists

Check if the `claude-sandbox` image exists:

```bash
docker image inspect claude-sandbox > /dev/null 2>&1 && echo "EXISTS" || echo "MISSING"
```

If MISSING, build it:

```bash
cd "$HOME/.claude/container-config" && docker build -t claude-sandbox .
```

If the Dockerfile or container-config directory doesn't exist, tell the user the container
config hasn't been set up yet and stop.

## Step 2: Create .claude-data directory

```bash
mkdir -p .claude-data
```

## Step 3: Update .gitignore

Check if `.gitignore` exists and already contains `.claude-data/`:

```bash
grep -q "\.claude-data" .gitignore 2>/dev/null && echo "ALREADY_IGNORED" || echo "NEEDS_ADDING"
```

If NEEDS_ADDING, append `.claude-data/` to `.gitignore`. Create the file if it doesn't exist.
Also ensure `deploy_key` and `deploy_key.pub` are in `.gitignore` (for Step 4).

## Step 4: Git access setup

Ask the user using AskUserQuestion:

"How should the container access this git repo for push/pull?"

Options:
1. **"I'll handle git push/pull outside the container"** — skip key setup.
2. **"Generate a new deploy key"** — generate an ed25519 SSH keypair at `./deploy_key`,
   display the public key, and tell the user to add it as a deploy key in the repo settings
   (GitHub: Settings > Deploy keys > Add deploy key, check "Allow write access").
3. **"I already have a deploy key"** — ask for the path, copy it to `./deploy_key`.

If option 2 or 3: ensure `deploy_key` is in `.gitignore`, set permissions (`chmod 600`),
and create/update `.claude-data/git-ssh-command.sh`:

```bash
#!/bin/bash
exec ssh -i /project/deploy_key -o StrictHostKeyChecking=no "$@"
```

Then tell the user that inside the container, git push/pull will automatically use the deploy key.

## Step 5: Project-specific CLAUDE.md (optional)

Check if the project has a `.claude/CLAUDE.md` or `CLAUDE.md`. If it does, ask the user:

"This project has a CLAUDE.md. Want to add container-specific instructions to it?"

If yes, help them add relevant instructions (e.g., build commands, test commands, etc.).

## Step 6: Add to PATH (first time only)

Check if `claude-sandbox` is already on PATH:

```bash
command -v claude-sandbox > /dev/null 2>&1 && echo "ON_PATH" || echo "NOT_ON_PATH"
```

If NOT_ON_PATH, detect the OS and set it up:

```bash
uname -s 2>/dev/null || echo "Windows"
```

**Linux/macOS:**
```bash
mkdir -p ~/.local/bin
ln -sf ~/.claude/container-config/claude-sandbox.sh ~/.local/bin/claude-sandbox
chmod +x ~/.claude/container-config/claude-sandbox.sh
```

**Windows (MINGW/MSYS):**
```bash
cp "$HOME/.claude/container-config/claude-sandbox.cmd" "$HOME/AppData/Local/Microsoft/WindowsApps/claude-sandbox.cmd"
```

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
