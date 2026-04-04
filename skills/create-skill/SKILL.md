---
name: create-skill
description: Create or update a custom skill (slash command) integrated with this config system
argument-hint: [skill-name] [description or changes]
user-invocable: true
host-only: true
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Glob
---

Create or update a custom skill for Claude Code, integrated with the config repo at `~/.claude/claude-code-config/`.

All changes are made in the repo (`~/.claude/claude-code-config/skills/`), then the live symlink in `~/.claude/skills/` is refreshed to pick up the changes (handles both real symlinks and Windows copy-fallback).

The user should provide: `$ARGUMENTS`

If no arguments were given, ask the user what they want to do.

## Step 1: Determine mode

Check if the skill already exists:

```bash
ls ~/.claude/claude-code-config/skills/<skill-name>/SKILL.md 2>/dev/null
```

- **Exists** → **update mode**: read the existing SKILL.md and apply the requested changes.
- **Does not exist** → **create mode**: scaffold a new skill from scratch.

If the user named an existing skill but didn't specify what to change, read the current SKILL.md and ask what they'd like to modify.

## Step 2: Gather requirements

**Create mode** — parse the arguments or ask the user for:
- **Skill name** — lowercase, hyphens only, max 64 chars (e.g. `deploy`, `review-pr`, `lint-fix`)
- **What the skill does** — one-line summary
- **When it should be used** — what triggers it (user invokes it, Claude auto-detects, etc.)

**Update mode** — understand what the user wants to change:
- Frontmatter fields (description, allowed-tools, effort, etc.)
- Steps in the skill body (add, remove, rewrite)
- Behavior changes

## Step 3: Design / apply changes

Before writing, review the frontmatter reference to pick the right options.

### Frontmatter fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name. Defaults to directory name if omitted. Lowercase, hyphens, max 64 chars. |
| `description` | Yes | What the skill does and when to use it. Front-load the key use case. Max 250 chars in listings. |
| `argument-hint` | No | Hint shown in autocomplete, e.g. `[issue-number]` or `[filename]`. |
| `user-invocable` | No | `true` (default) = shows in `/` menu. `false` = hidden, only Claude can invoke it. |
| `disable-model-invocation` | No | `true` = Claude won't auto-load this skill. Use for manual-only commands. Default `false`. |
| `allowed-tools` | No | Tools available without per-use permission. Space-separated or YAML list. |
| `model` | No | Override the model for this skill (e.g. `claude-sonnet-4-6`). |
| `effort` | No | Override effort level: `low`, `medium`, `high`, `max`. |
| `context` | No | Set to `fork` to run in an isolated subagent context. |
| `agent` | No | Which subagent type when `context: fork` (e.g. `Explore`, `Plan`). |
| `paths` | No | Glob patterns — skill auto-activates only for matching files. |

### Available tools for `allowed-tools`

Core tools: `Read`, `Grep`, `Glob`, `Edit`, `Write`, `Bash`, `WebFetch`, `WebSearch`, `Agent`, `Skill`, `AskUserQuestion`

Patterns: `Bash(*)` (all), `Bash(npm *)` (only npm), `Bash(find:*)` (only find), `MCP(*)` (all MCP)

### String substitutions available in skill body

- `$ARGUMENTS` — everything the user typed after the skill name
- `$0` through `$N` — positional arguments (space-separated)
- `${CLAUDE_SESSION_ID}` — current session ID
- `${CLAUDE_SKILL_DIR}` — absolute path to this skill's directory

## Step 4: Write the skill file

All writes go to the repo at `~/.claude/claude-code-config/skills/<skill-name>/SKILL.md`.

**Create mode:** Create the directory and file.

**Update mode:** Edit the existing file in place using the Edit tool. Preserve any parts the user didn't ask to change.

Guidelines for writing good skill bodies:
- Be specific and imperative — "Run X", "Read Y", "Ask the user Z"
- Include actual commands in fenced code blocks where applicable
- Use numbered steps for sequential operations
- Use AskUserQuestion when user input or confirmation is needed
- Reference paths relative to `~/.claude/claude-code-config/` for config files, or relative to the project for project files
- If the skill modifies config files, it should integrate with `/backup` (i.e. changes go in the repo)

## Step 5: Refresh the live symlink

Always re-link, even in update mode — this ensures Windows copy-fallback gets refreshed:

```bash
rm -rf ~/.claude/skills/<skill-name>
ln -sf ~/.claude/claude-code-config/skills/<skill-name> ~/.claude/skills/<skill-name>
```

## Step 6: Update the README

Read `~/.claude/claude-code-config/README.md`. There are **three places** to update:

### 6a: Intro bullet list

Near the top, find the line starting with `- **Slash commands**` and update it to include the new skill. Keep the format: `/<name>` followed by a short parenthetical. List skills alphabetically.

### 6b: File tree

Find the `skills/` section inside the `What's Included` fenced code block.

**Create mode:** Add a new line in alphabetical order:

```
│   ├── <skill-name>/SKILL.md          # /<skill-name> — <short description>
```

Use `├──` for non-last entries and `└──` for the last. Update the previous last entry from `└──` to `├──` if needed.

**Update mode:** If the description changed, update the comment on the existing line.

### 6c: Features section

If the skill is user-invocable and significant enough to warrant its own section (i.e. it's a major feature, not a utility), add a `### <Skill Name> (\`/<skill-name>\`)` section under `## Features` with a brief description of what it does. Use AskUserQuestion to ask the user if they want a features section for this skill. For small/utility skills, skip this.

**Update mode:** If there's an existing features section for this skill and the description/behavior changed, update it.

## Step 7: Verify

Confirm the skill is in place:

```bash
ls -la ~/.claude/skills/<skill-name>/SKILL.md
```

Then tell the user:
- **Create:** The skill is ready to use as `/<skill-name>`
- **Update:** `/<skill-name>` has been updated — changes take effect immediately
- The README has been updated
- Changes will be synced on next `/backup`
- On other machines, `/backup` will automatically link it after pulling
