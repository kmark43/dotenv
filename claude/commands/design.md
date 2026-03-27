Write architecture design(s) for: $ARGUMENTS

Arguments can be:
- A number: `/design 3` — top N "Spec Ready" tasks from Plane
- Task IDs: `/design PROJ-123,PROJ-456` or `/design PROJ-123 | PROJ-456` — specific tasks (comma or `|` separated)
- Multiple names: `/design "user auth" | "push notifications"` — each searched independently
- A single feature name: `/design "user authentication"` — search Plane, confirm match
- A spec path: `/design docs/specs/user-auth/v1.md` — use directly

## Instructions

### Step 1: Resolve the task/spec list

**If given a number N:**
- Search Plane for top N tasks with status "Spec Ready" (by backlog priority order)
- Display the list and wait for confirmation

**If given task IDs (comma or `|` separated):**
- Split on `,` or ` | ` to get individual IDs
- Fetch each from Plane, read spec path from `**Spec:**` field in task description
- Display confirmed list and wait

**If given multiple names (`|` separated):**
- Split on ` | ` to get individual names
- Treat each as a separate task — resolve, confirm, and process each in order (same flow as bulk task IDs)

**If given a single feature name:**
- Search prioritized backlog first, then full backlog
- Present top 1-3 matches and wait for confirmation

**If given a spec path directly:**
- Confirm file exists, read feature name from it, proceed

### Step 2: Determine execution mode

- **1 task:** Use the single-task interactive flow (Step 3)
- **2+ tasks:** Use the parallel hybrid flow (Step 4)

---

### Step 3: Single-task flow (interactive, foreground)

Run in a fresh subagent with clean context. Do not carry context from a prior spec session.

**3a. Resolve spec path**
- From the Plane task `**Spec:**` field, or from the directly provided path
- If no spec path found in Plane task, report and stop

**3b. Check for existing design**
- Check `docs/designs/<feature-slug>/` for an existing design
- If found, show it and ask: amend (new version) or skip?

**3c. Activate the `architect` agent with ONLY:**
- `CLAUDE.md`
- The PM spec at the resolved path
- Any existing designs in `docs/designs/` for related features

Do NOT pass: code, PM conversation history, other tasks' designs, prior conversation history

**3d. Architect runs its full interactive flow**

The architect operates in 4 phases — the command must not short-circuit any of them:

