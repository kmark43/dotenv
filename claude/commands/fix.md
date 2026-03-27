Fix a bug or small task: $ARGUMENTS

Arguments can be:
- A task ID: `/fix PROJ-123`
- A task name: `/fix "login button broken"` — searches prioritized backlog first, then full backlog
- A description: `/fix "crash on logout screen"`

Use this command for bug fixes and small contained tasks that don't require a PM spec or architecture design. For features that need planning, use `/pm-spec` instead.

## Instructions

### Step 1: Resolve the task

**If given a task ID:** fetch it from Plane directly.

**If given a name or description:**
- Search prioritized backlog first, then full backlog
- Present top 1-3 matches:
  ```
  Found matching tasks:
  1. PROJ-123: [title] — [description] ← best match
  2. PROJ-456: [title] — [description]
  Which did you mean? (or confirm #1)
  ```
- Wait for confirmation before proceeding

### Step 2: Sanity check

Before invoking the developer, evaluate whether this task is appropriate for the lightweight path. Check all of the following:

- Does the task have a clear, testable expected outcome?
- Is the scope contained to a specific behavior (not a system redesign)?
- Can it likely be implemented without data model changes or new API surfaces?
- Is it describable in a few sentences without needing user stories or acceptance criteria sections?

If any check fails, surface a warning:
```
## Scope Warning

This task may be too large or ambiguous for the lightweight fix path.

Concern: [what triggered the warning]

Options:
1. Proceed anyway (you take responsibility for scope)
2. Escalate to /pm-spec PROJ-123 for a full spec
```
Wait for the user to choose before proceeding.

### Step 3: Developer

Use the `developer` agent with ONLY this context:
- `CLAUDE.md`
- The Plane task title and full description (this is the "spec")
- Relevant existing source files needed for the fix

Do NOT pass:
- PM spec files
- Architecture design files
- Other tasks or history

Instruct the developer to:
1. Read `CLAUDE.md` for project conventions
2. Treat the Plane task description as the full requirement
3. Implement the fix — minimal, targeted, no scope creep
4. If the fix turns out to require structural changes, new API surfaces, or data model changes — STOP and escalate:
   ```
   ## Escalation Required

   This fix cannot be completed without a spec or architecture design.

   Reason: [what was discovered — be specific]
   Recommendation: /pm-spec PROJ-123

   No code has been changed.
   ```
5. Otherwise, output an implementation summary listing files changed and what was fixed

### Step 4: QA

After dev completes (without escalation), use the `qa` agent with ONLY this context:
- `CLAUDE.md`
- The Plane task title and description (tests against stated expected behavior)
- The implementation summary from Step 3
- Read access to the codebase

Do NOT pass:
- Architecture design
- Dev chat history

Instruct QA to:
1. Test that the bug described in the task is fixed
2. Test that the fix doesn't break the surrounding behavior (regression)
3. Apply the same rigor as always — assume bugs exist
4. Write the report to `docs/qa/<feature-slug>-fix-review.md`

### Step 5: Dev Fix (if needed)

If QA verdict is FAIL, use the `developer` agent again with ONLY:
- `CLAUDE.md`
- The QA report
- The Plane task description (for expected behavior reference)
- Relevant source files

Same escalation rule applies — if fixing the QA issues requires structural changes, stop and escalate.

### Step 5b: Final QA (after dev fix)

After dev fix completes, run QA again to verify the fixes didn't introduce new issues.

Use the `qa` agent with ONLY:
- `CLAUDE.md`
- The Plane task title and description (tests against stated expected behavior)
- The dev fix summary from Step 5
- Read access to the codebase

Do NOT pass: dev chat history, prior QA conversation history

Instruct QA to:
1. Re-verify the bugs from the previous QA report are actually fixed
2. Test that the fix doesn't break the surrounding behavior (regression)
3. Write a new QA report to `docs/qa/<feature-slug>-fix-v<N>-review.md` (incrementing version)

**If this QA also fails:** loop back to Step 5 (Dev Fix) → Step 5b (Final QA). Repeat until QA passes or 3 total fix cycles have been attempted. After 3 failed cycles, stop and report to the user for intervention.

### Step 6: Update Plane

On completion:
- Update Plane task status to "In Review"
- Add a brief comment: what was changed and QA result

Output a summary:
```
## Fix Complete — PROJ-123: [title]

- Dev: [N files changed]
- QA: [PASS | FAIL → fixed → verified PASS]
- Plane: status → In Review

QA report: docs/qa/<slug>-fix-review.md
Ready for your review.
```
