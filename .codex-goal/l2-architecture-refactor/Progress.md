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
- Phase 2 decisions: TDD=yes(确定性出生 roll + 进化链 = 纯逻辑,可断言确定性/进化效果); smoke-test=yes(新增 smoke_progression.tscn 挂进 inkmon/session 组留在 gate 内;另跑 m1+content 防回归)。
- Phase 3 decisions: TDD=yes(snapshot 形状 + actor 注入 = 数据契约改动,可断言); smoke-test=yes(inkmon/session[含注入] + m1[unit-key fallback] + app-root[training enemy snapshot])。
  - 实现:snapshot 形状 learned_skill_id(单) → skill_slots(数组,= entry.skill_slots 投影);unit_actor 吸收新形状,primary=slot0 作 active skill(保 M1 单技能平衡不变, 多技能 equip 留 future), 存 skill_slots;保留 _setup_from_unit_config(unit_key) M1 fallback;顺手 equip_abilities 防 primary==basic 重复授予(P2→P3 note)。同步改两个 enemy snapshot builder(app_root + smoke)。
  - 设计:新 main 层内容真相 `InkMonSpeciesCatalog`(scenes/inkmon-main/logic/content/)。baby 物种 base 委托 battle 层 unit_config(单一真相,level-1 平衡不变);进化形态 base = baby base × stat_mult(stub,不手敲数值)。技能池 per-(species,slot);出生每槽确定性 roll(RandomNumberGenerator seeded);进化链表 species→{next,level 阈值};X→X2 = SKILL_EVOLUTIONS 映射(v1 X2 目标用现有真实技能占位,真 X2 ability 随 lab 内容)。`derive_battle_stats` 改走 catalog(覆盖进化形态)。starter roster 仍走 from_unit_config(设计出生,不 roll,保平衡);新增 from_birth 工厂走 roll。

## Checkpoints

- (每相位:`<date> - phase <N> - commit <short-sha> - review: <pass/N findings fixed> - smoke: <pass/skipped:reason>`)
- 2026-05-31 - phase 1 - commit cb71d3f - review: pass(0 high/critical; 1 medium deferred; cleanup low/nit ignored) - smoke: pass(inkmon/session+m1+content+app-root 全 PASS)
- 2026-05-31 - phase 2 - commit 0cccf9a - review: 1 latent fixed(basic_attack 移出技能池) + 2 low deferred - smoke: pass(inkmon/session[含 progression]+app-root+content+m1 全 PASS)

## Open Review Findings

- [P1, medium, deferred] `derive_battle_stats()` 对不在 catalog/`_configs()` 的 species(含 from_dict 缺字段时的空串)走 `Log.assert_crash(false)` 硬崩。P2 后 surface = `InkMonSpeciesCatalog.get_base_stats` → `_species_node`(catalog 是 8 baby + 进化形态的严格超集)。判定延后不阻塞:① 旧 `_normalize_stats({})` 在缺 stats 时同样崩;② v1 所有 roster species 都由 from_unit_config/from_birth/evolve 产生必在 catalog;③ 跨版本改物种属 Non-Goal「不写存档迁移」明确不支持;④ fail-fast 是既定错误模型。
- [P2, low, deferred] 多段进化链 X→X2 二次套用:cinder_kit→cinder_fox→cinder_drake 时,fox 阶段 slot1 若 roll 到 fireball,会在 drake 进化时再被 SKILL_EVOLUTIONS 升级成 chain_lightning。非崩溃、chain_lightning 在合法池内、语义可辩(进一步进化技能再强化)、仅 cinder 这一条两段链触发。v1 stub 接受;真内容来 lab 时再定 X→X2 是否只作用于"原始携带槽"。
- [P2→P3, low, note] `InkMonUnitActor.equip_abilities` 若 `learned_skill_id == inkmon_basic_attack` 会重复授予 basic(get_skill_config(basic) 再 grant 一次)。已通过"basic 不进技能池"在 P2 数据侧规避;P3 改 from_battle_snapshot/actor 时可顺手加 primary==basic 的防御(skip 重复 grant)。

## Consistency Review

- (结尾填:`<date> - Goal.md vs 实现:<no divergence | resolved items>`)

## Blockers

- None
