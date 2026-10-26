# AGENTS.md

> Single source of truth for this repo. `CLAUDE.md` and `.cursor/rules/agents.mdc`
> both point here. Keep this file current; it is read by every coding agent.

## Project

**face-presence** — macOS CLI that samples the camera, counts faces on-device, and prints presence as JSON. No images stored.

## Tech stack

- Language-agnostic base (agent + SDLC layer)

## Commands

- `make build` — compile `Sources/face-presence.swift` to `build/face-presence` with the embedded Info.plist and an ad-hoc signature.
- `make check` — typecheck plus `tests/cli_test.sh` (argument handling; no camera). `FACE_PRESENCE_CAMERA_TEST=1 make check` adds one real sample and a 15-second loop that checks only one capture session stays alive. Run before every commit.
- `make install [PREFIX=...]` — copy the binary to `$PREFIX/bin` (default `~/.local`).
- Single source file on purpose; keep it that way until there is a second concern.



## SDLC working agreements

These are non-negotiable for all agents and humans:

- **Conventional Commits** — `<type>(<scope>): <desc>` (`feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`, `revert`). **No `Co-Authored-By` trailer.**
- **Trunk-based** — work on a short-lived branch `<type>/<short-desc>`; **never commit directly to `main`**. Merge within 1–2 days.
- **Tests with every change** — production changes ship with test changes. Don't commit if tests fail.
- **Never** use `git push --force` or bypass hooks with `--no-verify`.
- **Security** — never commit secrets; `.env*`, `*.pem`, `*.key`, `*_rsa`, `*.p12` are gitignored. Check `git diff --cached` before committing. Never read/print `.env` files.
- **Hook strictness:** `standard` (see `.husky/` or `.pre-commit-config.yaml`).
- **Branch protection:** `main` is protected on GitHub (PR required, owner cannot bypass). Decided 2026-10-12.
- **Privacy is the product:** frames never touch disk, the network, or logs. Any change that stores or transmits image data needs an explicit decision in `docs/decisions/` first.

<!-- gh-task:start -->

## Task management

Tasks are GitHub Issues. Leaves (tasks and bugs) live in this repo, flat, one PR to `main` each.
Initiatives and the pinned Plan live in the planning repo `anthnyalxndr/face-presence-tasks` (recorded in
`git config gh-task.plan-repo`). The `gh task` extension enforces the conventions; use it for every
write and raw `gh issue view` / `gh issue list` for reads.

- `gh task ready` lists what an agent may start now: open, labeled `agent` by the owner, no open
  blocker or sub-issue, no status label, a Description plus checkbox acceptance criteria, one
  `priority:*` label. Highest priority first, then lowest number. Each line names its initiative.
  `gh task initiatives` lists the open initiatives with open and done leaf counts. The same commands
  work whether this repo plans in itself or in a companion; `gh task` reads the location from git config.
- `gh task create --title … --description … --ac … [--ac …] --priority high|medium|low --parent <n>`
  is the only way to add a task. A bare `--parent` number is an initiative in the planning repo;
  `--standalone` with a reason in the description is the escape hatch. `--kind initiative` creates
  an initiative in the planning repo; initiatives nest at most three deep and are never worked.
- Ordering is `--blocked-by` (any repo; a bare number is an issue in this repo). Integration work is a leaf blocked by the leaves it
  integrates. A leaf has no children. No integration branches.
- `gh task start <n>` claims a ready issue, creates branch `<type>/<n>-<slug>` linked to it, and
  prints the brief (Description, Acceptance criteria, Pointers). `--stack-on <sibling>` bases the
  branch on a sibling leaf's branch when two leaves must land in order. `gh task check <n> --ac <k>`
  ticks a criterion once a test or command proves it. `gh task done <n> --pr <n|url>` refuses while a
  criterion is unchecked (unless `--incomplete "<reason>"`), links the draft PR (`Closes #n`) and
  moves the issue to `review`. A human merges; merge closes the issue.
- Other people file bugs and feature requests through the issue forms; an accepted feature request
  becomes a task via `/task-refine`.
- Skills: `/task-status`, `/task-add`, `/task-next`, `/task-refine`, `/task-plan`, `/task-triage`,
  `/task-autopilot`. Decisions live in `docs/decisions/`, not in issues.

<!-- gh-task:end -->

## Suggested workflow loop

For any non-trivial change, follow this loop (skills are Claude Code superpowers skills):

1. **Brainstorm** the design — `superpowers:brainstorming` (→ spec in `docs/superpowers/specs/`).
2. **Plan** — `superpowers:writing-plans` (→ plan in `docs/superpowers/plans/`).
3. **Implement test-first** — `superpowers:test-driven-development`.
4. **Debug systematically** when something breaks — `superpowers:systematic-debugging`.
5. **Self-review** before claiming done — `superpowers:verification-before-completion` (run the actual commands).
6. **Request review** — `superpowers:requesting-code-review` and/or `/code-review`.
7. **Commit & PR** — `commit-commands:commit-push-pr` (Conventional Commits).
8. **Record decisions** worth keeping in `docs/decisions/` (ADRs).
   Track follow-up work with `gh task create`, never in TODO comments or a todo file.

## Tooling (skills / plugins to reach for)

- `context7` for current library docs.
- Always available: `superpowers:*`, `commit-commands:*`, `code-review`, `pr-review-toolkit:*`.

## Learned User Preferences

_Append durable preferences the user expresses (one bullet each, with the why).
These persist across sessions and apply to how you work in this repo._

<!-- e.g. - Prefer X over Y because … -->

## Learned Workspace Facts

_Append durable, non-obvious facts about this codebase (architecture, gotchas,
env quirks) as you discover them. Verify a fact still holds before relying on it._

- AVFoundation never frees an `AVCaptureSession` that has run, even after `stopRunning()`, removing its input and output, and draining an autorelease pool. Create one session per process and start and stop it per sample. A session per sample grew to 74 GB in 12 days (verified 2026-10-26 on macOS 15).
- The camera grant follows the binary's code signature, so each rebuilt binary may raise a new Camera prompt the first time it runs.

<!-- e.g. - The build fails if DB is unreachable because … -->
