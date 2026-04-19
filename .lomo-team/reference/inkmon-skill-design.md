# Inkmon 技能池推荐实现设计

> 基于 `mechanics-taxonomy.md` + LGF 框架能力 + hex ATB 自走棋约束，设计 inkmon 的首批示范技能。
> **目的**：为 `example/hex-atb-battle/` 提供"机制模板库"，让未来 AI 基于 LGF 做 inkmon 本体时能**模仿已有 pattern**而非自由发挥。
> 日期：2026-04-18

---

## 一、设计原则

### 1. Pattern 驱动，不是玩法驱动

这些技能不是 inkmon 的"最终技能池"，是**框架用法范本库**。每个技能被选中的首要标准：
- 它是否**清晰映射到 LGF 的某组原语组合**？
- 未来 AI 看到类似需求（"我要做 X 机制"）时，能否**在这里找到最相近的 pattern** 并改写？

### 2. 梯度：从简单原语到复杂组合

| Tier | 复杂度 | LGF 原语覆盖 |
|---|---|---|
| Tier 1 (MVP) | 单 Action / 简单 Component | Ability 生命周期、Action execute、事件 push、AttributeModifier、基础 PreEvent |
| Tier 2 (中级) | Timeline + 多 Action 组合 | Timeline keyframe、TargetSelector、Resolvers、动态目标 |
| Tier 3 (高级) | 跨系统组合 | On Death event、Component swap（变身）、永久 scaling、Actor 生成 |

**目标**：AI 从 Tier 1 的技能学到"基本套路"，再去改写 Tier 2 / 3 的已知例子实现变体。

### 3. 优先覆盖"共识机制 + hex 原生"

依据 taxonomy 附录 A（三游戏共识）+ 附录 B（hex + TFT 原生）：

- **必选**：护盾 / 增伤 / 易伤 / AoE / On Death / 条件触发 / 自伤换益 / 斩杀 / 召唤
- **hex 特色必选**：推、拉、瞬移、链锁、AoE 形状、地形伤害格
- **避开**：卡牌独有机制（Exhaust / Scry / Discard 协同），inkmon 不是卡牌游戏
- **不做 meta 层**：羁绊、商店、升级、Augment —— 这些是 inkmon 本体游玩层的事，不属于 LGF example 范畴

### 4. 原型 ≠ 照搬

每个技能都有**原型来源**（哪个游戏的哪个机制），但**数值/形状/触发条件按 inkmon 的 hex + ATB 重新设计**。目标是学机制，不是搬数据。

---

## 二、hex ATB 自走棋的核心约束

在设计具体技能前，明确 inkmon 的底层规则（这些决定了哪些机制能直接搬、哪些要改写）：

1. **Hex 网格**：六方向移动/攻击，邻居判定 = 6 格（不是 4）；AoE 形状（直线、扇形、环）在 hex 下有自然的 60° 增量
2. **ATB (Active Time Battle)**：每个单位有独立的行动条，满了执行一次 action；**非回合制**，所以 Slay the Spire 的"每回合"概念要转译为"每 N 秒"或"每次行动后"
3. **自走棋**：玩家**不直接操控**单个单位的技能释放；单位根据 AI 和 ATB 自动行为；玩家层主要操作：布阵、装备分配（meta 层，不在本文档）
4. **Actor 分两类**（来自 `logic-game-framework-config/attributes/`）：
   - `hero_attribute_set`：可操控 / 部署的英雄单位
   - `tower_attribute_set`：防御/固定单位（设计上可以是 minion、召唤物、场景互动单位）
5. **战斗规模**：小规模（估计 3-8 单位对 3-8 单位），比 TFT 的 10v10 小；每场时长短
6. **LGF 约束（回顾 `enforcing-lgf`）**：
   - Action / Condition / Cost 是**共享 static var**，**不能有状态**
   - 状态必须放 `AbilitySet.tag_container` 或事件里
   - 技能必须能**回放**（Replay 系统要求状态可重放）

---

## 三、LGF 能力映射速查（设计时先看这张表）

当你想实现某类机制时，优先找 LGF 里已有的对应原语：

| 想要的效果 | LGF 原语 | 注意 |
|---|---|---|
| 一次性造成伤害 | `Action.execute()` + push damage event | shared static，无状态 |
| 持续效果（DOT / HOT / buff duration） | Ability + Timeline periodic keyframe + TagContainer stacks | duration 和 stacks 都放 tag |
| 拦截伤害（减伤 / 护盾 / 免疫） | `PreEventConfig` handler + `modify_intent` 或 `cancel_intent` | 每条路径必须返回 Intent |
| 增伤 / 减伤百分比 | `AttributeModifier` 或 PreEvent modify_intent | 前者修属性 post-tick；后者拦事件现场改 |
| 条件触发（HP < X% / 被攻击时） | 对应事件的 `PreEventConfig` 或 `PostEventConfig` 加 filter | filter 返回 bool |
| 范围目标（AoE） | `TargetSelector`（hex 邻居 / 直线 / 环） | 坐标靠 `UGridMap` |
| 位移（push / pull / teleport） | Action 计算新坐标 + 改 Actor 的 position | 要检查碰撞 |
| 召唤 Actor | `GameplayInstance.add_actor()` + `_on_id_assigned` | 生命周期手动管 |
| 动态数值（基于施法者属性） | `Resolvers.float_fn(fn)` 延迟求值 | 不能存 self._attack_power |
| 多阶段 action（蓄力） | Timeline 多 keyframe，每 frame 触发不同 action | 注意 total_duration |
| 跨 ability 状态（counter / 标记） | `AbilitySet.tag_container.apply_tag(name, duration, stacks)` | 跨 ability 也能查 |

---

## 四、技能池总览

### Tier 1 — MVP（6 个，**先做全部**）

| # | 名称 (inkmon) | 原型 | 核心 LGF 学习点 |
|---|---|---|---|
| 1 | Strike（基础攻击） | 所有游戏基础 | Ability + damage Action |
| 2 | Poison（中毒） | Slay the Spire | Timeline periodic + TagContainer stack + 衰减 |
| 3 | Ward（护盾） | Slay the Spire Block | PreEvent modify_intent 减伤 + 层数消耗 |
| 4 | Knockback Punch（推击） | Into the Breach Titan Fist | hex 位移 + 碰撞额外伤害 |
| 5 | Expose（易伤标记） | Slay the Spire Vulnerable / ItB A.C.I.D. | PreEvent modify_intent 增伤 + duration |
| 6 | Execute（斩杀） | TFT Dark Star / StS Bane | Condition(HP%) + 动态伤害 |

