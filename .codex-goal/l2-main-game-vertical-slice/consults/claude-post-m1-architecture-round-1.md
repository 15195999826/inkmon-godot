我已经把 M1 实现、LGF core（`GameWorld` / `GameplayInstance` / `WorldGameplayInstance`）、`ItemSystem` 的真实接口都核对过了。下面是 Post-M1 架构 handoff。

> 说明：当前环境没有暴露 Write / ExitPlanMode 工具，我无法写计划文件，所以按你的要求（"只做架构设计讨论，不编辑文件"）直接把 handoff 作为正文交付。

---

# InkMon L2 Post-M1 架构 Handoff

## 0. 读代码后定的两条地基事实（决定后面一切）

1. **`InkMonBattleWorldGI` 名不副实**：它 `extends WorldGameplayInstance`，但 `WorldGameplayInstance` 的契约是"整局游戏唯一的、长命的 world，owns battle procedure"（见其 `2026-04-19-world-as-single-instance.md`）。而 M1 这个类实际是**短命、team-keyed（left/right）、自带 `InkMonBattleProcedure`、跑完即 `end()`** 的"一场战斗 session"。⚠️ **这是最大命名/语义冲突，第 1 节必须消解。**
2. **`GameplayInstance` 是 `RefCounted`，`end()` 即销毁**（`gameplay_instance.gd:55`）。所以任何要跨战斗/跨场景存活的状态（roster/gold/inventory）**绝不能挂在 instance 上**——必须有 instance 之外的属主。

---

## 1. Post-M1 架构：模块 / 边界 / 谁 owns 什么

### 1.1 三个存活层级

| 层 | 生命周期 | 类型 | 职责 |
|---|---|---|---|
| **持久层** `PlayerState`（新 Autoload） | 整个存档 | `Node`(autoload) | roster / gold / inventory 逻辑句柄 / progression / overworld flags。**唯一 save-load 根。** 纯数据 + `to_dict/from_dict`，不碰 LGF instance。 |
| **流程层** `AppRoot`（单一入口 scene + 状态机） | 整个会话 | `Node` 场景树根 | screen flow 状态机（`Overworld / Battle / NpcMenu`）。owns LGF instance 的**创建/tick/销毁**。`project.godot` 的 `run/main_scene` 指向它，替换掉旧 `Simulation.tscn` 入口。 |
| **模拟层** GameplayInstance（两种，兄弟关系） | 短命/半持久 | `RefCounted` | `InkMonOverworldInstance`（半持久，玩家在世界里时存活）+ `InkMonBattleInstance`（=现 `InkMonBattleWorldGI`，每次遭遇 new 一个，跑完销毁）。二者都注册进 `GameWorld._instances`，**同一时刻只有一个被 `tick`**。 |

### 1.2 谁 owns LGF instance —— `AppRoot` 状态机，不是 PlayerState

- `GameWorld`（autoload）仍是 instance registry + `event_processor` 属主，保持不动。
- `AppRoot` 状态机驱动切换，**不用 `change_scene_to_file`**（KB 信号：scattered scene change 是反模式）。Overworld/Battle/NPC 都是 `AppRoot` 下的子节点 + 对应 GameplayInstance，切换 = 状态机激活/挂起 + 选择 tick 哪个 instance。这样 PlayerState/ItemSystem/GameWorld 全程不死。

### 1.3 battle ↔ overworld 切换（核心数据流）

```
Overworld state: tick InkMonOverworldInstance（玩家移动/NPC）
  → 撞 Trainer NPC → AppRoot 进入 Battle state
    1. PlayerState 产出 battle_config = [roster_entry.project_to_battle_snapshot()...]
    2. GameWorld.create_instance(func(): return InkMonBattleInstance.new())
    3. battle.start({left_roster_snapshots, right_roster_snapshots, seed})
    4. AppRoot 只 tick 这个 battle instance（其余挂起）→ 跑到 battle_finished
    5. 读 result + replay_data → BattleAnimator 播放（UI 层）
    6. PlayerState.apply_battle_result(result)  # 发奖/经验/掉血结算
    7. GameWorld.destroy_instance(battle.id)   # battle 即弃
  → 回 Overworld state
```

