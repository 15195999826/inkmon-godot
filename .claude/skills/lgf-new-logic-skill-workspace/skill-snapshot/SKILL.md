---
name: lgf-new-logic-skill
description: Use when implementing any logic-layer skill/ability/buff/passive from the inkmon taxonomy design (see `.lomo-team/reference/inkmon-skill-design.md` — 16 skills across Tier 1/2/3). Trigger on casual phrasings too — "做 Poison", "实现 Ward", "来个 Chain Lightning", "加个吸血被动", "做 Tier 2 技能 X", "照着 Shadow Step 再做一个类似的", "尸爆怎么写". Explicitly a companion to `enforcing-lgf` (coding rules) and `gdscript-coding` (syntax) — this skill owns the "where to put it, how to wire it into the submodule, and how to test it" dimension. Especially relevant when the user is doing logic work (often at the office) and deferring presentation/visual wiring for later.
---

# 新增 inkmon 逻辑层技能（taxonomy 16 技能实现指南）

读完本 skill 就能动手。**不要**用你的先验写"该怎么做一个技能"——本项目有明确的设计源和工作流,必须照做。

---

## 0. 三层 skill 协作(读之前先理清边界)

| Skill | 职责 | 你去看的时候 |
|---|---|---|
| `enforcing-lgf` | **规矩**:Actor 生命周期、共享无状态、Resolver、PreEvent Intent、属性访问 | 写具体 Action/Ability/PreEvent 代码前 |
| `gdscript-coding` | **GDScript 语法**:类型标注、变量遮蔽、Lambda、Array 类型化 | 任何 GDScript 改动 |
| `lgf-new-logic-skill`(本) | **wiring + 工作流**:去哪写、怎么接 scenario 测试、submodule 边界、pattern 传递验证 | 一个"技能级"任务的起点 |

三者同时适用时,以 `enforcing-lgf` 的规则为准(本 skill 不复述那些规则)。

---

## 1. 权威设计源:先读 `.lomo-team/reference/inkmon-skill-design.md`

**所有要实现的技能都在那份文档里**,共 16 个,分 Tier 1/2/3:

| Tier | 数量 | 性质 | 何时选 |
|---|---|---|---|
| Tier 1 MVP | 6 (Strike / Poison / Ward / Knockback Punch / Expose / Execute) | 单 Action / 简单 Component,验证 LGF 基础原语 | 首要实现 |
| Tier 2 中级 | 6 (Fireball / Decimating Smash / Chain Lightning / Thorns / Mend / Shadow Step) | Timeline + 多 Action 组合 | Tier 1 完成后 |
| Tier 3 高级 | 4 (Deathrattle / Stance / Demon Form / Summon Totem) | 跨系统组合 | 前两 tier 稳定后 |

**每个技能的设计卡都包含**:
- 灵感来源(StS / ItB / TFT 的哪个机制)
- LGF 拆解(用哪个 Component / Action / Timeline / TargetSelector)
- 骨架代码(不是最终代码,是起点)
- 能测试的 LGF 能力(写 scenario 要覆盖哪些断言)
- 变体方向(做完主技能后可做的变种)

### 使用设计卡的标准流程

1. **对号**:用户说"做 X" → 去 `inkmon-skill-design.md` 查 X 是否在 16 个里
2. **完整读那一节**(包括变体方向 —— 可能用户其实想做变体而不是主技能)
3. **若不在 16 个里**:停下来问用户 —— 是加入 taxonomy 还是临时做?不要自由发挥

**原则**:这些技能是"**机制模板库**"不是"最终技能池"。实现质量 > 数量。未来 AI 看到相似需求(比如"做 HOT")要能**模仿 Poison 改写**,而不是重新发明。

---

## 2. 目录与 submodule 边界(**极其重要**)

### 2.1 仓库结构

```
inkmon-godot/                              ← 外层仓库 (你 commit 的主场)
├── .claude/skills/                        ← skill 三件套
│   ├── enforcing-lgf/                     (规矩)
│   ├── gdscript-coding/                   (语法)
│   └── lgf-new-logic-skill/               (本 skill)
├── .lomo-team/reference/
│   └── inkmon-skill-design.md             ← 权威设计源 ★
├── addons/                                ← submodule → github.com/15195999826/godot-addons.git
│   └── logic-game-framework/
│       ├── core/                          (框架)
│       ├── stdlib/                        (复用 Action/Component)
│       └── example/hex-atb-battle/        ← 技能实现写在这里 ★
│           ├── skills/                    (主动技能 AbilityConfig)
│           ├── buffs/                     (buff 定义,如 HexBattlePoisonBuff)
│           ├── actions/                   (伤害/治疗/反伤/自定义 Action)
│           └── ...
└── tests/skill_scenarios/                 ← scenario 测试(外层) ★
```

### 2.2 Submodule 工作流

**警告**:`addons/` 是独立的 git 仓库(`godot-addons.git`),本地如果没 init 会几乎是空的。开工前**必须**:

```bash
# 确认 submodule 已初始化;若 addons/logic-game-framework/example/ 为空则:
git submodule update --init --recursive
```

