# Claude Code Multi-Agent Workflow

A linear, low-token-bleed workflow for building features with PM, Architect, Developer, and QA agents.

---

## Overview

Each feature moves through stages you control. Agents are stateless, activated only when you call them, and run in isolated context windows — no history bleeds between stages or between tasks.

```
Backlog → PM Spec → Architecture Design → Implementation → QA → Done
           ↑ you        ↑ you (optional)    ↑ parallel ok   ↑ auto  ↑ you
         approve           approve
```

Continuation between stages is always prompted and optional. You can also skip directly to any stage if the prior artifacts already exist.

---

## Setup

### 1. Install globally (done once)

Agents and commands are stored in a versioned git repo and installed into `~/.claude/` where Claude Code picks them up automatically.

**Clone and install:**
```bash
git clone <your-repo-url> ~/Projects/claude-config
cd ~/Projects/claude-config
./install.sh
```

**To update after pulling changes:**
```bash
cd ~/Projects/claude-config && git pull && ./install.sh
```

After install, `~/.claude/` will contain:
```
~/.claude/
  agents/
    pm.md           # Product Manager
    architect.md    # Software Architect
    developer.md    # Developer
    qa.md           # QA Engineer
  commands/
    spec.md            # /spec — write PM spec(s), single or bulk
    design.md          # /design — write architecture design(s), single or bulk
    feature.md         # /feature — full dev+QA pipeline, auto worktree
    fix.md             # /fix — lightweight bug fix (no spec/design needed)
    dev-task.md        # /dev-task — single isolated dev task (parallelizable)
    qa-review.md       # /qa-review — standalone QA review
    dev-fix.md         # /dev-fix — fix bugs from a QA report
    worktrees.md       # /worktrees — list and manage feature worktrees
    pr.md              # /pr — create PRs for completed features
  CLAUDE.md.template  # copy to new projects
  WORKFLOW.md         # this file
```

### 2. Per-project setup

Copy the template and fill it in:
```bash
cp ~/.claude/CLAUDE.md.template ./CLAUDE.md
```

Fill in your tech stack, repo structure, conventions, and protected paths. All agents read this file automatically.

Create the docs structure:
```bash
mkdir -p docs/specs docs/designs docs/qa
```

### 3. Set reasoning effort

Set session effort to medium for the best balance of speed and quality:
```bash
export CLAUDE_CODE_EFFORT_LEVEL=medium
```

Or add to your shell profile (`~/.zshrc`, `~/.bashrc`) to make it permanent.

Note: effort is a session-wide setting inherited by all subagents. Per-agent effort levels are not currently supported by Claude Code.

### 4. Connect Plane MCP (optional but recommended)

See the official Plane MCP docs to connect your workspace. Once connected, all commands support task lookup by name, ID, or backlog position, and automatically sync status and descriptions.

**Plane workflow statuses used:**
- **Backlog** → default
- **Spec Ready** → after PM spec is frozen
- **Design Ready** → after architecture design is approved
- **In Progress** → when dev starts (set by `/feature`)
- **In Review** → after QA passes and commit is made
- **Done** → after your final review and merge

---

## Daily Workflow

### Writing PM specs

`/spec` handles single features and bulk backlog batches in one command. Each task runs in a fully isolated subagent — no context bleeds between tasks.

**Single feature (name search, creates or finds Plane task):**
```
/spec "user authentication with email and social login"
/spec PROJ-123
/spec "auth feature"
```

**Bulk — top N prioritized backlog tasks:**
```
/spec 3
```

**Bulk — specific tasks:**
```
/spec PROJ-123,PROJ-456
```

**Single-task flow:**
1. Claude resolves the task (searches prioritized backlog first, then full backlog), confirms the match
2. If no Plane task exists: confirmed, then offered to create one after spec is frozen
3. PM agent (fresh subagent) writes a draft spec to `docs/specs/<feature>/v1.md`
4. PM surfaces open questions — you answer, PM updates, repeat until resolved
5. You approve: "lgtm", "freeze it", "approved", etc.
6. Plane task updated: Problem + Goals + AC + spec path copied in, status → "Spec Ready"
7. Prompted: **"Run `/design` for this spec now? (y/n)"**
   - Yes → fresh `/design` subagent starts (no PM history passed)
   - No → done

