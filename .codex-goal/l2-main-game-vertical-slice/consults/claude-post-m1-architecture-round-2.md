已核实：`ItemSystem`（`addons/lomolib/inventoryKit/item_system.gd`）确有 `get_items_in_container`（:548）/`get_item_snapshot`（:511）/`create_item`（:278）/`register_container`（:149）/`reset_session`（:111）/`configure_domain`（:103）/`get_all_containers`（:202），但**无整库 serialize/to_dict**。`RtsRng` autoload 确在 `project.godot:27` 指向 `example/rts-auto-battle/`。下面逐条收敛。

---

# 第 2 轮：逐条裁决（A–H）

## A. PlayerState 属主：撤回 Autoload，改 Session-owned ✅

**最终建议：`AppRoot` owns `InkMonGameSession`，session 内含 `InkMonPlayerState`。PlayerState 不做 Autoload。**

Codex 是对的，我第 1 轮把 KB 那句话用反了。KB 的条件是"**如果你需要一个全局单例**，就用 autoload 别用 static"——它没说"你必须需要全局单例"。这里的关键问题是：**我们到底需不需要全局可达？** 答案是不需要。

- **可测试性是决定因素**（与你 memory 里 `feedback_godot_cwd` / headless-first 一致）：autoload 是进程级可变全局，跑多个 headless smoke 时状态会串，得靠 `reset()` 纪律兜底；session 是一个普通对象，每个 test `InkMonGameSession.new()` 拿干净实例，天然隔离。
- **生命周期清晰**：session `RefCounted`/`Node`，AppRoot 创建即活、退出即弃；存档 = `session.player_state.to_dict()`。
- **ItemSystem 仍是 autoload**（框架基建，不动），但**玩家对它的视图**（逻辑名→container_id 映射）挂在 session 上；session 启动时 `ItemSystem.reset_session()` + `configure_domain()`，teardown 时清。这样 session 与 ItemSystem 的边界不打架。

> 唯一代价：UI/scene 不能 `PlayerState.xxx` 直接全局抓，要从 `AppRoot.session` 取。这正是我们想要的——强制依赖显式化。

## B. 入口策略：vertical slice 阶段**不碰 `project.godot`** ✅

**最终建议：新增 `scenes/inkmon-main/InkMonMain.tscn`（挂 `AppRoot`）作为独立入口，靠 F6 / `--path . <scene>` 跑；`project.godot` 的 `run/main_scene` 与 `Simulation.tscn` + `SimulationManager` Web bridge 全程不动，直到 slice 验收通过再考虑切换。**

- preview / web bridge（`godot_validate_skill` / `godot_preview_skill` 等）是现役 demo API，切 main_scene 会直接断掉，vertical slice 期间不值得冒这个险。
- 两个入口并存零冲突：AppRoot 自带 session，不依赖 SimulationManager。
- **切换是最后一个独立 commit**，不混进功能 slice，且切换时要确认 Web 分支去留（是否让 InkMonMain 也注册 bridge，还是 bridge demo 退役）——这条留给收口决策，不在 v1 scope。

## C. `InkMonBattleWorldGI` 命名：名义边界 now，重命名 later（不强制） ✅

**规则二选一，handoff 写死：**

1. **现在（名义边界，零 churn）**：保留类名 `InkMonBattleWorldGI`，只加**一行 class 文档注释** + handoff 术语表一行：
   > "本类语义是 *一场战斗 session instance*（team-keyed、跑完即 `end()`），**不是** the persistent world；它 `extends WorldGameplayInstance` 仅为复用 instance/tick 脚手架。"
   不改文件名、不改引用、不动 M1 提交。
2. **以后（可选，独立 commit）**：当且仅当真要做 `InkMonOverworldInstance` 落地、需要并存两个 instance 类时，再在一个**专门的 rename-only commit** 里改成 `InkMonBattleSessionInstance`。**handoff 不把它列为 v1 必做项**，只列为 "naming debt #1"。

→ 文档**不要求**马上大改；只要求一行注释消歧义。

## D. 字段草案（见下方"接口级草案"§2.1–2.3）✅

## E. ItemSystem：改写成 capability contract（不锁方法名）✅

虽然我已核实当前方法名都在，但按你的要求写成**能力需求 + 验证点**，让 Codex 实现时对着契约走、不被某个具体签名绑死：

