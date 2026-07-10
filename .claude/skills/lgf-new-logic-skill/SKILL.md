---
name: lgf-new-logic-skill
description: Use when implementing any skill/ability/buff/passive from the inkmon taxonomy design (see `.lomo-team/reference/inkmon-skill-design.md` — 16 skills across Tier 1/2/3). Trigger on casual phrasings too — "做 Poison", "实现 Ward", "来个 Chain Lightning", "加个吸血被动", "做 Tier 2 技能 X", "照着 Shadow Step 再做一个类似的", "尸爆怎么写". Explicitly a companion to `enforcing-lgf` (coding rules) and `gdscript-coding` (syntax) — this skill owns the "where to put it, how to wire it into the submodule, how to test it, and how to wire the presentation layer" dimension. Logic + presentation are implemented together; the previous "logic-only, leave TODO for visuals later" mode has been deprecated (see §7).
---

# 新增 inkmon 逻辑层技能（taxonomy 16 技能实现指南）

> ⚠️ 本 skill 当前被 skillOverrides **有意禁用**模型调用（2026-07-10 确认：短期不开发新技能）。
> 文档已随技能应用层收敛轮（docs/plan/hex-skill-applayer-convergence-plan.md）刷新对齐现实；
> 恢复技能开发时删除 override 即可直接启用。

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

## 1. 权威设计源 + 进度查询(开工 Step 0)

### Step 0 — 进度与已落地清单**问机器,不问文档**

原 `docs/skills/skill-implementation-progress.md` 已废除,职责拆解:

1. **哪些技能已落地** → 读 `all_skills.gd::_build_manifest()`(总花名册)或跑 SkillPreview 枚举;manifest lint(`hex/regression` 组)保证清单与注册/表演接线一致,不会烂
2. **Pattern 速查** → 本 skill §4 映射表的「参考」列直接指向落地文件;模仿改写已落地技能永远优于照 design 文档骨架重写
3. **「偏离 design 文档的地方」** → 以代码现状为准(design 文档写作时 LGF 还在演进,如护盾走独立 ShieldComponent 而非 PreEventConfig);拿不准时对照落地技能

### Step 1 — 读权威设计源:`.lomo-team/reference/inkmon-skill-design.md`

16 个技能,分 Tier 1/2/3:

| Tier | 数量 | 性质 | 何时选 |
|---|---|---|---|
| Tier 1 MVP | 6 (Strike / Poison / Ward / Knockback Punch / Expose / Execute) | 单 Action / 简单 Component,验证 LGF 基础原语 | 首要实现 |
| Tier 2 中级 | 6 (Fireball / Decimating Smash / Chain Lightning / Thorns / Mend / Shadow Step) | Timeline + 多 Action 组合 | Tier 1 完成后 |
| Tier 3 高级 | 4 (Deathrattle / Stance / Demon Form / Summon Totem) | 跨系统组合 | 前两 tier 稳定后 |

**每个技能的设计卡都包含**:
- 灵感来源(StS / ItB / TFT 的哪个机制)
- LGF 拆解(用哪个 Component / Action / Timeline / TargetSelector)— **若 progress 文档「偏离」一节标了它过时,以 progress 为准**
- 骨架代码(不是最终代码,是起点)
- 能测试的 LGF 能力(写 scenario 要覆盖哪些断言)
- 变体方向(做完主技能后可做的变种)

### 使用设计卡的标准流程

1. **对号**:用户说"做 X" → 去 `inkmon-skill-design.md` 查 X 是否在 16 个里
2. **完整读那一节**(包括变体方向 —— 可能用户其实想做变体而不是主技能)
3. **回头查 progress** 看有没有相近 pattern 已落地;有就先看落地实例
4. **若不在 16 个里**:停下来问用户 —— 是加入 taxonomy 还是临时做?不要自由发挥

### Step 2 — 完成后回写本 skill