### Tier 2 — 中级（6 个）

| # | 名称 | 原型 | 核心 LGF 学习点 |
|---|---|---|---|
| 7 | Fireball（六邻 AoE） | StS Thunderclap / TFT Karma | TargetSelector hex ring + 多目标 event |
| 8 | Decimating Smash（蓄力重击） | TFT Sion | Timeline 多 keyframe + 延迟结算 |
| 9 | Chain Lightning（链锁） | ItB Electric Whip / TFT Xayah | 动态目标选择 + 迭代 action |
| 10 | Thorns（反伤被动） | StS Thorns / TFT Bramble Vest | PostEvent 反应 + 反向 push event |
| 11 | Mend（治疗友军） | TFT Lulu / Hextech Gunblade | TargetSelector 筛友方最低血 + 属性增益 |
| 12 | Shadow Step（瞬移突袭） | TFT Pyke / Zed | 坐标计算 + 多阶段 action |

### Tier 3 — 高级（4 个）

| # | 名称 | 原型 | 核心 LGF 学习点 |
|---|---|---|---|
| 13 | Deathrattle: Explode（尸爆） | StS Corpse Explosion / ItB Goo | On Death handler + 延迟 AoE |
| 14 | Stance: Wrath/Calm（姿态切换） | StS Watcher | Component swap + 双套 modifier |
| 15 | Demon Form（无限 scaling） | StS Demon Form | Periodic Timeline 永久叠 modifier |
| 16 | Summon Totem（召唤图腾） | ItB Bombling / TFT 召唤物 | 生成新 Actor + 独立 AI + 生命周期 |

**共 16 个技能**。全部做完后 LGF 的核心能力（Ability / Action / Event / Timeline / TargetSelector / Component / TagContainer / Resolver / Actor 生命周期）都有至少一个可运行的参考实现。

---

## 五、Tier 1 — MVP 技能设计卡

### 技能 1：Strike（基础攻击）

**灵感**：所有游戏的基础攻击（auto-attack）。
**效果**：对相邻格的一个敌人造成施法者攻击力的伤害。
**ATB 定位**：普攻，ATB 填满即释放；可能不是"技能"而是"基础行动"。

**LGF 拆解**：

- **Ability** = `BasicAttackAbility`
- **Components**:
  - `ActivateInstanceComponent`（ATB 满 → 激活一次）
  - `NoInstanceComponent` OR `ActiveUseComponent`（看 ATB 怎么模型化）
- **Target**: `TargetSelector.enemies_in_range(range=1)` → 取 1 个
- **Action**: 新建 `DamageAction`（如果没有）
  - `execute(ctx)`：`push_damage_event(caster, target, damage)`
  - damage 来自 `Resolvers.float_fn(_ -> caster.attribute_set.attack_power)`
- **Event**: `DamageEvent`（已有）

**骨架**（示意）：
```gdscript
class_name BasicAttackAbility
# 静态构造（因为 AbilityConfig 是 static var）
static var CONFIG := AbilityConfig.builder() \
    .with_component(ActivateInstanceConfig.new()) \
    .with_action(DamageAction.new({
        "target": TargetSelector.enemies_in_range(1),
        "damage": Resolvers.float_fn(func(ctx): 
            return ctx.caster.attribute_set.attack_power)
    })) \
    .build()
```

**能测试的 LGF 能力**：
- Ability 生命周期（activate → execute → deactivate）
- 基础 damage event 流转
- Resolver 延迟求值

**变体方向**：远程版本 = range > 1；多段攻击 = 连续 push 多次 event；按武器系数 = damage 乘以武器 modifier。

---

### 技能 2：Poison（中毒）

**灵感**：Slay the Spire 的 Poison。
**效果**：给目标施加 N 层 Poison。之后每 2 秒对目标造成"等于当前层数的伤害"，然后层数 -1。层数归零后效果消失。
**为什么必做**：这是 Slay the Spire 机制 #1 代表；也是 DOT 家族（燃烧、流血）的通用模板。

**LGF 拆解**：

- **施毒技能**（造成中毒）= `PoisonStrikeAbility`
  - Action: `ApplyTagAction`（已有或新建）
  - 在 `target.ability_set.tag_container.apply_tag("poison", duration=-1, stacks=N)` — duration=-1 表示不按时间衰减（靠自 tick 消耗）
- **中毒效果本身**（DOT tick）= 挂在 target 身上的一个**被动 Ability**，叫 `PoisonPassiveAbility`
  - 施毒时：若 target 没有 `PoisonPassiveAbility`，则 `ability_set.add_ability(PoisonPassiveAbility.CONFIG)`
  - Component: `ActivateInstanceComponent`（由 Timeline 驱动）
  - Timeline: 每 2 秒一个 keyframe
  - 每 keyframe action:
    1. `stacks = tag_container.get_stacks("poison")`
    2. 若 `stacks <= 0` → `ability_set.remove_ability(self)` 并返回
    3. `push_damage_event(source=self, target=self, amount=stacks, type="poison")`
    4. `tag_container.apply_tag("poison", -1, stacks-1)` 覆盖为新层数

**关键 Pattern**：
- **状态在 `tag_container`**，不在 Ability 本身（遵守 LGF 共享无状态规则）
- **DOT 效果 = 一个带 Timeline 的 passive Ability**（这就是用户最初的直觉：DOT 是 Timeline + 定期执行的 Ability）
- **传导效果**（新层数叠加老层数）看业务：StS 风格是累加，也可以做成刷新

**骨架**：
```gdscript
class PoisonPassiveAbility extends Ability:
    static var CONFIG := AbilityConfig.builder() \
        .with_timeline(Timeline.periodic(interval_sec=2.0)) \
        .with_action_on_keyframe(PoisonTickAction.new()) \
        .build()

class PoisonTickAction extends Action.BaseAction:
    func execute(ctx: ExecutionContext) -> void:
        var actor_tag := IAbilitySetOwner.get_ability_set(ctx.caster).tag_container
        var stacks := actor_tag.get_stacks("poison")
        if stacks <= 0:
            IAbilitySetOwner.remove_ability(ctx.caster, ctx.ability)
            return
        EventPhase.push_damage(ctx.caster, ctx.caster, stacks, "poison")
        actor_tag.apply_tag("poison", -1.0, stacks - 1)
```

