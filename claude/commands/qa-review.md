Run a QA review for the following feature: $ARGUMENTS

The argument should be the path to the PM spec (e.g., `docs/specs/user-auth/v1.md`).

## Instructions

Use the `qa` agent with ONLY this context:
- `CLAUDE.md`
- The PM spec at the provided path
- The implementation summary at `docs/qa/<feature-slug>-dev-summary.md` (if it exists)
- Read access to the codebase

Do NOT pass:
- Architecture design
- Dev chat history
- PM or architect conversation history

Instruct QA to:
1. Read the PM spec fully — acceptance criteria and functional requirements are the only pass/fail criteria
2. Test every acceptance criterion
3. Test every functional requirement
4. Test every edge case listed in the spec
5. Review for premature abstractions or unnecessary complexity
6. Write the full report to `docs/qa/<feature-slug>-v<N>-review.md`

When done, output the verdict and bug count so the user can decide whether to run `/dev-fix`.
