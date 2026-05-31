# L2 / M1 构建 brief（给 Codex）

> 本 brief 是 InkMon 主游戏（L2）**第一个里程碑 M1** 的可执行规格，自洽、可独立执行。
>
> **完整设计背景在 lab 仓（同一台机器，可直接读，动手前请先读这几份）：**
> - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\CONTEXT.md` —— 领域术语表（战斗/属性/元素/技能/角色/经济）
> - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\BUILD-PLAN.md` —— 里程碑 + M1 最短路径 + 风险评审
> - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0001-inkmon-battle-is-atb-auto-battler.md`
> - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0002-v1-is-standalone-playable-vertical-slice.md`
> - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0003-dual-channel-stats.md`
> - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0004-skill-fixed-kit-rolled-from-pools.md`
> - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0005-l2-is-main-game-in-inkmon-godot.md`

## 你在造什么

InkMon 是一个**云顶之弈式 ATB 自走棋**：hex 棋盘、单位 ATB 自动行动；每个 InkMon 是 Dota2 英雄深度（多技能 + 6 装备 + 强化）。最终目标是可游玩纵切（主世界 + 6 NPC + 战斗）。

**但 M1 只做"可跑的战斗核心"，不碰主世界。** M1 = 一个 **headless、可跑通的 4v4 InkMon hex ATB 战斗**，tick 到分出胜负，附一个断言赢家的 smoke。

## 落地位置（重要）

- L2 = **本仓的主游戏项目**（新建游戏目录，消费 `addons/logic-game-framework` addon）。建议 `scenes/inkmon-battle/{core,logic,frontend}`，镜像 `addons/logic-game-framework/example/hex-atb-battle/` 的三层结构。
- **不要改 addon 里的 example**（hex-atb-battle 是参考库，保持不动）——是**复制其结构**到游戏目录，作为真游戏改造。
- 先读：本仓 `CLAUDE.md`、`addons/logic-game-framework/CLAUDE.md`、skill `.claude/skills/lgf-new-logic-skill/`、参考实现 `addons/logic-game-framework/example/hex-atb-battle/`。

## M1 锁定的设计（只列战斗相关）

- 战斗：**4v4，胜负 = 一方全灭**，ATB 自动行动，hex 棋盘。队伍 = 战(Tank)/法(Mage-DPS)/牧(Healer) + 1 灵活位。
- 属性：**双通道** — HP / AD(普攻伤害) / AP(技能伤害) / Armor(物抗) / MR(法抗) / Speed(ATB 充能)。**不是** demo 的 atk/def。
- 元素：**6 个**(light/dark/fire/water/wind/earth)。克制：wind→earth→water→fire→wind 有向环 + light↔dark 互克、对四元素中立(中立对 wind↔water、earth↔fire)。落成**伤害倍率**。
- 技能：M1 阶段每只 InkMon 给 **1 个技能 + 通用普攻**(多技能槽是 M2)。

## M1 最短路径（按序；大部分是从指明文件复制改造）

1. **Day-1 闸（先做这个）**：给 `addons/logic-game-framework/scripts/attribute_set_generator_script.gd` 喂一个 `InkMonUnit` 配置(HP/max_hp 含 cross-clamp + ad/ap/armor/mr/speed)，生成 `InkMonUnitAttributeSet`。参照同款先例 `addons/logic-game-framework/example/attributes/attributes_config.gd`(Dota2Unit 块) 和生成产物 `example/attributes/generated/dota2_unit_attribute_set.gd`。**确认它编译、setter/clamp 存在**；若生成器在 6 属性上卡壳就**手写**这个 attribute set。⚠️ 所有战斗代码都读这些属性，不通则一切不通。
2. **整类 fork `character_actor.gd` → `InkMonUnitActor`**(不是改 AI 工厂)。原 `character_class` enum 把身份焊死在 stats/skill/passive/AI/replay 上，必须整体替换为 `{role, species, stage}`。换掉 5-stat init(`set_atk_base/set_def_base`，约 line 53-64)为双通道(`set_ad_base/set_ap_base/set_armor_base/set_mr_base`)，加 `element_primary/element_secondary/role` 字段。ATB(`accumulate_atb/can_act/reset_atb`，line 186-201)、facing、death、serialize **照抄**。
3. **写伤害公式** = 一个常驻 `PreDamageEvent` passive(模式抄 `example/hex-atb-battle/logic/abilities/buffs/expose_buff.gd:33-43`)：handler 读 `damage_type` 选 armor 还是 MR → 减伤 → 再乘元素倍率 → `Modification.multiply("damage", coeff)`。挂现有 hook(`damage_action.gd:179` 处 `process_pre_event`)。普攻走 PHYSICAL(读 ad/armor)、技能走 MAGICAL(读 ap/mr)，路由免费。
   - **减伤公式(已定默认，可调)**：LoL 式 `final = base × 100/(100+resist)`，K=100。
   - **元素倍率(已定默认)**：克制 ×1.3 / 被克 ×0.7 / 中立 ×1.0。**双属性 v1 简化**：只用 **skill 的元素 vs 防守方主属性(element_primary)**，副属性先不参与。
   - 6 元素表硬编码成 const dict（见 inkmon-lab ADR-0006）。
4. **普攻**：抄 `strike.gd:39-47` 的 resolver，改读 `.attribute_set.ad`，并打元素标签。
5. **手搓 4 只 InkMon + kit**：**直接复用现成 demo 技能**(`fireball.gd`/`chain_lightning.gd`/`poison.gd`/`holy_heal.gd`/`stun.gd` 全在 `example/.../abilities/active/`)，按 AP 改 resolver、贴元素标签。每只 1 技能 + 普攻。4 只 = tank/mage/healer/flex。
6. **3 个角色 AI**：`RoleTank/RoleDps/RoleHealer` extends `AIStrategy`，多为组合现成 helper(`ai_strategy.gd:51-121` 已有 `_select_lowest_hp/_select_lowest_hp_percent/_select_nearest/_move_toward`)。Healer≈`ranged_support_strategy.gd` 几乎照抄；Tank≈`melee_attack_strategy` 改打最近敌人；DPS 打最低血。override `ai_strategy_factory.gd` 的 `get_strategy` 按 `actor.role` 路由。
7. **`InkMonBattleWorldGI`**(抄 `hex_demo_world_gameplay_instance.gd`)：override `_setup_teams`(line 101-111)成 4v4 手搓阵容，去掉 `_apply_inspire_buff_to_all`。`_create_battle_procedure`、placement(`_place_team_randomly`)、`_check_battle_end`(`hex_battle_procedure.gd:312-334` 纯全灭逻辑)**原样复用**——4v4 不需改胜负判定。
8. **M1 smoke**(抄 `demo_headless.gd`)：headless 同步 tick 循环到 `MAX_TICKS`；断言 `_result ∈ {left_win,right_win}`(非空/非超时)且败方 alive==0。打印 PASS/FAIL 后 quit。日志里 `damage_action.gd:192-195` 已有 `final vs base damage` 行，可肉眼验证减伤+克制生效。

## ⚠️ 别被"框架复用"骗了（评审抓到的真坑）

- `CharacterActor` 是 **class-keyed 到骨子里** → 第 2 步是**整类 fork**，不是"加个 role 字段/改 AI 工厂"。
- demo 的 actor 只持**单技能**(`_skill_ability_id` 单数) → 多技能槽 + "放哪个技能" AI 是**全新**；M1 故意只给 1 技能避开它。
- 技能池靠 lab 的 L3(AI 技能生成)**还没建** → M1 **不做**出生 roll/变异，**手搓复用 demo 技能**。
- replay 决定性：一旦单位带新字段，`serialize()/snapshot` 要吸收，否则 replay 漂移(M1 可先不深究，但别假设零成本)。

## M1 明确不做（全部推后/stub）

主世界 + 6 NPC、装备/刻印、**勋章(玩家级——框架无玩家级属主，是真 gap，别碰)**、出生 roll/变异、进化、金币经济、save/load、canon 真数据(M1 用手写 stub，不接 lab)。

## 验收

`scenes/inkmon-battle/` 下一个 headless smoke 跑通 4v4、断言唯一赢家 + 败方全灭，并能在日志看到减伤/元素倍率影响数字。能跑 = M1 完成。
