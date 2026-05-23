# LGF 进阶技能 Phase 2+

## Objective

按 `addons/logic-game-framework/docs/skills/advanced-skills-impl-plan.md`
+ `advanced-skills-next-batch.md` 完成 9 个进阶技能 phase，覆盖 control / board hazard / cleanup / position swap / lifesteal / line AoE 七类新 pattern。

每个 phase 必须同时落地三层：
1. **Logic 层**：buff / skill / scenario / 必要时 LGF core 改动
2. **Presentation 层**：frontend renderer（VFX / icon / floating text / 动画），参考已有 Fireball / Poison 渲染 pattern
3. **验收层**：`/run-dev-scene skill-preview` 自主验收技能 + scenario PASS + Progress.md checkpoint

## Phase 顺序（按文档推荐讨论顺序 + Milestone 分组）

### Prep · 目录整理 / Frontend 渲染探针

- hex 应用层 `skills/` + `buffs/` → `abilities/{active,buffs,passives,shared}/`。文件移动 + `.gd.uid` 同步 + `class_name` 不变 + 引用路径更新
- 不改 LGF core，不顺手引入 Gateway/Stun/Poison runtime 行为
- 同步看一遍 `scripts/SkillPreviewBattle.gd` + frontend 现有技能渲染 pattern（Fireball / Poison / Strike），摸清后续 phase frontend 复用方式与 skill-preview dev scene 入口
- 验收：`/run-dev-scene skill-preview` 跑现有技能不崩

### M1 — 控制三件套

**Phase A · Stun**
- Logic: `HexBattleStunBuff`（canonical buff）：TagComponentConfig=`cant_act` + TimeDurationConfig + on-apply `CancelActiveExecutionsAction`
- Logic: buff tags `["buff","negative","control","stun"]`；不强加 `stunned` component tag
- Logic: `skill_stun` apply via `HexBattleStunBuff.create_config(duration_ms)`
- Logic: 独立实例语义 — 重复 Stun 各 grant 新 Ability，component-owned tag 生命周期清理；禁用 `LooseTagAction.Remove("cant_act")`
- Frontend: buff icon + 眩晕 VFX（头顶星星 / 模型 idle stagger）+ floating text "Stunned"
- Scenario: `stun_independent_instances_scenario.gd`（Case 1 短前长后 / Case 2 长前短后；断言 stun 实例数 / source metadata / `has_tag("cant_act")` 状态）
- 验收: `/run-dev-scene skill-preview` 对 `skill_stun` PASS

**Phase B · Silence**
- Logic: `HexBattleSilenceBuff`：TagComponentConfig=`cant_use_skill` + TimeDuration
- Logic: buff tags `["buff","negative","control","silence"]`
- Logic: ActiveGateway 按 gateway id / action kind 区分入口（ACTIVE_SKILL 拦 / Strike / Move 不拦）；不用 `ability_tags.has("skill")` 判定
- Frontend: buff icon + silence VFX（口部禁言符号 / 沉默 aura）+ 尝试主动技能时 floating text "Silenced"
- Scenario: `silence_active_skill_gate_scenario.gd`（active skill 失败 reason 含 `cant_use_skill`；Strike/Move/passive/buff tick/deathrattle 不受影响）
- 验收: `/run-dev-scene skill-preview` 对 `skill_silence` PASS

**Phase B2 · Break（改 LGF core）**
- Logic: `HexBattleBreakBuff`：TagComponentConfig=`cant_use_passive` + TimeDuration + 维护 passive disabled-source 引用计数
- Logic: buff tags `["buff","negative","control","passive_break"]`
- Logic LGF core 改动：
  - `Ability.receive_event()` 顶层短路（disabled → 不派发事件给 NoInstanceComponent triggered passive）
  - `Ability.tick_executions()` 顶层短路（disabled → 冻结 periodic timeline，不 destroy 不 catch-up）
  - `StatModifierComponent` / `DynamicStatModifierComponent` 新增 passive break hook（disabled → 撤销外部 modifier；resume → 按当前 state 重新注册）
- Logic: `NoInstanceComponent` / `ActivateInstanceComponent` 严禁实现 break hook（注释明示规则）
- Logic: 多 Break 引用计数：最后一个 source 移除才恢复
- Frontend: buff icon + 紫色 aura / passive 图标灰化 + floating text "Broken"
- Scenario: `break_passive_disable_scenario.gd`（Thorn / Vigor-Vitality / DemonForm / Overlap 四 case）
- 验收: `/run-dev-scene skill-preview` 对 `skill_break` PASS

### M2 — Summon Totem 正式 + Fire Tile