每完成一个技能:manifest 加行(见 §2.3)即完成"进度登记"(lint 会守住一致性);若落地了**新 pattern**,在本 skill §4 映射表加一行指向它;若实现偏离 design 文档,在对应技能文件头注释写明现状与理由(本项目注释只讲现状原则)。

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
├── docs/plan/hex-skill-applayer-convergence-plan.md  ← 2026-07 应用层收敛决策(9 点)
├── addons/                                ← submodule → github.com/15195999826/godot-addons.git
│   └── logic-game-framework/
│       ├── core/                          (框架)
│       ├── stdlib/                        (复用 Action/Component/Projectile)
│       └── example/hex-atb-battle/
│           ├── core/                      共享数据层:跨战斗事件类型等
│           ├── logic/                     ← 逻辑层,技能实现写在这里 ★
│           │   ├── abilities/active/      (主动技能 AbilityConfig, 一技能一文件)
│           │   ├── abilities/buffs/       (buff 定义 + buff_tags 词表)
│           │   ├── abilities/passives/    (被动)
│           │   ├── abilities/shared/      (all_skills manifest / skill_tags / std_timelines
│           │   │                           / skill_presets / skill_helpers / cooldown_system)
│           │   ├── actions/               (伤害/治疗/挂buff/推拉/自定义 Action)
│           │   ├── config/                (skill_meta_keys / hex_battle_cues / class 配置)
│           │   ├── target_selectors.gd    (通用 TargetSelector)
│           │   └── character_actor.gd     (Actor 子类)
│           ├── frontend/                  表演层:visualizer 注册表 (cue / buff 图标)
│           └── tests/battle/skill_scenarios/  ← scenario 测试(submodule 内) ★
└── tools/run_tests.ps1                    ← 测试入口(hex/skills / hex/regression 组)
```

**三层分工**:
- **hex-atb-battle/core** 共享、跨战斗的事件类型等数据层。
- **hex-atb-battle/logic** 战斗逻辑(本 skill 99% 的写作目标):技能/Buff/Action/Actor 子类/AI/TargetSelector。
- **hex-atb-battle/frontend** 视觉层,按 §7 与逻辑同步接入。

**90% 的新增技能代码都在 `logic/abilities/` 这一层**;core 和 frontend 只在下沉原语或登记 cue/图标时才碰。

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
# 2. 在 submodule 内提交(push 按需 —— 可先本地 commit、跑通 scenario 后再一起 push)
git add <files> && git commit -m "feat(...)"
# 3. 回外层 bump 指针
cd ..
git add addons
git commit -m "chore(addons): bump submodule for <feature>"
# 4. 要推上游时两个仓库都 push(push 不一定每次提交做)
(cd addons && git push) && git push
```

**不要**在外层直接 `git add addons/logic-game-framework/example/xxx.gd` —— 那会尝试把单个文件当外层追踪,违反 submodule 语义。

### 2.3 哪些改动在哪层

| 改动 | 层 | 原因 |
|---|---|---|
| 新 AbilityConfig / Ability / Buff | submodule `logic/abilities/` | example 的一部分 |
| 新 Action / TargetSelector | submodule | 属于 example 或 stdlib |
| scenario 测试(`XxxScenario extends SkillScenario`) | **submodule** `example/hex-atb-battle/tests/battle/skill_scenarios/` | 目录自动扫描发现;外层 `run_tests.ps1 hex/skills` 驱动 |
| manifest 登记 + cue/tag 词表 + frontend 注册表 | submodule | lint 断言一致性 |
| 新 skill 文档 / skill 更新 | 外层 `.claude/skills/` | |
| inkmon-skill-design.md 修订 | 外层 `.lomo-team/` | |

---

## 3. 实现流程(从设计卡到 PR)

