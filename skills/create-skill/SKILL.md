---
name: create-skill
description: Creates one or more new custom skills (slash commands) with automatic related-skill linking. Use when the user wants to build a new skill, add a slash command, scaffold a new capability, or turn a repeated workflow into a reusable command. Use /update-skill to modify existing skills.
argument-hint: [skill-name...] [description]
user-invocable: true
host-only: true
related:
  - update-skill
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Glob, Grep
---

Create one or more new custom skills for Claude Code, integrated with the config repo at `~/.claude/ccpraxis/`.

All changes are made in the repo (`~/.claude/ccpraxis/skills/`), then the live symlinks in `~/.claude/skills/` are refreshed to pick up the changes (handles both real symlinks and Windows copy-fallback).

The user should provide: `$ARGUMENTS`

If no arguments were given, ask the user what they want to create.

**Take your time with this skill.** Creating new skills is a design task — ask clarifying questions, think about edge cases, and validate the plan with the user before writing anything. Don't rush to deliver.

## Step 1: Parse skill names from arguments

The user may specify one or more skill names followed by a description. Skill names are lowercase-hyphenated tokens (`[a-z][a-z0-9-]*`).

**Parsing algorithm:** greedily consume all leading tokens that match the skill name pattern. The first token that doesn't match (or the remainder after all matching tokens) is the description.

Examples:
- `/create-skill deploy Set up deployment automation` → skill: `deploy`, description: "Set up deployment automation"
- `/create-skill foo bar Build two related tools` → skills: `foo`, `bar`, description: "Build two related tools"

**Always confirm the interpretation with the user** before proceeding:

> I'll create two skills: `foo` and `bar`.
> Description: "Build two related tools".
> Is that right?

This confirmation step is essential since the skills don't exist yet and there's no directory to validate against.

## Step 2: Validate that none already exist

For each parsed skill name, check:

```bash
ls ~/.claude/ccpraxis/skills/<skill-name>/SKILL.md 2>/dev/null
```

- **None exist** → proceed to Step 3.
- **Some already exist** → Warn the user about each existing skill:

  > `/<skill-name>` already exists. Use `/update-skill <skill-name> <changes>` to modify it.

  Continue with the skills that don't exist if the user's intent is clear, or ask for clarification. Don't create or overwrite existing skills.

## Step 3: Gather requirements

For each skill being created, parse the arguments or ask the user for:
- **Skill name** — lowercase, hyphens only, max 64 chars. Consider gerund form (`processing-pdfs`) or action-oriented (`process-pdfs`). Avoid vague names (`helper`, `utils`, `tools`). Cannot contain reserved words ("anthropic", "claude").
- **What the skill does** — one-line summary
- **When it should be used** — what triggers it (user invokes it, Claude auto-detects, etc.)