**Phase C0 · Summon Totem 正式实现**
- Logic: 移除 spike-only flag；正式 TOTEM actor archetype（CharacterActor 或同等 base）
- Logic: actor-level lifetime（spawn → 自动攻击 → expire / death cleanup）
- Logic: `summon_totem.gd` skill；`HexBattleSpawnActorAction` 接 actor source / team list 合同
- Logic: `HexBattleTotemAttack` ability（nearest-enemy target selection）
- Logic: `HexBattleProcedure` actor source / team list 合同
- Frontend: Totem 模型 / 占格 sprite + spawn 入场动画 + 自动攻击 VFX + 死亡 / expire 退场动画
- Scenario: spawn / 自动攻击 / lifetime expire / 死亡 cleanup / replay 稳定
- 验收: `/run-dev-scene skill-preview` 对 `summon_totem` PASS

**Phase C · Fire Tile（先 spike）**
- Spike 决定: 路线 A passable `EnvironmentActor` overlay vs 路线 B battle-level tile effect registry
- 若路线 A 成立 (Logic):
  - `HexBattleActor.placement_mode` 枚举：`UNPLACED` / `OCCUPANT` / `OVERLAY`
  - 仅 `HexWorldGameplayInstance` placement/spawn API 写 `placement_mode`
  - `remove_actor()` 按 `placement_mode` switch 清理：OCCUPANT 释放 `grid.occupant` 带 identity guard；OVERLAY 绝不碰 occupant
  - battle tick 拆双线：所有 `HexBattleActor` 跑 `ability_set.tick` / `tick_executions`；只有 alive `CharacterActor` 跑 ATB / AI
- Logic: Fire Tile damage pulse source=fire_tile_actor.id；creator 仅 metadata；走完整 damage pipeline (pre/shield/damage/death/post-damage)
- Logic: 时间语义 — spawn_time 立即 pulse；后续 spawn_time + interval_ms 起步；同格多 Fire Tile 独立 tick / 独立伤害
- Logic: 高 HP；正常 lifetime 到期移除；可被 Thorn 反伤打死按 OVERLAY cleanup
- Frontend: 火焰 tile overlay sprite + 每次 pulse 闪光 / particle + spawn / expire 动画 + 多 overlay 视觉叠加（不重影）
- Scenario: overlap / pulse 时机 / Thorn 反伤击杀 / replay 稳定
- 验收: `/run-dev-scene skill-preview` 对 `skill_fire_tile`（或同等 spawning skill）PASS

### M3 — Cleanse + Swap

**Phase D · Cleanse**
- Logic: `skill_cleanse`：friendly/self only，range=3，移除 1 个 negative buff Ability
- Logic: 选择规则（按优先级）：`control` → `passive_break` → 其它 negative；同级按 grant order
- Logic: 执行 `target.ability_set.revoke_ability(buff.id, AbilitySet.REVOKE_REASON_DISPELLED, "cleanse")`
- Logic: 目标无 negative buff 时 success no-op，metadata `{ "cleanse_removed": false }`
- Logic: 不附带 heal；不做 Dispel positive buff；不抽 framework Primitive Action，先 skill-local
- Frontend: 清除 VFX（光环散开 / 白光收束）+ 被清 buff icon 消失动画 + floating text "Cleansed"
- Scenario: 至少两种 negative buff（Poison + Stun/Silence/Break）cleanse；positive buff / shield / stance 不误清
- 验收: `/run-dev-scene skill-preview` 对 `skill_cleanse` PASS

**Phase E · Swap**
- Logic: `skill_swap`：CharacterActor only（自/友/敌可，不能 self / EnvironmentActor），range=3
- Logic: skill-local `_SwapPositionsAction`：validate all（双 alive + valid coord + grid occupant 一致）→ commit（临时清 occupant → 重放 → 双 `ActorDisplacedEvent` 同 swap_id：caster 先 target 后）
- Logic: 任一 validate 失败整体 failure，不改 grid/actor
- Logic: 不造伤 / 不触发碰撞 / 不加 `cant_act`
- Frontend: 双方瞬移 VFX（位置溶解 → 对方位置重现）+ 同 swap_id 双 displacement 视觉同步
- Scenario: 成功 / dead target / self / EnvironmentActor / out-of-range 各一 case
- 验收: `/run-dev-scene skill-preview` 对 `skill_swap` PASS

### M4 — Lifesteal + Piercing Line

**Phase F · Lifesteal**（按 `advanced-skills-next-batch.md` V1）
- Logic: 主动技能；吸血基准 = `DamageEvent.actual_life_damage * ratio`
- Logic: 不做 passive lifesteal；reflected / self damage 不触发 lifesteal
- Frontend: 红色丝线 VFX 从目标连到 caster + heal floating text + caster heal flash
- Scenario: 普通命中 / 护盾吸收后只算 actual / overkill / 反伤 source 不吸血
- 验收: `/run-dev-scene skill-preview` 对 lifesteal skill PASS