```
a. 读 inkmon-skill-design.md 对应设计卡 (§1)
     ↓
b. 读 enforcing-lgf + 本 skill §4/§5,检查 LGF 原语怎么用
     ↓
c. 调研既有原语 + 起草方案稿
     - 文件清单 / Action 拆分 / Timeline / 决策树
     - **明确列出"新机制清单"**:新 Action / 新事件类型 / 新公共 API / 新 schema 字段
     - 列出需要用户决断的设计抉择(如事件复用 vs 新建)
     ↓
d. ★ 用户 align 门(**必须,即使 0 新机制也走**)
     - 把**完整可执行架构方案**(细到能直接落码,见 §3.2)交给用户
     - **等待用户明确 GO 信号**(自然语言"开始 / 实现吧 / 动手 / GO" 之类) — 选项题答完 ≠ GO
     - 任何"新机制"必须用户逐项确认后才能进入实现
     - 用户可能要求与外部(Codex / 其他 reviewer)讨论后再定;未达成共识时不要往下走
     - **❌ 反模式**:用户答完决策题(尤其全选推荐项)后顺势进入实现 — 全 A 不等于"动手吧"。0 新机制也要先把方案完整呈现,显式等"开始"信号。
     ↓
e. 在 submodule 内实现
     - 主动 AbilityConfig: addons/.../example/hex-atb-battle/logic/abilities/active/
       (「选目标→挂 buff/盾」零结构差异家族直接用 HexBattleSkillPresets.buff_applier;
        带独有机制的写显式 builder 链, 范本 = poison.gd)
     - 被动 AbilityConfig: addons/.../example/hex-atb-battle/logic/abilities/passives/
     - Buff (若有): addons/.../example/hex-atb-battle/logic/abilities/buffs/
     - manifest 登记: shared/all_skills.gd::_build_manifest() 加一行 config
       (timeline 经 builder.timeline(data) 随 config 自动注册, 不手抄注册列表)
     - 新 Action (仅当现有不够): addons/.../example/hex-atb-battle/logic/actions/
     - 新 TargetSelector (若形状特殊): 技能文件内嵌; coord 型区域技能必须提供
       compute_checked_coords() static 纯函数(README「目标选择三层分工」铁律)
     ↓
f. scenario 测试: submodule tests/battle/skill_scenarios/<name>_scenario.gd (§5, 自动发现)
     ↓
g. 跑验证: ./tools/run_tests.ps1 hex/skills hex/regression
   (regression 含 manifest lint —— timeline/图标/cue/tag/必填 meta 五类接线一致性)
     ↓
h. 在 submodule 内 commit; 外层 bump addons 指针(push 按需)
     ↓
i. (可选) pattern 传递验证: 新 session 让 AI 基于此技能做变体 (§6)
```

### 3.1 "新机制"的判定标准(在 align 门内逐项审议)

> ⚠️ **澄清**:本节是"新机制清单"的识别标准 — 用来在 align 门里把它们逐条列出让用户审。**不是 align 门的触发条件** — align 门**任何技能都走**,与有无新机制无关(见 §3 步骤 d)。

任一条命中即视为"新机制",**必须**在方案稿里单独列条,逐项征得用户确认:

- 新增 / 修改 `hex-atb-battle/core` 的事件类型(包括给现有事件加字段)
- 新增 LGF core / stdlib 层的公共 API
- 新增不在 design 卡里的 Action / Component / Resolver
- 修改外部 addon(如 `ultra-grid-map`)的公共接口
- 引入新的 ability_tag / meta key / damage_type 等 schema 值

**反例**(不算"新机制",方案稿里**不必单列**,但方案整体仍要走 align 门 + 等 GO):
- 复用现有 Action / 现有事件,仅参数化使用
- 新增技能内部私有 helper 函数
- scenario 测试本身

### 3.2 用户 align 门的产出格式

方案稿必须 **可执行级完整** — 用户读完应该能确认"按这个方案直接 ctrl-c/v 就是最终代码"。无含糊、无"实现时再定"的余地。把所有犹豫点在方案里就敲定。

方案稿至少包含:

1. **调研结论表**:既有原语现状(API、事件、Action)→ 是否够用
2. **拟实现文件清单**:每个文件标"新建/改",带具体路径
3. **完整代码骨架**:`.gd` 文件级别的 ABILITY / Action / Resolver / Buff 草案 — 含**所有** const(CONFIG_ID / COOLDOWN_MS / 阈值 / 数值)、`ability_tags`(词表内, 见 §4)、`meta()` key(RANGE + TARGETING 必填)、StageCue cue_id(HexBattleCues 常量, 注明复用哪个 vs 新增,见 §7.3)
4. **Timeline 节奏**:用哪条共享标准(HexBattleStdTimelines.MELEE_500 / CAST_LAUNCH_600 / HIT_RESPONSE_100)还是自定义(真有节奏个性才自定义; 自定义给 duration + 每个 tag 的 time_ms)
5. **数值常量集中表**:把所有 magic number 列在一处(伤害 / 治疗 / 阈值 / duration / cooldown),用户能一眼看完;不留"实现时挑数字"
6. **"新机制清单"**(§3.1 标准):逐条列出 + 候选方案 + 推荐倾向;若 0 条就写"无"
7. **scenario 覆盖清单**:每个 case 的 scene_config / actions / 期望断言
8. **表演层接入计划**:按 §7.1 checklist 逐项写"接 / 不接 / 复用什么"