**能测试的 LGF 能力**：
- Timeline periodic keyframe
- TagContainer 的 stacks 计数
- Ability 动态添加/移除（`add_ability` / `remove_ability`）
- 共享 Action 无状态原则（`PoisonTickAction` 不能有 self._count）

**变体方向**：
- **Burn**（固定伤害不衰减）：去掉 stacks -1 的那步，改为 duration 驱动
- **Bleed**：跟 Burn 类似但可以被"Cleanse"清除
- **Poison 增强 Relic**：施法者挂额外 tag "poison_amplify"，PoisonTickAction 读这个 tag 决定 stacks 增减速度

---

### 技能 3：Ward（护盾）

**灵感**：Slay the Spire Block。
**效果**：给目标（自身或友军）施加 N 点护盾值。下次受到伤害时，先消耗护盾再扣血。护盾被打破或在 X 秒后自动消失。

**LGF 拆解**：

- **施护盾技能** = `WardAbility`
  - Action: `ApplyWardAction`
  - 在 `target.ability_set.tag_container.apply_tag("ward", duration=10.0, stacks=N)`
  - 并给 target 加 `WardPreEventAbility`（一次，幂等）
- **护盾拦截** = `WardPreEventAbility`
  - Component: `PreEventComponent`（已有）
  - 挂在 `DamageEvent` 的 pre 阶段
  - Handler: 
    ```gdscript
    func(mutable: MutableEvent, ctx: AbilityLifecycleContext) -> Intent:
        var ward := ctx.ability_set.tag_container.get_stacks("ward")
        if ward <= 0:
            return EventPhase.pass_intent()
        var incoming := mutable.get("damage")
        var absorbed := min(ward, incoming)
        ctx.ability_set.tag_container.apply_tag("ward", -1, ward - absorbed)
        return EventPhase.modify_intent(ctx.ability.id, [
            Modification.new("damage", incoming - absorbed)
        ])
    ```

**关键 Pattern**：
- **PreEvent 必定返回 Intent**（这是 LGF 硬性规定，违反会 runtime assert）
- **护盾值存 tag**，Pre handler 每次查
- **护盾破 + 剩余伤害继续**：modify_intent 降伤害，不是 cancel_intent

**骨架**：
```gdscript
class WardPreEventAbility:
    static var CONFIG := AbilityConfig.builder() \
        .with_pre_event(DamageEvent, _ward_handler) \
        .build()

static func _ward_handler(mutable, ctx) -> Intent:
    # (见上方)
```

**能测试的 LGF 能力**：
- PreEventConfig handler（每条路径返回 Intent）
- `modify_intent` vs `cancel_intent` vs `pass_intent`
- Tag duration + stacks 双重衰减（duration 消失自动清 tag）

**变体方向**：
- **Barricade**（护盾不衰减）：把 duration=-1 永久
- **Thorns 风格反伤**：handler 额外 push 一个 damage event 回攻击者
- **条件护盾**（只挡物理）：handler 先判断 `mutable.get("damage_type")` 再决定是否吸收

---

### 技能 4：Knockback Punch（推击）

**灵感**：Into the Breach Titan Fist。
**效果**：对相邻敌人造成伤害，并把它朝攻击方向推 1 格。若被推的格子有其他单位 → 都受额外碰撞伤害。若推到边界/墙 → 目标受碰撞伤害。

**为什么必做**：hex 原生机制的代表；涉及坐标计算和多步骤 action 编排。

**LGF 拆解**：

- **Ability** = `KnockbackPunchAbility`
- **Target**: 相邻 1 格敌人
- **Action**: 组合 action，分步骤：
  1. `DamageAction`（造成基础伤害）
  2. `PushAction`（计算推的目标格）
     - 读 caster 位置 + target 位置 → 推方向（hex 6 方向之一）
     - 目标新坐标 = target + 方向
     - 碰撞检测：
       - 如果新格是墙/地图边界 → target 受碰撞伤害（1 点）
       - 如果新格有其他单位 → target + 被撞者都受碰撞伤害，target 不移动
       - 否则 → 更新 target 的 position
- **Event**: 可能需要 `ActorMovedEvent` 让前端/其他系统感知（如果已有 `TeleportEvent` 或类似可复用）

**hex 推方向计算**：
```gdscript
# UGridMap 应该提供 hex 邻居方向枚举
var dir := UGridMap.get_direction(caster.pos, target.pos)  # 6 方向之一
var new_pos := UGridMap.neighbor(target.pos, dir)
```

**骨架**（伪码，简化）：
```gdscript
class PushAction extends Action.BaseAction:
    var _damage_on_collision: IntResolver  # 碰撞伤害

    func execute(ctx: ExecutionContext) -> void:
        var caster_pos = ctx.caster.position
        var target = ctx.target
        var dir = UGridMap.hex_direction(caster_pos, target.position)
        var new_pos = UGridMap.neighbor(target.position, dir)
        
        if not UGridMap.is_valid(new_pos) or UGridMap.is_wall(new_pos):
            _push_damage_event(target, _damage_on_collision.resolve(ctx))
            return
        
        var blocker = UGridMap.get_actor_at(new_pos)
        if blocker != null:
            _push_damage_event(target, _damage_on_collision.resolve(ctx))
            _push_damage_event(blocker, _damage_on_collision.resolve(ctx))
            return
        
        target.position = new_pos
        _push_moved_event(target, dir)
```

**能测试的 LGF 能力**：
- 多步骤组合 Action（多个子 Action 顺序 execute）
- 坐标几何计算（hex 方向）
- 与 `UGridMap` Autoload 的交互
- 碰撞后条件化的事件 push

**变体方向**：
- **Pull**（拉）：方向反转 + 穿越判定
- **Push N 格**：循环推直到撞到
- **Wind Torrent**（群推）：一条直线/一整行所有单位同方向推

---

### 技能 5：Expose（易伤标记）

**灵感**：Slay the Spire Vulnerable / ItB A.C.I.D.
**效果**：对目标施加 Expose 标记，持续 5 秒。期间目标受到的伤害 +50%。
**区别**：和 Poison 的 DOT 不同 —— 不直接扣血，是**修改受伤害**。