**关键决策**：battle 是**独立 sibling instance**，不是 overworld instance 内的 procedure。理由：battle 是 team-keyed + 弃后即焚 + 要 deterministic replay；overworld 是 persistent + 无 team + 无 procedure。塞一起就重蹈 brief 警告的"class-keyed 到骨子里"的坑。（见第 5 节 Rejected #1。）

### 1.4 battle 侧要做的最小改造

- 把 `InkMonBattleWorldGI` 概念上正位为"battle session instance"（可保留类名，但 handoff 注明它**不是** the world）。
- `_setup_teams(config)`（现 `ink_mon_battle_world_gi.gd:161`）改成**优先吃 `config["left_roster_snapshots"]`**（PlayerState 投影出的快照），fallback 才用 `InkMonUnitConfig.get_default_roster`。这是 roster→battle 的唯一注入点。

---

## 2. PlayerState / roster / inventory / gold / progression / save-load 归属

### 2.1 数据模型（全部纯数据，`to_dict/from_dict`）

```
PlayerState (autoload Node)
├── gold: int                      # 标量货币，NOT an item
├── roster: Array[InkMonRosterEntry]
├── overworld: { player_coord, visited_flags, npc_states }
├── progression: { ... 玩家级解锁/进度 }
└── inventory: InkMonInventoryRef  # 逻辑句柄，见 2.3
```

`InkMonRosterEntry`（持久拥有的一只 InkMon，**与 battle actor 解耦**）：
```
{ entry_id, species, stage, role, elements,
  level/exp(progression),
  persistent_stats: {max_hp, ad, ap, armor, mr, speed},  # 成长后的基线
  learned_skill_id,
  equipment_container_id,   # → ItemSystem 容器（v1 可空）
  medals: [...] }           # 玩家给这只挂的勋章/team buff source（v1 静态）
```

### 2.2 roster entry → battle actor 的**投影函数**（v1 最关键的一块）

`InkMonRosterEntry.project_to_battle_snapshot() -> Dictionary`，把持久 stat + 装备加成 + 勋章 team-fold（见第 4 节）**预先算成**一份 battle 用的 stat dict。`InkMonUnitActor._init` 当前从 `InkMonUnitConfig` 读 stub stat（`ink_mon_unit_actor.gd:36-43`）——改成可从快照注入。**progression / 装备 / 勋章全部在投影时落进 attribute base，battle 内部零感知。** 这一步是 deterministic、replay-safe 的。

### 2.3 inventory / 容器归属 —— 复用 `ItemSystem`，不建平行库

- 启动时 `ItemSystem.configure_domain(InkMonItemDomain.new(), InkMonItemCatalog.new())`（catalog 配 gold-priced 的 consumable / equipment config）。
- PlayerState owns **逻辑名 → container_id 的映射**（`{"bag": cid, "equip:<entry_id>": cid}`），**不存裸 container_id**——因为 container_id 是 `ItemSystem` 自增的（`item_system.gd:158`），跨 save/load 不稳定。

### 2.4 save-load 边界

- **唯一存档根 = `PlayerState.to_dict()` → JSON → `user://save.json`。** 含 gold / roster / overworld / progression / **inventory 快照**。
- inventory 快照不靠 ItemSystem 自带（它**只有 per-item `get_item_snapshot`，没有整库序列化**）。PlayerState 持一个 `InkMonInventorySerializer`：
  - save：遍历自己登记的逻辑容器 → 每个容器 `get_items_in_container` → `get_item_snapshot` → 收进 dict。
  - load：`ItemSystem.reset_session()` → 按**逻辑名顺序**重建容器（拿回新 container_id 重填映射）→ 按快照 `create_item` 重建 item。
- **v1 只在 overworld / NPC 菜单存档，不存战斗中途**（battle instance 与 replay 不进存档；战斗可由 seed+roster 重建）。这条要和设计确认（影响"战中读档"UX）。

---

## 3. 六个 NPC system 的 v1 handler 边界

统一契约：所有 NPC 实现 `InkMonNpcHandler`（`on_interact(player_state) -> InkMonNpcSession`），stub 与 real 同接口、可热替。