**呈现后等用户明确 GO** — 用户回完 AskUserQuestion 选项题 **不算** GO。要等用户用自然语言说 "开始 / 实现吧 / 动手 / GO" 之类措辞,才解锁实现任务(§3 流程的 e 步及之后)。

期间用户提出修改 → 改方案稿 → 重新呈现 → 再次等 GO。

> 💡 经验上 AI 的反模式:用户一连答完几个 AskUserQuestion 选 A,AI 误读为"用户已经同意整个方案" → 直接进入实现。GO 信号必须是用户**主动发出的、关于"开始动手"的明确表态**,不是被动答完选项题。

---

## 4. LGF 能力映射速查

先读设计卡里的"LGF 拆解"一节,再对照这张表确认原语。详细用法读 `enforcing-lgf/reference/`。

| 想要的效果 | LGF 原语 | 参考(落地文件在 logic/abilities/ 下) |
|---|---|---|
| 单体挂 buff/盾(零结构差异) | **`HexBattleSkillPresets.buff_applier`** | preset 声明: `active/stun.gd`;展开范本: `active/poison.gd` |
| 一次性伤害 | `HexBattleDamageAction` + TargetSelector | `active/strike.gd` |
| 治疗 | `HexBattleHealAction` | `active/holy_heal.gd` |
| 持续效果(DOT/HOT/buff) | Buff Ability(`StatModifierConfig` + `TimeDurationConfig`)或 Timeline periodic | `buffs/poison_buff.gd` |
| 拦截伤害(减伤/免疫) | `PreEventConfig` + `modify_intent`/`cancel_intent` | `buffs/expose_buff.gd`(护盾走 ShieldComponent, 见 `buffs/ward_buff.gd`) |
| 增伤/减伤百分比 | `AttributeModifier` 或 PreEvent `modify_intent` | 前者长期;后者即时(`active/stance.gd` 双向修正) |
| 条件触发(HP%、被击时) | `NoInstanceConfig` + `TriggerConfig` + filter | `passives/thorn.gd` / `passives/deathrattle_aoe.gd` |
| 范围目标(hex 形状) | 内嵌 `TargetSelector` + **`compute_checked_coords()` 纯函数**(selector/预览共用铁律) | `active/grid_cone.gd` / `active/piercing_line.gd` |
| 位移 / 推拉 / 瞬移 | `HexBattlePushAction` / 内嵌 SkillLocalAction 改 grid+hex_position | `active/knockback_punch.gd` / `active/shadow_step.gd` |
| 召唤 Actor | `HexBattleSpawnActorAction` | `active/summon_totem.gd` |
| 动态数值 | `Resolvers.float_fn(ctx -> ...)`;取 caster 用 `HexBattleSkillHelpers.caster(ctx)` | `active/execute.gd`(条件伤害) |
| 多阶段(蓄力) | 自定义 `TimelineData` 多 tag | `active/crushing_blow.gd` / `active/swift_strike.gd`(三连) |
| **一次施法内多消费方派生数据** | 链头 action 算一次写 `ctx.set_execution_state()`, 下游只读 | `active/chain_lightning.gd`(便签)/ `active/shadow_step.gd`(跨 tag) |
| 跨 ability 状态 | `AbilitySet.tag_container.apply_tag(name, duration, stacks)` | `enforcing-lgf` §3 |
| 反伤链防护 | damage event 带 `is_reflected`,filter 排除 | `actions/reflect_damage_action.gd` |
| **词表/协议**(必读) | tag→`HexBattleSkillTags`/`HexBattleBuffTags`;cue→`HexBattleCues` 菜单;施法输入→meta `TARGETING`(actor/coord/self) | `shared/skill_tags.gd` / `config/hex_battle_cues.gd` / `config/skill_meta_keys.gd` |

### 关键原则(都是 enforcing-lgf 的硬规定,这里只做提醒)