- **Phase 1:** Read CLAUDE.md + PM spec + existing related designs. Verify spec status is "Ready for Architect" — if not, stop and report.
- **Phase 2 (iterative Q&A):** Ask all architectural questions in one batch. Wait for answers. Ask follow-up rounds if needed. Only proceed when no more questions remain.
- **Phase 3:** Write the design to `docs/designs/<feature-slug>/vN.md`. Present it for review.
- **Phase 4 (iterative review):** When feedback is received, evaluate its scope before invoking a revision agent:

  **Use `architect-revise` (fast) when feedback is surface-level:**
  - Wording, clarity, or phrasing changes
  - Adding examples or elaboration to existing sections
  - Minor restructuring within a section
  - Small additions that don't change the technical approach
  - Fixing inconsistencies or typos

  **Use `architect` (full) when feedback is structural:**
  - Changes to data model, API shape, or security model
  - Scope changes (adding or removing what's being built)
  - Significant tradeoff reconsiderations
  - New risks that weren't previously identified
  - Feedback that contradicts an existing architectural decision

  Invoke the appropriate agent with: the design file, the specific feedback, and CLAUDE.md. No prior conversation history.
  Repeat until approved.

**3e. On approval**
- Plane task status → "Design Ready"
- Design file path added to Plane task as comment
- Output:
  ```
  ## Design Approved — PROJ-123: [title]
  File: docs/designs/<feature-slug>/vN.md
  Plane: updated
  ```

**3f. Offer to continue to implementation (optional)**
```
Start implementation now? (y/n)
```
- If yes: create git worktree first:
  ```bash
  git worktree add .worktrees/<slug> feature/PROJ-123-<slug>

  # Fix absolute paths → relative paths (required for devcontainer/mount compatibility)
  echo "gitdir: ../../.git/worktrees/<slug>" > .worktrees/<slug>/.git
  echo "../../.worktrees/<slug>/.git" > .git/worktrees/<slug>/gitdir
  ```
  Then spawn a fresh `/feature` subagent inside that worktree with ONLY the design path — NO history from this design session
- If no: done

---

### Step 4: Multi-task parallel hybrid flow

Parallelizes writing while keeping Q&A interactive for quality. Each task maintains context isolation — no history bleeds between tasks.

#### Phase 1: Parallel question generation (background)

For each task, resolve the spec path and check for existing designs first (same as 3a/3b). Then spawn one background `architect` subagent per task simultaneously. Each receives ONLY:
- `CLAUDE.md`
- The PM spec at the resolved path
- Any existing designs in `docs/designs/` for related features
- **Instruction:** Read all context. Identify architectural clarifying questions — things the spec doesn't answer that affect design decisions. Write them to `docs/designs/<slug>/_questions.md`. Do NOT write a design yet. Do NOT ask the user — write questions to the file and terminate.

All agents run simultaneously. Wait for all to complete.

#### Phase 2: Sequential per-task Q&A (foreground)

For each task in order:

1. Read `docs/designs/<slug>/_questions.md`
2. If the architect had no questions, note it and move to the next task
3. Present the questions to the user in the foreground
4. Allow natural back-and-forth — if answers raise follow-up architectural questions, continue the conversation
5. When all questions are resolved, write the final answers to `docs/designs/<slug>/_answers.md`
6. Move to the next task's Q&A

```
## Architect Q&A — Task 1 of N: PROJ-123 — [title]

The architect has the following questions:

Q1: [question] — needed to decide: [what]
Q2: [question] — needed to decide: [what]

Please answer these questions.
```

After completing Q&A for a task, show:
```
Q&A complete for PROJ-123. Moving to next task...
```

#### Phase 3: Parallel design writing (background)

Spawn one background `architect` subagent per task simultaneously. Each receives ONLY:
- `CLAUDE.md`
- The PM spec at the resolved path
- Any existing designs in `docs/designs/` for related features
- `docs/designs/<slug>/_questions.md` — the questions
- `docs/designs/<slug>/_answers.md` — the user's answers
- **Instruction:** Write the design to `docs/designs/<slug>/v1.md` using the provided answers. Do NOT ask questions — they have been answered. Follow the standard design format from the architect agent instructions.

All agents run simultaneously. Wait for all to complete.

#### Phase 4: Consolidated review (foreground)

Present all drafted designs to the user:

```
## Architecture Designs Ready for Review

### 1. PROJ-123: [title]
File: docs/designs/<slug-1>/v1.md
Key decisions: [2-3 bullet points]

### 2. PROJ-456: [title]
File: docs/designs/<slug-2>/v1.md
Key decisions: [2-3 bullet points]

Review each design. For each, respond with:
- "approved" / "lgtm" to freeze
- Feedback to revise (reference by number or task ID)
```

Process the user's response:
- **Approved designs:** Update Plane (status → "Design Ready", add design path as comment)
- **Designs with feedback:** Write feedback to `docs/designs/<slug>/_feedback.md`

#### Phase 5: Parallel revision (background, conditional)

If any designs received feedback, evaluate the feedback scope for each and spawn the appropriate agent:

**Use `architect-revise` (fast) when feedback is surface-level:**
- Wording, clarity, or phrasing changes
- Adding examples or elaboration to existing sections
- Minor restructuring within a section
- Small additions that don't change the technical approach
- Fixing inconsistencies or typos

**Use `architect` (full) when feedback is structural:**
- Changes to data model, API shape, or security model
- Scope changes (adding or removing what's being built)
- Significant tradeoff reconsiderations
- New risks that weren't previously identified
- Feedback that contradicts an existing architectural decision

Each revision agent receives:
- `CLAUDE.md`
- The current design version
- `docs/designs/<slug>/_feedback.md`
- **Instruction:** Revise the design based on the feedback. Write the new version to `docs/designs/<slug>/v<N+1>.md`.

All revision agents run simultaneously. Wait for all to complete, then return to Phase 4 for the revised designs only. Loop narrows each round until all designs are approved.

#### Phase 6: Finalization

After all designs are approved:
```
## All Designs Approved

| Task | Design | Status |
|------|--------|--------|
| PROJ-123: [title] | docs/designs/<slug-1>/v1.md | Design Ready |
| PROJ-456: [title] | docs/designs/<slug-2>/v1.md | Design Ready |

Start implementation now? (y/n/select)
```
- If yes: spawn `/feature` with all design paths (runs as parallel pipelines)
- If select: let user pick which designs to implement
- If no: done

### Workflow artifact files

Underscore-prefixed files are workflow artifacts used for phase-to-phase communication. They are not versioned designs.

```
docs/designs/<slug>/
  _questions.md     # Phase 1 output: architect's questions
  _answers.md       # Phase 2 output: user's answers
  _feedback.md      # Phase 4 output: user's review feedback
  v1.md             # Phase 3 output: design draft
  v2.md             # Phase 5 output: revised design (if needed)
```
