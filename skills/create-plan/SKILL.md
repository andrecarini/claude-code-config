---
name: create-plan
description: Creates a new persistent plan file for a multi-session initiative. Use when the user wants to plan a complex task that will span multiple sessions, needs tracking across context boundaries, or says things like "let's plan", "create a plan", "make a plan for".
user-invocable: true
argument-hint: <plan-name> [description]
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Glob
related:
  - resume-plan
  - manage-plans
---

# Create a Persistent Plan

Create a persistent plan file for a multi-session initiative. Plans live in `.claude-plans/` at the project root and serve as the single source of truth across sessions — they survive context compaction and session boundaries.

## Arguments

- `$0` — Plan name (kebab-case, e.g. `flutter-debug-workflow`)
- Remaining arguments — Brief description of the objective

If no arguments given, ask the user what they want to plan.

## Steps

### 1. Find the project root and set up the plans directory

Determine the project root using this priority:
1. `git rev-parse --show-toplevel` — if inside a git repo, use the repo root
2. If not a git repo, check if `.claude-plans/` already exists by walking up from cwd
3. If neither works, ask the user which directory is the project root (cwd may have changed due to prior `cd` commands in this session)

Always create `.claude-plans/` at the project root, regardless of the current working directory.

- Create it: `mkdir -p <project-root>/.claude-plans`
- If it's a git repo, add `.claude-plans/` to `<project-root>/.gitignore` if not already there (plans are local working documents, not committed)

### 2. Check for name collisions

If `<project-root>/.claude-plans/$0.md` already exists, warn the user and ask whether to overwrite it or pick a different name.

### 3. Gather context

Before writing the plan, understand:
- What is the objective? What does "done" look like?
- What are the incremental deliverables? (Each should be independently useful)
- What constraints or known challenges exist?
- What has already been tried or decided?

Ask the user if any of this is unclear. Don't assume.

### 4. Write the plan file

Create `<project-root>/.claude-plans/$0.md` with this structure:

```markdown
# <Plan Title>

> **Living document.** Update at every checkpoint marked with 🔄.

## Objective

<What we're building and why. 2-3 sentences max.>

### Desired Behavior

<What the end result looks like from the user's perspective. Concrete example interaction if applicable.>

### Deliverables

| # | Deliverable | Status |
|---|-------------|--------|
| 1 | ... | ⬜ Not started |
| 2 | ... | ⬜ Not started |

Status values: ⬜ Not started | 🔧 In progress | ✅ Done | ❌ Discarded

## Architecture / Approach

<How it works. Diagrams if helpful.>

## Current State

### What Works
<Bulleted list, or "Nothing yet" if fresh>

### What's Broken / Blocked
<Bulleted list, or "Nothing" if clean>

### 🔄 Attempt Log

| # | What was tried | Result | Date |
|---|----------------|--------|------|
| | | | |

## Untried Approaches (Priority Order)

1. ...
2. ...

## Discarded Approaches

| Approach | Why Discarded |
|----------|--------------|
| | |

## Key References

<Files, source locations, URLs, documentation — anything needed to resume work>

## Session Workflow

Each session working on this plan:
1. **Start** — Read this plan file → Run `/resume-plan <name>` to create a scoped session plan
2. **Work** — Execute tasks with test/validate loop, mark tasks complete as they pass
3. **End** — Update THIS plan file: attempt log, deliverable status, current state, timestamp

## 🔄 Update Checkpoints

Update this document when:
1. A fix/approach is attempted (add to Attempt Log)
2. A deliverable status changes
3. A new constraint or requirement is discovered
4. An approach is confirmed working or discarded
5. At session start and end

**Last updated:** <current date>
```

### 5. Confirm with the user

Show the plan file path and a summary of what was captured. Ask if anything is missing or wrong before proceeding.

## Important

- Plans are **working documents**, not specifications. They should be concise and actionable.
- Each deliverable should be independently useful — don't plan big-bang deliveries.
- The plan file is the **single source of truth** for this initiative across sessions.
- Don't over-plan. Capture what's known, leave room for discovery.