**LGF 拆解**：

- **施法技能** = `ExposeAbility`
  - Action: `ApplyTagAction` → `target.tag_container.apply_tag("expose", duration=5.0, stacks=1)`
  - 并给 target 加 `ExposePreEventAbility`（幂等）
- **易伤效果** = `ExposePreEventAbility`
  - Component: `PreEventComponent`
  - 挂 `DamageEvent` pre
  - Handler:
    ```gdscript
    func(mutable, ctx) -> Intent:
        if ctx.ability_set.tag_container.get_stacks("expose") <= 0:
            return EventPhase.pass_intent()
        var base = mutable.get("damage")
        return EventPhase.modify_intent(ctx.ability.id, [
            Modification.new("damage", base * 1.5)
        ])
    ```

**关键 Pattern 对比（重要！）**：

| | **Poison** (DOT) | **Expose** (增伤 debuff) |
|---|---|---|
| 主动扣血 | ✅ 每 tick push damage event | ❌ |
| 改变他人伤害 | ❌ | ✅ 拦截 damage event |
| 实现手段 | Timeline periodic + DamageAction | PreEvent modify_intent |
| 去除方式 | 层数归零 | duration 到期 |

这两种是 **状态效果的两大基础模式**。AI 应该能分辨何时用哪个。

**能测试的 LGF 能力**：
- PreEvent modify_intent 的百分比加成
- 与 Ward 的 PreEvent 叠加（谁先算？LGF 应该有排序规则）
- Tag duration 时间衰减

**变体方向**：
- **Weak**（受害方减伤）：对 attacker 施加 weak tag，attacker 的 DamageEvent 乘 0.75
- **破甲**（Sunder）：改 target 的 defense 而不是 modify incoming damage
- **Mark + Execute 组合**：Expose 同时叠一个 mark tag，Execute 技能读 mark 判斩杀阈值

---

### 技能 6：Execute（斩杀）

**灵感**：TFT Dark Star / Slay the Spire Bane。
**效果**：对 HP < 20% 的敌人造成 999 真实伤害（实质秒杀）；对高血敌人只造成普通伤害。

**LGF 拆解**：

- **Ability** = `ExecuteAbility`
- **Action**: `ConditionalDamageAction`
  - 读 `target.attribute_set.hp` 和 `target.attribute_set.max_hp`
  - 若 `hp/max_hp < 0.2` → push_damage_event with damage=9999 且标记为 "true_damage"
  - 否则 → push_damage_event 正常伤害

**或者更优雅**：用 `Condition` 拆成两个 Action：
```gdscript
AbilityConfig.builder()
    .with_cost(ExecuteHpCheckCost)  # 可选：低血才能施放
    .with_action_branch([
        {condition: LowHpCondition, action: ExecuteKillAction},
        {condition: null, action: NormalDamageAction},
    ])
```

**骨架**：
```gdscript
class LowHpCondition extends Condition:
    var _threshold: FloatResolver
    
    func check(ctx: ExecutionContext) -> bool:
        var hp_ratio = ctx.target.attribute_set.hp / ctx.target.attribute_set.max_hp
        return hp_ratio < _threshold.resolve(ctx)

class ExecuteKillAction extends Action.BaseAction:
    func execute(ctx):
        EventPhase.push_damage(ctx.caster, ctx.target, 9999, "true_damage")
```

**关键 Pattern**：
- **Condition 判条件**（LGF 已有）
- **真实伤害**：damage event 带 type，PreEvent 里对 "true_damage" 绕过 ward/armor
- **动态阈值**：threshold 从 config 或 caster 属性读

**能测试的 LGF 能力**：
- `Condition.check` 用法
- 条件分支 Action
- 伤害 type 字段在 event chain 中的传递
- Cost（可选）控制施放条件

**变体方向**：
- **Bane**（只对中毒目标真伤）：Condition 改查 target 的 "poison" tag
- **Culling Strike**（击杀奖励）：Action 后接 OnKillBonusAction，给施法者 +1 攻击力
- **概率斩杀**：加 random condition

---

## 六、Tier 2 — 中级技能设计卡

Tier 2 每个技能都**组合多个 LGF 原语**。前面 Tier 1 是"单点验证"，Tier 2 是"组合验证"。

### 技能 7：Fireball（六邻 AoE）

**灵感**：StS Thunderclap / TFT Karma Singularity。
**效果**：选一个目标格，对该格 + 六邻七格内所有敌人造成魔法伤害。

**LGF 拆解**：
- **Target**: `TargetSelector.hex_ring(center, radius=0..1, filter=enemies)` — 返回最多 7 个 Actor 的数组
- **Action**: `MultiTargetDamageAction` 遍历所有返回 target，逐个 push_damage_event
- 注意：LGF 的 TargetSelector 应该已经支持多目标返回（查 `addons/logic-game-framework/core/actions/target_selector.gd`）

**骨架**：
```gdscript
static var CONFIG := AbilityConfig.builder() \
    .with_action(DamageAction.new({
        "targets": TargetSelector.hex_ring(radius_max=1, faction="enemy"),
        "damage": Resolvers.float_fn(func(ctx): 
            return ctx.caster.attribute_set.spell_power * 1.5)
    })) \
    .build()
```

**能测试的 LGF 能力**：
- TargetSelector 的 hex 形状过滤
- 多目标 damage event 的批量 push
- 事件处理顺序（7 个目标依次结算还是同时？涉及 LGF 的 event ordering 约定）

**变体**：
- **Line AoE**：`hex_line(dir, length=4)`
- **Cone AoE**：`hex_cone(dir, spread=60°, length=3)`
- **Ring of Fire**（中心不伤害）：`hex_ring(radius_min=1, radius_max=1)`

---

### 技能 8：Decimating Smash（蓄力重击）

**灵感**：TFT Sion。
**效果**：蓄力 2 秒（期间不能被位移），然后对周围六邻格造成巨额物理伤害 + 眩晕 2 秒。

**LGF 拆解**：
- **Timeline**: 两 keyframe
  - `t=0s`：`ApplyTagAction`（给自己挂 `channeling` tag，免疫位移 —— 见变体）
  - `t=2s`：`MultiTargetDamageAction` + `ApplyTagAction`（给目标挂 `stun` tag）
