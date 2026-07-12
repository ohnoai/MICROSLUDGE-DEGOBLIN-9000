# Task Handoffs

Task files are the source of truth for work that spans multiple files, sessions, or agents.

- Before starting, inspect this folder for an existing matching task.
- For new non-trivial work, copy `TEMPLATE.md` to a short kebab-case name such as `scheduled-task-repair.md`.
- Use one file per task. Concurrent tasks must not share a task file.
- Set `owner` to the person, client, or agent currently responsible. Do not edit another owner's task without coordinating first.
- Update the task after meaningful checkpoints and before stopping. Record evidence, not guesses.
- Keep lasting project decisions in `../decisions/`; task files hold temporary execution state.
- Never store credentials, tokens, private user data, or environment-file contents here.
- When complete, transfer lasting decisions, set `status: complete`, and move the file to `archive/YYYY/`.

Allowed statuses are `planned`, `active`, `blocked`, and `complete`. `README.md` and `TEMPLATE.md` are not task records.
