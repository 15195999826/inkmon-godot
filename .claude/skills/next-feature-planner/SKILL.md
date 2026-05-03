---
name: next-feature-planner
description: Use when the user invokes /next-feature-planner or wants to choose the next feature, create or update .feature-dev/ docs, define acceptance criteria, update Progress/task-plan docs, and prepare a follow-up development prompt. This skill is for planning and documentation before implementation, not for doing the feature work.
---

# Next Feature Planner

Turn a loose next-feature conversation into a ready-to-execute `.feature-dev/` checkpoint.

Output = documented feature target + agreed acceptance criteria. Next conversation starts with `/autonomous-feature-runner`.

## Scope

- Work in current project root. Create `.feature-dev/` if missing.
- Default to Chinese explanations and Chinese docs.
- Do not implement product code unless user explicitly pivots.
- Do not commit / push / open PR unless user asks.
- Preserve unrelated dirty worktree changes.

## Required Reads (token-conscious)

Run `git status -sb` first. Then read by tier — **do not read everything up front**.

**Tier 1 — always read** (启动必读, ~3 files):

1. `.feature-dev/README.md` — index / file roles
2. `.feature-dev/Next-Steps.md` — execution cursor (current goal / 下一步 / 验收准则)
3. `.feature-dev/task-plan/README.md` — current active plan or waiting/index page

**Tier 2 — read on trigger** (按需读, do NOT read unless triggered):

| File | Read when |
|---|---|
| `.feature-dev/Current-State.md` | 用户提到上次 baseline / Next-Steps 与代码现状疑似冲突 / 准备写新 feature 的 baseline 章节 |
| `.feature-dev/Progress.md` | 用户问"上次做到哪" / 准备复用上次的 evidence / Next-Steps 不清晰需要交叉对照 |
| `.feature-dev/Autonomous-Work-Protocol.md` | 仅在准备讨论 commit 策略 / phase-close 流程 / 项目特有约束时读;planner 阶段通常**不需要** |
| `.feature-dev/archive/README.md` | 仅在准备新建 archive 入口 / 用户问归档规则时读;planner 阶段通常**不需要** |
| `.feature-dev/archive/<slug>/Summary.md` | 仅在新 feature 显式继承前一 sub-feature 的 baseline 时读对应那一份 |
| `.feature-dev/task-plan/<feature>/phase-X.md` | 仅在该 phase 即将启动 / 用户要修改其 AC 时读 |

冲突优先级:newest explicit user instruction > `Next-Steps.md` > `Progress.md` > `Current-State.md`. Report conflict before editing.

If `Next-Steps.md` says previous feature completed, check `archive/` for matching entry. If missing, create archive **before** overwriting current planning docs; copy the complete `task-plan/` tree into archive entry before replacing the root task plan.

If `Next-Steps.md` is in waiting state, `task-plan/README.md` must NOT still claim an older active feature. Normalize to waiting/index state before planning the next.

## Workflow

### 1. Clarify the next feature

If clear from user or `Next-Steps.md`, summarize in one paragraph; ask only if scope is ambiguous.

If unclear, discuss focused:
- What feature next? Workflow / capability changed?
- Non-goals (do not pull in)?
- Avoid re-opening old completed milestones unless user wants.

After feature confirmed, update `.feature-dev/`:
- `Next-Steps.md`: current goal / next executable step = "define acceptance criteria"
- `Progress.md`: task name / status=planned / initial checklist (keep terse — full AC checklist comes after step 3)
- `task-plan/README.md`: replace stale active plan with new title + phases + non-goals + links to archived baselines
- `task-plan/<feature>/` phase docs only if feature is large (see step 3 doc structure)
- `Current-State.md` only if active checkpoint or baseline facts changed
- Do NOT delete previous feature records until archived under `archive/`

### 2. Define acceptance criteria with user

Discuss "what proves this is really done" before implementation.

Cover when relevant: functional behavior / regression coverage / evidence (test commands, smoke, browser ops, manifest paths) / user simulation / stop condition (exact `Next-Steps.md` wording = feature accepted).

Propose small practical set, let user tighten. Don't invent heavy criteria by default.

### 3. Write the agreed acceptance contract

After AC confirmed:

- `Next-Steps.md`
  - Add/refresh `## 验收准则`
  - `## 下一步` = next executable action (not history)
  - `## 非下一步` tight
- `Progress.md`
  - Checklist mirrors AC
  - Evidence placeholders for commands / browser runs / room-session ids / manifests / reports / residual risks
- `task-plan/README.md`
  - Phase list + `## 收口条件`
  - Split phase docs only when work is too large for single plan

#### Phase doc structure (token-conscious, mandatory)

When you split into `task-plan/<feature>/phase-X.md`, the phase doc MUST be lean:

**Required in `phase-X.md` (≤ 2K char target):**
- Scope (1-2 sentences)
- AC list (numbered, one line each + measurable evidence path)
- Invariants this phase must NOT break (validation suite baseline numbers / replay bit-identical / etc)
- Sub-task checklist (X.1, X.2, ...)

**Optional in `phase-X.design.md` (separate file, not loaded by runner):**
- Design rationale (why this approach)
- Option comparisons (A vs B, decision来源)
- User Q&A excerpts (AskUserQuestion 答复)
- Implementation hints / API exploration notes

`autonomous-feature-runner` reads `phase-X.md` only. `.design.md` is for planner / human reference. If you don't need design notes, don't create `.design.md`.

When the feature target changes, sweep `AGENTS.md`, `CLAUDE.md`, `README.md`, project doc indexes only if their active-checkpoint wording would become misleading.

### 4. Prepare the development handoff

Concise handoff prompt the user pastes into a new conversation. MUST invoke `/autonomous-feature-runner`:

```text
使用 /autonomous-feature-runner，根据 .feature-dev/Next-Steps.md 开发新 feature。
先读 .feature-dev/README.md、.feature-dev/Next-Steps.md、.feature-dev/task-plan/README.md（Tier 1 必读）。
其余文件按 skill 的 Tier 2 触发条件按需读。
确认 Next-Steps 已有当前目标和验收准则；按当前目标、非目标和验收准则推进。
每完成一步，更新 Next-Steps 的"下一步"和 Progress 的 evidence；持续执行直到达到系统功能验收，并按 archive 规则归档（包含 Progress / Current-State 清场）后，把 Next-Steps 改为等待用户确认下一个 feature。
```

Summarize changed files; call out implementation has not started.

## Editing Rules

- Use Edit/Write tools.
- `Next-Steps.md` = execution cursor.
- `Progress.md` = current feature evidence + status. **At feature archive time it gets reset to a waiting template** (see autonomous-feature-runner archive step).
- `Current-State.md` = current baseline facts only — capability bullets + test-baseline table + cross-feature constraints. **Phase implementation details belong in archive, NOT here.**
- `task-plan/README.md` aligned with `Next-Steps.md`: either active plan or waiting/index, never stale active.
- `task-plan/<feature>/phase-X.md` ≤ 2K char (AC + invariants + checklist). Design notes go to `phase-X.design.md`.
- `reference/` for stable protocols / architecture, not active task progress.
- Future v2/v3 ideas → `docs/future/` only if user asks to preserve.

## Done Criteria For This Skill

- Next feature confirmed.
- `Next-Steps.md` names current goal + next executable action.
- AC documented.
- `Progress.md` and `task-plan/` have matching checklist / evidence / phase structure.
- Phase docs (if any) are lean per the structure above.
- No root `task-plan/README.md` content still names a previous completed feature as active.
- User has ready-to-paste prompt invoking `/autonomous-feature-runner`.