- **Action/Condition/Cost 共享无状态** — 状态放 `tag_container` 或 local var
- **PreEvent handler 每条路径必须 `return Intent`**
- **Actor ID 不在 `_init` 生成**,在 `_on_id_assigned` 里 sync 到组件
- **Actor 属性直接访问** `actor.attribute_set.xxx`,不写 getter

---

## 5. scenario 测试框架(submodule `example/hex-atb-battle/tests/battle/skill_scenarios/`)

**每个新技能必须配 scenario**。目录自动扫描发现(丢进去即被 `smoke_skill_scenarios` 收编),
已有 60+ scenario 当范本。

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
| 被动反伤 | `thorn_scenario.gd` |

### 5.4 运行

```powershell
./tools/run_tests.ps1 hex/skills hex/regression
```

判定:每个 scenario 独立 PASS/FAIL,不依赖彼此。regression 组含 **manifest lint**
(timeline 注册/BUFF_REGISTRY/cue 词表/tag 词表/RANGE+TARGETING 必填五类接线一致性),
新技能接线漏了哪样它会指名道姓地红。

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

## 7. 表演层接入清单(逻辑做完同步接,**不留 TODO**)

**重要**:本 skill 早期版本曾允许"先做逻辑、表演留 TODO 回家再补"。**已废弃**——每次落地一个技能都欠一笔技术债,后续往往遗忘或集中拖延,所以现在改为**逻辑 + 表演同步实现**。表演层接入面比想象小,checklist 大多 1-2 处而已。

### 7.1 接入面候选清单(对照下表逐项判断)

| 接入点 | 文件 | 何时必接 |
|---|---|---|
| **BUFF_REGISTRY**(buff 头顶图标) | `frontend/visualizers/buff_visualizer.gd::BUFF_REGISTRY` | 任何**新 buff** ability(config_id 白名单,不接**永远不显示**;manifest lint 断言 ② 兜底,漏接会红) |
| **StageCue cue_id**(施法瞬间 vfx) | 先 `logic/config/hex_battle_cues.gd` 加常量 → 再 `frontend/visualizers/stage_cue_visualizer.gd` 注册表引用该常量 | 用 `StageCueAction` 时;**优先复用现有 cue**(菜单里挑),声明处只许写 `HexBattleCues.XXX`(裸字符串会被 lint 断言 ③/④ 抓);暂无视觉的 cue 进 lint 豁免名单并在菜单标注 |
| **default_registry**(visualizer 注册) | `frontend/visualizers/default_registry.gd::create()` | **只有**新加 Visualizer 类时才动(普通技能 / buff 复用现有 visualizer 即够) |
| **ProjectileActor.CFG_VISUAL_TYPE** | 各投射物注册位置 | 仅当技能用了**自定义投射物形态**(普通投射物已有标准类型,先复用) |

### 7.2 BUFF_REGISTRY 一行格式

```gdscript
HexBattleMyBuff.CONFIG_ID: {
    "short": "X",                            # 1-2 字符头顶字母
    "color": Color(0.9, 0.4, 0.2),           # 16 进制色彩区分别 buff
    "primary_source": PrimarySource.STACKS,  # STACKS(读 ability.stacks) / SHIELD_REMAINING(护盾) / NONE(只 duration 不显数字)
},
```

**short / color 选取约定**:
- 取 ability 名首字母大写(P=Poison、E=Expose、S=Shield、U=Surge、T=Thorn …)
- 已用色避开:Poison 紫(0.6,0.2,0.8) / Ward 蓝(0.3,0.5,1.0) / Surge 橙(0.95,0.6,0.2) / Thorn 暖橙(1.0,0.5,0.2) / Vitality 绿(0.3,0.9,0.4) / Vigor 金黄(0.95,0.85,0.3)
- 同性质 buff(positive / negative)颜色区分够即可,不必一致

### 7.3 复用 cue id 的判断

**优先复用,不编新名**。Expose 的 setup 标记直接复用 `HexBattleCues.MELEE_SLASH`(挥手特效)就够,玩家看到"caster 朝 target 挥了一下"的视觉反馈即可。新 cue 仅在以下场景才加:
- 视觉语义与现有任何 cue 都不匹配(例如召唤 / 远程瞬移 / debuff glow 圈这种特殊视觉)
- 流程:`HexBattleCues` 加常量(官方菜单) → `stage_cue_visualizer.gd` 加类别/配置并引用该常量;暂时不接视觉则进 lint 的 `CUE_NO_VISUAL_YET` 豁免名单