**Bulk (2+ tasks) — parallel hybrid flow:**

When multiple tasks are given, specs are processed in parallel phases to minimize your idle time:

1. **Parallel question generation** — all PM agents launch in background simultaneously, each reads its context and writes questions to `docs/specs/<slug>/_questions.md`
2. **Sequential Q&A** — you answer each task's questions one at a time in the foreground, with natural back-and-forth follow-ups
3. **Parallel spec writing** — all PM agents launch in background simultaneously, each writes its spec using your answers
4. **Consolidated review** — all drafts presented at once for review; approve or give feedback per spec
5. **Parallel revision** — specs with feedback get revised in parallel; loop until all approved
6. **Finalization** — all specs frozen, Plane updated, offered to run `/design`

The Q&A stays interactive and per-task for quality, while question generation and writing happen in parallel across all tasks.

**Amending a spec:** run `/spec` again for the same task — if a spec exists Claude asks whether to amend (new version) or skip.

---

### Writing architecture designs

`/design` handles single features and bulk in one command. Each design runs in a fresh subagent with no history from the spec session or prior tasks.

**Single design:**
```
/design docs/specs/user-auth/v1.md
/design PROJ-123
/design "user authentication"
```

**Bulk — top N "Spec Ready" tasks:**
```
/design 3
/design PROJ-123,PROJ-456
```

**Single-task flow:**
1. Claude resolves the spec path (from argument, Plane task, or name search), confirms
2. Architect (fresh subagent) reads `CLAUDE.md` + PM spec + existing related designs
3. Architect verifies spec status is "Ready for Architect" — stops if not
4. **Question phase (iterative):**
   - Architect asks all architectural questions it can identify in one batch
   - You answer
   - If answers raise new questions, follow-up round — repeat until no more
   - Only then does it write
5. Architect writes design to `docs/designs/<feature>/vN.md`, presents for review
6. You give feedback → architect makes targeted edits → repeat until approved
7. Plane updated: design path added, status → "Design Ready"
8. Prompted: **"Start implementation now? (y/n)"**
   - Yes → worktree auto-created, fresh `/feature` subagent starts (no design history passed)
   - No → done

**Bulk (2+ tasks) — parallel hybrid flow:**

When multiple tasks are given, designs are processed in parallel phases:

1. **Parallel question generation** — all architect agents launch in background simultaneously, each reads its spec and writes questions to `docs/designs/<slug>/_questions.md`
2. **Sequential Q&A** — you answer each task's architectural questions one at a time in the foreground, with natural back-and-forth follow-ups
3. **Parallel design writing** — all architect agents launch in background simultaneously, each writes its design using your answers
4. **Consolidated review** — all designs presented at once for review; approve or give feedback per design
5. **Parallel revision** — designs with feedback get revised in parallel (uses `architect-revise` for surface-level feedback, full `architect` for structural changes); loop until all approved
6. **Finalization** — all designs approved, Plane updated, offered to run `/feature`

**Parallel tip:** approve a design and kick off implementation while working on the next design by sending both in the same message:
```
/feature docs/designs/user-auth/v1.md
/design "push notifications"
```
The `/feature` pipeline runs as a subagent while you work interactively on the next design.

---

### Running implementation (full pipeline)

**Single feature:**
```
/feature docs/designs/user-auth/v1.md
/feature PROJ-123
/feature "user authentication"
```

**Multiple features in parallel (each gets its own worktree + subagent):**
```
/feature "integration tests" | "jest unit testing"
/feature PROJ-123,PROJ-456
/feature 3
```

When multiple features are given (or a fuzzy search finds multiple matches), all worktrees are created upfront and each pipeline runs as a parallel subagent — no waiting between features.

**What happens automatically:**
1. Worktree(s) created: `feature/PROJ-123-<slug>` branch, `.worktrees/<slug>` directory
2. **Dev agent** (fresh subagent per feature) — reads design + PM spec, implements, flags ambiguity instead of guessing
3. **QA agent** (fresh subagent per feature) — reads PM spec only (not design), tests every AC and FR, assumes bugs exist, writes report to `docs/qa/`
4. **Dev Fix agent** (fresh subagent, only if QA fails) — fixes against QA report only
5. **Final QA** (fresh subagent, only if dev fix ran) — verifies fixes didn't introduce new issues, loops back to dev fix if needed (max 3 cycles)
6. Commit made on the feature branch with design/spec/QA references in the message
7. Plane status → "In Review"
8. Summary output with diff review instructions and `/pr` command

