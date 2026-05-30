核验完毕,三处技术声明里有一处**失真**,是唯一 blocker。其余共识可签。

---

## 1️⃣ 是否同意作为 handoff 共识

**总体同意 A–H 全部裁决**,但 §2 的**注入点描述有一处必须改写后才能签**(blocker):

🔴 **Blocker — §2.2/§2.3 "注入点"对当前代码的描述是错的**

草案写:
> 注入点:`_setup_teams(config)` 优先吃 `config.left_roster_snapshots`...`InkMonUnitActor._init`(`:36-43`)从 snapshot.battle_stats 注入而非读 stub。

实际代码链路(已核实):
- `_setup_teams` 吃的 key 是 **`left_roster`**(不是 `left_roster_snapshots`),且值是 **unit_key 字符串列表**,不是 snapshot — `ink_mon_battle_world_gi.gd:162`
- `_create_team_actor(unit_key, team_id)` → `InkMonUnitActor.new(unit_key)` **只收一个字符串** — `:170-173`
- `InkMonUnitActor._init(p_unit_key)` 自己回头去 `InkMonUnitConfig.get_unit_config(unit_key)` 把 stats 从静态表拉出来,`:36-43` 是 `set_*_base(stats[...])` — **stats 来源写死在 config 表里**,`:24-33`

所以"从 snapshot 注入"**不是 :36-43 改几行**,而是要新开一条 actor 构造路径(接受 snapshot dict、绕开 `InkMonUnitConfig` 自加载),并同步改 `_create_team_actor` + `_setup_teams` 的 key 名与签名。这是一处真实的接口改造,下游若照草案"换几行"会直接撞墙。

→ **handoff 必须把 §2.3 注入点改写为**:"新增 actor 构造路径接受 `battle_stats` 投影值,与现有 `unit_key→InkMonUnitConfig` 默认路径并存(default 留作 fallback,不删);`_setup_teams` 新增 `*_roster_snapshots` 优先、`*_roster` 兜底。"

🟡 **次要 — snapshot 缺 `hp` 字段**:actor `_init` 同时读 `stats["max_hp"]` 和 `stats["hp"]`(`:37-38`),但 §2.2 `battle_stats` 只有 `max_hp`。需在契约里写死"新战斗 `hp := max_hp`"(snapshot 不带 current hp),否则注入路径会缺字段。

其余 **A/B/C/E/F/G/H 全部同意**,无 blocker。`WorldGameplayInstance` 短命 RefCounted 已核实(`world_gameplay_instance.gd:4` 注释 + extends `GameplayInstance`),0.2 地基事实成立。

---

## 2️⃣ Hard acceptance criteria(可断言、非泛泛)

1. **投影确定性**:同一 `RosterEntry` 连投影两次,`battle_stats` 逐字段相等(纯函数,无随机/无副作用)。
2. **注入真来自 snapshot**:用一个**故意偏离 default 的 stat**(如 `max_hp` 设成非配置表值)起 battle,断言 actor 的属性 == snapshot 值 — 证明走的是注入路径**而非悄悄 fallback 到 config**。
3. **hp 起始契约**:新战斗 actor `hp == battle_stats.max_hp`。
4. **save/load 幂等**:`session.to_dict() → from_dict() → to_dict()` 深度相等,含 `_inventory_map` 逻辑名集合 + 每容器 (item config, count)。
5. **存档无裸 id**:序列化输出里 grep 不到 runtime `container_id` 整数,只有逻辑名。
6. **result 可回定位**:`per_entry` 的每个 `source_entry_id` 都能在 roster 命中;投影链全程不丢 `entry_id`。
7. **instance 拓扑互斥**:任一 tick 只有 `_active_instance_id` 一个被 tick;`battle.end()` 后 `session`/`player_state` 仍存活可读(RefCounted 销毁不带走持久态)。
8. **6 NPC 地板**:每个 `on_interact(session)` 跑完后**至少 1 个** PlayerState/roster/inventory 字段发生可 headless 断言的变更(Guild/Cultivation 含在内)。
9. **回归不破**:改 actor 构造路径后,现有 `smoke_m1_battle.tscn` 仍 PASS(default fallback 未被破坏)。

---

## 3️⃣ 最小安全实现顺序(8 步,全部脊柱先行)

1. `InkMonGameSession` + `InkMonPlayerState` 纯数据 + `to_dict/from_dict` 往返(headless,**不碰 ItemSystem**)。
2. `InkMonInventorySerializer` + `session._inventory_map`,只挂 ItemSystem 三能力(枚举/快照/重建),save→load 往返断言。
3. `InkMonRosterEntry` + `project_to_battle_snapshot()` 纯函数(确定性断言,AC#1)。
4. 改 `InkMonUnitActor` 增 snapshot 构造路径 + `_setup_teams`/`_create_team_actor` 吃 snapshots(保留 default fallback),跑 `smoke_m1_battle` 不回归(AC#2/#9)。
5. `get_result()` + `PlayerState.apply_battle_result()` 用 `source_entry_id` 回写(headless,AC#6)。
6. `InkMonAppRoot` 状态机 + `InkMonMain.tscn` 独立入口,单 instance tick 切换;过一次 **DevAgent runtime gate**(只验 scene 起得来,非 imagegen)。
7. 6 个 NPC handler 的**数据契约**部分(headless 断言状态变更,AC#8),UI 面暂不做。
8. 玩家可见 UI 面(overworld 移动表现 / NPC 面板 / Shop)逐个走 **claude-p 讨论 → imagegen mockup → Godot UI → DevAgent 实测** 三段 gate。

> 1–5 + 7 全 headless 脊柱,6 是首个新 scene 须 runtime gate,8 是唯一像素面。与 H 段口诀一致。

---

## 4️⃣ 硬边界风险检查

| 边界 | 状态 | 说明 |
|---|---|---|
| 不直接调 hex-atb example | ✅ 通过 | 已核实 `InkMonBattleWorldGI extends WorldGameplayInstance`(core);`HexCoord` 来自 `addons/ultra-grid-map`(共享 lib)**不是** hex-atb example。battle scene 自带完整 inkmon-battle 子树,无跨 example import。 |
| 不平行 ItemSystem | ✅ 通过 | serializer 只**组合**三能力,不另起库存系统;契约已禁"假设整库 to_dict"。 |
| 不动 L2 project-level | ✅ 通过 | PlayerState session-owned 非 autoload;`project.godot` 全程不动;medal/team-passive 投影期 fold,不引 player-level LGF attribute owner。 |
| UI / DevAgent gate | ✅ 通过 | data 层先 headless;首个新 scene(AppRoot)走 runtime gate;像素面走三段 gate。 |
| RtsRng 跨 example autoload | ⚠️ 已知债接受 | 是既成 autoload(`project.godot:27`),非新增跨 example 调用,记 debt #2,不碰 submodule — 合规。 |

**唯一残留自查项交给 Codex**:第 4 步给 actor 加 snapshot 构造路径时,**不要顺手从 hex-atb example 借任何投影/stats 工具** — 投影逻辑必须落在 inkmon-battle 或新 L2 层自己写。这是改造期最容易无意识跨界的点。

---

签字前提:把 §2.3 注入点按 blocker 改写 + snapshot 补 `hp:=max_hp` 契约。改完即可作为 M1 handoff 共识。要不要我把**第 4 步 actor 双构造路径**的实现级 spec(新签名 + fallback 分支 + 哪些字段从 snapshot 覆盖)展开?这块是下游最易跑偏的地方。
