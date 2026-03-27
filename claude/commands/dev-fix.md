Fix the bugs identified in the following QA report: $ARGUMENTS

The argument should be the path to the QA report (e.g., `docs/qa/user-auth-v1-review.md`).

## Instructions

Use the `developer` agent with ONLY this context:
- `CLAUDE.md`
- The QA report at the provided path
- The PM spec referenced in the QA report (read only for acceptance criteria)
- Relevant existing source files

Do NOT pass:
- Architecture design
- Previous dev chat history
- QA conversation history
- PM or architect chat history

Instruct the developer to:
1. Read CLAUDE.md for conventions
2. Read every BUG entry in the QA report
3. Fix each bug exactly — do not change unrelated code
4. Do not address complexity concerns unless they are causing actual bugs
5. Flag any bug that cannot be fixed without an architecture or spec change
6. Output a fix summary:

```
## Fix Summary

**QA Report:** [path]

### Bugs Addressed
- BUG-1: [title] — Fixed: [brief description of fix]
- BUG-2: [title] — Fixed: [brief description of fix]

### Bugs Requiring Escalation (if any)
- BUG-N: [title] — Requires: [PM spec amendment | Architecture design amendment]
  Reason: [why this can't be fixed in code alone]

### Files Changed
- path/to/file.ts — [what changed]
```

After the fix summary is written, report to the user so they can decide whether to re-run `/qa-review` or approve.
