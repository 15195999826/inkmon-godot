# Cast Eligibility 走 Metadata, 不走 Condition

## 原则

> **"如何释放" 是声明, 不是行为. 声明必须可查询.**

任何 cast eligibility 配置 (cast 前用来过滤候选 / 判断能不能打) 必须是 **declarative metadata**, 让 AI / UI / tooltip / 玩家 cast 路径都能**事前查询**, 不需要 dry-run 任何 behavioral 检查.

Condition 是**事件到达时的 reactive 判断**, 适合"该不该响应这个事件". 它的本职是被动技能, 不是主动 cast 目标合法性.

---

## 判断规则

| 配置语义 | 时机 | 放哪 |
|---|---|---|
| Cast 前过滤候选 (range / faction / 目标种类 / LOS / min_range) | cast 前, 由 AI/UI 查询 | **ability metadata** 或 ability tag |
| 事件到达时是否响应 (反伤是否触发 / buff 是否叠层 / 伤害类型筛选) | 事件 broadcast 时 reactive 判断 | **Condition** |
| 物理参数 (push 阻挡 / blocks_path / 撞击伤害) | 系统查询时 | **plain data 字段** (如 `CollisionProfile`) |
| Action 行为 (打谁 / 打多少 / 谁受益) | 执行时 | **Action 子类** |
| 资源消耗 (mp / cd / 消耗物) | cast 时 | **Cost** |

**问自己一个问题决定归属**: "AI 不跑 cast 流程, 能不能从 ability 上读到这个配置?" 能 → metadata; 不能 → 它就不是 cast eligibility.

---

## 现状对照

✅ **已对的 metadata 路径**:
- `range` 走 ability metadata (`HexBattleSkillMetaKeys.RANGE`), `can_use_skill_on()` 消费
- `enemy / ally` 走 ability tag, `can_use_skill_on()` 消费
- `allowedTargetKinds` 走 ability metadata (`HexBattleSkillMetaKeys.ALLOWED_TARGET_KINDS`, default `["Character"]`), `can_use_skill_on()` 消费

✅ **已对的 Condition 路径**:
- `HasTagCondition` / `NoTagCondition` / `TagStacksCondition` — 都是 trigger 命中后的"我该不该执行"判断, 是 condition 的本职舞台

---

## 反模式

❌ **把 cast 配置塞进 Condition**

```gdscript
# WRONG: 把"能不能打 env"做成 condition
class TargetAllowedCondition extends Condition:
    var allowed_kinds: Array[String]
    func check(ctx, event_dict, game_state) -> bool:
        var target := game_state.get_actor(event_dict["target_actor_id"])
        return target.type in allowed_kinds

config.conditions.append(TargetAllowedCondition.new(["Character"]))
```

后果:
- AI 在 `for target in candidates: if can_use_skill_on(...)` 里没法过滤墙 (condition 要拿 event_dict 才跑得起来)
- AI 要么 dry-run 整套 cast 流程, 要么把同样的规则在 AI 层复制一遍
- **双源真相**, 两边一改就漂移

✅ **正确做法**: metadata + 一处 declarative 查询入口

```gdscript
# 在 HexBattleSkillMetaKeys
const ALLOWED_TARGET_KINDS := "allowedTargetKinds"

# 在 can_use_skill_on
var allowed: Array = skill.get_meta(HexBattleSkillMetaKeys.ALLOWED_TARGET_KINDS, ["Character"])
if not target.type in allowed:
    return false

# 在技能配置
ability_config.meta(HexBattleSkillMetaKeys.ALLOWED_TARGET_KINDS, ["Character", "Environment"])
```

AI / UI / tooltip 都直接读 `skill.get_meta(...)`, 不需要任何 dry-run.

---

## 加新 cast eligibility 配置时的步骤

1. 加一个 metadata key 到 `HexBattleSkillMetaKeys` (或对应游戏的 meta keys 文件)
2. 在 `can_use_skill_on()` (或对应游戏的 declarative 查询入口) 加查询逻辑
3. 在需要的技能 config 里 `meta(KEY, value)` 显式声明
4. 默认值放在第 2 步的 `get_meta(KEY, DEFAULT)` 里, 这样**现有技能零修改**
5. **不要建新 Condition 类** — Condition 不是这个配置该去的地方
6. **不要给现有技能加 condition 来"补默认值"** — metadata default 已经兜底

---

## 玩家手动 cast 路径的规约

当前 demo 全 AI cast, AI 在选目标时调 `can_use_skill_on()` 过滤候选. 未来加玩家手动 cast UI 时:

- 玩家点击 → cast 路径 **必须**也调用 `can_use_skill_on()` 校验
- 否则玩家能绕过 metadata 限制 (例如超距打人 / 点墙硬打)
- 这是规约, 不是 condition 路径的"防御性兜底" 该解决的事

如果担心玩家路径漏接, 测试场景应**测试 cast 入口本身调用 `can_use_skill_on()`**, 而不是把规则同时塞进 condition 走双轨.

---

## 经验来源

LGF 在 `2026-04-29` 处理 EnvironmentActor opt-in 时, 在"目标合法性走 condition 还是 metadata"上反复 4 版.

最终收敛到 metadata 路径, 是因为 condition 路径无法满足 AI 事前过滤候选的需求 — AI 调 `can_use_skill_on(actor, skill, target)` 是同步函数, 拿不到 condition 需要的 `event_dict` / `AbilityLifecycleContext`. 把规则做进 condition 等于强迫 AI 自己复刻一份, 否则 AI 永远看不见这个限制.

把这个原则记在这里, 是为了让下次加新 cast eligibility 配置时 (例如 `requires_los` / `min_range` / `requires_ground_clear`) 一眼就知道走 metadata, 不走 condition, 不再绕.