**To review the diff after pipeline completes:**
```bash
cd .worktrees/<slug> && git diff main
```

**Giving feedback on a completed feature:**

Run `/feature` again for a feature that already has a worktree. Instead of starting fresh, it detects the existing worktree and prompts:

```
/feature PROJ-123
/feature "user authentication"
```

You can:
- **Give feedback** — describe what you want changed. A dev agent applies your feedback, QA runs again, dev-fix if needed, final QA to verify fixes, then commits.
- **Re-run QA only** — useful after manual changes to the worktree.
- **Start fresh** — deletes the worktree and runs the full pipeline from scratch.

This feedback loop is repeatable — run `/feature` as many times as needed until you're satisfied.

---

### Bug fixes and small tasks

For bugs and small contained tasks that don't need a PM spec or architecture design:

```
/fix PROJ-123
/fix "login button broken"
/fix "crash on logout screen"
```

**What happens:**
1. Claude finds the task in Plane, confirms
2. Sanity check — evaluates if the task is appropriate for the lightweight path:
   - Has a clear testable outcome?
   - Scope contained to a specific behavior?
   - No data model changes or new API surfaces likely?
   - If any fail → warning shown, you choose to proceed or escalate to `/spec`
3. Dev agent implements using only the Plane task description
4. If dev discovers the fix requires structural changes — stops and escalates:
   ```
   ## Escalation Required
   Reason: [what was discovered]
   Recommendation: /spec PROJ-123
   ```
5. QA tests stated expected behavior and regressions
6. Dev fix loop if QA finds issues
7. Plane status → "In Review"

**Rule of thumb:** if you can write a one-sentence expected outcome, use `/fix`. If you're debating what the right behavior should be, use `/spec` first.

---

### Parallel dev tasks

When a feature has multiple independently implementable pieces, use `/dev-task` for granular control:

```
/dev-task "implement token generation service | design: docs/designs/user-auth/v1.md | spec: docs/specs/user-auth/v1.md"
/dev-task "implement auth middleware | design: docs/designs/user-auth/v1.md | spec: docs/specs/user-auth/v1.md"
```

Send both in the same message to run in parallel. Each runs in its own isolated subagent.

**For tasks that touch the same files, use git worktrees:**
```bash
git worktree add .worktrees/auth-tokens feature/auth-tokens
git worktree add .worktrees/auth-middleware feature/auth-middleware

# Fix absolute paths → relative paths for each worktree (required for devcontainer/mount compatibility)
# For each <slug>:
echo "gitdir: ../../.git/worktrees/<slug>" > .worktrees/<slug>/.git
echo "../../.worktrees/<slug>/.git" > .git/worktrees/<slug>/gitdir
```
Run each `/dev-task` from its respective worktree directory. Merge/rebase after review.

---

### Managing worktrees

List all active feature worktrees and their pipeline status:
```
/worktrees
```

Shows a table with branch, Plane task, and status (In Progress / QA Passed / Awaiting PR / PR Open / Merged).

Remove merged worktrees:
```
/worktrees clean
```

Show details for a specific worktree:
```
/worktrees PROJ-123
/worktrees feature/PROJ-123-user-auth
```

---

### Creating PRs

Create a PR for a specific feature:
```
/pr PROJ-123
/pr feature/PROJ-123-user-auth
/pr "user authentication"
```

Bulk — create PRs for all features that have passed QA and have no open PR:
```
/pr all
```

Each PR is populated with: feature summary, files changed, QA verdict, and links to the spec, design, and QA report. Plane task status updated to "In Review".

---

### Standalone QA or fix

Run QA on its own (e.g., after manual changes):
```
/qa-review docs/specs/user-auth/v1.md
```

Fix bugs from an existing QA report:
```
/dev-fix docs/qa/user-auth-v1-review.md
```

---

## Artifact Reference

