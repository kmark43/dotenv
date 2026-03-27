Run the full implementation pipeline for one or more features: $ARGUMENTS

Arguments are flexible — provide as much or as little as you want:
- A design path: `/feature docs/designs/user-auth/v1.md`
- A spec path: `/feature docs/specs/user-auth/v1.md`
- A Plane task ID: `/feature PROJ-123`
- A feature name or description: `/feature "user authentication"`
- Multiple features (pipe-separated): `/feature "user auth" | "push notifications"`
- Multiple task IDs: `/feature PROJ-123,PROJ-456` or `/feature PROJ-123 | PROJ-456`
- A number: `/feature 3` — top N "Design Ready" tasks from Plane
- Nothing: `/feature` — will ask what to work on

## Instructions

This command runs: Resolve → Worktree Setup → Dev → QA → Dev Fix (if needed) → Final QA (if fixes were made) → Commit.
Each stage uses a fresh subagent. No history passes between stages.

**For multiple features:** all worktrees are created upfront, then each pipeline runs as a parallel subagent. No waiting between features.

---

## Stage 0: Resolution

### Resolve the feature list

**If given a number N:**
- Search Plane for top N tasks with status "Design Ready" (by backlog priority order)
- Display the list and wait for confirmation

**If given task IDs (comma or `|` separated):**
- Fetch each from Plane, read design path from `**Design:**` field
- Display confirmed list and wait

**If given multiple names/paths (`|` separated):**
- Resolve each independently (fuzzy match designs → specs → Plane)
- Display confirmed list and wait

**If given a single name/description:**
- Fuzzy match against:
  1. `docs/designs/` directory — find designs whose filename or title matches
  2. `docs/specs/` directory — find specs whose filename or title matches
  3. Plane backlog — search by name/description
- If **one match**: confirm and proceed as single feature
- If **multiple matches** (2-3): present them and ask:
  ```
  Found multiple matching features:
  1. docs/designs/integration-tests/v1.md — Integration Tests (PROJ-123)
  2. docs/designs/jest-unit-testing/v1.md — Jest Unit Testing (PROJ-456)

  Run one (enter number), or run all in parallel? (all/1/2)
  ```
  - If a number: proceed as single feature with that match
  - If "all": proceed as multi-feature parallel run with all matches

**If nothing provided:**
- Ask "Which feature(s) would you like to implement?"

If a design is found but no corresponding spec is referenced in it, report and stop.

---

## Existing Worktree Detection

After resolving the feature list, check if any resolved feature already has a worktree (`.worktrees/<slug>` exists or `git worktree list` shows a matching branch).

**If a worktree exists for a single feature**, show its current state and prompt:

```
Worktree already exists: .worktrees/<slug>
Branch: feature/PROJ-123-<slug>
Last commit: <short hash> — <message>
Last QA: [PASS | FAIL | PASS WITH CONCERNS | No QA report found]

What would you like to do?
1. Give feedback (describe changes you want)
2. Re-run QA only
3. Start fresh (delete and recreate worktree)
```

**If multiple features are given and some have existing worktrees**, list which exist and which are new. For existing ones, ask for feedback or skip. For new ones, proceed with normal worktree creation.

### Option 1: User feedback → Dev → QA → Dev Fix cycle

When the user provides feedback:

**Stage F1: Apply Feedback (Dev)**

Use the `developer` agent with ONLY:
- `CLAUDE.md`
- The user's feedback text (verbatim)
- The PM spec (for acceptance criteria reference)
- The most recent QA report from `docs/qa/<slug>-*-review.md` (if one exists)
- Read access to the worktree codebase

Do NOT pass: architecture design, previous dev history, previous QA conversation history

Instruct the developer to:
1. Read `CLAUDE.md` for conventions
2. Read the user's feedback carefully
3. Read the most recent QA report for context on prior issues (if it exists)
4. Apply changes based on the feedback — do not change unrelated code
5. If the feedback contradicts the PM spec acceptance criteria, flag it and ask for clarification
6. Run tests after changes — do not mark complete if new failures introduced
7. Output a feedback implementation summary

Save the summary to `docs/qa/<feature-slug>-feedback-summary.md`.

**Stage F2: QA Review**

Run the same QA process as Stage 2. Write a new versioned QA report (`docs/qa/<slug>-v<N>-review.md`, incrementing from the last version).

**Stage F3: Dev Fix (only if QA finds bugs)**