- **取消条件**（可选）：若 caster 在 t=0..2 之间被眩晕或死亡，Timeline 取消（LGF 的 Timeline 应该支持 cancel）

**关键 Pattern**：
- **蓄力本质是 Timeline 多 keyframe 延迟结算**
- 中间状态用 tag 标记（让 AI / 其他系统知道"正在蓄力"）
- 动画前端根据 `channeling` tag 显示蓄力特效

**骨架**：
```gdscript
static var CONFIG := AbilityConfig.builder() \
    .with_timeline(Timeline.builder()
        .at(0.0, ApplyTagAction.new({"tag": "channeling", "duration": 2.0}))
        .at(2.0, [
            DamageAction.new({
                "targets": TargetSelector.hex_ring(1, "enemy"),
                "damage": 50,
            }),
            ApplyTagAction.new({"tag": "stun", "duration": 2.0, "target_selector": ...}),
        ])
        .build()
    ) \
    .build()
```

**能测试的 LGF 能力**：
- Timeline 多 keyframe 按时间触发
- Timeline 中途取消（如果 LGF 支持）
- 多 Action 在同一 keyframe 顺序执行

**变体**：
- **Flame Strike**：蓄力 1s，落地前显示火圈（AoE 预告）；给敌人 1s 闪避窗口
- **Overload**（可中断）：若蓄力期间受到 >N 伤害，技能失败

---

### 技能 9：Chain Lightning（链锁闪电）

**灵感**：ItB Electric Whip / TFT Xayah / Zoe Paddle Star。
**效果**：对首个目标造成魔法伤害；然后跳到最近的另一个敌人伤害 -20%；再跳一次；最多 3 跳。

**LGF 拆解**：
- **Action**: `ChainAction`
  - 入参：初始 target / max_hops / damage_falloff
  - 维护一个 `visited` 集合（**但 Action 是 static 无状态！** 所以 visited 必须是 local 变量）
  - 每跳：找最近未打过的 enemy，push_damage_event，递归/循环
- **Damage Event 的 source 链**：每跳的 source 可以是上一个 target（让 thorns 反伤生效到连锁中间），也可以始终是 caster。设计选择。

**骨架（loop 版本）**：
```gdscript
class ChainLightningAction extends Action.BaseAction:
    var _max_hops: IntResolver
    var _damage: FloatResolver
    var _falloff: FloatResolver

    func execute(ctx: ExecutionContext) -> void:
        var current := ctx.target
        var damage := _damage.resolve(ctx)
        var hops := _max_hops.resolve(ctx)
        var falloff := _falloff.resolve(ctx)
        var visited := [current]

        for i in range(hops):
            if current == null:
                break
            EventPhase.push_damage(ctx.caster, current, damage, "lightning")
            damage *= (1.0 - falloff)
            current = _find_nearest_enemy(current, visited)
            if current != null:
                visited.append(current)
```

**关键 Pattern**：
- `visited` 是 **local 变量**，绝不存 self（共享无状态原则）
- 循环动态选目标 = `TargetSelector` 不够用，需要自己 iter
- 可以抽成 `HopTargetSelector` 做成可配置

**能测试的 LGF 能力**：
- 动态循环目标选择
- damage falloff（衰减）
- Action 无状态原则的实际应用（用 local var）

**变体**：
- **Bouncing Flask**（StS）：目标是**随机**不是最近
- **Chain Healing**：改成对友军治疗
- **Chain With Fork**（分叉）：每跳同时打 2 个目标

---

### 技能 10：Thorns（反伤被动）

**灵感**：StS Thorns / TFT Bramble Vest。
**效果**：被动 passive —— 每次受到**物理攻击**时，对攻击者反弹 N 点伤害。

**LGF 拆解**：
- **Ability**: `ThornsPassiveAbility`（添加到 actor 就永久挂着）
- **Component**: `PostEventComponent`（已有；监听 DamageEvent 的 post 阶段）
- **Post Handler**:
  ```gdscript
  func(event: GameEvent, ctx):
      if event.get("target") != ctx.caster:
          return
      if event.get("damage_type") != "physical":
          return
      var attacker := event.get("source")
      if attacker == null or attacker == ctx.caster:
          return
      EventPhase.push_damage(ctx.caster, attacker, thorns_damage, "thorns")
  ```

**关键 Pattern**：
- **被动反应 = PostEvent handler**（不修改原 event，只触发新 event）
- 避免循环：thorns event 不应再触发另一个 thorns event
  - 手段 1：damage_type="thorns" 的 event 被 thorns handler 过滤掉
  - 手段 2：event 带 `chain_depth`，>1 不再反伤

**能测试的 LGF 能力**：
- PostEventComponent / PostEvent handler
- event 发起新 event 的模式
- 无限递归防护（重要！）

**变体**：
- **Bronze Scales**（StS）：开局自动挂 Thorns（不需要技能施放）
- **Flame Barrier**（单回合反伤）：tag duration 限制
- **Reflect Magic**：只反魔法伤害

---

### 技能 11：Mend（治疗友军）

**灵感**：TFT Lulu Wild Growth / Hextech Gunblade。
**效果**：找到场上 HP 最低的友军（包括自己），治疗 N 点。

**LGF 拆解**：
- **Target**: 特殊 selector — `TargetSelector.lowest_hp_ally(include_self=true)`
- **Action**: `HealAction`
  - push 一个 `HealEvent`（如果已有；否则用 DamageEvent 的负向变体 / 专门的 HealEvent）
  - 治疗量 = Resolvers.float_fn 基于 caster.spell_power 或固定值

**骨架**：
```gdscript
static var CONFIG := AbilityConfig.builder() \
    .with_action(HealAction.new({
        "target": TargetSelector.lowest_hp_ally(include_self=true),
        "amount": Resolvers.float_fn(func(ctx): 
            return 30 + ctx.caster.attribute_set.spell_power * 0.8)
    })) \
    .build()
```

**关键 Pattern**：
- **友方过滤**：需要 faction 概念（caster.faction == target.faction）
- **治疗事件**：复用 DamageEvent 带 negative 还是用 HealEvent？—— 推荐独立 HealEvent，因为可以有独立的 Pre/Post handler（比如"增益治疗量"的 buff）
- **最低血筛选**：需要 TargetSelector 支持排序 + 取第一

