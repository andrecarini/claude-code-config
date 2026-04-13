---
name: update-skill
description: Modifies one or more existing custom skills (slash commands) with related-skill awareness. Use when the user wants to change, improve, fix, refactor, or extend an existing skill. Use /create-skill for new skills.
argument-hint: [skill-name...] [changes]
user-invocable: true
host-only: true
related:
  - create-skill
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Glob, Grep
---

Update one or more existing custom skills for Claude Code, integrated with the config repo at `~/.claude/claude-code-config/`.

All changes are made in the repo (`~/.claude/claude-code-config/skills/`), then the live symlinks in `~/.claude/skills/` are refreshed to pick up the changes (handles both real symlinks and Windows copy-fallback).

The user should provide: `$ARGUMENTS`

If no arguments were given, ask the user which skill(s) they want to update and what they'd like to change.

**Take your time with this skill.** Updating skills is a design task — read the existing skills carefully, ask clarifying questions, think about how changes interact with existing behavior, and validate the plan with the user before editing. Don't rush to deliver.

## Step 1: Parse skill names from arguments

The user may specify one or more skill names. Skill names are lowercase-hyphenated tokens that appear before the description of changes. Examples:

- `/update-skill backup Add a dry-run flag` → skill: `backup`, changes: "Add a dry-run flag"
- `/update-skill create-skill update-skill Add related field support` → skills: `create-skill`, `update-skill`, changes: "Add related field support"

To disambiguate: check each leading token against existing skill directories:

```bash
ls ~/.claude/claude-code-config/skills/
```

Tokens that match an existing skill directory are skill names. The first token that doesn't match (or the remainder) is the change description.

## Step 2: Validate that all named skills exist

For each skill name, check:

```bash
ls ~/.claude/claude-code-config/skills/<skill-name>/SKILL.md 2>/dev/null
```

- **All exist** → proceed to Step 3.
- **Some don't exist** → Warn the user about each missing skill:

  > `/<skill-name>` doesn't exist yet. Use `/create-skill <skill-name> <description>` to create it.

  List the available skills to help spot typos:

  ```bash
  ls ~/.claude/claude-code-config/skills/
  ```

  Continue with the skills that do exist if the user's intent is clear, or ask for clarification.

## Step 3: Expand the skill set via `related` links

This step is critical for maintaining consistency across linked skills.

For each skill in the working set, read its SKILL.md frontmatter and extract the `related` field (a YAML list of skill names). Then read the frontmatter of each related skill and extract its `related` field too. Continue until no new skills are added (transitive closure).

**Algorithm:**

1. Start with `working_set` = the skill names from Step 1.
2. For each skill in `working_set`, read its SKILL.md and extract the `related` list from frontmatter.
3. For each related skill not already in `working_set`, add it and read its `related` list too.
4. Repeat until `working_set` stops growing.

To extract the `related` field from frontmatter, read the SKILL.md and look for lines matching `  - <skill-name>` under the `related:` key in the YAML frontmatter block (between the `---` delimiters).

**If the expanded set is larger than what the user specified**, inform the user:

> The following related skills were automatically included because they are linked:
> - `/<related-skill-1>` (linked from `/<original-skill>`)
> - `/<related-skill-2>` (linked from `/<related-skill-1>`)
>
> I'll review these for consistency after making the requested changes.

The related skills are included for **review and consistency checking** — they won't be modified unless the requested changes require it. The user should understand which skills are in scope and why.

## Step 4: Read and understand all skills in the working set

For each skill in the working set, read the full SKILL.md and any supporting files:

```bash
cat ~/.claude/claude-code-config/skills/<skill-name>/SKILL.md
```

Also read the skill writing guide for reference on best practices:

```bash
cat ~/.claude/claude-code-config/references/skill-writing-guide.md
```

Before proposing any changes, make sure you fully understand:
- What each skill currently does (every step)
- The frontmatter configuration and why each field is set the way it is
- The folder structure — does the skill use supporting files?
- Whether the SKILL.md is approaching the 500-line limit
- Whether the description follows triggering best practices (third person, trigger contexts)
- Edge cases each skill already handles
- How the skills in the working set interact with each other
- How they interact with other skills or config files outside the working set