**修改 submodule 里的代码(即 addons/ 下任何文件)时**:

```bash
# 1. 进 submodule 目录改代码
cd addons
# 2. 在 submodule 内提交
git add <files> && git commit -m "feat(...)"
git push
# 3. 回外层 bump 指针
cd ..
git add addons
git commit -m "chore(addons): bump submodule for <feature>"
```

**不要**在外层直接 `git add addons/logic-game-framework/example/xxx.gd` —— 那会尝试把单个文件当外层追踪,违反 submodule 语义。

### 2.3 哪些改动在哪层

| 改动 | 层 | 原因 |
|---|---|---|
| 新 AbilityConfig / Ability / Buff | submodule | example 的一部分 |
| 新 Action / TargetSelector | submodule | 属于 example 或 stdlib |
| scenario 测试(`XxxScenario extends SkillScenario`) | **外层** `tests/skill_scenarios/` | 运行器在外层 |
| 新 skill 文档 / skill 更新 | 外层 `.claude/skills/` | |
| inkmon-skill-design.md 修订 | 外层 `.lomo-team/` | |

---

## 3. 实现流程(从设计卡到 PR)

```
a. 读 inkmon-skill-design.md 对应设计卡 (§1)
     ↓
b. 读 enforcing-lgf + 本 skill §4/§5,检查 LGF 原语怎么用
     ↓
c. 在 submodule 内实现
     - AbilityConfig: addons/.../example/hex-atb-battle/skills/
     - Buff (若有): addons/.../example/hex-atb-battle/buffs/
     - 新 Action (仅当现有不够): addons/.../example/hex-atb-battle/actions/
     - 新 TargetSelector (若形状特殊): addons/.../example/hex-atb-battle/target_selectors.gd
     ↓
d. 在 submodule 内 commit + push
     ↓
e. 外层写 scenario 测试: tests/skill_scenarios/<name>_scenario.gd (§5)
     ↓
f. 跑 scenario 验证: godot --headless tests/smoke_skill_scenarios.tscn
     ↓
g. 外层 bump addons 指针 + commit scenario
     ↓
h. (可选) pattern 传递验证: 新 session 让 AI 基于此技能做变体 (§6)
```

---

## 4. LGF 能力映射速查

先读设计卡里的"LGF 拆解"一节,再对照这张表确认原语。详细用法读 `enforcing-lgf/reference/`。

| 想要的效果 | LGF 原语 | 参考 skill 文件 |
|---|---|---|
| 一次性伤害 | `HexBattleDamageAction` + TargetSelector | `enforcing-lgf/reference/actions.md` |
| 治疗 | `HexBattleHealAction` | 同上 |
| 持续效果(DOT/HOT/buff) | Buff Ability(`StatModifierConfig` + `TimeDurationConfig`)或 Timeline periodic | `enforcing-lgf/reference/stdlib.md` |
| 拦截伤害(减伤/护盾/免疫) | `PreEventConfig` + `modify_intent`/`cancel_intent` | `enforcing-lgf/SKILL.md` §6 |
| 增伤/减伤百分比 | `AttributeModifier` 或 PreEvent `modify_intent` | 前者长期;后者即时 |
| 条件触发(HP%、被击时) | `NoInstanceConfig` + `TriggerConfig` + filter | `enforcing-lgf/reference/abilities.md` |
| 范围目标(hex 形状) | 自定义 `TargetSelector`(项目已有 `all_enemies` / `current_target` / `event_source`) | `example-app-game-logic.md` |
| 位移 / 推拉 | 新 Action 读 `UGridMap` 计算新坐标 + 改 `hex_position` | 参考 `MOVE_ABILITY` 模式 |
| 召唤 Actor | `add_actor()` + `_on_id_assigned` | `enforcing-lgf` §2 |
| 动态数值 | `Resolvers.float_fn(ctx -> ...)` | `enforcing-lgf` §5 |
| 多阶段(蓄力) | `TimelineData` 多 keyframe + 多 tag | `TimelineTags` 常量表 |
| 跨 ability 状态 | `AbilitySet.tag_container.apply_tag(name, duration, stacks)` | `enforcing-lgf` §3 |
| 反伤链防护 | damage event 带 `is_reflected`,filter 排除 | `reflect_damage_action.gd` |

### 关键原则(都是 enforcing-lgf 的硬规定,这里只做提醒)

- **Action/Condition/Cost 共享无状态** — 状态放 `tag_container` 或 local var
- **PreEvent handler 每条路径必须 `return Intent`**
- **Actor ID 不在 `_init` 生成**,在 `_on_id_assigned` 里 sync 到组件
- **Actor 属性直接访问** `actor.attribute_set.xxx`,不写 getter

---

## 5. scenario 测试框架(`tests/skill_scenarios/`)

**每个新技能必须配 scenario**。已有 ~9 个 scenario 当范本。

### 5.1 最小 scenario 骨架

