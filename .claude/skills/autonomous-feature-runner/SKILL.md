---
name: autonomous-feature-runner
description: Use when the user invokes /autonomous-feature-runner or asks to start automated feature development from .feature-dev/Next-Steps.md. This skill reads .feature-dev docs, verifies goal and acceptance criteria exist, implements continuously, updates Next-Steps and Progress after each step, and stops only when acceptance is met or a blocker requires user input.
---

# Autonomous Feature Runner

Use this skill for the execution phase after `/next-feature-planner` has prepared `.feature-dev/`.

The job is to develop from the documented goal and acceptance criteria, keep the docs current after each step, and continue until the acceptance contract is satisfied.

## Scope

- Work in the current project root.
- Do not start if `.feature-dev/Next-Steps.md` has no current goal or no acceptance criteria.
- Do not renegotiate the feature unless the documented goal is impossible or conflicts with the newest user instruction.
- Preserve unrelated dirty worktree changes.
- Do not commit, push, or create a PR unless the user explicitly asks.

## Required Reads

Start with `git status -sb`, then read:

1. `.feature-dev/README.md`
2. `.feature-dev/Current-State.md`
3. `.feature-dev/Next-Steps.md`
4. `.feature-dev/Progress.md`
5. `.feature-dev/task-plan/README.md`
6. `.feature-dev/Autonomous-Work-Protocol.md`

If `.feature-dev/` is missing, stop and ask the user to run `/next-feature-planner` first, unless the user explicitly asks this skill to create the baseline docs.

## Execution Loop

1. Confirm the current goal, non-goals, acceptance criteria, and current `Next-Steps.md` action.
2. Implement the next documented step.
3. Run the narrowest meaningful verification for that step.
4. Update `.feature-dev/Progress.md` with checklist status, commands, evidence paths, session ids, or residual risks.
5. Update `.feature-dev/Next-Steps.md` so `## 下一步` points to the next executable action.
6. Continue to the next step in the same turn when feasible.
7. **Phase-close gate (BEFORE commit)** — when all phase AC are PASS and code-side work is done, run the two-step refinement loop **before** updating Current-State / writing closeout docs / committing:

   **7a. Simplify pass** — invoke `/simplify` (the simplify skill) on the changed code. Scope = files touched in this phase (run `git diff --name-only HEAD` if unsure). The simplify pass may delete dead code, collapse duplication, remove premature abstractions, or rename for clarity.

   **7b. If simplify modified any code, re-run the full Validation Standard (§ below)** — the same suite that proved the phase passed AC. This is mandatory; simplify can introduce regressions and the phase is not closed until the suite is green again. Do not commit between simplify and re-validation.

   **7c. Doc-consistency review** — re-read the phase's task-plan AC document (e.g. `task-plan/<feature>/phase-X.md` §Acceptance) and walk each AC item against the actual code:
   - For every AC, locate the implementation (file:line) that satisfies it; record any AC where the implementation drifted from the documented contract (signature, return shape, behavior).
   - If code is right but the doc is stale → update the task-plan / Current-State / Progress entry to match reality.
   - If doc is right but code drifted → fix the code (and re-run validation again per 7b).
   - If both are right but evidence in `Progress.md` references a stale path / number → refresh evidence.
   - The output of this review is either "all AC contracts and docs aligned" or a punch list of fixes that must land before commit.

   **7d. Only after 7a-7c are clean** → proceed to commit (per `Autonomous-Work-Protocol.md` commit strategy) and the closeout sweep below.

8. When acceptance criteria are fully met (the **whole feature**, not just a phase), update:
   - `.feature-dev/Current-State.md` with new facts;
   - `.feature-dev/Progress.md` with final evidence;
   - re-run `git status -sb` and ensure any worktree status written into docs reflects the final closeout state, not a transient mid-run state;
   - sweep the entry/reference docs that should reflect the new baseline, at minimum `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/README.md`, and any relevant `docs/reference/*` files, so they do not still describe the previous checkpoint as current behavior;
   - create `.feature-dev/archive/<YYYY-MM-DD-feature-slug>/` following `.feature-dev/archive/README.md`;
   - copy final `Current-State.md`, `Next-Steps.md`, `Progress.md`, and `task-plan/` into that archive entry;
   - write archive `Summary.md` with feature name, acceptance conclusion, commands, real-use evidence, important paths, and residual risks;
   - update `.feature-dev/Next-Steps.md` to "已完成系统功能验收，接下来等待用户确认下一个 feature 开发" or equivalent wording.

## When To Stop And Ask

Stop before continuing if:

- Acceptance criteria are missing or contradictory.
- The next step would expand beyond documented non-goals.
- Verification requires credentials, production systems, or user-visible browsers that the user has not allowed.
- The worktree has unrelated changes in files you must edit and the merge boundary is unclear.
- A blocker changes the intended feature contract.

## Validation Standard

Do not treat compile success as feature acceptance unless the acceptance criteria say so.

Prefer evidence in this order when relevant:

- unit/typecheck for local contracts;
- fake-runtime smoke for workflow behavior;
- real runtime pilot for CLI / agent orchestration;
- built-in browser operation for user-facing workflows;
- manifest / report / artifact paths for durable evidence;
- final docs consistency sweep for entry docs, reference docs, archive snapshot, and `git status -sb` facts.

## Done Criteria For This Skill

The skill is done when either:

- acceptance criteria are met, the phase-close gate (§7a-7c: simplify → re-validate → AC-doc consistency review) is clean, entry/reference docs no longer describe the previous checkpoint as current behavior, an archive entry exists under `.feature-dev/archive/`, and `.feature-dev/Next-Steps.md` is updated to the final waiting-for-next-feature state; or
- a documented blocker is written to `.feature-dev/Progress.md` and the user is asked for a specific decision.

A phase commit without §7a-7c does not count as done — simplify and AC-doc consistency are commit blockers, not optional polish.