**Phase G · Piercing Line**（按 `advanced-skills-next-batch.md` V1；Cone 留后续）
- Logic: example-local `TargetSelector` 子类，沿 hex 方向遍历相邻 coord
- Logic: 复用 `HexBattleDamageAction`
- Frontend: 直线 projectile / beam VFX + 沿线命中节点 hit flash + 命中顺序视觉
- Scenario: 直线穿透多 actor / 阻挡 / 边界 / 命中顺序稳定
- 验收: `/run-dev-scene skill-preview` 对 piercing line skill PASS

## Frontend 表演层契约

- 三层架构（Core / Game Logic / Presentation）顺序不能反：先 Logic + scenario PASS，再做 Frontend
- 不在 Logic 层引用 frontend；frontend 通过 EventCollector / replay event 驱动
- 复用现有 frontend 渲染 pattern（参考 `addons/logic-game-framework/example/hex-atb-battle/frontend/` 下 Fireball / Poison / Strike 等已落地技能），不为单个新技能搭独立渲染系统
- buff icon、floating text、VFX particle 三件套尽量复用已有 helper；只有当现有 helper 表达力不够才扩

## Non-Goals

- 不抽通用 interrupt policy / StatusSystem / TileSystem / EquipmentSystem
- 不为每个新技能复制 Stun/Silence/Break buff class
- 不改 core Timeline 语义
- V1 不做 PassiveGateway / BuffGateway（保留设计边界）
- V1 不做 Dispel 敌方 positive buff
- V1 不做 Cone AoE（移至下一轮）
- V1 不做 passive Lifesteal
- 不做暂缓项（Pull / Counter / Flame Barrier / Corpse / Summon Wall / Equipment / Synergy / Star Level）
- 不为单个技能搭独立 frontend 渲染系统

## Validation

每个 phase 必须满足：

1. 对应 scenario `.gd` 在 hex skill scenario launcher（`addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn`）输出 `SMOKE_TEST_RESULT: PASS`
2. LGF 单元测试 `addons/logic-game-framework/tests/run_tests.tscn` 退出 0
3. 改 LGF core / 主架构的 phase（B2 / C0 / C）：`./tools/run_tests.ps1 -Required` 全部 PASS
4. **每个 phase 跑 `/run-dev-scene skill-preview` 对该 phase 引入的 skill 验收 PASS**（自主验收，不靠 user 手测）
5. 主仓 `--import` 通过；改 addon 后 submodule commit + 主仓 bump pointer

## Completion Gate

- 9 phase + Prep 全部完成
- 每个 phase 同时含 **Logic + Frontend + Validation** 三层 deliverable
- Progress.md `## Checkpoints` 列出对应数量 checkpoint，每条 review 字段为 `pass` 或 `N findings fixed`，每条含 `skill-preview: PASS`
- `git log --oneline <goal-start-ref>..HEAD` 每条 commit 在 Progress.md 有对应 checkpoint
- 改 core 的 phase 在 transcript 中可见 `./tools/run_tests.ps1 -Required` 全 PASS
- Final Consistency Review 完成，Progress.md 末尾含 `Consistency review: no divergence` 或 `N items resolved`
- `## Open Review Findings` 空（或已转入 `## Consistency Review` 作为 accepted descope）
- 回写 `addons/logic-game-framework/docs/skills/skill-implementation-progress.md` Phase 2+ 区域
- `advanced-skills-impl-plan.md` 末尾「落码前总检查」全部勾选

## Kickoff 步骤（写第一个 phase 前必做）

1. 进 `addons/` submodule 看 dirty 状态（主仓 git status 当前 `m addons`）：进 submodule `git status`，决定先 commit baseline 还是 stash；定下来后把 goal-start-ref（主仓 + submodule 双 ref）写入 Progress.md `Goal-start ref`
2. 确认 Prep 目录整理（`abilities/{active,buffs,passives,shared}/`）是否已做；未做则作为 Prep phase 先完成
3. **看 `scripts/SkillPreviewBattle.gd` + skill-preview dev scene 入口**，确认 `/run-dev-scene skill-preview` 可跑、能向其中注入新技能验收
4. **看 frontend 现有技能渲染 pattern**（`addons/logic-game-framework/example/hex-atb-battle/frontend/` 下 Fireball / Poison / Strike），把可复用 helper 与扩展点列出，写入 Progress.md（避免每个 phase 都从零摸 frontend）
5. advanced-skills-impl-plan.md 与 advanced-skills-next-batch.md 出现冲突时（Phase F / G）以 next-batch.md V1 为准
