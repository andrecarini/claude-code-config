---
name: resume-plan
description: Resumes work on an existing persistent plan. Reads the plan file, creates a scoped session plan, and begins execution. Use when the user says "work on the plan", "continue the plan", "resume work on", or references a plan by name.
user-invocable: true
argument-hint: <plan-name>
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Glob
related:
  - create-plan
  - manage-plans
---

# Resume Work on a Persistent Plan

Resume work on an existing plan from `.claude-plans/` at the project root.

## Arguments

- `$0` — Plan name (filename without `.md`, e.g. `flutter-debug-workflow`)

If no argument given, list available plans and ask which one.

## Steps

### 1. Find the project root and locate the plan

Determine the project root using this priority:
1. `git rev-parse --show-toplevel` — if inside a git repo, use the repo root
2. If not a git repo, check if `.claude-plans/` already exists by walking up from cwd
3. If neither works, ask the user which directory is the project root (cwd may have changed due to prior `cd` commands in this session)

Plans live at `<project-root>/.claude-plans/`.

If `.claude-plans/` doesn't exist or is empty, tell the user there are no plans yet and suggest `/create-plan` to get started.

Read `<project-root>/.claude-plans/$0.md`. If it doesn't exist, list available plans with their deliverable progress (e.g. "2/5 done") and ask the user which one they meant.

### 2. Assess current state

From the plan file, identify:
- Which deliverable is current (first non-✅ one)
- What's in "What's Broken / Blocked"
- What's next in "Untried Approaches"
- Last attempt in the "Attempt Log"

### 3. Create a session plan

Enter plan mode and create a Claude Code session plan (NOT a file — use the built-in plan tool). The session plan should:

- **Scope** — What specific deliverable/fix this session will tackle
- **Tasks** — Concrete, testable steps (3-7 tasks, not 20)
- **Success criteria** — How we know each task is done
- **Out of scope** — What we explicitly won't touch this session

Present the session plan to the user for approval before starting work.

### 4. Execute

Work through the session plan tasks:
- Test/validate each change before marking complete
- If a task fails, diagnose before moving on — don't skip
- If stuck after 2-3 attempts on the same task, update the plan file's Attempt Log and discuss with user

### 5. Update the plan file

At the end of the session (or when the user says to stop), update `<project-root>/.claude-plans/$0.md`:

- Add rows to **Attempt Log** for everything tried
- Update **Deliverables** table status
- Update **What Works** / **What's Broken** sections
- Move confirmed-failed approaches to **Discarded Approaches**
- Update **Last updated** timestamp

Do this even if interrupted — the plan must never go stale.

## Important

- **Read the plan file every session.** Don't rely on memory or conversation history.
- **The plan file is the source of truth.** If it contradicts your memory, trust the file.
- **Small, validated steps.** Don't attempt 5 things at once. Do one, test it, move on.
- **Update before stopping.** Even if the user says "let's stop" abruptly, update the plan file first.
- **Don't expand scope.** Stick to the session plan. If something new comes up, note it in the plan file for a future session.
