# Progress

## Current State

- Status: active
- Branch: `master`(用户选定,不另起分支)
- Goal-start ref: **L2 worldhost-tick refactor baseline commit**(含本 goal 文档 + `CONTEXT.md` 三层+Host/Command·Query/World Actor 三术语 + `docs/L2-ARCHITECTURE.md §0.5` 设计真相)。`/goal` 首轮用 `git rev-parse HEAD` 把确切 sha 记到本行。
- 设计真相:`docs/L2-ARCHITECTURE.md §0.5`(+ §1-§8);术语 `CONTEXT.md`(World Actor 层级 / 主世界 Command·Query / 主世界三层+Host)。

## 基线说明

baseline commit 含:`CONTEXT.md`(新增 World Actor 层级 / 主世界 Command·Query / 主世界三层+Host 三术语 + 两条「待重命名」)、`docs/L2-ARCHITECTURE.md`(新增 §0.5 三层图+运行模型,§1①/§4 反转标记)、本 `.codex-goal/l2-worldhost-tick-refactor/{Goal,Progress}.md`。
未纳入 baseline:`addons/` 子模块(Non-Goal 不动)。

## Phase Decisions

- (每相位开工前一行:`Phase <N> decisions: TDD=<yes/no,reason>; smoke-test=<yes/no,reason>`)
- 预判(开工时正式确认并覆写):
  - P1/P2(改名+层级)= TDD no(机械重构,既有 smoke 是回归网); smoke yes(全 inkmon 组回归)
  - P3(搬家)= TDD no(行为不变); smoke yes(回归)
  - **P4(tick+command 核心)= TDD yes**(逐格推进/确定性/重算可断言); smoke yes(重写 overworld-3d + app-root 移动 + 新 tick smoke)
  - P5/P6(内移)= TDD no; smoke yes(回归)
  - **P7(lifecycle)= TDD yes**(capture/hydrate 往返 + 不双写可断言); smoke yes
  - P8(表演抽离)= TDD no; smoke yes(UI 回归)
  - P9(文档蒸馏)= TDD no; smoke no(纯文档,grep 验过渡语清零)

## Checkpoints

- (每相位:`<date> - phase <N> - commit <short-sha> - review: <pass/N findings fixed> - smoke: <pass/skipped:reason>`)

## Open Review Findings

- None

## Consistency Review

- (末尾填)

## Blockers

- None
