Implement the following task using the approved architecture design: $ARGUMENTS

The argument should be in the format: `<task description> | design: <path to design> | spec: <path to PM spec>`

Example: `Implement the token generation service | design: docs/designs/user-auth/v1.md | spec: docs/specs/user-auth/v1.md`

## Instructions

Use the `developer` agent with ONLY this context:
- `CLAUDE.md`
- The PM spec at the specified path (for acceptance criteria)
- The architecture design at the specified path (for structure)
- Relevant existing source files for the specific task

Do NOT pass:
- PM chat history
- Architect chat history
- Other feature's dev history
- QA reports from other features

This task runs as an independent, stateless session. Each `/dev-task` invocation is isolated.

Instruct the developer to:
1. Read CLAUDE.md for project conventions
2. Read the PM spec for acceptance criteria relevant to this task
3. Read the architecture design for the structure to implement
4. Flag any ambiguity before writing code — do not guess
5. Implement only what is described in the task
6. Write an implementation summary

This command is suitable for running multiple tasks in parallel when tasks affect non-overlapping parts of the codebase.
