---
name: autonomous-feature-runner
description: Use when the user invokes /autonomous-feature-runner or asks to start automated feature development from .feature-dev/Next-Steps.md. This skill reads .feature-dev docs, verifies goal and acceptance criteria exist, implements continuously, updates Next-Steps and Progress after each step, commits completed phases per project protocol, and stops only when acceptance is met or a blocker requires user input.
---

# Autonomous Feature Runner

Execution phase after `/next-feature-planner` has prepared `.feature-dev/`.

Develop from documented goal + AC, keep docs current after each step, continue until AC contract satisfied.

## 宪法 (核心原则,违反需用户显式 override)

> **Override 定义**:仅当**当前对话里** user 明确说"这次允许违反宪法 #N / 这次跳过 #N"才算。历史 session 的允许、Progress.md 里的旧 override 记录、user 的隐含暗示都**不算**。无 override 时违反任一条 = stop-and-ask。

1. **Phase 复杂时主动拆分** — 触发条件按**耦合度**判,不按行数:phase 内子任务有 ≥2 个**互相不阻塞** 且 **AC 可独立验收** 的工作单元(例如:算法实现 + 算法回归测试 + UI 布线,三者独立)→ 拆 phase-X.a / phase-X.b / phase-X.c,各自独立 AC + 各自 phase-close gate。**不**触发条件:phase 涉及很多文件但子任务强耦合(改一个 class 顺带改 3 个 caller),保留单 phase。拆分时同步更新 `Next-Steps.md` 的"下一步"指到第一个子 phase,并在 `task-plan/<feature>/README.md` 里加 phase 拆分记录。不为了"不切分"硬塞耦合度差的子任务,也不为了"看起来 phase 多"切碎强耦合工作。
2. **测试失败深入根因,不绕过** — smoke / unit FAIL / TIMEOUT → 直接读 log → 找 SCRIPT ERROR / await 链断点 / assertion 实际值 → 复现 → 定位 → 修真因。**1 轮 deep-dive 定义** = 一次"读 log → 形成 hypothesis → 验证(改代码 / 加 print / 缩 repro)→ 拿到结论(确认/排除 hypothesis)";最多 3 轮无结论才升级 user(写明已尝试什么、log 实际报什么、卡在哪一层)。**禁止逃避手段**:disable / skip / xfail 测试、降阈值掩盖、注释 failing assertion、询问用户"要不要深入分析"(默认就深入,不问)。**baseline 更新边界**:可以接受新 baseline 字节,**前提是 runner 能用 1 句话说清字节差来源**(例:"M5 LongPath 改 A* 算法 → trace events 97→125 / CSV 829520→968343,字节增加来自路径长度多 17%")。**说不清来源就不接受**——是 unintended drift,要走 deep-dive。
3. **Doc token budget 硬约束** — Progress.md 中期 ≤ 80 行 / 末态 reset ≤ 15 行;Current-State.md ≤ 120 行;Next-Steps.md ≤ 40 行。**Active docs 只承载下个 runner / planner 必须的事实**,不承载历史 / 过程 / 决策 rationale / 期间踩坑——这些迁 `archive/<entry>/Summary.md`。超 budget = 信号"该归档/该 prune 了",立即处理。

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

**Tier 1 — always read on start** (启动必读, 2 files):

1. `.feature-dev/Next-Steps.md` — current goal / 下一步 / 验收准则
2. `.feature-dev/Progress.md` — current feature checklist / evidence / residual risks

**Tier 2 — read on trigger** (按需读):

