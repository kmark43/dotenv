List and manage active feature worktrees: $ARGUMENTS

Arguments (all optional):
- No argument: list all active worktrees with status
- `clean`: remove worktrees for branches that have been merged to main
- A branch name or task ID: show details for a specific worktree

## Instructions

### List all worktrees (default)

Run:
```bash
git worktree list
```

For each worktree that is NOT the main working tree:
1. Read the branch name (e.g., `feature/PROJ-123-user-auth`)
2. Extract the Linear task ID from the branch name if present
3. Fetch the Linear task title and current status (if Linear MCP available)
4. Determine local status by checking:
   - Does `docs/qa/<slug>-*-review.md` exist? → QA has run
   - What is the QA report verdict? → PASS / FAIL / PASS WITH CONCERNS
   - Is there a PR open for this branch? (`gh pr list --head <branch>`)
   - Has the branch been merged? (`git branch --merged main`)

Display as a table:
```
## Active Feature Worktrees

| Worktree | Branch | Linear | Status |
|----------|--------|--------|--------|
| .worktrees/user-auth | feature/PROJ-123-user-auth | PROJ-123: User Auth | QA Passed — awaiting PR |
| .worktrees/notifications | feature/PROJ-456-notifications | PROJ-456: Push Notifs | In Progress |
| .worktrees/dark-mode | feature/PROJ-789-dark-mode | PROJ-789: Dark Mode | PR Open #42 |
```

Status values (in order of pipeline):
- **In Progress** — dev not yet complete
- **QA Passed** — QA report exists with PASS verdict, no PR yet
- **QA Failed** — QA report exists with FAIL verdict, needs dev fix
- **Awaiting PR** — QA passed, commit exists, no PR open
- **PR Open #N** — PR exists, link to it
- **Merged** — branch merged to main (safe to clean up)

### Clean merged worktrees

If argument is `clean`:
1. Find all worktrees whose branch has been merged to main
2. List them and ask for confirmation:
   ```
   The following worktrees are merged and can be removed:
   - .worktrees/user-auth (feature/PROJ-123-user-auth)
   Remove these? (y/n)
   ```
3. On confirmation:
   ```bash
   git worktree remove .worktrees/<slug>
   git branch -d feature/PROJ-123-<slug>
   ```

### Show details for a specific worktree

If a branch name or task ID is given, show:
- Worktree path
- Branch name and Linear task
- Last commit message and hash
- QA report verdict (if exists)
- PR status and link (if exists)
- Files changed vs main: `git diff --stat main`
