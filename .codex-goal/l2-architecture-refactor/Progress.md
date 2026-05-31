# Progress

## Current State

- Status: active
- Branch: l2-architecture-refactor
- Goal-start ref: baseline commit(本分支首个 commit;启动 `/goal` 命令里写死该 sha,`/code-review max` 用 `git diff <goal-start-ref>...HEAD`)
- 设计真相:`docs/L2-ARCHITECTURE.md`(本会话 grill 拍板)

## 基线说明

规划文档放 `.codex-goal/`(本仓约定;`.claude-goal/` 被 .gitignore 排除,本仓用 `.codex-goal/` 且已 track 34 文件)。
baseline commit 含:架构文档(docs/L2-ARCHITECTURE.md + docs/GAME-VISION.md)、CONTEXT.md、L2-M1-BRIEF.md、本会话高优修复(app_root.gd / ink_mon_overworld_view_3d.gd / smoke_overworld_3d.gd / smoke_app_root.gd,已测通过)、本 `.codex-goal/l2-architecture-refactor/` 文档。
**未纳入 baseline**:`addons` 子模块指针漂移(非本次改动,保持不动)、`ink_mon_element_chart.gd` 的 file-mode 噪声(无内容改动)。

## Phase Decisions

- (每相位开工前一行:`Phase <N> decisions: TDD=<yes/no,reason>; smoke-test=<yes/no,reason>`)
- P5/P8 含内嵌小决策:P5 training→战斗的 handler 返回机制;P8 刻印实现框架(LGF 被动 ability vs skill_slot modifier)。均相位开始用 `game-architecture-patterns` skill 决定并记此段。
- Phase 1 decisions: TDD=yes(纯数据模型 + 序列化往返,public 接口可断言,典型 TDD 适用); smoke-test=yes(跑 inkmon/session + inkmon/m1 + inkmon/content + inkmon/app-root —— 删字段牵动这四组)。
  - 实现策略:entry 删 persistent_stats/learned_skill_id/medals,改 skill_slots/engravings,medals 移 PlayerState;`project_to_battle_snapshot` 内部改用派生 stats(`f(species,level)`)+ 从 skill_slots[0] 桥接 learned_skill_id,**保持 snapshot 输出形状不变** → unit_actor/M1 本相位不动(P3 才改形状)。`f(species,level)` v1 = 物种 base(取自 unit config,level-1 等于现状 config 值,不动战斗平衡)× 线性成长。

## Checkpoints

- (每相位:`<date> - phase <N> - commit <short-sha> - review: <pass/N findings fixed> - smoke: <pass/skipped:reason>`)

## Open Review Findings

- None

## Consistency Review

- (结尾填:`<date> - Goal.md vs 实现:<no divergence | resolved items>`)

## Blockers

- None