背景:**stage_cue_visualizer 对未登记的 cue id 静默跳过**(不报错)——所以 cue 走常量菜单 + lint 断言 ③ 双保险,编新名/打错字都过不了 CI。

### 7.4 为什么改成同步接

- 新 buff 不接 BUFF_REGISTRY → 玩家看不到 buff 在身上,demo 视觉错乱
- `# TODO 表演层` 占位字符串容易被忽视,project-wide grep 时混在其它 TODO 里
- 表演层接入面 checklist 化后接入成本极低(常见技能就 1-2 处,Expose 整体接入只加 1 行 BUFF_REGISTRY + 1 个 cue id 替换)

### 7.5 既知例外

scenario / headless 验证**不读表演层**(走 logic event collector),所以表演层接入只影响 demo / SkillPreview 等真实渲染场景。如果你的技能纯 pattern 验证(比如 vigor / vitality 这种属性 sandbox)且不打算在 demo 出现,可以**显式声明跳过** + 在 §10 收工自检里写明"表演层不接入,理由 X" — 但默认仍是同步接入。

---

## 8. 开工前自检

- [ ] `git submodule update --init --recursive` 已跑过(否则 example 空)
- [ ] 在 `.lomo-team/reference/inkmon-skill-design.md` 找到了对应技能的设计卡(或与用户确认"该加入 taxonomy")
- [ ] 读过设计卡的"LGF 拆解"+"骨架"+"能测试的 LGF 能力"+"变体方向"
- [ ] §4 映射表里找到了最近的落地 pattern 并读过那个 `.gd` + scenario
- [ ] 确认哪部分走 submodule 层、哪部分走外层(§2.3)
- [ ] 设计卡中指出的 LGF 原语,已确认存在(或识别出是新原语需要先谈)

## 9. 实现前自检(用户 align 门 — 在动手写代码之前必过)

- [ ] 方案稿按 §3.2 格式完成(调研 / 文件清单 / **完整代码骨架** / Timeline / 数值常量表 / 新机制清单 / scenario / 表演层计划)
- [ ] 方案 **可执行级完整** — 所有数值常量、cue_id、命名、ability_tags 都已敲定,不留"实现时再说"
- [ ] 「新机制清单」按 §3.1 标准识别完整(事件 schema / 公共 API / 不在 design 卡里的 Action 等);若有 → 用户已逐项明确确认
- [ ] 待决策的设计抉择已收敛(用户可能要求与外部 reviewer 讨论后再定 — 等达成共识)
- [ ] **收到用户明确 GO 信号**(自然语言"开始 / 实现 / 动手 / GO" 之类) — 答完选项题 ≠ GO;0 新机制也要等

## 10. 收工前自检

- [ ] Submodule 内已 commit(push 按需);外层已 bump submodule 指针
- [ ] scenario 已写并被自动发现,`./tools/run_tests.ps1 hex/skills hex/regression` 全绿
     (**regression 含 manifest lint** —— timeline/BUFF_REGISTRY/cue/tag/RANGE+TARGETING
     五类接线一致性,红了按报错逐条修,别绕)
- [ ] **表演层接入清单**(§7.1)逐项已勾完: BUFF_REGISTRY / cue(HexBattleCues 常量) /
     default_registry / projectile registry — 没接入的项显式写明跳过理由(§7.5)
- [ ] **scenario 重跑 5 次稳定** — 涉及 PreEvent / damage 拦截类技能, 必须 5 次都 PASS
     (普攻路径 crit 由装备 PreBasicAttackEvent 决定; 写 events.size() 断言易 flaky
     → 用伤害值阈值过滤主伤害 vs 附加伤害)
- [ ] **tag 语义两轴自查**: 载体轴(skill/passive/buff/intrinsic/status 互斥)×
     极性轴(positive/negative)——被动**永远不带** "buff"(那是状态实例专用载体,
     误贴会被 preview 选单排除;"增益被动" = passive+positive)
- [ ] `enforcing-lgf` 的 Validation Checklist 过了(共享无状态、PreEvent Intent、Resolver、Actor 生命周期)
- [ ] (若值得)新 session pattern 传递验证通过
