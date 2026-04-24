---
name: lgf-new-logic-skill
description: Use when adding any gameplay logic to the hex-atb-battle example — new active skills, passives, buffs, debuffs, heals, damage patterns, AOE, DoT, stuns, shields, life-steal, reflect, projectiles, or any ability-related behavior on a CharacterActor. Trigger even if the user says casual things like "加个吸血被动", "做个火球", "来个群伤技能", "给战士加眩晕" — anything that touches AbilityConfig/Action/Timeline/Passive in addons/logic-game-framework/example/hex-atb-battle. Covers file layout, the exact wiring sequence, canonical templates to read, shared-state rules, and the logic-vs-presentation boundary (since the user often adds logic at the office and wires presentation at home).
---

# 新增 lgf 逻辑层技能（hex-atb-battle example）

读这个之前你**不需要**扫代码库；读完就能开干。编码规范见姊妹 skill `.claude/skills/enforcing-lgf/SKILL.md`（共享状态、Resolver、PreEvent Intent 等）。本 skill 只讲"放哪、连到哪、抄谁"。

---

## TL;DR — 拿到需求立刻做这 5 件事

1. **对号入座范本**（§3 范本速查表）→ `Read` 那个文件，复制最接近的 ABILITY 当起点
2. **加 Timeline** → `skills/skill_timelines.gd`：新 `TIMELINE_ID` 常量 + `TimelineData` + 加进 `get_all_timelines()`
3. **加 AbilityConfig** → `skills/skill_abilities.gd`（主动）或 `skills/passive_abilities.gd`（被动）或 `buffs/`（buff）
4. **加枚举/映射**（仅主动技能）→ `config/skill_config.gd` `SkillType` 枚举 + `skill_abilities.gd::get_skill_ability()` 的 `SKILL_COOLDOWNS` 和 match case
5. **装备**（仅被动）→ `character_actor.gd::_grant_class_passives()` 按职业挂载；（主动）→ 通过 `get_class_skill()` 映射自动装备
6. **headless 验证**（§7）

完事再去 §5 的「检查清单」自检。

---

## 1. 目录一张图

```
addons/logic-game-framework/example/
├── hex-atb-battle-core/events/battle_events.gd   # DamageEvent/HealEvent/DeathEvent + DamageType { PHYSICAL, MAGICAL, PURE }
└── hex-atb-battle/
    ├── skills/
    │   ├── skill_abilities.gd       ★ 主动技能 AbilityConfig
    │   ├── skill_timelines.gd       ★ Timeline + TIMELINE_ID 常量
    │   ├── passive_abilities.gd     ★ 被动技能
    │   └── cooldown_system.gd       # CooldownCondition / TimedCooldownCost
    ├── buffs/inspire_buff.gd        # Buff 范本（StatModifier + TimeDuration）
    ├── actions/                     # 项目层 Action（伤害/治疗/反伤/移动）
    ├── target_selectors.gd          # current_target/ability_owner/event_source/all_enemies/fixed
    ├── character_actor.gd           # equip_abilities() + _grant_class_passives()
    ├── battle_ability_set.gd        # 冷却 API：start_cooldown/is_on_cooldown
    ├── hex_battle_pre_events.gd     # PreDamageEvent / PreHealEvent
    ├── config/{skill,class,skill_meta_keys}_config.gd
    └── main.tscn                    # headless 入口

addons/logic-game-framework/
├── core/abilities/shared/timeline_tags.gd   # TimelineTags 所有常量在这
├── core/abilities/components/               # AbilityConfig 的 4 种组件 Config
└── stdlib/                                  # 可复用 Action/Component（写新 Action 前先翻）
    ├── actions/{stage_cue,launch_projectile}_action.gd
    └── components/{stat_modifier,time_duration,stack,dynamic_stat_modifier}_config.gd
```

---

## 2. 写新 Action 前先翻 stdlib 和 actions/

**不要急着新建 Action 文件**。先 Grep 一遍是否已有：

| 需求 | 已存在的 Action |
|---|---|
| 造成伤害（含暴击/击杀/命中回调） | `HexBattleDamageAction`（`actions/damage_action.gd`） |
| 治疗（含过量治疗回调） | `HexBattleHealAction` |
| 对攻击者反伤 | `HexBattleReflectDamageAction` |
| 发射投射物 | `LaunchProjectileAction`（stdlib） |
| 纯表演提示（前端消费） | `StageCueAction`（stdlib） |
| 移动（两阶段） | `HexBattleStartMoveAction` + `HexBattleApplyMoveAction` |

**只有当现有 Action 语义不够**（如新增一个"吞噬目标回血"原子操作）才写新 Action。写新 Action 时读 `damage_action.gd` 当骨架：继承 `Action.BaseAction`、super 构造传 `target_selector`、`execute` 返回 `ActionResult`、**禁止在 execute 里改 self**（共享红线，见 `.claude/skills/enforcing-lgf/SKILL.md` §3）。

---

## 3. 范本速查表：对号入座，先抄后改