Same as Stage 3.

**Stage F3b: Final QA (after dev fix)**

Same as Stage 3b — run QA again to verify the fixes. Loop Dev Fix → Final QA until QA passes or 3 fix cycles attempted.

**Stage F4: Commit**

```bash
git add -A
git commit -m "refactor(PROJ-456): apply feedback — <brief description>

Feedback: <1-line summary of what user asked for>
Spec: docs/specs/<slug>/vN.md
QA: docs/qa/<slug>-vN-review.md"
```

### Option 2: Re-run QA only

Skip straight to Stage F2 (QA Review) on the current worktree state. Useful after manual changes.

### Option 3: Start fresh

```bash
git worktree remove .worktrees/<slug> --force
```

Then proceed with normal worktree creation and the full pipeline (Single-feature flow or Multi-feature parallel flow).

### Final output (feedback cycle)

```
## Feedback Cycle Complete

**Feature:** [feature name]
**Branch:** feature/PROJ-456-<slug>
**Worktree:** .worktrees/<slug>

### Feedback Applied
[brief summary of changes made]

### Results
- Dev: Complete — [N files changed]
- QA: [PASS | FAIL → fixed → verified PASS]
- Commit: [hash]

### Artifacts
- Feedback summary: docs/qa/<slug>-feedback-summary.md
- QA report: docs/qa/<slug>-vN-review.md

### Next
  /pr PROJ-456
  Or give more feedback: /feature PROJ-456
```

---

## Single-feature flow

When running a single feature, prompt for base branch before creating the worktree:

```
Base branch: main (default) — change? (type branch name, task ID, or press enter to use main)
```

If the user types something, fuzzy match against:
- Active feature branches from `git branch --list "feature/*"`
- Active worktrees from `git worktree list`
- If input looks like a task ID (e.g. "123" or "PROJ-123"), match to a branch containing that ID

Show the match and confirm:
```
Base branch: feature/PROJ-123-user-auth — correct? (y/n)
```

If no match found, ask the user to clarify or enter the full branch name.

Create the worktree:
```bash
# Derive slug from design file path
# Branch: feature/PROJ-456-<slug> (or feature/<slug> if no task ID)
git worktree add .worktrees/<slug> --base <resolved-base-branch> -b feature/PROJ-456-<slug>

# Fix absolute paths → relative paths (required for devcontainer/mount compatibility)
echo "gitdir: ../../.git/worktrees/<slug>" > .worktrees/<slug>/.git
echo "../../.worktrees/<slug>/.git" > .git/worktrees/<slug>/gitdir
```

If base branch is not main, note it in the output:
```
Worktree created: .worktrees/<slug>
Branch: feature/PROJ-456-<slug> (based on feature/PROJ-123-user-auth)
Note: if the base branch changes, rebase this branch on top of it before merging.
```

Then run Stages 1–4 below.

---

## Multi-feature parallel flow

When running multiple features:

1. **Skip the base branch prompt** — all features branch off main by default
   - If any feature needs a custom base branch, use single-feature mode instead

2. **Create all worktrees upfront** before spawning any subagents:
   ```bash
   git worktree add .worktrees/<slug-1> -b feature/PROJ-123-<slug-1>
   git worktree add .worktrees/<slug-2> -b feature/PROJ-456-<slug-2>
   # ... one per feature

   # Fix absolute paths → relative paths for each worktree (required for devcontainer/mount compatibility)
   # For each <slug>:
   echo "gitdir: ../../.git/worktrees/<slug>" > .worktrees/<slug>/.git
   echo "../../.worktrees/<slug>/.git" > .git/worktrees/<slug>/gitdir
   ```

3. **Confirm then launch** — show the plan and confirm:
   ```
   Ready to run in parallel:
   - .worktrees/integration-tests → feature/PROJ-123-integration-tests
   - .worktrees/jest-unit-testing → feature/PROJ-456-jest-unit-testing

   Launch parallel pipelines? (y/n)
   ```

4. **Spawn one subagent per feature** simultaneously. Each subagent receives ONLY:
   - Its own design path
   - Its own worktree path
   - The instructions for Stages 1–4 below
   - No context from other features or this resolution session

