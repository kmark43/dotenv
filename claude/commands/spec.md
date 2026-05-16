Write PM spec(s) for: $ARGUMENTS

Arguments can be:
- Multiple descriptions: `/spec "user auth" | "push notifications" | "dark mode"` — each processed independently
- A single feature name/description: `/spec "user authentication"`

## Instructions

### Step 1: Resolve the feature list

**If given multiple descriptions (`|` separated):**
- Split on ` | ` to get individual feature names
- Display the list and wait for confirmation before proceeding

**If given a single name/description:**
- Check `docs/specs/` for any existing spec whose slug or title closely matches
- If found, show it and confirm: amend (new version) or start fresh?
- If not found, proceed to write a new spec

### Step 2: Determine execution mode

- **1 task:** Use the single-task interactive flow (Step 3)
- **2+ tasks:** Use the parallel hybrid flow (Step 4)

---

### Step 3: Single-task flow (interactive, foreground)

Run in a fresh subagent with clean context.

**3a. Check for existing spec**
- Check `docs/specs/<feature-slug>/` for an existing spec
- If a spec file exists, show it and ask: amend (new version) or skip?

**3b. Activate the `pm` agent with ONLY:**
- `CLAUDE.md`
- `README.md` (if it contains product context)
- The feature name/description provided by the user
- Any existing related specs from `docs/specs/`

Do NOT pass: code, architecture docs, other tasks' specs, prior conversation history

**3c. PM writes the spec**
- Writes to `docs/specs/<feature-slug>/v1.md` (or next version if amending)
- Surfaces open questions — stay in loop, answer them, PM updates spec
- Repeat until no open questions remain

**3d. Present spec for review**

After the PM finishes writing the spec (no open questions remaining), output:
```
## Spec Draft Complete — [title]
File: docs/specs/<feature-slug>/v1.md

Please review the spec. When ready:
- Approve to freeze and optionally move to design
- Or give feedback to revise
```

Wait for the user to read and respond.

**3e. On approval**
- User says "approved", "lgtm", "freeze it", etc.
- PM sets status to "Ready for Architect"
- Then immediately ask:
```
## Spec Frozen — [title]
File: docs/specs/<feature-slug>/v1.md

Run /design for this spec now? (y/n)
```
- If yes: spawn a fresh `/design` subagent with only the spec path — NO history from this spec session
- If no: done

---

### Step 4: Multi-task parallel hybrid flow

Parallelizes writing while keeping Q&A interactive for quality. Each task maintains context isolation — no history bleeds between tasks.

#### Phase 1: Parallel question generation (background)

For each task, check for existing specs first (same as 3a). Then spawn one background `pm` subagent per task simultaneously. Each receives ONLY:
- `CLAUDE.md`
- `README.md` (if it contains product context)
- The feature name/description
- Any existing related specs from `docs/specs/`
- **Instruction:** Read all context, identify open questions and ambiguities, write them to `docs/specs/<slug>/_questions.md`. Do NOT write a spec yet. Do NOT ask the user — write questions to the file and terminate.

All agents run simultaneously. Wait for all to complete.

#### Phase 2: Sequential per-task Q&A (foreground)

For each task in order:

1. Read `docs/specs/<slug>/_questions.md`
2. If the agent had no questions, note it and move to the next task
3. Present the questions to the user in the foreground
4. Allow natural back-and-forth — if answers raise follow-up questions, continue the conversation
5. When all questions are resolved, write the final answers to `docs/specs/<slug>/_answers.md`
6. Move to the next task's Q&A

```
## Q&A — Task 1 of N: [title]

The PM agent has the following questions:

Q1: [question]
Q2: [question]

Please answer these questions.
```

After completing Q&A for a task, show:
```
Q&A complete for [title]. Moving to next task...
```

#### Phase 3: Parallel spec writing (background)

Spawn one background `pm` subagent per task simultaneously. Each receives ONLY:
- `CLAUDE.md`
- `README.md` (if it contains product context)
- The feature name/description
- `docs/specs/<slug>/_questions.md` — the questions
- `docs/specs/<slug>/_answers.md` — the user's answers
- **Instruction:** Write the spec to `docs/specs/<slug>/v1.md` using the provided answers. Do NOT ask questions — they have been answered. If any remaining ambiguity exists, note it in the Open Questions section of the spec.

All agents run simultaneously. Wait for all to complete.

#### Phase 4: Consolidated review (foreground)

Present all drafted specs to the user:

```
## Spec Drafts Ready for Review

### 1. [title]
File: docs/specs/<slug-1>/v1.md
[2-3 line summary of what the spec covers]

### 2. [title]
File: docs/specs/<slug-2>/v1.md
[2-3 line summary of what the spec covers]

Review each spec. For each, respond with:
- "approved" / "lgtm" to freeze
- Feedback to revise (reference by number)
```

Process the user's response:
- **Approved specs:** Freeze immediately — PM sets status to "Ready for Architect"
- **Specs with feedback:** Write feedback to `docs/specs/<slug>/_feedback.md`

#### Phase 5: Parallel revision (background, conditional)

If any specs received feedback, spawn background `pm` subagents for those specs only. Each receives:
- `CLAUDE.md`
- The current spec version
- `docs/specs/<slug>/_feedback.md`
- **Instruction:** Revise the spec based on the feedback. Write the new version to `docs/specs/<slug>/v<N+1>.md`. Do NOT ask questions.

Wait for all to complete, then return to Phase 4 for the revised specs only. Loop narrows each round until all specs are approved.

#### Phase 6: Finalization

After all specs are frozen:
```
## All Specs Frozen

| Feature | Spec | Status |
|---------|------|--------|
| [title] | docs/specs/<slug-1>/v1.md | Spec Ready |
| [title] | docs/specs/<slug-2>/v1.md | Spec Ready |

Run /design for all specs now? (y/n/select)
```
- If yes: spawn a fresh `/design` session with all spec paths
- If select: let user pick which specs to design
- If no: done

### Workflow artifact files

Underscore-prefixed files are workflow artifacts used for phase-to-phase communication. They are not versioned specs.

```
docs/specs/<slug>/
  _questions.md     # Phase 1 output: PM's questions
  _answers.md       # Phase 2 output: user's answers
  _feedback.md      # Phase 4 output: user's review feedback
  v1.md             # Phase 3 output: spec draft
  v2.md             # Phase 5 output: revised spec (if needed)
```