| 能力需求 | v1 验证点 | 当前可满足的入口（已核实，仅供参考非强约束） |
|---|---|---|
| 注册一个域 + 目录（gold 计价的 consumable/equipment config） | 启动后 `get_domain()/get_catalog()` 非空 | `configure_domain()` |
| 会话级清空重建 | load 前能把库清干净 | `reset_session()` |
| 在某容器内造物 | Shop 扣 gold 后能新增一件 | `create_item()` |
| 枚举某容器内全部 item id | save 时能遍历 | `get_items_in_container()` |
| 取单件可序列化快照 | save 出的 dict 能喂回 create 重建 | `get_item_snapshot()` |
| 枚举所有容器 | 自检/调试 | `get_all_containers()` |
| **整库一次性序列化** | ❌ **不存在** → 必须由 L2 自己组合上面几条实现 serializer | —— |

**契约结论**：L2 写 `InkMonInventorySerializer`，**只允许依赖"枚举容器内 id + 取单件快照 + 造单件"这三种能力**；若实现时发现具体方法名与上表不符，以"能满足该能力"为准替换，不阻塞。**禁止假设存在整库 to_dict。**

## F. RtsRng autoload 异味：v1 **显式接受，不碰 submodule** ✅

**最终建议：v1 明确接受这个 autoload 依赖，记为 "boundary debt #2"，不在 vertical slice 内修，绝不动 addon/submodule。**

- 它已是现役 determinism 依赖，L2 battle 复用它能直接拿到 replay-safe RNG，零成本。
- "把 RNG 提进 core/stdlib" = 改 submodule + bump pointer + 回归全套 determinism/replay smoke，**纯粹是 scope 爆炸**，与 vertical slice 无关。
- v1 唯一动作：在 handoff 写明"L2 战斗 determinism 依赖 `RtsRng` autoload（来自 rts example），这是已知分层债，后置清理"。如果哪天真要还债，是独立 milestone，不混进 L2 slice。

## G. 六 NPC：撤掉"纯 stub"，定义 minimal-real 地板 ✅

Codex 对。既然完成门槛把"**NPC systems**"列为一个验收面，那"开面板 + 占位文案、零机制"对 Guild/Cultivation 太薄——它们至少要**走通 handler 契约 + 一次可观测的 PlayerState 读/写**，才算"NPC system 这一面真的接上了"。调整为三档**都有 real 行为**，区别只在机制厚度：

| NPC | v1 档位 | minimal-real 地板（都要可 headless 断言） |
|---|---|---|
| Trainer | 🟢 FULL | 触发 battle → 消费 result → 发 gold/exp → 回写 |
| Shop | 🟢 FULL | 扣 gold ↔ `create_item` 进 bag |
| Adopt/Release | 🟡 LITE | roster `append`/`erase` 一条 entry（顺带演练 save 往返） |
| Training | 🟡 LITE | 扣 gold → bump 一条 entry 的 persistent_stat/exp |
| **Guild** | 🟢 **MINIMAL-REAL（原 STUB 升级）** | 走 handler 契约 + **读/写一个 PlayerState flag**（如领取一次性 join 奖励 / 记录 `guild_joined=true`），面板可极简 |
| **Cultivation** | 🟢 **MINIMAL-REAL（原 STUB 升级）** | 走 handler 契约 + **一次 gold→progression 的真写**（如花 gold 加一点 player-level progression 计数），机制可单行 |

**规则**：v1 没有"纯占位"NPC；地板 = 同一个 `InkMonNpcHandler.on_interact(session)` 契约 + 至少一次可断言的状态变更。机制深度可后置，但"接上了"必须 headless 可证。

## H. UI gate 对实现顺序的影响：数据层先行、UI 面后置 ✅

**硬分线：**

- **可以先做、纯 headless、无需 mockup**：`InkMonGameSession`/`PlayerState`（含 save/load 往返）、roster→battle 快照投影、battle 发奖回写、NPC handler 的**数据契约**部分、serializer。→ slice 步骤 1、2 全程 headless，**先建脊柱**。
- **必须先 imagegen mockup + DevAgent runtime gate**：overworld 移动**表现面**、每个 NPC **菜单/面板**、Shop UI、任何 Control 子树交互。→ slice 步骤 4 与 5/6 的 UI 半边，**停下来走"讨论→mockup→Godot 实现→DevAgent 实测"三段 gate**。
- **AppRoot 状态机（步骤 3）**：逻辑可 headless 驱动 create/tick/destroy，但因为是**首个新 L2 scene**，需 DevAgent adapter 跑一次 runtime gate（非 imagegen，是 scene 真起得来的验证）。