5. **Report as each completes.** When all are done, show the combined summary:
   ```
   ## Parallel Pipeline Complete

   | Feature | Branch | QA | Commit |
   |---------|--------|----|--------|
   | Integration Tests | feature/PROJ-123-integration-tests | PASS | abc1234 |
   | Jest Unit Testing | feature/PROJ-456-jest-unit-testing | PASS → fixed | def5678 |

   Review and PR:
     /pr PROJ-123
     /pr PROJ-456
   ```

---

## Stage 1: Development

Use the `developer` agent with ONLY:
- `CLAUDE.md`
- The architecture design
- The PM spec (from the design's `PM Spec:` field)
- Relevant existing source files

Do NOT pass: design session history, prior conversation, other features' context

Instruct the developer to:
1. Read `CLAUDE.md` for conventions, tech stack, and test instructions
2. Read the PM spec for acceptance criteria
3. Read the architecture design for structure
4. Run the existing test suite — note any pre-existing failures (do not own them)
5. Flag any ambiguity before writing code — do not guess
6. Implement exactly what is specified — no scope creep
7. Write tests per the guidelines in `CLAUDE.md` and developer agent instructions
8. Run tests after implementing — do not mark complete if new failures introduced
9. Output an implementation summary including test results

Save the implementation summary to `docs/qa/<feature-slug>-dev-summary.md`.

---

## Stage 2: QA Review

Use the `qa` agent with ONLY:
- `CLAUDE.md`
- The PM spec (acceptance criteria and functional requirements)
- The implementation summary from Stage 1
- Read access to the codebase (in the worktree)

Do NOT pass: architecture design, dev chat history, prior conversation

Instruct QA to:
1. Run the full test suite — any new failures vs the dev summary baseline are bugs
2. Test every acceptance criterion
3. Test every functional requirement
4. Test every edge case from the PM spec
5. Review for complexity concerns
6. Write the full QA report to `docs/qa/<feature-slug>-v<N>-review.md`

---

## Stage 3: Dev Fix (only if QA finds bugs)

If QA verdict is PASS, skip to Stage 4.

If FAIL or PASS WITH CONCERNS (blocking bugs only):

Use the `developer` agent again with ONLY:
- `CLAUDE.md`
- The QA report
- The PM spec (for acceptance criteria reference)
- Relevant existing source files

Do NOT pass: architecture design, Stage 1 dev history, QA conversation history

Instruct the developer to:
1. Address each BUG in the QA report
2. Fix only what is listed — do not change other code
3. Run tests after fixing — do not mark complete if tests fail
4. Output a fix summary

---

## Stage 3b: Final QA (after dev fix)

After dev fix completes, run QA again to verify the fixes didn't introduce new issues.

Use the `qa` agent with ONLY:
- `CLAUDE.md`
- The PM spec (acceptance criteria and functional requirements)
- The dev fix summary from Stage 3
- Read access to the codebase (in the worktree)

Do NOT pass: architecture design, dev chat history, prior QA conversation history

Instruct QA to:
1. Run the full test suite — any new failures are bugs
2. Re-verify the bugs from the previous QA report are actually fixed
3. Test every acceptance criterion (full regression, not just the fixes)
4. Write a new versioned QA report to `docs/qa/<feature-slug>-v<N>-review.md` (incrementing from the last version)

**If this QA also fails:** loop back to Stage 3 (Dev Fix) → Stage 3b (Final QA). Repeat until QA passes or 3 total fix cycles have been attempted. After 3 failed cycles, stop and report to the user for intervention.

---

## Stage 4: Commit

```bash
git add -A
git commit -m "feat(PROJ-456): <feature title>

Base: <base-branch> (if not main)
Implements: docs/designs/<slug>/vN.md
Spec: docs/specs/<slug>/vN.md
QA: docs/qa/<slug>-vN-review.md"
```

Update Plane task status to "In Review".

---

## Final Output (single feature)

```
## Feature Pipeline Complete

**Feature:** [feature name]
**Branch:** feature/PROJ-456-<slug>
**Base:** [main | feature/PROJ-123-<slug>]
**Worktree:** .worktrees/<slug>

### Results
- Dev: Complete — [N files changed], tests [pass/N new failures fixed]
- QA: [PASS | FAIL → fixed → verified PASS]
- Commit: [hash]

### Artifacts
- Implementation summary: docs/qa/<slug>-dev-summary.md
- QA report: docs/qa/<slug>-vN-review.md

### Review
  cd .worktrees/<slug> && git diff <base-branch>

### Next
  /pr PROJ-456
```

If base branch is not main, the diff command uses the base branch so you see only this feature's changes.