| NPC | v1 等级 | 必须跑通什么 | 为何 |
|---|---|---|---|
| **Trainer Advancement** | 🟢 **REAL** | 触发 battle entry → 消费 result → 发 gold/exp → 写回 PlayerState | 是 loop 的**战斗入口 + 发奖 + progression** 闭环，不真就没 loop |
| **Shop** | 🟢 **REAL**（至少 gold↔item） | 扣 gold → `ItemSystem.create_item` 进 bag | 闭 loop 的**花费**半边 |
| **Release / Adopt** | 🟡 **REAL-lite** | roster `append` / `erase` 一条 entry | 改动极小，且能**演练 roster+save 往返**；Adopt 也用于新游戏种 roster |
| **Training** | 🟡 **REAL-lite** | 扣 gold → bump 一条 roster entry 的 persistent_stat / exp | 闭 **progression** 半边，handler 很薄 |
| **Guild** | ⚪ **STUB** | 开面板 + 占位文案，无机制 | 社交/任务 v1 无依赖 |
| **Cultivation** | ⚪ **STUB** | 开面板 + 占位 | 修炼成长机制后置 |

> v1 loop 验收链由 Trainer + Shop + (Adopt 种 roster) 三者就能跑通：移动→Trainer 战斗→发奖→Shop 花费→存→读。

---

## 4. Medal / team-wide passive（LGF actor-keyed gap）的 v1 处理

**结论：v1 不在 LGF 建"玩家级/队伍级属主"，按 brief"别碰"。** 改用两手：

1. **静态勋章 = 投影期 stat-fold**（首选）：team-wide 勋章（如"全队 +5% HP"）在 `project_to_battle_snapshot()` 阶段直接加进每只的 `max_hp_base`。零新框架概念、deterministic、replay 安全。
2. **若需"反应式"队伍光环**（如"队友死亡时全队 +AD"）：v1 退化为给每只 battle actor **各发一份相同的 passive ability**（actor-keyed N 份拷贝），仍走现有 `ability_set` 机制（仿 `ink_mon_damage_math_passive` 的挂法）。不引入共享属主。
3. 真·player-level attribute owner **明确记为 known gap，推后**。v1 勋章 = 战前静态 fold only。

---

## 5. Rejected alternatives（≥5，含理由）

1. **❌ overworld 复用/继承 `InkMonBattleWorldGI`，或 battle 作为 overworld instance 内的 procedure**。battle 是 team-keyed + 弃后即焚 + 要独立 replay seed；overworld 是 persistent + 无 team。混用重蹈 brief 的"class-keyed 到骨子里"陷阱，且违反 `WorldGameplayInstance` 的"MVP 同时只允许一场战斗" assert（`world_gameplay_instance.gd:82`）。
2. **❌ 把 roster/gold/inventory 放进某个 GameplayInstance（如 overworld instance）**。`GameplayInstance` 是 `RefCounted`，`end()` 即析构（`gameplay_instance.gd:55`），持久玩家档会随 instance 一起死。持久状态必须在 instance 之外 → autoload。
3. **❌ `PlayerState` 用 static `_instance` 单例**。KB + 仓库惯例：全局服务用 Godot Autoload，不用 static `_instance`（生命周期/测试可复位）。
4. **❌ 新建一套平行 inventory/gold 存储**。违反硬约束"不要创建平行 ItemSystem"；`ItemSystem` 已有 domain/catalog/container/snapshot，经 `configure_domain` 复用即可。
5. **❌ v1 就在 LGF 造 player-level attribute owner 来支撑勋章**。brief 明示是真 gap、"别碰"；投影期 stat-fold 已能覆盖 v1 需求，避免侵入式框架改动。
6. **❌ 用 `change_scene_to_file` 切 overworld/battle/NPC 屏**。KB 警告 scattered scene change；单入口 scene + 状态机让 PlayerState/ItemSystem/GameWorld 全程存活。
7. **❌ 直接 type against `example/hex-atb-battle/` 的 WorldGI/procedure/AI/skills**。硬边界：example 仅参考；L2 已 fork 出 `scenes/inkmon-battle/` 自有副本，只 type against LGF core + L2 自有类。
8. **❌ save 时序列化整个 GameWorld / 战斗中途态**。过度 scope、非确定面大；v1 只存 PlayerState 持久档，战斗可由 seed+roster 重建。

