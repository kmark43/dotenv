Create pull request(s) for feature worktrees: $ARGUMENTS

Arguments can be:
- No argument: create PR for the current branch (must be a feature branch)
- A branch name: `/pr feature/PROJ-123-user-auth`
- A Plane task ID: `/pr PROJ-123`
- A feature name: `/pr "user authentication"` — searches active worktrees/branches
- `all`: create PRs for all worktrees with status "Awaiting PR" (QA passed, no PR yet)

## Instructions

### Step 1: Resolve branches to create PRs for

**No argument or branch name:** use the current branch or specified branch directly.

**Plane task ID or feature name:**
- Match to an active worktree/branch (same lookup as `/worktrees`)
- Confirm the match before proceeding

**`all`:**
- Run `git worktree list` and find all feature branches
- Filter to only branches where:
  - A QA report exists with a PASS verdict
  - No PR is already open (`gh pr list --head <branch>` returns empty)
- Display the list and wait for confirmation:
  ```
  PRs to create:
  1. feature/PROJ-123-user-auth — PROJ-123: User Auth
  2. feature/PROJ-456-notifications — PROJ-456: Push Notifications
  Create PRs for all? (y/n)
  ```

### Step 2: For each branch — create the PR

**Gather context:**
- Read the last commit message for the feature description
- Find the design file: `docs/designs/<slug>/vN.md` — read Key Decisions and Risks Flagged
- Find the QA report: `docs/qa/<slug>-vN-review.md` — read the Summary and any open complexity concerns
- Find the spec file: `docs/specs/<slug>/vN.md` — read Goals and Acceptance Criteria
- Get the Plane task URL (if available)

**Push the branch if not already pushed:**
```bash
git push -u origin feature/PROJ-123-<slug>
```

**Create the PR:**
```bash
gh pr create \
  --title "feat(PROJ-123): <feature title>" \
  --body "..." \
  --base main \
  --head feature/PROJ-123-<slug>
```

**PR body format:**
```markdown
## Summary
[2-3 bullet points from the design's Key Decisions and spec Goals]

## Changes
[files changed summary — from git diff --stat main]

## QA
[QA report verdict + any complexity concerns worth noting]

## References
- Plane: [task URL]
- Spec: docs/specs/<slug>/vN.md
- Design: docs/designs/<slug>/vN.md
- QA Report: docs/qa/<slug>-vN-review.md
```

**After PR is created:**
- Update Plane task status to "In Review" (if not already)
- Output the PR URL

### Step 3: Final output

```
## PRs Created

- PROJ-123: User Auth → [PR URL]
- PROJ-456: Push Notifications → [PR URL]

Plane: statuses updated to "In Review"
```

If any branch failed (not pushed, conflicts, etc.) report it separately so you can handle it manually.