| 你要做的 | 去读这个 | 关键机制 |
|---|---|---|
| 近战单体 | `skill_abilities.gd::SLASH_ABILITY` | Timeline `START→HIT→END`，`on_critical` 回调示范 |
| 近战蓄力 | `skill_abilities.gd::CRUSHING_BLOW_ABILITY` | Timeline 含 `WINDUP` tag |
| 近战多段 | `skill_abilities.gd::SWIFT_STRIKE_ABILITY` | `HIT1/HIT2/HIT3` 多 tag |
| 远程投射物（物理） | `skill_abilities.gd::PRECISE_SHOT_ABILITY` | **双组件**：`active_use`(发射) + `component_config`(命中响应) |
| 远程投射物（魔法追踪） | `skill_abilities.gd::FIREBALL_ABILITY` | 同上，视觉 key 不同 |
| 治疗 | `skill_abilities.gd::HOLY_HEAL_ABILITY` | `HexBattleHealAction` + `FloatResolver` |
| 移动类两阶段 | `skill_abilities.gd::MOVE_ABILITY` | `START` 预订格 → `EXECUTE` 落地 |
| 数值型 Buff | `buffs/inspire_buff.gd::INSPIRE_BUFF` | `StatModifierConfig` + `TimeDurationConfig` |
| 事件触发型被动 | `passive_abilities.gd::THORN_PASSIVE` | `NoInstanceConfig` + `TriggerConfig` + filter |
| 亡语 AOE | `passive_abilities.gd::DEATHRATTLE_AOE` | trigger `"death"` + `all_enemies()` selector |
| 属性联动被动 | `passive_abilities.gd::VITALITY_PASSIVE` | `DynamicStatModifierComponentConfig` |
| Pre 阶段拦截（减伤/免疫） | **example 暂无** — 见 `.claude/skills/enforcing-lgf/SKILL.md` §6 的 PreEventConfig 示例 + `hex_battle_pre_events.gd` 的事件常量 |

**未覆盖但有需求的类型**（写之前提醒用户，这些是 example 里首次出现的模式）：
- AOE 主动（扇形/直线/圆形）→ 需先在 `target_selectors.gd` 加 selector，再用 `HexBattleDamageAction` + 新 selector 组装
- DoT / HoT → 用 `NoInstanceConfig` + 周期事件，或新增一个基于 `TimeDurationComponent` 的 tick 组件（框架暂无周期 tick 组件，可能要写）
- 控制（眩晕/沉默）→ 纯 Tag 方案：buff 用 `StatModifierConfig`/空 component 挂 `ability_tags`，然后在 `ActiveUseConfig` 加 `condition` 检查 `has_tag("stun")` 阻断激活
- 护盾/闪避 → `PreEventConfig` + `"pre_damage"`，返回 `cancel_intent` 或 `modify_intent`

---

## 4. 三条关键约定（其余见 `.claude/skills/enforcing-lgf/SKILL.md`）

**① Action/Condition/Cost 是跨角色共享的**。不能在 execute 里改 self 字段。状态放 `ctx.ability_set.tag_container`。

**② 反伤链防护**。被动 filter 里必须排除 `is_reflected` 的 damage 事件，否则无限循环。参考 `passive_abilities.gd::_thorn_filter`。

**③ 投射物命中 filter 必须双重匹配**。`source_actor_id == owner` **且** `ability_config_id == ability.config_id`，防止别人的箭触发你的命中逻辑。参考 `skill_abilities.gd::_projectile_hit_filter`。

---

## 5. 检查清单（写完逐条过）

- [ ] Timeline 加到 `skill_timelines.gd::get_all_timelines()` 返回的数组里
- [ ] （主动）`SkillType` 枚举加了新值；`get_skill_ability()` 的 match 加了 case；`SKILL_COOLDOWNS` 字典有条目
- [ ] （主动）`.condition(CooldownCondition.new())` + `.cost(TimedCooldownCost.new(SKILL_COOLDOWNS["xxx"]))` 都配了
- [ ] （被动）`character_actor.gd::_grant_class_passives()` 按职业 `grant_ability()` 了
- [ ] Action 的 execute 里没有 `self._xxx +=` 之类的 self-mutation
- [ ] 被动 filter 排除了 `is_reflected` / 自伤 / 死者 / 非本人事件
- [ ] 投射物命中 filter 检查了 `ability_config_id`
- [ ] PreEventConfig 的 handler 每个 return 路径都是 `EventPhase.xxx_intent()`
- [ ] `StageCueAction` 的 `cue_id` 是占位字符串（comment 标注"待表演层对接"）
- [ ] headless 跑通没 crash，日志里伤害/治疗/冷却数值符合预期

---

## 6. 只做逻辑、不做表演（工作模式边界）

**可以做**：Timeline / AbilityConfig / Action / Buff / Passive / PreEvent、冷却数值、触发条件、filter、selector、headless 验证、`StageCueAction` 的 `cue_id` **占位字符串**。

**不要碰**（留回家做）：
- `ProjectileActor.CFG_VISUAL_TYPE` 对应的美术/粒子/贴图资源
- `.tscn` / scene 层（按钮、图标、受击动画）
- Godot 编辑器 Inspector 里的 node 配置
- `hex-atb-battle-frontend/` 下的文件

把前端接入点全部以**字符串 cue_id + comment**的形式留下，让回家时能 Grep 出来一次性对接。

---

## 7. headless 验证

```bash
cd C:/GodotProjects/inkmon-godot
godot --headless addons/logic-game-framework/example/hex-atb-battle/main.tscn
```

**判定标准**：
- 无 parse error / assertion crash
- 日志 print 出伤害/治疗/冷却/死亡/被动触发，数值与预期一致
- 战斗能正常结束（不无限循环、不卡死）
- 录像 JSON 可落盘（由 `BattleRecorder` 自动写）

---

## 8. 加属性 / 加 TimelineTag / 加新事件

这些是**跨 example 的改动**，做之前告诉用户一声：

- 新属性 → `example/attributes/attributes_config.gd` 改后**需要重新生成** `generated/hex_battle_character_attribute_set.gd`（注释写了 `AUTO-GENERATED`）
- 新 Timeline tag → `core/abilities/shared/timeline_tags.gd` 加 const
- 新 battle 事件 → `hex-atb-battle-core/events/battle_events.gd`（含强类型 `from_dict`/`to_dict`）
- 新 Pre 事件 → `hex-atb-battle/hex_battle_pre_events.gd`