**For multi-skill creation, also ask:**
- How do the skills relate to each other? (What's the division of responsibility?)
- Should any of them also link to existing skills via `related`?
- Should they share the same frontmatter settings (allowed-tools, effort, etc.) or differ?

If the user's description is vague, ask follow-up questions. Good things to clarify:
- Should this be user-invocable (shows in `/` menu) or internal-only (Claude auto-triggers)?
- Does it need specific tools (Bash, WebFetch, etc.)?
- Should it run in a fork context or inline?
- Are there edge cases or failure modes to handle?
- Does it interact with other skills or config files?
- Will it need supporting files (reference docs, scripts, templates, examples)?
- Is the skill's logic complex enough to warrant splitting across SKILL.md and supporting files?

## Step 4: Design the skills

Before writing anything, **read the skill writing guide** for frontmatter fields, folder structure, progressive disclosure, description writing, and style guidance:

```bash
cat ~/.claude/ccpraxis/references/skill-writing-guide.md
```

Then **present the full design to the user** and get confirmation. This includes:

1. **Per-skill breakdown:**
   - Proposed frontmatter — all fields you plan to set, with rationale for non-obvious choices
   - Step outline — numbered list of what the skill will do, in order
   - Edge cases — what happens when things go wrong
2. **Folder structure:**
   - Will the skill use only SKILL.md, or also supporting files?
   - If supporting files are planned, list the proposed files and their purpose
   - Ensure the SKILL.md body will stay under 500 lines — if approaching the limit, plan what goes into supporting files
   - Supporting file references must be one level deep from SKILL.md
3. **Related-skill wiring:**
   - Skills created together will automatically be added to each other's `related` list
   - Show the exact `related` field for each skill (including any links to existing skills the user requested)
4. **Cross-skill consistency:**
   - Are the skills' responsibilities clearly divided?
   - Do they reference each other correctly (e.g., "use /X instead" messages)?
   - Are shared conventions (naming, frontmatter style) consistent?
5. **Questions** — anything you're unsure about

Use AskUserQuestion to present the design and get approval before proceeding to Step 5.

## Step 5: Write the skill files

Only proceed here after the user has approved the design from Step 4.

All writes go to the repo at `~/.claude/ccpraxis/skills/<skill-name>/SKILL.md`.

For each skill, create the directory and SKILL.md. If the design from Step 4 includes supporting files, also create them:

```
<skill-name>/
├── SKILL.md              # Main instructions (required)
├── reference.md          # Detailed docs (if needed, loaded when needed)
├── examples.md           # Usage examples (if needed, loaded when needed)
└── scripts/
    └── helper.sh         # Utility script (if needed, executed not loaded)
```

Only create files that are actually needed. Most skills need only SKILL.md.

**Auto-wire `related` frontmatter:** Skills created together in the same invocation are automatically added to each other's `related` list. If the user also requested links to existing skills, include those too.

Guidelines for writing good skill bodies:
- Be specific and imperative — "Run X", "Read Y", "Ask the user Z"
- Include actual commands in fenced code blocks where applicable
- Use numbered steps for sequential operations
- Use AskUserQuestion when user input or confirmation is needed
- Reference paths relative to `~/.claude/ccpraxis/` for config files, or relative to the project for project files
- If the skill modifies config files, it should integrate with `/backup` (i.e. changes go in the repo)
- Keep SKILL.md under 500 lines — if approaching the limit, move reference material to supporting files and add pointers
- Write descriptions in third person with trigger contexts (see the skill writing guide)
- Explain the WHY behind instructions rather than issuing heavy-handed MUSTs — Claude is smart and handles edge cases better when it understands the reasoning
- Only add context Claude doesn't already have — challenge each paragraph's token cost
- For complex skills, use progressive disclosure: SKILL.md as overview, supporting files for detail
- Use `${CLAUDE_SKILL_DIR}` in bash commands to reference bundled files regardless of working directory

## Step 6: Review the skills

After writing, **read back the full SKILL.md for every created skill** and do a self-review:
- Does each skill's frontmatter make sense? Are the right tools allowed?
- Is the description in third person, specific enough to trigger correctly, with trigger contexts?
- Are all steps clear and unambiguous?
- Is the SKILL.md under 500 lines? If not, should some content move to supporting files?
- If supporting files exist, are they referenced one level deep from SKILL.md?
- Are the `related` fields correctly wired (every skill lists all its siblings)?
- Do cross-references between skills match (e.g., "use /X instead" messages point to the right skill)?
- Is terminology consistent throughout?
- Will the skills work on both Linux/macOS and Windows?
- Do they interact correctly with other skills and the config repo?

If you spot issues, fix them before proceeding.

## Step 7: Refresh live symlinks

For each created skill:

```bash
rm -rf ~/.claude/skills/<skill-name>
ln -sf ~/.claude/ccpraxis/skills/<skill-name> ~/.claude/skills/<skill-name>
```

## Step 8: Update the README

Read `~/.claude/ccpraxis/README.md`. There are **three places** to update per skill:

### 8a: Intro bullet list

Near the top, find the line starting with `- **Slash commands**` and add each new skill. Keep the format: `/<name>` followed by a short parenthetical. List skills alphabetically.

### 8b: File tree

Find the `skills/` section inside the `What's Included` fenced code block. Add a new line per skill in alphabetical order:

```
│   ├── <skill-name>/SKILL.md          # /<skill-name> — <short description>
```

Use `├──` for non-last entries and `└──` for the last. Update the previous last entry from `└──` to `├──` if needed.

### 8c: Features section

If any of the skills are user-invocable and significant enough to warrant their own section (i.e. major features, not utilities), add a `### <Skill Name> (\`/<skill-name>\`)` section under `## Features` with a brief description. Use AskUserQuestion to ask the user. For small/utility skills, skip this.

## Step 9: Verify

For each created skill, confirm it's in place:

```bash
ls -la ~/.claude/skills/<skill-name>/SKILL.md
```

Then tell the user:
- Which skills are ready to use (as `/<skill-name>`)
- How they're linked via `related` fields
- The README has been updated
- Changes will be synced on next `/backup`
- On other machines, `/backup` will automatically link them after pulling
