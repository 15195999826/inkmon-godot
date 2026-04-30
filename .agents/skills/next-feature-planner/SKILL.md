---
name: next-feature-planner
description: Use when the user invokes /next-feature-planner or wants to choose the next feature, create or update .feature-dev/ docs, define acceptance criteria, update Progress/task-plan docs, and prepare a follow-up development prompt. This skill is for planning and documentation before implementation, not for doing the feature work.
---

# Next Feature Planner

Use this project-local skill to turn a loose next-feature conversation into a ready-to-execute `.feature-dev/` checkpoint.

The output of this skill is a documented feature target plus agreed acceptance criteria. The next conversation should be able to start by invoking `/autonomous-feature-runner` against `.feature-dev/Next-Steps.md`.

## Scope

- Work in the current project root. If `.feature-dev/` is missing, create it with the standard files before continuing.
- Default to Chinese explanations and Chinese docs.
- Do not implement product code while using this skill unless the user explicitly pivots from planning to implementation.
- Do not commit, push, or create a PR unless the user explicitly asks.
- Preserve unrelated dirty worktree changes.

## Required Reads

Before discussing or editing, run `git status -sb`, then read or create:

1. `.feature-dev/README.md`
2. `.feature-dev/Current-State.md`
3. `.feature-dev/Next-Steps.md`
4. `.feature-dev/Progress.md`
5. `.feature-dev/task-plan/README.md`
6. `.feature-dev/Autonomous-Work-Protocol.md`
7. `.feature-dev/archive/README.md`

If these files conflict, prefer newest explicit user instruction, then `Next-Steps.md`, then `Progress.md`, then `Current-State.md`. Report the conflict briefly before editing.

If `Next-Steps.md` already says the previous feature completed system functional acceptance, check `.feature-dev/archive/` for a matching archive entry. If it is missing, create the archive before overwriting current planning docs for the next feature.

## Workflow

### 1. Clarify the next feature

If the next feature is already clear from the user or `Next-Steps.md`, summarize it in one short paragraph and ask for confirmation only if the scope is ambiguous or risky.

If no feature is clear, discuss with the user. Keep this focused:

- Ask what feature they want next.
- Identify the user-facing workflow or backend capability it changes.
- Name non-goals that should not be pulled into this checkpoint.
- Avoid re-opening old completed milestones unless the user explicitly wants that.

After the feature is confirmed, update `.feature-dev/` docs before discussing acceptance:

- `.feature-dev/Next-Steps.md`: current goal, short goal description, immediate next step = define acceptance criteria.
- `.feature-dev/Progress.md`: task name, status = planned / acceptance criteria pending, initial checklist.
- `.feature-dev/task-plan/README.md`: task title, high-level phases, non-goals.
- Phase docs under `.feature-dev/task-plan/` only if the feature is large enough to need staged execution.
- `.feature-dev/Current-State.md` only if the active checkpoint or baseline facts changed.
- Do not delete previous feature records until they are archived under `.feature-dev/archive/`.

### 2. Define acceptance criteria with the user

Discuss "what proves this is really done" before implementation starts.

Cover these categories when relevant:

- Functional behavior: what new mode, route, workflow, UI path, or contract must work.
- Regression coverage: what old mode or baseline must still work.
- Evidence: test commands, fake-runtime smoke, real runtime pilot, browser operation, manifest/report paths, room/session ids.
- User simulation: whether the AI must use the built-in browser and a test project.
- Stop condition: what exact `Next-Steps.md` wording means the feature is fully accepted.

Do not invent heavy acceptance criteria by default. Propose a small practical set, then let the user tighten it.

### 3. Write the agreed acceptance contract

After acceptance criteria are confirmed, update:

- `.feature-dev/Next-Steps.md`
  - Add or refresh `## 验收准则`.
  - Keep `## 下一步` as the next executable action, not a history log.
  - Keep `## 非下一步` tight.
- `.feature-dev/Progress.md`
  - Add checklist items that mirror the acceptance criteria.
  - Add evidence placeholders for commands, browser runs, room/session ids, manifests, reports, and known residual risks.
- `.feature-dev/task-plan/README.md`
  - Add or refresh phase list and `## 收口条件`.
  - Split phase docs only when the work is too large for a single plan.

When the feature target changes, also sweep `AGENTS.md`, `CLAUDE.md`, `README.md`, and project docs indexes only if their active-checkpoint wording would become misleading.

### 4. Prepare the development handoff

End with a concise handoff prompt the user can paste into a new conversation. The prompt must explicitly invoke `/autonomous-feature-runner`; do not end with a generic "start developing from Next-Steps" prompt.

```text
使用 /autonomous-feature-runner，根据 .feature-dev/Next-Steps.md 开发新 feature。
先读 .feature-dev/Current-State.md、.feature-dev/Next-Steps.md、.feature-dev/Progress.md、.feature-dev/task-plan/ 和 .feature-dev/Autonomous-Work-Protocol.md。
确认 Next-Steps 已有当前目标和验收准则；按当前目标、非目标和验收准则推进。
每完成一步，更新 Next-Steps 的"下一步"和 Progress 的 evidence；持续执行直到达到系统功能验收，并按 archive 规则归档后，把 Next-Steps 改为等待用户确认下一个 feature。
```

Also summarize changed files and call out that implementation has not started.

## Editing Rules

- Use the Edit/Write tools for manual edits.
- Keep `.feature-dev/Next-Steps.md` as the execution cursor.
- Keep `.feature-dev/Progress.md` as evidence and status.
- Keep `.feature-dev/Current-State.md` as current facts only.
- Keep `reference/` for stable protocols and architecture, not active task progress.
- Do not put future v2/v3 ideas into current task docs; put them in `docs/future/` only if the user asks to preserve them.

## Done Criteria For This Skill

The skill is done when:

- The next feature is confirmed.
- `.feature-dev/Next-Steps.md` names the current goal and next executable action.
- Acceptance criteria are documented.
- `Progress.md` and `task-plan/` have matching checklist/evidence/phase structure.
- The user has a ready-to-paste prompt for the next development conversation, and that prompt invokes `/autonomous-feature-runner`.
