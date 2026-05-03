---
name: autonomous-feature-runner
description: Use when the user invokes /autonomous-feature-runner or asks to start automated feature development from .feature-dev/Next-Steps.md. This skill reads .feature-dev docs, verifies goal and acceptance criteria exist, implements continuously, updates Next-Steps and Progress after each step, commits completed phases per project protocol, and stops only when acceptance is met or a blocker requires user input.
---

# Autonomous Feature Runner

Execution phase after `/next-feature-planner` has prepared `.feature-dev/`.

Develop from documented goal + AC, keep docs current after each step, continue until AC contract satisfied.

## Scope

- Work in current project root.
- Do not start if `Next-Steps.md` has no current goal or no AC.
- Do not renegotiate feature unless documented goal is impossible / conflicts with newest user instruction.
- Preserve unrelated dirty worktree changes.
- Do not push / open PR unless user asks.
- Local commit after each completed phase or independent task once phase-close gate is clean and verification passed, per `Autonomous-Work-Protocol.md`.
- If `Autonomous-Work-Protocol.md` has no project-specific commit policy, do not commit unless user asks.

## Required Reads (token-conscious)

Run `git status -sb` first. Read by tier — **do not read everything up front**.

**Tier 1 — always read on start** (启动必读, ~3 files):

1. `.feature-dev/README.md` — index / file roles
2. `.feature-dev/Next-Steps.md` — current goal / 下一步 / 验收准则
3. `.feature-dev/Progress.md` — current feature checklist / evidence / residual risks

**Tier 2 — read on trigger** (按需读):

| File | Read when |
|---|---|
| `.feature-dev/Current-State.md` | Tier 1 不足以判断 baseline / Next-Steps 与代码现状疑似冲突 / 准备 sweep entry-doc 时核对当前 baseline |
| `.feature-dev/task-plan/README.md` | 准备启动新 phase / 需要 phase 列表 / 需要"收口条件"原文 |
| `.feature-dev/task-plan/<feature>/phase-X.md` | **每次进入新 phase 时读这一份**(只读这一份,不读全部 phase docs) |
| `.feature-dev/task-plan/<feature>/phase-X.design.md` | **不读**(planner 阶段的设计附录,runner 不需要);仅当 phase-X.md 的 AC 与代码冲突且 phase-X.md 没说清来源时才读 |
| `.feature-dev/Autonomous-Work-Protocol.md` | 准备 commit / 进入 phase-close gate / 跑 validation suite 前需要确认顺序 |
| `.feature-dev/archive/README.md` | 准备新建 archive 入口时(全 feature AC 都过、收口阶段) |

If `.feature-dev/` is missing, stop and ask user to run `/next-feature-planner` first, unless user explicitly asks to create baseline docs.

Conflict priority: newest explicit user instruction > `Next-Steps.md` > `Progress.md` > `Current-State.md`. Stop and report if next executable step unclear.

## Execution Loop

1. Confirm current goal, non-goals, AC, and `Next-Steps.md` 下一步.
2. Implement next documented step.
3. Run narrowest meaningful verification.
4. Update `Progress.md`: checklist status, commands, evidence paths, session ids, residual risks.
5. Update `Next-Steps.md` so `## 下一步` points to next executable action.
6. Continue to next step in same turn when feasible.
7. **Phase-close gate (BEFORE commit)** — when all phase AC are PASS and code-side work done, run two-step refinement loop **before** updating Current-State / writing closeout docs / committing:

   **7a. Simplify pass** — invoke `/simplify` on changed code. Scope = files touched in this phase (`git diff --name-only HEAD` if unsure). May delete dead code, collapse duplication, remove premature abstractions, rename for clarity.

   **7b. If simplify modified any code, re-run full Validation Standard (§ below)** — same suite that proved phase passed AC. Mandatory; simplify can introduce regressions. Phase not closed until suite green again. Do not commit between simplify and re-validation.

   **7c. Doc-consistency review** — re-read the phase's `task-plan/<feature>/phase-X.md` §AC and walk each AC item against actual code:
   - For every AC, locate implementation (file:line) that satisfies it; record any AC where implementation drifted from documented contract (signature, return shape, behavior).
   - Code right but doc stale → update task-plan / Current-State / Progress entry to match reality.
   - Doc right but code drifted → fix code (re-run validation per 7b).
   - Both right but `Progress.md` evidence references stale path / number → refresh evidence.
   - Output: "all AC contracts and docs aligned" or punch list of fixes that must land before commit.

   **7d. Only after 7a-7c clean** → create phase/local commit (per `Autonomous-Work-Protocol.md`), then continue closeout sweep.

