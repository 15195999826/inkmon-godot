# 统一 live-actor 数据模型（主游戏）

- Status: accepted（2026-06-03 grill-with-docs 设计轮敲定）
- **已决策、未实现** —— 代码仍是旧的 `InkMonGameSession`/entry/投影模型；本 ADR 是迁移目标，实现前 `main-game-architecture.md` 相关章节描述的仍是现状。

## Context

主游戏（hex 行走世界 + 战斗 + 存档）现有数据模型是 **data-first / 投影式**：

- 持久层 `InkMonGameSession` → `InkMonPlayerState` 持 `Array[InkMonRosterEntry]`（纯数据，无 stats/HP）。
- 进战斗时 `project_battle_roster` 把 entry **投影**成临时 `InkMonUnitActor`（snapshot Dictionary → `from_battle_snapshot`），战斗完 `_reset_battle_state` 销毁。
- 结果经 `apply_battle_result`（按 `source_entry_id` 映射）**摘要回写** entry（gold + exp）。
- 物品/装备容器引用住 `InkMonGameSession.inventory_map`（logical name → `ItemSystem` 容器 id）；装备数值在投影期 `_fold_equipment_stats` 重算。

这套 `InkMonGameSession` / entry / 投影 / 回写是 AI 在落实需求时自建的中间层，**未与项目所有者对齐**，且与所有者的心智模型相悖 —— 也与 LGF `WorldGameplayInstance` 的本意（"World 长期持有 actor / grid / systems，战斗是短命 procedure"）相悖。所有者的 UE 项目 DESKTK（同源 InventoryKit 插件）走的也是 actor-centric：库存/装备是挂在 Character 上的 `UActorComponent`，物品实例住中央 `UInventoryKitItemSystem`（WorldSubsystem）。

## Decision

改为 **统一 live-actor 模型**：游戏世界的一切实体（player / NPC / 出战 InkMon）都是**常驻 GI registry 的活 `InkMonWorldActor` 子类**，从读档活到存档；battle 是跑在这些活 actor 上的短 procedure，原地改其状态，**无投影、无快照、无回写**。

- **序列化契约**：读档 = 存档数据 → 建 actor；写档 = actor → 存档数据。每个持久 actor 自序列化其持久切片。
- **存什么**：身份 + 选择 + 进度（`species_id` / `level` / `exp` / `skill_slots` / `engravings` / 装备）+ **当前 HP（carryover，跨战斗 + 跨存档保留）**；**不存**派生六维（读档时从 `f(species, level)` 重算）。
- **玩家级数据**（gold / progression / medals）→ 挂 **PlayerActor**；bag 容器 → PlayerActor；每只 equipment 容器 → 各 UnitActor（镜像 UE InventoryKit 的 container-as-ActorComponent）。
- **物品实例**仍住中央 `ItemSystem` autoload（按 id），各 actor 持容器 id 引用 —— 这是 InventoryKit 原生设计（UE 同源项目一致），不是要消除的"全局"。装备效果在 **equip 时**应用到活 actor，不再投影期折叠。
- **序列化编排**归 **Host 控制面**（遍历 registry 全部 actor + `ItemSystem` 物品仓库 → `InkMonSaveFile` 落盘）。
- **删**：`InkMonGameSession` / `InkMonPlayerState` / `InkMonRosterEntry`（数据对象）/ `project_battle_roster` / `from_battle_snapshot` / `apply_battle_result`（摘要回写）/ `_fold_equipment_stats` / `inventory_map`。
- **留**：`InkMonSaveFile`（纯磁盘 IO）。
- **死亡语义（数据模型层）**：UnitActor HP 归零后**留 registry**（`is_downed` / HP=0）、**进存档**，不移除。revive / permadeath stakes / 全灭→game over = 游戏设计层，待 `game-vision.md` 游戏循环成文再定。

## Considered Options

- **A. 维持现状（data-first 投影式）** —— entry 纯数据、每战投影临时 actor、摘要回写。优点：存档轻、stats 纯派生、actor 不跨战斗持久。缺点：两套表示（entry + actor）、投影/回写机器、偏离 LGF World-owns-Battle、与所有者心智不符。
- **B. 统一 live-actor（本决策）** —— actor 即唯一表示，跨战斗持久，自序列化。优点：单一表示、贴 LGF 本意、无回写、贴所有者 UE 同源项目。缺点：actor 跨战斗持有运行时态（current HP 进存档）；序列化 LGF actor 需各自定义持久切片。

## Consequences

- 取代/改写 `main-game-architecture.md`：§8c（entry 对象删，持久切片折进 actor；新增 current HP 进存档）、§2③（无投影，battle 跑活 actor）、§3（actor 是 runtime 真相）。§8（结果不自动落盘）仍成立 —— 结果在 actor 上，手动存档才落盘。
- §8c 的**核心极简原则存活**：仍只序列化"身份 + 选择 + 进度"、派生六维不入存档 —— 只是承载它的从独立 entry 变成 actor，派生时机从"投影"挪到"读档建 actor"。
- 原 god-object 拆分计划（#3）的前提（session = 数据层、投影给 battle）被本决策取代；GI 内部域从"overworld / battle / session 三块"简化为"overworld / battle 两域 + GI 作 registry / 序列化根"。数据模型重设计是 #3 的前置。
- **待定（未随本 ADR 决议）**：单位 HP 归零的死亡语义（permadeath / 复活 / 留 0 待治疗 —— 决定死 actor 是否留 registry、是否进存档）；PlayerActor / UnitActor 具体类型与继承位；actor 持久切片的序列化形状。