| Artifact | Location | Written by | Read by |
|----------|----------|-----------|---------|
| PM Spec | `docs/specs/<feature>/vN.md` | PM agent | Architect, Dev, QA |
| Architecture Design | `docs/designs/<feature>/vN.md` | Architect agent | Dev |
| Dev Summary | `docs/qa/<feature>-dev-summary.md` | Dev agent | QA |
| QA Report | `docs/qa/<feature>-vN-review.md` | QA agent | Dev Fix, you |
| Feedback Summary | `docs/qa/<feature>-feedback-summary.md` | Dev agent (feedback) | QA |
| Workflow Artifacts | `docs/specs/<feature>/_*.md`, `docs/designs/<feature>/_*.md` | Parallel phases | Next phase |

### Versioning

- **Spec amendments:** new file `v2.md`, `v3.md` — includes `## Changes from vN` at top
- **Design amendments:** new file versioned against PM spec — includes `## Changes from vN` at top
- Old versions are never deleted — they are the paper trail

### When to keep spec files long-term

- **Large features / complex domain logic:** keep forever — future context for re-design
- **Small tasks / bug fixes:** archive after shipping (keep committed, stop reading actively)
- **Never delete:** the file is cheap; losing context is expensive

---

## Context Isolation (how token bleed is prevented)

Each agent only receives what it needs. No history is passed between stages or between tasks.

| Agent | Gets | Does NOT get |
|-------|------|-------------|
| PM | CLAUDE.md, Plane task, existing specs | Code, architecture, chat history |
| Architect | CLAUDE.md, PM spec, existing designs | Code, PM chat history |
| Dev | CLAUDE.md, PM spec (AC only), design | PM/architect chat history, other features |
| QA | CLAUDE.md, PM spec (AC/FR only), impl summary | Architecture design, dev chat history |
| Dev Fix | CLAUDE.md, QA report, PM spec (AC only) | Architecture design, dev/QA chat history |

Bulk commands (`/spec N`, `/design N`) spawn a completely fresh subagent per task — task 1's conversation is never visible to task 2.

Continuation prompts (spec → design, design → implementation) always spawn a fresh subagent — the prior stage's conversation history is never passed forward.

---

## Command Reference

| Command | Usage |
|---------|-------|
| `/spec <feature/ID/name/N>` | Write PM spec(s) — single or bulk |
| `/design <spec/ID/name/N>` | Write architecture design(s) — single or bulk |
| `/feature <design/ID/name/N>` | Full pipeline: single or parallel — worktree(s) → Dev → QA → fix → verify QA → commit |
| `/fix <ID/name/description>` | Lightweight bug fix (no spec/design needed) |
| `/dev-task <desc \| design: path \| spec: path>` | Single isolated dev task (parallelizable) |
| `/qa-review <spec path>` | Standalone QA review |
| `/dev-fix <qa report path>` | Fix bugs from a QA report |
| `/worktrees [clean \| ID/branch]` | List and manage feature worktrees |
| `/pr <ID/branch/name/all>` | Create PR(s) for completed features |

---

## Adding to a New Project

1. `cp ~/.claude/CLAUDE.md.template ./CLAUDE.md` — fill in tech stack, conventions, protected paths
2. `mkdir -p docs/specs docs/designs docs/qa`
3. Set up Plane workflow statuses: Backlog, Spec Ready, Design Ready, In Progress, In Review, Done
4. Run `/spec` or `/spec 3` to start

No other per-project configuration needed. All agents and commands are global.

---

## Troubleshooting

**Architect starts writing without asking questions**
Tell it: "Stop — you haven't asked your clarifying questions yet." The agent prompt requires Phase 2 before Phase 3.

**Dev guessed instead of flagging ambiguity**
Run `/qa-review` — QA will catch it. Then file a bug against the implementation with `/dev-fix`.

**Plane task not found by name**
Try a more specific name, or use the task ID directly (`PROJ-123`).

**Parallel tasks conflicting on the same files**
Use git worktrees (see above). Each worktree is an isolated working directory on its own branch.

**Spec has open questions but got marked Ready**
Edit the spec status back to "Open Questions" and continue the spec conversation.

**`/fix` escalated but the task really is small**
Override by running `/dev-task` directly with more specific context, or add more detail to the Plane task description and retry.

**Not sure whether to use `/fix` or `/spec`**
Ask: can you write a one-sentence expected outcome? If yes, try `/fix`. If you're debating what the right behavior should be, use `/spec`.

**Worktree left over after merge**
Run `/worktrees clean` to remove merged worktrees and their local branches.