---

## 6. First implementation slice（最小可验证增量，按序）

| # | 增量 | 验证（headless 优先 + DevAgent gate） |
|---|---|---|
| 1 | **`PlayerState` autoload + roster/gold/progression + save/load 往返**（纯数据，无 UI） | 新建 group `inkmon/player_state`：new-game 种子 → 改 gold/roster → `to_dict`→`from_dict` → 断言相等。纯 headless。**这是脊柱。** |
| 2 | **battle 吃 roster 快照 + 发奖回写** | 改 `_setup_teams` 吃 `roster_snapshots`；保持 `inkmon/m1` smoke 绿，新增 smoke：PlayerState roster→battle→断言赢家→`apply_battle_result` 后 gold delta 正确。headless。 |
| 3 | **`AppRoot` 单入口 + 状态机 + instance 生命周期**（Overworld→Battle→back，先无 UI） | headless 驱动跑完一轮 create/tick/destroy battle instance；**首个新 L2 scene → 需 DevAgent adapter 实测**（runtime gate）。 |
| 4 | **`InkMonOverworldInstance` + 玩家在 UGridMap 上移动**（先无 NPC） | **UI gate**：先讨论 overworld 表现面 → imagegen mockup → Godot 实现 → DevAgent runtime 验。 |
| 5 | **NPC 契约 + 2 个 REAL NPC（Trainer / Shop）** | 闭"战斗入口 + 花费"两半。headless 契约测 handler；菜单走 DevAgent。 |
| 6 | **REAL-lite（Adopt/Release、Training）+ STUB（Guild、Cultivation）** | roster 改动顺带演练 save 往返。 |
| 7 | **v1 full loop 集成 smoke** | 移动→Trainer 战斗→发奖→Shop 花费→存→读→断言状态还原。headless 集成 + DevAgent 端到端。 |

> 每个新 L2 scene/UI/overworld/NPC flow **不能只靠 headless**，需 DevAgent adapter 实测；每个 player-facing UI surface 走"讨论 → imagegen mockup → Godot 实现"三段 gate。

---

## 7. 最大风险 / handoff 必须写明的分歧

1. **🔴 instance 拓扑分歧（最高杠杆）**：battle 是独立 sibling instance（我推荐）还是 overworld instance 内的 procedure？`InkMonBattleWorldGI extends WorldGameplayInstance` 的命名暗示后者，但语义是前者。**这条不拍板，下游每个模块都漂。**
2. **🔴 roster entry → battle actor 投影函数**：progression/装备/勋章能否在战斗里生效，全押在这个投影上。若 battle 继续读 `InkMonUnitConfig` stub stat（`ink_mon_unit_actor.gd:36`），成长就永远不反映到战斗。必须先定义投影边界。
3. **🟠 ItemSystem 无整库序列化 + container_id 不稳定**：自增 id（`item_system.gd:158`）跨存档会变，必须持久化"逻辑名→容器"映射而非裸 id，且 load 时按固定顺序重建。漏了会丢装备/串味。
4. **🟠 Medal/team-passive gap 的 v1 范围共识**：v1 = 战前静态 stat-fold only，无反应式队伍光环、无 player-level 属主。设计若想 v1 就要反应式光环，scope 爆炸。
5. **🟠 `RtsRng` autoload 分层异味**：`project.godot:27` 把 autoload 指向 `example/rts-auto-battle/logic/rts_rng.gd`——L2 战斗 determinism 依赖它，却违反"不依赖 example"边界。要么把 RNG 提升进 core/stdlib，要么显式接受这个 autoload 依赖。Codex 须明确选一个。
6. **🟡 存档粒度**：v1 仅 overworld/NPC 存档，不存战斗中途（战斗靠 seed+roster 重建）。需与设计确认，影响"战中读档/读档刷战"UX。
7. **🟡 UI/runtime gate 纪律**：overworld/NPC UI 不可 headless-only 交付；Codex 须在每个 surface 上停下来走 mockup + DevAgent gate，否则违反 L2 验证约定。

---

需要我把其中某一块（最可能是 **#1 instance 拓扑** 或 **#2 投影函数签名**）展开成 Codex 可直接落地的接口级 spec 吗？