口诀：**data layer 不画图直接写；任何玩家会看到的像素，先 mockup 再写。**

---

# 接口级草案

## §1 会话与入口（A/B 落地）

```gdscript
# scenes/inkmon-main/app_root.gd —— 单入口状态机，挂在 InkMonMain.tscn 根
class_name InkMonAppRoot extends Node

enum AppState { OVERWORLD, BATTLE, NPC_MENU }

var session: InkMonGameSession          # AppRoot owns it
var _state: AppState
var _active_instance_id: int = -1       # 当前被 tick 的 GameWorld instance

func _ready() -> void:
    session = InkMonGameSession.new()
    session.begin()                     # 内部: ItemSystem.reset_session + configure_domain + 建逻辑容器
func enter_battle(encounter: InkMonEncounterSpec) -> void   # → 见 §3 数据流
func _process(delta) -> void:           # 只 tick _active_instance_id 对应 instance
```

```gdscript
# InkMonGameSession —— 非 autoload，可被 headless 直接 new()
class_name InkMonGameSession extends RefCounted   # 或 Node，若需 signal/树

var player_state: InkMonPlayerState
var _inventory_map: Dictionary           # logical_name(String) -> container_id(int)，不进存档裸 id
func begin() -> void
func end() -> void
func to_dict() -> Dictionary             # = { "player": player_state.to_dict(), "inventory": <serializer 输出> }
func from_dict(d: Dictionary) -> void
```

> headless test：`var s := InkMonGameSession.new(); s.begin(); ...; s.to_dict()==reload` —— 不依赖任何 autoload 全局态。

## §2 RosterEntry → BattleUnitSnapshot → BattleConfig（D）

### §2.1 `InkMonRosterEntry`（持久，存档内）
```gdscript
{
  entry_id: int,                  # session 内稳定，存档内持久
  species: StringName,
  stage: int,
  role: StringName,               # tank / dps / support ...
  elements: Array[StringName],
  level: int, exp: int,
  persistent_stats: {             # 成长后基线（progression 已折入）
    max_hp: int, ad: int, ap: int, armor: int, mr: int, speed: int
  },
  learned_skill_id: StringName,
  equipment_container_id_logical: String,   # 逻辑名（如 "equip:<entry_id>"），非裸 id；v1 可空
  medals: Array[StringName]       # 静态勋章 id；v1 投影期 fold
}
```

### §2.2 `InkMonBattleUnitSnapshot`（投影产物，**纯值、replay-safe**）
```gdscript
# InkMonRosterEntry.project_to_battle_snapshot() -> Dictionary
{
  source_entry_id: int,           # 回写发奖时定位 roster
  species: StringName,
  role: StringName,
  elements: Array[StringName],
  learned_skill_id: StringName,
  battle_stats: {                 # = persistent_stats ⊕ 装备加成 ⊕ 勋章 fold，已算死
    max_hp: int, ad: int, ap: int, armor: int, mr: int, speed: int
  },
  # 注意: 不含 level/exp —— 成长只影响 battle_stats 数值, battle 内部零感知 progression
}
```

### §2.3 `InkMonBattleConfig`（喂给 battle session instance）
```gdscript
{
  seed: int,                      # 来自 RtsRng / 遭遇生成, replay 锚
  left_roster_snapshots:  Array[Dictionary],   # = 玩家队 project_to_battle_snapshot() 列表
  right_roster_snapshots: Array[Dictionary],   # = 对手队（NPC/野生）同结构
  rules: { ... }                  # v1 可空 / 默认
}
```

**注入点**：`_setup_teams(config)`（`ink_mon_battle_world_gi.gd:161`）优先吃 `config.left_roster_snapshots`，缺省才 fallback `InkMonUnitConfig.get_default_roster`。`InkMonUnitActor._init`（`:36-43`）从 snapshot.battle_stats 注入而非读 stub。

### §2.4 battle result（回写）
```gdscript
# battle.get_result() -> Dictionary
{
  winner_team: StringName,        # "left"/"right"
  survivors: Array[int],          # source_entry_id 列表
  casualties: Array[int],
  per_entry: { source_entry_id: { hp_remaining, damage_dealt, ... } },
  replay_data: <现有 replay 结构>  # 不进存档
}
# PlayerState.apply_battle_result(result) -> 发 gold/exp、按 per_entry 结算掉血
```