## Step 5: Understand what the user wants to change

Parse the user's change description. Common update types:
- **Frontmatter changes** — description, allowed-tools, effort, model, related, etc.
- **Step modifications** — add, remove, or rewrite steps
- **Behavior changes** — different logic, new edge case handling, altered flow
- **Structural changes** — splitting a skill, merging skills, changing context mode
- **Resource restructuring** — moving content between SKILL.md and supporting files, adding bundled files
- **Cross-skill changes** — aligning behavior, sharing conventions, adding links

If the request is vague or ambiguous, ask clarifying questions. Good things to clarify:
- Which specific part(s) of which skill(s) should change?
- Should existing behavior be preserved or replaced?
- Are there edge cases the change introduces?
- How does the change interact with the rest of each skill's flow?
- For multi-skill changes: should the same change apply to all, or different changes to each?

## Step 6: Design the changes

Before editing anything, **present the planned changes to the user** and get confirmation. This includes:

1. **Per-skill breakdown** — for each skill being modified:
   - What will change — specific sections/lines being modified, with before/after where helpful
   - What stays the same — confirm which parts are preserved
2. **Related skills impact** — for related skills not being directly modified:
   - Whether they need any changes for consistency
   - If no changes needed, explicitly state why they're fine as-is
3. **Ripple effects** — does this change affect the README, other skills outside the working set, or settings?
4. **Edge cases** — anything the change might break or introduce
5. **Questions** — anything you're unsure about

Use AskUserQuestion to present the plan and get approval before proceeding to Step 7.

## Step 7: Apply the changes

Only proceed here after the user has approved the plan from Step 6.

For each skill being modified, edit the existing file in place using the Edit tool. **Preserve any parts the user didn't ask to change.** Be surgical — don't rewrite the whole file if only one section needs to change.

Guidelines:
- Use the Edit tool for targeted changes, not Write (which replaces the whole file)
- If the change is large enough that a full rewrite is cleaner, use Write — but only after careful review
- Preserve the existing style and conventions of the skill body
- If adding new steps, maintain the existing numbering scheme
- If changing frontmatter, keep fields in the same order
- If changes involve adding supporting files, create them alongside SKILL.md
- If moving content from SKILL.md into supporting files, update SKILL.md with pointers (one level deep)

## Step 8: Review all changes

After editing, **read back the full SKILL.md for every modified skill** and do a self-review:
- Does each skill still make sense end-to-end with the changes applied?
- Are all steps still consistent within each skill?
- Are the skills in the working set consistent with each other?
- Did any edit break references (step numbers, field names, etc.)?
- Is the description still in third person with trigger contexts after changes?
- Is the SKILL.md still under 500 lines? If changes pushed it over, should some content move to supporting files?
- If supporting files were added or modified, are they referenced one level deep from SKILL.md?
- Are edge cases still handled?
- Will the skills work on both Linux/macOS and Windows?
- Do they interact correctly with other skills and the config repo?

If you spot issues, fix them before proceeding.

## Step 9: Refresh live symlinks

For each modified skill, re-link — this ensures Windows copy-fallback gets refreshed:

```bash
rm -rf ~/.claude/skills/<skill-name>
ln -sf ~/.claude/claude-code-config/skills/<skill-name> ~/.claude/skills/<skill-name>
```

## Step 10: Update the README (if needed)

Only update the README if the changes affect what's documented there. Read `~/.claude/claude-code-config/README.md` and check:

### 10a: Intro bullet list

If any skill's short description changed, update the `- **Slash commands**` line near the top.

### 10b: File tree

If any skill's description changed, update the comment on the skill's line in the `What's Included` fenced code block.

### 10c: Features section

If there's an existing features section for any modified skill and the description/behavior changed significantly, update it.

## Step 11: Verify

For each modified skill, confirm it's in place:

```bash
ls -la ~/.claude/skills/<skill-name>/SKILL.md
```

Then tell the user:
- Which skills were updated — changes take effect immediately
- Which related skills were reviewed and whether they needed changes
- Whether the README was updated (and what changed)
- Changes will be synced on next `/backup`
- On other machines, `/backup` will automatically link them after pulling