**能测试的 LGF 能力**：
- TargetSelector 的友方 / 排序 / 筛选能力
- HealEvent / HealAction（如果没有则新建）
- Resolver 中读取 caster 属性做 scaling

**变体**：
- **AoE Heal**：`hex_ring_ally` 治疗所有邻近友军
- **Shield on Heal**：治疗的同时挂 Ward
- **Smite** (Inverse)：对最低血**敌人**造成真伤

---

### 技能 12：Shadow Step（瞬移突袭）

**灵感**：TFT Pyke / Zed。
**效果**：瞬移到目标敌人的身后（hex 坐标关系），并对其造成一次暴击（+50% 伤害）。

**LGF 拆解**：
- **Action**: 组合
  1. `TeleportAction`
     - 计算"身后"格：从 target 位置 → target 当前朝向的反方向 1 格
     - 若反向格被占 → 失败（或寻找备用空格）
     - 更新 caster.position
  2. `DamageAction`（带 crit 标记）
     - damage *= 1.5
- **hex 中"身后"的定义**：需要 Actor 有朝向属性（`facing_direction`），或者用"远离其他敌人的方向"

**骨架**：
```gdscript
class ShadowStepAction extends Action.BaseAction:
    func execute(ctx: ExecutionContext) -> void:
        var target = ctx.target
        var dir_behind = _opposite(target.facing)
        var land_pos = UGridMap.neighbor(target.position, dir_behind)
        
        if not UGridMap.is_empty(land_pos):
            land_pos = _find_fallback_pos(target)
            if land_pos == null:
                return  # 无地方落点，技能失败
        
        ctx.caster.position = land_pos
        EventPhase.push_event(ActorTeleportedEvent.new(ctx.caster, land_pos))
        EventPhase.push_damage(ctx.caster, target, 
            ctx.caster.attribute_set.attack_power * 1.5, "physical")
```

**能测试的 LGF 能力**：
- Actor 朝向属性
- 空间关系计算（相对坐标）
- 失败容错（无落点时降级）
- 多事件批量 push（TeleportedEvent + DamageEvent）

**变体**：
- **Assassinate**（暗杀）：+100% 伤害，但只对 HP < 50% 有效（接 Execute pattern）
- **Jump Attack**：落在 target 前方，推 target 1 格
- **Backstab**（非瞬移）：若 caster 已经在 target 身后，下次攻击 +100% 伤害

---

## 七、Tier 3 — 高级技能设计卡

Tier 3 用到 LGF 的**跨系统组合能力**：On Death 事件 / Component swap / 永久 scaling / Actor 生成。这些是验证框架**真正深度**的地方。

### 技能 13：Deathrattle: Explode（尸爆）

**灵感**：StS Corpse Explosion / ItB Goo 死亡分裂 / 炉石亡语。
**效果**：此单位死亡时，对周围六邻敌人造成等于其 MaxHP 25% 的伤害。

**LGF 拆解**：
- **Ability**: `ExplodeOnDeathAbility`（被动，挂在单位身上）
- **Component**: `PostEventComponent`（监听 `ActorDeathEvent`）
- **Handler**:
  ```gdscript
  func(event, ctx):
      if event.get("actor") != ctx.caster:
          return  # 只响应自己的死亡
      var damage = ctx.caster.attribute_set.max_hp * 0.25
      var victims = TargetSelector.hex_ring(1, "enemy").select(ctx.caster.position)
      for v in victims:
          EventPhase.push_damage(ctx.caster, v, damage, "explosion")
  ```

**关键 Pattern**：
- **On Death 是 PostEvent on ActorDeathEvent**
- 注意：`ctx.caster` 在死亡时仍然是有效对象？—— LGF 应该在 ActorDeathEvent 的 post 阶段完成后才真正 remove actor；但这要 LGF 核心保证 / 文档化
- **MaxHP% 伤害**：用 `caster.attribute_set.max_hp * 0.25`（此时 hp 已经是 0，但 max_hp 还在）

**能测试的 LGF 能力**：
- ActorDeathEvent 的存在与 post 阶段时序
- 死亡 actor 在 handler 中的可用性
- 递归防护（尸爆打死另一个有尸爆的 → A 爆 → B 死 → B 爆 → ... 需要 LGF 保证事件链不爆栈）

**变体**：
- **Split**（ItB Goo）：死亡时在自己格 / 相邻格生成 2 个小单位（见技能 16 召唤）
- **Life Link**（Darkling）：死亡后 2 秒复活（需要 Timeline 延迟 + 新 Actor）
- **Volatile**：受到致命伤害时先 explode 再死，顺序很关键

---

### 技能 14：Stance: Wrath/Calm（姿态切换）

**灵感**：Slay the Spire Watcher。
**效果**：单位有两种姿态。
- **Wrath（愤怒）**：造成伤害 +50%，受到伤害 +50%
- **Calm（冷静）**：造成伤害 -25%，受到伤害 -25%
技能主动切换当前姿态；也可按回合轮换。

**LGF 拆解**：

**方案 A：用两个不同的 Ability 代表姿态**
- `WrathStanceAbility`：挂上时给自身 `AttackAmp +0.5` 和 `IncomingAmp +0.5`（两个 AttributeModifier）
- `CalmStanceAbility`：挂上时给自身 `AttackAmp -0.25` 和 `IncomingAmp -0.25`
- **切换 = remove 旧的 + add 新的**

**方案 B：单 Ability + tag 表姿态**
- `StanceAbility`（长期挂着）
- tag 存当前姿态（`stance:wrath` / `stance:calm`）
- PreEvent handler 查 tag 决定 modifier

**推荐方案 A**，因为：
1. 不同姿态的 behavior 差异可能很大（不只是百分比，可能每回合动作都不同）
2. 对 AI 更直观："wrath ability 存在 → 单位在愤怒态"
3. modifier 通过 AttributeModifier 挂载，离开姿态自动脱落

**骨架**：
```gdscript
class SwitchToWrathAction extends Action.BaseAction:
    func execute(ctx: ExecutionContext) -> void:
        var ability_set = IAbilitySetOwner.get_ability_set(ctx.caster)
        ability_set.remove_ability_by_id("stance:calm")  # 幂等
        ability_set.add_ability(WrathStanceAbility.CONFIG)

class WrathStanceAbility:
    static var CONFIG := AbilityConfig.builder() \
        .with_id("stance:wrath") \
        .with_component(AttributeModifierComponent.new({
            "attack_amp": 0.5,
            "incoming_amp": 0.5,
        })) \
        .build()
```