8. **When AC fully met (whole feature, not just phase)** — closeout + archive + clean-slate sweep:

   **8a. Update active docs**:
   - `Current-State.md` with new baseline facts (capability bullets + test-baseline table + cross-feature constraints only — **phase implementation detail goes to archive, not here**).
   - `Progress.md` with final evidence (right before reset in 8e).
   - Re-run `git status -sb` so any worktree status written into docs reflects final state, not transient mid-run.

   **8b. Sweep entry/reference docs** that should reflect new baseline:
   - `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/README.md`, relevant `docs/reference/*` files.
   - They must not still describe previous checkpoint as current behavior.

   **8c. Create archive entry** under `.feature-dev/archive/<YYYY-MM-DD-feature-slug>/` per `.feature-dev/archive/README.md`:
   - Copy final `Current-State.md` (the new-baseline version), `Next-Steps.md`, `Progress.md`, complete `task-plan/` tree into archive entry **before** replacing root task plan.
   - Do not archive only `task-plan/README.md` — archive the whole tree.
   - Write archive `Summary.md`: feature name, AC conclusion, commands, real-use evidence, important paths, residual risks.

   **8d. Replace root task plan with waiting state**:
   - `task-plan/README.md` → waiting/index page pointing to archive entry; not still claiming completed feature is active.

   **8e. CLEAN-SLATE SWEEP (token-conscious, mandatory)** — archive is now the authoritative copy of feature history. Reset active docs:
   - `Progress.md` → reset to waiting template (≤ 15 lines): `## Progress` heading + `Status: 无 active feature` + 1 line linking to last archive entry. Drop all phase AC checklists / evidence / sub-task progress from previous feature.
   - `Current-State.md` → keep only baseline-relevant content (capability bullets, test-baseline table, key cross-feature constraints, Git status, decision-source links to archive). Drop per-phase implementation detail of the just-archived feature; if reader needs phase detail they read archive `Summary.md`.
   - `Next-Steps.md` → "已完成系统功能验收，接下来等待用户确认下一个 feature 开发" or equivalent.
   - Verify: `Progress.md` and `Current-State.md` post-reset together fit in ~3K char total. If they don't, you copied too much.

## When To Stop And Ask

Stop before continuing if:
- AC missing or contradictory.
- Next step would expand beyond documented non-goals.
- Verification needs credentials / production systems / user-visible browsers user has not allowed.
- Worktree has unrelated changes in files you must edit and merge boundary unclear.
- Blocker changes intended feature contract.

## Validation Standard

Don't treat compile success as feature acceptance unless AC says so.

Prefer evidence in this order when relevant:
- unit/typecheck for local contracts;
- fake-runtime smoke for workflow behavior;
- real runtime pilot for CLI / agent orchestration;
- built-in browser operation for user-facing workflows;
- manifest / report / artifact paths for durable evidence;
- final docs consistency sweep for entry docs, reference docs, archive snapshot, `git status -sb` facts.

## Done Criteria For This Skill

Done when EITHER:
- AC met, phase-close gate (§7a-7c: simplify → re-validate → AC-doc consistency review) clean, completed phase/task has local commit when project protocol requires, entry/reference docs no longer describe previous checkpoint as current behavior, archive entry exists, **clean-slate sweep §8e completed (`Progress.md` + `Current-State.md` reset to baseline-only state)**, `Next-Steps.md` updated to waiting-for-next-feature, root `task-plan/README.md` no longer a stale active plan;
- OR documented blocker written to `Progress.md` and user asked for specific decision.

A phase commit without §7a-7c does not count as done — simplify and AC-doc consistency are commit blockers, not optional polish.
A feature archive without §8e clean-slate sweep does not count as done — leaving phase detail in `Progress.md` / `Current-State.md` after archive defeats the whole purpose (next feature's planner/runner has to read 14K char of stale history).