## §3 NPC handler 契约（G）
```gdscript
class_name InkMonNpcHandler extends RefCounted   # stub/real 同接口可热替
func on_interact(session: InkMonGameSession) -> InkMonNpcSession
# 每个 NPC（含 Guild/Cultivation）的 on_interact 至少产生一次可断言的 session 状态变更
```

## §4 Inventory serializer 契约（E，implementation-agnostic）
```
能力依赖（仅此三项）:
  - 枚举某容器内 item id 列表
  - 取单件 item 的可序列化快照
  - 在某容器内按快照重建单件
save: 遍历 session._inventory_map 的每个逻辑容器 → 枚举 id → 取快照 → 收 dict（按逻辑名排序）
load: reset_session → 按逻辑名固定顺序重建容器(拿回新 id 重填 _inventory_map) → 按快照逐件重建
禁止: 假设存在 ItemSystem 整库 to_dict / serialize
验证: save→load→断言 (逻辑名集合一致 ∧ 每容器 item config/count 一致)
```

---

# 明确撤回 / 修改的第 1 轮建议

1. **撤回**：~~`PlayerState` 作为新 Autoload~~ → 改为 **`AppRoot` owns `InkMonGameSession`，session 内含 `InkMonPlayerState`，非 autoload**（A）。连带 Rejected-alt #3 收紧为"static 和 autoload **都不用**于玩家档，用 session-owned"。
2. **撤回**：~~`project.godot` 的 `run/main_scene` 指向 AppRoot、替换 `Simulation.tscn` 入口~~ → vertical slice 期间 **`project.godot` 不动**，AppRoot 走独立 `InkMonMain.tscn` 入口，切换留到收口（B）。
3. **修改**：Guild / Cultivation 从 **⚪ STUB** 升级为 **🟢 MINIMAL-REAL**（走 handler 契约 + 一次可断言状态写），v1 无纯占位 NPC（G）。
4. **修改**：`InkMonBattleWorldGI` 第 1 轮说"概念上正位" → 收紧为**名义边界规则**：现在只加一行文档注释消歧义，**不要求改名**；改名是后置 rename-only commit（C）。
5. **修改**：ItemSystem 那段从"列方法名" → 改为 **capability contract + 验证点**，并显式标注"**无整库序列化，须 L2 自组合**"（E）。
6. **明确化（非撤回）**：RtsRng 从"Codex 须选一个" → 收敛为**单一裁决：v1 显式接受、不碰 submodule、记为 boundary debt #2**（F）。

---

# 最小 handoff 章节结构（建议 Codex 落地用）

```
0. 两条地基事实
   0.1 InkMonBattleWorldGI 是 battle session 非 the world（名义边界规则, C）
   0.2 GameplayInstance 是 RefCounted, end() 即销毁 → 持久态不挂 instance

1. 存活层级与属主
   1.1 三层: InkMonGameSession(含 PlayerState, 非 autoload) / AppRoot 状态机 / 两类 instance
   1.2 入口策略: InkMonMain.tscn 独立入口, project.godot 不动 (B)
   1.3 battle↔overworld 数据流 (§3 流程)
   1.4 battle 最小改造 (_setup_teams 吃 snapshots)

2. 数据模型与投影 (接口级草案 §2 全量字段)
   2.1 RosterEntry  2.2 BattleUnitSnapshot  2.3 BattleConfig  2.4 result 回写

3. Inventory / gold / save-load
   3.1 ItemSystem capability contract (E, 三能力 + 禁整库 to_dict)
   3.2 逻辑名→container_id 映射存档, 非裸 id
   3.3 存档根 = session.to_dict(); v1 不存战斗中途

4. NPC 契约 + 六系统档位 (G, 含 Guild/Cultivation minimal-real 地板)

5. Medal/team-passive: v1 投影期静态 fold, player-level 属主记 gap

6. 已知债 (debt registry)
   #1 naming: BattleWorldGI 改名后置
   #2 RtsRng autoload 依赖 example, 后置清理 (F)
   #3 Web bridge / main_scene 切换决策后置 (B)

7. First slice (7 步, 标注每步 headless / mockup+DevAgent gate, H)

8. 风险与未决分歧 (instance 拓扑 / 投影边界 / 存档粒度 / UI gate 纪律)
```

---

需要我把 **§2 投影函数**（`project_to_battle_snapshot` 的勋章/装备 fold 具体算法）或 **§1 AppRoot 状态机的 instance tick 切换时序**展开成 Codex 可直接照抄的实现级 spec 吗？这两块是下游最容易各自发挥跑偏的地方。