```gdscript
class_name MyNewSkillScenario
extends SkillScenario

func get_name() -> String:
    return "MySkill does X"

func get_scene_config() -> Dictionary:
    return {
        "map": {"rows": 3, "cols": 3},
        "caster":  {"class": "WARRIOR", "pos": [0, 0]},
        "enemies": [{"class": "WARRIOR", "pos": [1, 0], "hp": 1000}],
        "target":  {"mode": "auto"},
    }

func get_active_skill() -> AbilityConfig:
    return HexBattleMyNewSkill.ABILITY  # 从 submodule 里 import

func get_max_ticks() -> int:
    return 100   # 足够跑完完整流程

func assert_replay(ctx: ScenarioAssertContext) -> void:
    var target := ctx.enemy_id(0)
    # 断言 replay 产出的事件序列 & 最终状态
    ctx.assert_float_eq(ctx.total_damage_to(target), 50.0, "damage to target")
```

### 5.2 ScenarioAssertContext 常用断言

先读 `tests/skill_scenarios/scenario_assert_context.gd` 获取完整 API。常用:
- `ctx.filter_damage_events({...})` — 按 kv 过滤
- `ctx.total_damage_to(actor_id)`
- `ctx.assert_float_eq(actual, expected, message)`
- `ctx.assert_array_float_eq(actual, expected, message)`
- `ctx.assert_actor_ability_absent(actor_id, config_id, message)` — 验证 buff/passive 被 revoke
- `ctx.caster_id` / `ctx.enemy_id(i)`

### 5.3 范本:对号入座

| 你做的技能类型 | 读哪个 scenario 当模板 |
|---|---|
| 单体直伤 | `strike_scenario.gd` |
| DOT | `poison_scenario.gd` ★(完整骨架,含层数衰减断言) |
| 多段攻击 | `swift_strike_scenario.gd` |
| AoE | `fireball_scenario.gd` |
| 投射物 | `precise_shot_scenario.gd` |
| 蓄力 | `crushing_blow_scenario.gd` |
| 治疗 | `holy_heal_scenario.gd` |
| 被动触发(on death) | `deathrattle_aoe_scenario.gd` |
| 被动反伤 | (建 Thorns 时创建) |

### 5.4 运行

```bash
godot --headless tests/smoke_skill_scenarios.tscn
```

判定:每个 scenario 独立 PASS/FAIL,不依赖彼此。

---

## 6. Pattern 传递验证(**每个技能实现完做一次**)

这是 taxonomy 设计的核心目标 —— 技能本身是"机制模板",要验证 AI 能否基于它做变体。

```
技能做完 → 新 session 给 AI 下指令:
  "基于 [刚实现的 X],做它的变体 [设计卡里列的变体之一]"

观察:
- AI 是否找到了设计卡(`.lomo-team/reference/inkmon-skill-design.md`)?
- AI 是否复用了 X 的代码结构(而非自由发挥)?
- 产出的变体 scenario 是否通过?

结果:
- ✅ 模仿准确 → pattern 传递有效,继续下一技能
- ❌ AI 自由发挥 → 可能需要:
    a. `enforcing-lgf` 补 pattern 指引
    b. 本 skill 补 §4 映射项
    c. 设计卡本身需要更详细
```

不要跳过这步 —— taxonomy 存在的理由就是 pattern 可传递。

---

## 7. 只做逻辑、不做表演(工作模式边界)

**背景**:用户常在办公不方便调表演时写逻辑,回家再对接前端。

**可以做**:
- AbilityConfig / Timeline / Action / Buff / Passive / PreEvent
- 伤害/治疗/冷却数值
- TargetSelector 形状
- scenario 测试(所有断言)
- headless 验证

**留给"回家后"**(用占位字符串标记):
- `StageCueAction` 的 `cue_id` — 写成 `"my_skill_cue"` + 注释 `# TODO 表演层待对接`
- `ProjectileActor.CFG_VISUAL_TYPE` — 同上
- `.tscn` / scene 层、inspector、`hex-atb-battle-frontend/` 相关

**好处**:回家时 `grep -r "TODO 表演层"` 能一次性列出所有接入点。

---

## 8. 开工前自检

- [ ] `git submodule update --init --recursive` 已跑过(否则 example 空)
- [ ] 在 `.lomo-team/reference/inkmon-skill-design.md` 找到了对应技能的设计卡(或与用户确认"该加入 taxonomy")
- [ ] 读过设计卡的"LGF 拆解"+"骨架"+"能测试的 LGF 能力"+"变体方向"
- [ ] 确认哪部分走 submodule 层、哪部分走外层(§2.3)
- [ ] 设计卡中指出的 LGF 原语,已确认存在(或识别出是新原语需要先谈)

## 9. 收工前自检

- [ ] Submodule 内已 commit + push
- [ ] 外层已 bump submodule 指针
- [ ] scenario 测试已写,`smoke_skill_scenarios` headless 跑过全绿
- [ ] `StageCueAction` / Visual key 的占位字符串都带 `# TODO 表演层` 注释
- [ ] `enforcing-lgf` 的 Validation Checklist 过了(共享无状态、PreEvent Intent、Resolver、Actor 生命周期)
- [ ] (若值得)新 session pattern 传递验证通过