| File | Read when |
|---|---|
| `.feature-dev/README.md` | 首次接触本项目 `.feature-dev/` 结构 / 不确定哪份文档负责哪件事 / Tier 1 + 下面的文件读完仍不知道下一步去哪 |
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

   **7a. Simplify pass** — 用 Skill tool 调 `simplify` skill(skill name = "simplify",`Skill` 工具 `skill` 字段填 "simplify"),scope arg 给本 phase 改的文件列表(`git diff --name-only HEAD` 拿不准就用这个)。simplify 可以删 dead code、合并重复、去掉过早抽象、按清晰度重命名。

   **7b. If simplify modified any code, re-run full Validation Standard (§ below)** — same suite that proved phase passed AC. Mandatory; simplify can introduce regressions. Phase not closed until suite green again. Do not commit between simplify and re-validation.

   **7c. Doc-consistency review** — re-read the phase's `task-plan/<feature>/phase-X.md` §AC and walk each AC item against actual code:
   - For every AC, locate implementation (file:line) that satisfies it; record any AC where implementation drifted from documented contract (signature, return shape, behavior).
   - Code right but doc stale → update task-plan / Current-State / Progress entry to match reality.
   - Doc right but code drifted → fix code (re-run validation per 7b).
   - Both right but `Progress.md` evidence references stale path / number → refresh evidence.
   - Output: "all AC contracts and docs aligned" or punch list of fixes that must land before commit.

   **7d. Doc prune (token budget enforcement,§宪法 #3)** — phase 完成 commit 前 prune active docs:
   - `Progress.md` 收紧:删本 phase 期间累积的"量化对比表 / 关键决策 rationale / 期间踩坑提醒 / phase 中期试错记录"。**迁移目的地**:
     - 已存在 `archive/<entry>/Summary.md`(mid-archive 场景)→ 直接 append 到该 Summary 末尾对应 section
     - 还没 archive 入口(常规 phase 收口,等待 feature 全部 AC 才 archive)→ 留在 `Progress.md` 末尾 `<details><summary>期间笔记 (待 §8c 迁 archive)</summary>...</details>` 折叠段;**折叠段内容不计入 80 行 budget**(reader 默认看不见,只在 §8c 时展开剪贴到 Summary.md draft)
   - `Next-Steps.md` 收紧:只留"当前目标 / 下一步具体动作 / 验收准则状态行 / 非目标"。删期间踩坑提醒、详细 demo 复现脚本(留路径,不复制命令全文)。AC evidence 表只留"路径 + 数字",不留 prose 解释段。
   - 验:`Progress.md` 可见内容(去掉 `<details>` 折叠段)≤ 80 行,`Next-Steps.md` ≤ 40 行。超出 = 没 prune 干净。

   **7e. Only after 7a-7d clean** → create phase/local commit (per `Autonomous-Work-Protocol.md`), then continue closeout sweep.

8. **When AC fully met (whole feature, not just phase)** — closeout + archive + clean-slate sweep:

   **8a. Update active docs**(遵守 §宪法 #3 budget):
   - `Current-State.md` 新 baseline:capability bullets 1 行/项 + **test-baseline 行(总数,不列每个 smoke)** 例如 `rts/all 55/55 + LGF 73 + hex/regression PASS,baseline CSV 970512 bytes`+ 跨 feature 不变约束 + decision-source 链接 archive。**禁止**列举每个 smoke 名称、复制 phase 实现细节、抄 spec 决策列表(D1/D2/...)进 active doc——这些都该在 archive Summary.md。Current-State.md ≤ 120 行 hard cap。
   - `Progress.md` 写最终 evidence (右接 §8e reset)。
   - Re-run `git status -sb` so worktree status in docs = final state, not transient mid-run。

   **8b. Sweep entry/reference docs** that should reflect new baseline:
   - `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/README.md`, relevant `docs/reference/*` files.
   - They must not still describe previous checkpoint as current behavior.

   **8c. Create archive entry** under `.feature-dev/archive/<YYYY-MM-DD-feature-slug>/` per `.feature-dev/archive/README.md`:
   - Copy final `Current-State.md` (the new-baseline version), `Next-Steps.md`, `Progress.md`, complete `task-plan/` tree into archive entry **before** replacing root task plan.
   - Do not archive only `task-plan/README.md` — archive the whole tree.
   - Write archive `Summary.md`:feature name、AC conclusion、commands、real-use evidence、important paths、residual risks。**§7d 期间累积的 `<details>期间笔记</details>` 折叠段全部展开剪贴进 `Summary.md` 对应 section**(量化对比表 → §Quantitative;关键决策 → §Decisions;期间踩坑 → §Lessons),剪贴完后从 `Progress.md` 删掉折叠段。

   **8d. Replace root task plan with waiting state**:
   - `task-plan/README.md` → waiting/index page pointing to archive entry; not still claiming completed feature is active.

   **8e. CLEAN-SLATE SWEEP (token-conscious, mandatory)** — archive is now the authoritative copy of feature history. Reset active docs:
   - `Progress.md` → reset to waiting template (≤ 15 lines): `## Progress` heading + `Status: 无 active feature` + 1 line linking to last archive entry. Drop all phase AC checklists / evidence / sub-task progress from previous feature.
   - `Current-State.md` → keep only baseline-relevant content (capability bullets, test-baseline table, key cross-feature constraints, Git status, decision-source links to archive). Drop per-phase implementation detail of the just-archived feature; if reader needs phase detail they read archive `Summary.md`.
   - `Next-Steps.md` → "已完成系统功能验收，接下来等待用户确认下一个 feature 开发" or equivalent (≤ 40 行)。
   - Verify (硬性):`Progress.md` ≤ 15 行 + `Current-State.md` ≤ 120 行 + `Next-Steps.md` ≤ 40 行。超出 = 复制了 phase 详情进 active doc,违 §宪法 #3,迁回 archive Summary.md。

## When To Stop And Ask

Stop before continuing if:
- AC missing or contradictory.
- Next step would expand beyond documented non-goals.
- Verification needs credentials / production systems / user-visible browsers user has not allowed.
- Worktree has unrelated changes in files you must edit and merge boundary unclear.
- Blocker changes intended feature contract.
- **测试连续 3 轮 deep-dive 仍无结论**(§宪法 #2)— 写明已尝试什么、log 实际报什么、卡在哪一层,再问 user。一次 fail 直接深入,不问。

## Validation Standard

Don't treat compile success as feature acceptance unless AC says so.

Prefer evidence in this order when relevant:
- unit/typecheck for local contracts;
- fake-runtime smoke for workflow behavior;
- real runtime pilot for CLI / agent orchestration;
- built-in browser operation for user-facing workflows;
- manifest / report / artifact paths for durable evidence;
- final docs consistency sweep for entry docs, reference docs, archive snapshot, `git status -sb` facts.

### How to actually run smoke (inkmon-godot)

**默认走 `tools/run_tests.ps1`** — 项目自带的并行 runner,读 `addons/logic-game-framework/{tests,example/*/tests}/test_groups.json` manifests, 5x 并行 + 自动 PASS/FAIL/TIMEOUT 收集 + 失败时 dump 末 30 行 log。**不要再手工串行 godot --headless 一条条跑**(每条独立 Bash 一个 tool call,十几条 = 浪费 token + 慢 5x)。

| 场景 | 命令 |
|---|---|
| Stop-runner 核心(LGF + rts/regression + skill scenarios + frontend), phase-close gate 默认 | `.\tools\run_tests.ps1 -Required` (~8s) |
| 单 namespace 全套(rts 所有 group:regression / pathfinding / obstruction / combat / economy / command / flying / replay / ui / frontend) | `.\tools\run_tests.ps1 rts/all` (~30s) |
| 自定义子集(只 pathfinding 相关改动) | `.\tools\run_tests.ps1 rts/pathfinding rts/replay core/unit` |
| 看可用 group 列表 | `.\tools\run_tests.ps1 -List` |

PowerShell 工具调用范例(避免 cwd 漂):
```
PowerShell: Set-Location D:\GodotProjects\inkmon\inkmon-godot; & .\tools\run_tests.ps1 -Required 2>&1 | Select-Object -Last 40
```

写新 smoke 时把 `.tscn` 加进对应 manifest(`example/<example>/tests/test_groups.json` 的合适 group),回归路径就自动被 `-Required` / `<ns>/all` 覆盖。新 smoke 锁定的是 stop-runner 触发条件之一时(replay / baseline / determinism / 关键玩法路径)写进 `regression` (required);否则按主题进 pathfinding / combat / economy 等。

baseline CSV byte-identical 验证 runner 不替你做(它只跑 smoke 不 cmp 文件),仍需手工 `cmp` 比对 `tests/baselines/0ad-baseline-master.csv`。

**例外**:当用户要你 reproduce 一个 mock-only 的特定场景(例如临时写一份 `.claude/tmp/repro_*.gd` 测某个变量切换),那条仍单独 `godot --headless` 跑,**不**进 manifest;只有作为"永久回归"留下来的 smoke 才进 manifest。

## Done Criteria For This Skill

Done when EITHER:
- AC met, phase-close gate (§7a-7c: simplify → re-validate → AC-doc consistency review) clean, completed phase/task has local commit when project protocol requires, entry/reference docs no longer describe previous checkpoint as current behavior, archive entry exists, **clean-slate sweep §8e completed (`Progress.md` + `Current-State.md` reset to baseline-only state)**, `Next-Steps.md` updated to waiting-for-next-feature, root `task-plan/README.md` no longer a stale active plan;
- OR documented blocker written to `Progress.md` and user asked for specific decision.

A phase commit without §7a-7d does not count as done — simplify、AC-doc consistency、doc prune 都是 commit blockers,不是可选 polish。
A feature archive without §8e clean-slate sweep does not count as done — leaving phase detail in `Progress.md` / `Current-State.md` after archive defeats the whole purpose (next feature's planner/runner has to read 14K char of stale history)。
违反 §宪法 #1 (硬塞复杂 phase) / #2 (绕过 / disable 失败测试) / #3 (active doc 超 budget) 任一条 = 本 skill 未完成,即使 AC 字面打勾。
