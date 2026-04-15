---
name: manage-plans
description: Lists, views, updates, and deletes persistent plan files. Use when the user wants to see their plans, check plan status, edit a plan directly, delete old plans, archive completed plans, or says things like "show my plans", "list plans", "delete the plan", "update the plan status".
user-invocable: true
argument-hint: [list|view|update|delete|archive] [plan-name]
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Glob
related:
  - create-plan
  - resume-plan
---

# Manage Persistent Plans

CRUD operations for persistent plan files in `.claude-plans/` at the project root.

## Arguments

- `$0` — Operation: `list`, `view`, `update`, `delete`, or `archive`. Defaults to `list` if omitted.
- `$1` — Plan name (required for all operations except `list`)

## Steps

### 1. Find the project root

Determine the project root using this priority:
1. `git rev-parse --show-toplevel` — if inside a git repo, use the repo root
2. If not a git repo, check if `.claude-plans/` already exists by walking up from cwd
3. If neither works, ask the user which directory is the project root

Plans live at `<project-root>/.claude-plans/`.

If `.claude-plans/` doesn't exist or is empty, tell the user there are no plans yet and suggest `/create-plan`.

### 2. Route to operation

Based on `$0`, execute one of the following:

---

### Operation: `list` (default)

List all `.md` files in `.claude-plans/` (excluding the `archive/` subdirectory). For each plan, read the file and extract:

- **Plan name** — filename without `.md`
- **Objective** — first line of the `## Objective` section
- **Deliverable progress** — count of ✅ vs total deliverables (e.g. "2/5 done")
- **Last updated** — the date from the `**Last updated:**` line
- **Status** — derive from deliverables: all ✅ = "Complete", any 🔧 = "In progress", all ⬜ = "Not started", mix = "In progress"

Display as a formatted table. If there are also archived plans, mention how many exist in the archive.

---

### Operation: `view`

Read `<project-root>/.claude-plans/$1.md` and display a structured summary:

- **Objective** and desired behavior
- **Deliverables** table with current status
- **Current state** — what works, what's broken
- **Last attempt** — most recent row from the Attempt Log
- **Next steps** — first item from Untried Approaches

This is a read-only overview. Suggest `/resume-plan $1` if the user wants to start working, or `/manage-plans update $1` to edit directly.

---

### Operation: `update`

Read the plan file and ask the user what they want to change. Common edits:

- **Add deliverable** — append a row to the Deliverables table
- **Remove deliverable** — remove a row (with confirmation)
- **Change deliverable status** — update the status emoji
- **Edit objective** — rewrite the Objective section
- **Add to Attempt Log** — append a new row
- **Update Current State** — rewrite What Works / What's Broken
- **Add/remove Untried Approaches**
- **Add Key References**

Use the Edit tool for surgical changes. Don't rewrite the whole file.

After editing, update the `**Last updated:**` timestamp.

---

### Operation: `delete`

Read the plan file's objective and deliverable summary, then ask for confirmation:

> Delete plan `$1`? (Objective: <objective>, Progress: <X/Y done>)

If confirmed, delete `<project-root>/.claude-plans/$1.md`.

If all deliverables are ✅, suggest archiving instead of deleting.

---

### Operation: `archive`

Move the plan to `<project-root>/.claude-plans/archive/`:

1. Create `archive/` if it doesn't exist: `mkdir -p <project-root>/.claude-plans/archive`
2. If the plan has unfinished deliverables, warn the user and ask for confirmation
3. Move the file: `mv <project-root>/.claude-plans/$1.md <project-root>/.claude-plans/archive/`
4. Confirm the archive with the plan name and final deliverable status

Archived plans can still be viewed with `view` by specifying the archive path, but they won't appear in the default `list` output.

## Important

- This skill is for direct plan management — inspecting, editing, housekeeping. For working *through* a plan (executing tasks, updating attempt logs during work), use `/resume-plan`.
- Always update the `**Last updated:**` timestamp when modifying a plan.
- When deleting, prefer archiving if the plan has any completed deliverables — completed work shouldn't disappear.