**关键 Pattern**：
- **Component 的生命周期 = Ability 的生命周期**：Ability remove 时 Component on_end 自动卸载 modifier
- **Ability id 对比**：切换前要删旧 stance（否则累积）
- **AttributeModifier 机制**（LGF 已有）：ability 持续期间修改 actor 的某属性

**能测试的 LGF 能力**：
- Ability 的动态 add / remove
- AttributeModifierComponent 的自动挂载/卸载
- Ability ID 与状态机管理

**变体**：
- **三态切换**（Watcher Mantra → Divinity）：多加一个 DivinityStanceAbility，有触发条件
- **Auto-switch**：每 10 秒自动 rotate（Timeline 里切）
- **Locked stance**：某些单位只能一种姿态

---

### 技能 15：Demon Form（无限 scaling）

**灵感**：Slay the Spire Demon Form。
**效果**：passive —— 每 3 秒永久 +2 攻击力，**没有上限**，战斗持续越久越强。

**LGF 拆解**：
- **Ability**: `DemonFormAbility`（passive 挂着）
- **Timeline**: `Timeline.periodic(interval=3.0)`
- **Action**: `PermanentAttackBuffAction`
  - 给自己**直接修改** `attribute_set.base_attack_power += 2`（而不是用 AttributeModifier —— 因为 modifier 是临时的，会在 ability 卸载时还原）
  - 或者：`AttributeModifier` 以"stacks" 方式每次 +2 永不移除

**方案选择**：
- **方案 A**：直接 mutate `base_attack_power`（简单但脏，绕过 modifier 系统）
- **方案 B**：挂一个 `"demon_form_stacks"` tag，stack 数 +1；AttributeModifier 读 stack 数乘 2 作为加成 → **推荐**

**骨架**（方案 B）：
```gdscript
class DemonFormAbility:
    static var CONFIG := AbilityConfig.builder() \
        .with_timeline(Timeline.periodic(3.0)) \
        .with_action_on_keyframe(IncrementDemonFormStacksAction.new()) \
        .with_component(AttributeModifierComponent.new({
            "attack_power": Resolvers.float_fn(func(ctx):
                return ctx.ability_set.tag_container.get_stacks("demon_form") * 2)
        })) \
        .build()

class IncrementDemonFormStacksAction extends Action.BaseAction:
    func execute(ctx):
        var tc = ctx.ability_set.tag_container
        var n = tc.get_stacks("demon_form") + 1
        tc.apply_tag("demon_form", -1.0, n)  # duration=-1 永久
```

**关键 Pattern**：
- **无限 scaling = tag stacks 无上限 + AttributeModifier 动态读 stacks**
- 保持 Action 无状态：stacks 读写都走 tag
- **Resolver 在 Modifier 里**：modifier 每次结算时动态算加成

**能测试的 LGF 能力**：
- Timeline periodic 永久运行
- AttributeModifier 与 Resolver 的组合
- Tag stacks 无上限累积

**变体**：
- **Ritual**（敌方版 Demon Form）：每回合 +3 Str，挂在敌人身上施加威胁
- **Thousand Cuts**（每行动 +1）：把 Timeline 换成 on_attack event 触发
- **Exponential**（scaling 指数）：stacks 累积 * 2 而不是 +2

---

### 技能 16：Summon Totem（召唤图腾）

**灵感**：ItB Bombling / TFT 召唤物 / 炉石图腾。
**效果**：在相邻空格召唤一个图腾 actor（HP 低、不会移动、每 3 秒对最近敌人自动攻击）。图腾持续 15 秒或被打死。

**LGF 拆解**：
- **Action**: `SummonTotemAction`
  - 找 caster 相邻空格
  - `GameplayInstance.add_actor(TotemActor.new(caster.faction))`
  - 设置 totem position = 找到的空格
  - 给 totem 挂一个 TTL ability（15 秒后自毁）
- **Totem actor 本体**:
  - 继承 `Actor`（或专门的 `TowerActor`，因为项目有 `tower_attribute_set`）
  - 自带一个 passive AutoAttackAbility（Timeline 每 3 秒攻击最近敌人）
  - 低 HP（15）、无移动、faction = summoner.faction

**关键 Pattern**：
- **召唤 = 动态生成 Actor 并加入 instance**（见 `enforcing-lgf` §2 Actor 生命周期）
- **_on_id_assigned** 里同步 ability_set 的 owner_actor_id
- **Faction 继承**：召唤物阵营 = 施法者阵营
- **TTL**：用 Timeline + DespawnAction 或者 tag duration + PreEvent 监听
- **`tower_attribute_set` 派上用场**：召唤物天然适合用 tower attribute（低 HP、高攻击或辅助）

**骨架**：
```gdscript
class SummonTotemAction extends Action.BaseAction:
    func execute(ctx: ExecutionContext) -> void:
        var empty_neighbor = _find_empty_neighbor(ctx.caster.position)
        if empty_neighbor == null:
            return  # 无地方召唤
        
        var totem = TotemActor.new(ctx.caster.faction, ctx.caster.gameplay_instance_id)
        ctx.gameplay_instance.add_actor(totem)
        totem.position = empty_neighbor
        
        EventPhase.push_event(ActorSummonedEvent.new(
            summoner=ctx.caster, summoned=totem))

class TotemActor extends Actor:
    func _init(faction: String, instance_id: String):
        super._init()
        self.faction = faction
        self._instance_id = instance_id
        self.attribute_set = TowerAttributeSet.new()
        self.ability_set = AbilitySet.new()
        # 召唤物自带的自动攻击 + 自毁
        self.ability_set.add_ability(AutoAttackAbility.CONFIG)
        self.ability_set.add_ability(DespawnAfterAbility.CONFIG_15SEC)

    func _on_id_assigned() -> void:
        ability_set.owner_actor_id = get_id()
        attribute_set.actor_id = get_id()
```

**能测试的 LGF 能力**：
- **动态 Actor 生成**（add_actor + _on_id_assigned）
- 使用 `tower_attribute_set`
- 跨 Ability 的组合（召唤物自带多个 ability）
- Actor 的 faction 与阵营判定
- Summoned actor 的独立 AI / Timeline
- TTL / 自毁机制

**变体**：
- **Split**（尸爆 + 召唤）：单位死亡时生成 2 个小单位（组合技能 13 + 16）
- **Persistent Summon**（永久召唤物）：去掉 TTL
- **Shared HP Totem**（灵魂链 / TFT Senna）：施法者受到伤害也扣图腾 HP，反之亦然

---

## 八、Roadmap — 推荐实施顺序

基于"**每一步都能产生独立测试的 pattern**"原则，不要一次铺开 16 个：

### 阶段 1：验证核心 pattern（1-2 周）

1. **Strike**（技能 1）→ 确认 Ability + Action 基础跑通，能 headless 测试
2. **Poison**（技能 2）→ **这是关键验证**：Timeline periodic + TagContainer + Ability 动态增删
3. **Ward**（技能 3）→ PreEvent modify_intent 的标准用法

**阶段 1 结束目标**：
- AI 能看懂这 3 个技能的代码
- 新 session 让 AI 基于 Poison **模仿做 HOT**（Heal Over Time），看它能否正确套用 pattern
- 如果 AI 产出合理 HOT → pattern 传递有效，继续
- 如果 AI 又自由发挥 → 可能还需要在 `enforcing-lgf` skill 里加"实现新机制前先查 patterns"的硬引导

### 阶段 2：扩展机制词典（1-2 周）

4. **Expose**（技能 5）→ 另一种 debuff 范式（对比 Poison）
5. **Knockback Punch**（技能 4）→ hex 位移的代表
6. **Execute**（技能 6）→ 条件分支 / 动态伤害
7. **Fireball**（技能 7）→ AoE 范式

### 阶段 3：复杂组合（2-3 周）

8. **Decimating Smash**（技能 8）→ Timeline 蓄力
9. **Thorns**（技能 10）→ PostEvent 反应 + 递归防护
10. **Chain Lightning**（技能 9）→ 动态目标选择
11. **Mend**（技能 11）→ 友方选择 + Heal Event

### 阶段 4：框架深度（3-4 周）

12. **Shadow Step**（技能 12）→ 空间计算
13. **Deathrattle**（技能 13）→ On Death
14. **Stance**（技能 14）→ Component 动态切换
15. **Demon Form**（技能 15）→ 无限 scaling
16. **Summon Totem**（技能 16）→ Actor 动态生成

### 每阶段的测试协议

1. **实现** → 在 `example/hex-atb-battle/abilities/` 建 `ability_<name>.gd`
2. **单元测试** → 在 `addons/logic-game-framework/tests/` 或 `tests/` 加 headless 测试
   - 验证伤害数值、tag 层数、Actor 位置变化等
3. **Pattern 验证** → **新 session 让 AI 用 skill 模仿实现相似但不同的技能**
   - 把 AI 的产出和你的参考实现 diff
   - 如果 pattern 套用准确 → 成功
   - 如果偏差大 → 写 `docs/patterns/<mechanism>.md` 显式补充指引（这就是 A 方案的启动时机）
4. **迭代** → 根据 AI 反馈调整 `enforcing-lgf` skill 或 pattern 文档

---

## 九、后续扩展方向（Phase 2+）

完成 16 个 Tier 1-3 技能后，如果 inkmon 游玩需要更多机制：

### 9.1 按 taxonomy 继续补

**还未覆盖但常见的机制族**（参考 taxonomy 相应章节）：

| 机制族 | 代表变体 | 建议原型 |
|---|---|---|
| AoE 其他形状 | Line / Cone | taxonomy §2.1 / §2.2 |
| Pull / Swap | 反向位移 | ItB Grappling Hook / Teleporter |
| Thorns 变体 | Flame Barrier (单回合) | StS |
| Counter | 防御反击 | TFT Urgot / Jax |
| Silence | 禁用技能 | TFT Ahri / StS Entangled |
| Corpse 交互 | Exhume 式 | StS |
| Lifesteal | 吸血 | TFT Bloodthirster |
| 地形伤害格 | Fire tile | ItB Fire |
| 阻挡墙 | 召唤 wall | ItB Digger |

### 9.2 按 inkmon 玩法独特扩展

inkmon 如果引入独特玩法（羁绊、装备合成等），新机制不一定有 taxonomy 对应：

- **羁绊系统触发** — 多单位激活的群体 buff；需要**羁绊判定器**（System 层）
- **装备被动 On Hit** — 装备挂 passive ability，每次攻击触发；Tier 2 技能 10（Thorns）的 PostEvent 范式可迁移
- **升星（1/2/3 星）** — 属性缩放 + 技能数值缩放；设计 `star_level` 属性 + 所有 Resolver 读它

### 9.3 反哺框架

实施过程中可能发现 LGF **原语缺口**。常见情况：

- **TargetSelector 不支持某过滤条件** → 扩充 selector
- **PreEvent handler 顺序不可控** → 加 priority / order 机制
- **Timeline 不支持取消** → 加 cancel API
- **新 Event type 需要** → 按 LGF 规则新建（`example/hex-atb-battle-core/events/`）

**何时反哺**：
- ✅ 多个技能都需要同一个缺口 → 进 framework
- ❌ 单个技能特殊需求 → 技能自己 hack，别污染框架
- ❌ 还没验证需求是否真的通用 → 先留技能内，等 3 个以上技能需要再提取

---

## 十、产出清单

本文档产出后，完整 `.lomo-team/reference/` 应该包括：

```
.lomo-team/reference/
├── into-the-breach-raw.md       # 原始机制数据
├── slay-the-spire-raw.md        # 原始机制数据  
├── tft-raw.md                   # 原始机制数据
├── mechanics-taxonomy.md        # 跨游戏机制分类表
└── inkmon-skill-design.md       # 本文档：16 个技能设计卡 + roadmap
```

**下一步**（新 session 接续时）：
- 从阶段 1 技能 1（Strike）开始，在 `example/hex-atb-battle/abilities/` 下实现
- 同步写 headless 测试在 `addons/logic-game-framework/tests/` 或项目 `tests/` 下
- 每完成一个技能，用新 session 做 pattern 传递验证（让 AI 基于它做变体）

---

> **文档产出**：Claude Opus 4.7 @ 2026-04-18，基于 16 小时会话中对 LGF / hex ATB / 三参考游戏机制的综合分析。
