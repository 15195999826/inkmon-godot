# L2 主游戏架构 — 当前真相

> 本文 = inkmon-godot **主游戏(L2)代码架构**的当前唯一真相,取代 `.codex-goal/l2-main-game-vertical-slice/Post-M1-World-Architecture-Handoff.md`(那份的几条已被推翻,见下)。
> 范围:主游戏代码结构 / 所有权边界 / 重构方向。**不含**玩法设计(玩法真相在 lab `docs/plan/current/L2/`)、LGF 框架设计(在 `addons/logic-game-framework/docs/`)。
> 来源:2026-05-31 grill-with-docs 会话拍板。

---

## 0. 定位

主游戏架构是**长期地基,认真修**(非一次性脚手架)。下面的"现状 = 错"条目按地基标准要纠正,不是"能跑就行"。

---

## 0.5 主世界运行模型 = 同步 tick + command + 三层 Host (2026-06-01 grill 反转)

> **本节 reverses §1① 的"即时同步移动"与 §4 的"❌ 不借 command queue"。** 主世界改成 dota2-auto-battle 式同步 tick:输入 → command → 逻辑 tick 推进世界态 → 表演据 event 渲染。§1①/§4 的旧表述按本节理解。术语见 `CONTEXT.md`(World Actor 层级 / 主世界 Command·Query / 主世界三层+Host 三条)。

### 三层 + Host

```
┌──────────────────────────────────────────────────┐
│  Host (InkMonWorldHost ← 原 InkMonGameDirector)    │  composition root,在 logic/presentation 之上
│  建两孩子 + 接线(连 command↓ / event↑) +            │  不参与 command/event 对等流
│  生命周期(save/load/new-game/reset = 重建孩子) +     │
│  tick 泵(GameWorld.tick_all(FIXED_DT))              │
└─────────────┬────────────────────────┬─────────────┘
          creates                  creates
              ▼                        ▼
   ┌──────────────────────┐ command↓ ┌──────────────────┐
   │ Logic                │ ◄─────── │ Presentation      │
   │ GameWorld (autoload) │  event↑  │ View3D / HUD /     │
   │  └ InkMonWorldGI     │ ───────► │ drawer / modal     │
   │     └ session /       │          │                   │
   │       world actors /  │          │                   │
   │       systems /       │          │                   │
   │       overworld grid  │          │                   │
   └──────────────────────┘          └──────────────────┘
```

- **两轴别混**:数据流(运行时)= **双向**(command 下 / event 上 ⇒ "感觉平级");代码依赖 = **单向 DAG**(Presentation→Logic;Logic 谁都不依赖、永不引用 UI;Host→两者)。⇒ Logic 是地基,Presentation 长其上,Host 在两者之上;lifecycle 重建归 Host(它建了两孩子),**非**"表演层重建逻辑层"。
- **嵌套两 Host(§6b)**:外 `InkMonMain`(切屏 + 选 session)/ 内 `InkMonWorldHost`(建 world+view + lifecycle)。

### 读写 = CQRS

- **Query(读)= 同步**:UI 渲染直接调 WorldGI 只读方法(roster / gold / near-npc / 列表 enabled)。
- **Command(写)= 异步唯一入口**:UI 改任何游戏/世界/存档态 → enqueue → tick 应用 → 结果经 event/signal 回流 → UI 被动刷(**不读返回值**)。纯 UI 状态(切 tab / 抽屉 / modal / 相机 / 菜单开着)**不算 command**,留表演本地(于是旧 `app_state` 拆成 WorldGI 的战斗 MODE + 表演的面板态)。
- ⚠️ 此 "Command" ≠ battle 层 LGF `Action` / `ABILITY_ACTIVATE_EVENT`,两层独立。上行仍用 WorldGI mutation signal,**不建全局 EventBus**。
- **lifecycle(save/load/new-game/reset)= Host 控台操作,不进 command 队列**(它销毁/重建世界本身):save = `world.capture_to_session()` + `session.to_dict` + IO;load = IO + `session.from_dict` + 重建 world + `world.hydrate_from_session()`。

### tick / 移动模型

- 逻辑 **固定 30Hz**(FIXED_DT)。Host 每帧 `GameWorld.tick_all(FIXED_DT)` → `WorldGI.tick` → 无战斗走 `base_tick` → tick 注册的 System(CommandDrain → Movement);有战斗走基类阻塞 battle 分支(一帧跑完,record-then-playback 不变)。**零 addon 改动**(base_tick + mutation signal 都是基类现成的)。
- **玩家/NPC = `InkMonWorldActor`**(进 GI registry),移动用基类 mutation signal `actor_position_changed` 喂表演。
- **离散跳格 + view 补间**:world actor 逻辑态 = `{cell(=occupant), moving_to, progress∈[0,1), pending_path}`。每 tick `progress += dt/步时长(≈0.22s)`;`≥1` → occupant 跨一格 + emit `actor_position_changed(cell, moving_to)`,view 在两格间补间(≤0.22s)。**逻辑真相永远是离散 hex 格**,只多一个进度标量,**非**连续浮点(sim-nav 不借)。
- **连点重算(latest-wins,方案 A)**:新 command → 走完正在进入的当前格(occupant 自然 flip 到 moving_to)→ moving_to 之后的旧路立刻丢弃换 `astar(moving_to, target)`。view 永不被打断(只补间相邻已提交格)⇒ 零 snap / 零竞态(`_assert_load_during_move` 那类 race 被结构性消灭),表演 correct-by-construction。

### 命名(2026-06-01 grill)

- 主世界代码前缀统一 `InkMonWorld*`(非 `InkMonOverworld*`,待重命名)。
- World actor 层级:`InkMonWorldActor`(持 `hex_position`)→ `InkMonBattleActor`(+ 死亡 / ability)→ `InkMonUnitActor`。玩家/NPC = `InkMonWorldActor`;`hex_position` 从 `InkMonBattleActor` 上移到基类。
- `InkMonGameDirector` → `InkMonWorldHost`(它是 Host,非表演层)。

---

## 1. 三块架构(互不混)

对标 hex-atb-battle:它只有 ② battle 那一块;inkmon 主游戏多了 ① overworld 和 ③ session。

### ① 主世界 (Overworld) — hex 网格世界（现状方向基本对）

> ⚠️ **移动模型已被 §0.5 反转(2026-06-01 grill)**:从"即时同步 `move_actor_to` + tween 追"改为"command → 30Hz tick 逐格推进 → event 驱动 view";玩家从"轻 occupant"升级为轻 `InkMonWorldActor`(仍无 ability/timeline)。本节 occupant/即时移动旧表述按 §0.5 理解。

- 形态:玩家角色行走、承载 6 个 System NPC 的 **hex 网格世界**(= lab 设计真相)。
- 移动:点目标 → **grid 插件寻路** → 沿路径逐步移动 → emit 事件 → 动画。
- **玩家 = 轻 occupant + move 控制器**(2026-05-31 拍板),**不是** battle actor 带 move Ability。借 hex-atb move 的**机制模式**(reserve→落位→emit move 事件→visualizer/tween 动画),不搬 ability/timeline/actor 那套。
- 现状 `InkMonOverworldGrid` + `InkMonOverworldMoveController` + `InkMonOverworldView3D` 正是这条 occupant+控制器路子,**地基对**。
- ⏳ **寻路 delta(已确认,待办)**:现状 `InkMonOverworldGrid.find_path` 是**自写 BFS**;但 `addons/ultra-grid-map/pathfinding/grid_pathfinding.gd` 插件**自带 `astar` / `astar_simple`**。用户要"寻路走 grid 插件" ⇒ 自写 BFS 应替换为插件 astar。(本轮记下,不深挖。)
- ⚠️ **纠正(2026-05-31 hallucination)**:本文档先前写"主世界 hex 是设计错误 / 整套作废 / 改自由移动 3D" —— **用户从未这么说**,是我把被污染的选项描述当成确认。lab CONTEXT 明确主世界 = hex 网格世界。两个提交(`64a8452` / `47e7e73`)的 hex-grid-移动**地基方向对**,只是有 UI 层 race bug(drawer ghost / overlay 层级 / load-during-move),**修 bug,不废地基**。
- ⏳ 未定:player-move 复用 hex-atb move 到什么粒度(Ability 级 vs 纯控制器级)—— 本轮 grill 继续。

### ② Battle — 唯一 world GI 内的 procedure(无独立 battle GI)

**目标模型 = LGF World-owns-Battle(2026-05-31 用户拍板)**:整个主游戏**只有一个** `InkMonWorldGI`(extends `WorldGameplayInstance`)承载逻辑 + 世界数据;**战斗是它内跑的 `InkMonBattleProcedure`,不是独立 GI**(用户原话:"battle 是 procedure 模式,没有 battle GI")。

- ✅ **复用(现状对)**:`InkMonBattleProcedure` + M1 战斗数学(双通道伤害 / 6 元素 / 角色 AI / action / passive)—— 全保留不动。战斗 actor(`InkMonUnitActor`)从 roster snapshot 现造。
- ❌ **合并掉(现状错)**:`InkMonBattleWorldGI`(被 codex 造成"一场战斗 = 一个独立 world 实例,create→destroy")= "战斗 owns 世界"老式;职责并进唯一 `InkMonWorldGI`,战斗只留 procedure。
- **战斗呈现 = record-then-playback**:sim 瞬间同步算完 → 录 timeline(procedure 已在录)→ `FrontendBattleAnimator` 回放(复用 hex-atb animator/visualizer 栈)。**不走 live-tick**:auto-battler 无战斗中干预需求;暂停/0.5-4x 倍速/重看免费;决定性天然;异步 PvP/Web 友好;逆 live-tick 是逆框架。"实时@1x"与"算完回放@1x"画面无差。

> ⚠️ **「唯一 world GI 持两套 grid(主世界 + 战斗)战斗期切 active」= 第一版临时方案,非定稿。** 用户原话:非脑海中最优解,未来再优化;**但不是本次重构核心**(核心 = God object 拆解 + 三块边界 + 职责纪律)。

### ③ Session — 持久存档（独立于 ①②）

- `InkMonGameSession` 持 `roster / gold / progression`,是存档根。
- overworld 与 battle **不互相引用**,通过 session 间接连:
  - 进战斗:从 session 投影 `InkMonBattleUnitSnapshot` 喂给 battle procedure(在唯一 world GI 内起)。
  - 战斗结束:battle result 写回 session。

---

## 2. 数据模型(总纲,细节见 §8c-decision)

- **单只 InkMon 养成深度 = 深度英雄(Dota 向)**:多技能槽 + 6 装备 + 刻印 + 勋章 + 进化 stage。
  - brief 第 16 行"云顶之弈式自走棋"是误导比喻 —— InkMon 不是 TFT 浅棋子。真实形态 = "hex 棋盘上一队 Dota 深度英雄的 ATB 自走战"。
- **核心原则**:存档 entry 只存"身份 + 选择 + 进度",不存"算出的最终值"(技能/stats 同构;细节 §8c-decision)。
- **存档永不需要向后兼容**:`from_dict` 遇旧版直接丢弃重开,不写迁移。⇒ 数据模型可边做边改,不必怕破坏存档。

---

## 3. 唯一真相 = 运行时内存,不双写

- session 内存即真相;**save 序列化一次,load 反序列化一次,中间不来回同步**。
- ❌ 现状作废:`app_root._set_player_coord()` 每步往 `session...player_coord` 写 = 持续双写。正解:运行时世界态只住主世界运行层(world GI / grid);存档字段只在 save/load 两端读写。
- (这条同时消灭了本会话审出的"player_coord 三处不一致"根因。)

---

## 4. 职责纪律(借自 `no-game-no-life`,取形不取器)

借**职责边界纪律**,不照搬机制:

1. 逻辑层不引用 UI。
2. UI 不直接改逻辑(走间接)。
3. 规则按模块分块(NPC 规则住进各 handler)。

- 上行(逻辑→UI)= signal:battle 用 WorldGI 内建 mutation signal;overworld 用普通 Godot signal。UI connect 被动刷新。
- ⚠️ **部分反转(§0.5, 2026-06-01 grill)**:主世界**改为采用 command(队列)+ System 驱动同步 tick**(见 §0.5),此处"不借 Command queue"已作废。仍**不借**:全局 EventBus autoload(上行仍用 WorldGI mutation signal,不建第二套总线)。"System 基类"= 复用 LGF `base_tick` 注册的 `System`,非另造一套。

---

## 5. NPC handler 契约

- **✅ 已拍板(用户原话"handler 自含逻辑,只收 session")**:6 handler 统一**只收 `session`**,规则住 handler 内;纯数据 NPC(shop / cultivation / guild / advancement / release_adopt)直接读写 session;handler **不碰 UI / flow**。
- ❌ 现状作废:`run_action(app_root)` 让 handler 反向持 God object —— 切断。
- ⏳ **未拍板(我的提案,非用户决定)**:training→战斗这种"要触发流程"的 NPC 怎么表达 —— 我提过"返回 `intent`(start_battle+config)由场景层解释起 battle procedure",但该问题当时被 app_root 困惑打断、**用户未确认**。返回形状(现状 `{ok, message}` vs 加 intent)留 §9。

---

## 6. UI 搭建

- 全 `.tscn`(尽量编辑器设计),代码只填文字 / 绑数据,动态列表(roster/bag/NPC 行)用 instantiate 组件场景。
- UI 在 presentation 层,只订阅 signal / 调窄 API,不直接改逻辑。
- ❌ 现状作废:100% 代码 `Button.new()` 搭 UI + 零 UI .tscn。

---

## 6b. 场景入口 / 接线层（2026-05-31 拍板）

- **薄场景 Node = 接线员**,不是 God object:只做 ① 开机(`GameWorld.init` + 建 world GI)② 接线(GI signal → UI view;玩家输入 → 控制器)③ 切台(主世界 ↔ 战斗 ↔ NPC ↔ save)。**零规则、零数据、零 UI 自绘**。
- 对标 `demo_frontend.gd`(LGF 薄场景样板):inkmon 主场景 = 它多接几路(主世界 view / HUD / NPC 抽屉 / save-load / 持 `InkMonGameSession`)。
- **场景分层 = 两层(2026-05-31 ngnl 式)**:
  - **外层 screen 路由**(ngnl `inner_main` 式):标题 → 菜单 → 进游戏 的大场景切换。v1 可先 stub(直接进游戏),但结构留好,将来加标题/菜单不必重接入口。
  - **内层游戏导播**:只管游戏内(主世界 ↔ 战斗 ↔ NPC ↔ save),零规则零数据零 UI 自绘。
- **入口落定(2026-05-31)**:删 `app_root` God object 概念,换 LGF demo_frontend 式薄场景脚本;**project.godot `run/main_scene` 切到 InkMonMain**;`Simulation.tscn` 退成纯 web 桥(或废弃)。`app_root` 是 codex 无中生有的 controller 层(LGF 模型里没有),用户明确"没有这个概念"。

## 7. God object 拆解

`app_root.gd`(现 1593 行)按职责拆:

| 现状塞在 app_root 的 | 去向 |
|---|---|
| NPC 规则(cultivate/advance/buy/adopt) | 各 NPC handler(收 session) |
| 战斗实例生命周期 | 合并:唯一 InkMonWorldGI 内的 InkMonBattleProcedure(无独立 battle GI) |
| overworld grid/move | 保留地基(hex grid + 控制器),寻路换 grid 插件 astar;UI race bug 修掉 |
| 全部 UI 搭建 | presentation view(.tscn) |
| 持久数据 | session |

场景根 Node 只剩:**wiring(建 world GI/连 signal/挂 UI)+ 输入转发 + flow 切换(主世界 ↔ 在同一 world GI 内起 battle procedure)**。

---

## 8. 两个被审提交的处置(纠正先前结论)

- `64a8452`(hex 主世界)+ `47e7e73`(移动动画修复):**地基方向对,保留**。hex-grid + grid 寻路 + 移动动画正是 §1① 要的(参考 hex-atb move)。
- 那轮审出的 bug(drawer ghost / overlay 层级 / load-during-move)是 **UI 层真 bug,要修**,但不牵连 hex-grid-移动地基。
- ⚠️ 先前本文档写"这两个提交随 hex overworld 作废一起删除" = 基于 hallucination 的错误结论,已撤销。

---

## 8b. 存档(2026-05-31 拍板)

- **手动存档点 + 可重刷**(主机 RPG 式,非防 save-scum):玩家开 save 菜单才存,**可多槽**,允许读档重刷战斗/养成。
- ⇒ 战斗结果**不自动落盘**:`apply_battle_result` 只改内存 session;玩家不手动存就不持久。读旧档 = 回到上次手动存的内存态,重打战斗结果可不同。
- session 内存仍是唯一真相;save = 某刻 `to_dict` 写一个槽,load = 读某槽 `from_dict` 重建内存(§3 不双写不变)。
- 现状 `save_game/load_game` 是单文件无槽 + 无菜单触发;改成多槽 + save 菜单。`InkMonInventorySerializer`(逻辑容器名 capture/restore)模式对,保留。

## 8c-decision. RosterEntry = 存身份+选择+进度,不存算出的最终值(2026-05-31 拍板)

统一原则(技能 + stats 同构):**entry 只存"这只是谁 / 选了什么 / 练到哪",不存"由此算出的运行时数值"**。

**技能槽 = 存"哪槽选了哪技能",不存变异数值(A 物化但只到 skill_id 粒度)**:
- 结构:`skill_slots: Array[{slot_index:int, skill_id:String}]`。
- **出生唯一随机 = "每槽 roll 中哪个技能"(2026-05-31 用户拍板,原话"我从来没说过要技能变异")**:技能 roll 只决定哪槽哪技能,**技能本身无数值变异**。个体独特性来自 ①槽内 roll 选中谁 ②刻印 ③装备 —— 不含"同技能不同数值"。entry 不存 per-skill variance。
  - ⚠️ 这条与 lab ADR-0004 "出生每槽 roll **并带个体数值变异**"原文**冲突**。冲突源 = 我(claude)误读 ADR 并反复追问强加,非用户意图。**以用户口径为准:无技能变异。**
  - ⏳ lab 待同步(lab 仓):ADR-0004 那句"个体数值变异"应删或标废。
  - 未来若真要"收集刷个体"质感:存档不向后兼容 ⇒ 届时给 skill_slot 加 variance 字段零代价,但**不是当前设计意图**。
- 读档直接读 `skill_slots`,不依赖技能池在场,不重 roll。
- 进化(模型 B):旧 slot 保留;新阶段新增 slot → roll 一次写 skill_id;部分技能 X→X2 = 改对应 slot 的 skill_id。
- ⇒ 替换现状 `learned_skill_id`(单数)。`project_to_battle_snapshot` 改投影 skill_slots。

**进化 = species 字段改写 + 进化链表(2026-05-31 拍板,读法 A)**:
- 进化时 entry 的 `species` 改写成下一形态(`cinder_kit` → `cinder_fox` → ...);需一张**进化链映射表**(species → 下一形态 + 阈值)。
- 每形态 = 一条**独立 species 数据**(独立立绘/名/属性档/技能池/槽数),lab"每阶段为独立物种"字面落地;canon/L3 按"一物种一条目"生成。
- "同一只"靠 `entry_id` 认(进化是变身非换只,entry_id 不变);`stage` 字段仍存(冗余但便于直接读阶段/驱动阈值逻辑)。
- ⇒ 属性派生 key = `species`(已编码形态),即 `f(species, level)`(下一条 stats 的 stage 参数随之简化)。

**stats = 派生,只存 level,不存六维**:
- entry 存 `{species, stage, level, exp}`;六维属性 = `f(species, level)` 运行时派生(species 已编码形态/阶段),**不进 entry**。
- 培养(花金币)= +level(+刻印),不直接改属性数。同物种同阶同级 base 相同;个体独特性来自技能选择/刻印/装备(合 lab)。
- ⇒ **删现状 `persistent_stats` 字段**(现状存全套六维 = 物化派,与此冲突,要改)。`project_to_battle_snapshot` 的 `battle_stats` 改为派生算出。
- ⏳ 依赖未定项:`f(species,stage,level)` 公式 = lab 标"等级是否线性加属性=待定"(见 §9)。v1 可先用最简单线性,公式调整不影响 entry 结构(只存 level)。

**刻印 = v1 只做"技能强化"(2026-05-31 用户原话:"第一版只做：技能强化(让某个技能增加额外效果或者数值增强)")**:
- 用户给的是**效果语义**:刻印强化**某一个具体技能**(给它加额外效果 / 数值增强)。
- ⛔ **v1 不做**(以下是我之前自行扩写、已删):属性面板增益 buff、队伍光环、技能强化以外的杂项。原"队伍光环撞 LGF gap"整段基于我**虚构的例子**,删除。
- ⏳ **实现框架(我的推断,未经用户拍板)**:倾向 LGF 被动 ability(`grant_ability`,hook 目标技能的事件做强化,与 `InkMonDamageMathPassive` 同款);但"改某个具体技能"也可能更适合做成挂在该 skill_slot 上的 modifier —— 实现方式留实现时定。
- **存储形状(2026-05-31 用户拍板)**:`engravings: [{engraving_id, target_slot}]` —— 每条刻印显式指明它强化哪个 skill_slot(`target_slot` 对应 `skill_slots[].slot_index`)。
- ⇒ 刻印**不进 battle_stats 数值折叠**(它改技能行为,不是六维加成)。

**装备 = LGF Phase-G 系统(2026-05-31 用户拍板,非自写)**:
- 用 lomolib Phase-G:`EquipmentManager` + `StatAggregator`(flat 累加,按 source 可移除)+ `AbilityGrantor`(grant/revoke 委托项目层回调)。
- Phase-G `equip()` **一次同时**读 item config 的 `stats`(→数值聚合)和 `granted_abilities`(→能力授予)。⇒ **装备天然既能加数值又能 grant 能力**;"v1 装备要不要 grant 能力"是伪问题(Phase-G 本就两条都给)。
- ❌ **现状对齐债**:`InkMonItemDomain.get_item_stat_mods`(空 stub)+ 自写折叠 = 重复造 Phase-G 已有轮子。**弃 stub,接 Phase-G `EquipmentManager`**。

**battle_stats 折叠(简化后)**:
- `battle_stats = base(f(species, level)) + StatAggregator 累加的装备 stats`。flat 加法。
- ability 来源(不进 stats 折叠,走 grant):skill_slots 技能 + 普攻 + move + 刻印被动 + 装备 granted_abilities(Phase-G)。
- 折叠发生在 `project_to_battle_snapshot`(投影时算,不存进 entry,合 §3 不双写)。
- ⏳ 刻印不占 6 装备槽(培养来源,非商店买),所以走**独立 grant 列表**还是复用 Phase-G AbilityGrantor 模式 = 实现细节,留实现时定(不影响存档结构 = engravings:[id])。

**RosterEntry v1 目标字段(本轮 grill 收敛)**:
```
{ entry_id, species, stage, level, exp,
  skill_slots: [{slot_index, skill_id}],   # 替换 learned_skill_id 单数; 无 variance
  engravings: [{engraving_id, target_slot}], # 刻印(v1 只强化某技能); target_slot 指 skill_slots 的 slot_index
  equipment_container: "equip:<id>",        # 逻辑容器名(现状已有, 对)
}
```
删:`persistent_stats`(六维改派生)、`learned_skill_id`(改 skill_slots)、`medals`(移到 PlayerState=玩家级)。
六维 stats = `f(species, level)` 运行时派生,不进 entry。

## 8c-gap. 现状 RosterEntry 改动清单(对照 §8c-decision)

现状字段:`entry_id / species / stage / role / elements / level / exp / persistent_stats(六维) / learned_skill_id(单数) / equipment_container / medals`。

- ✅ 保留:`entry_id / species / stage / role / elements / level / exp / equipment_container`。
- 🔧 改:`learned_skill_id`(单数)→ `skill_slots: [{slot_index, skill_id}]`(无变异)。
- ➕ 加:`engravings: [{engraving_id, target_slot}]`(刻印,v1 **只强化某技能**,来源培养;target_slot 指 skill_slots 的 slot_index;实现框架未定,见 §9)。
- ❌ 删:`persistent_stats`(六维 → 运行时 `f(species, level)` 派生,不进 entry)。
- ↗️ 移:`medals` → `InkMonPlayerState`(勋章是**玩家级**,非单只;影响所有 InkMon,对标 TFT 海克斯)。注:玩家/队伍级属主是 LGF 框架 gap(Post-M1 handoff §6),但存档层面 medal 列表归 PlayerState 明确。

## 9. 待用户给设计后再定(本轮 grill 未覆盖)

- **PlayerState 结构**:`medals`(玩家级,刚从 entry 移来)+ `progression`(现状无类型 Dict 袋子,key 随手加)要不要类型化 —— 数据模型仅剩这块。
- **主世界双 grid 共存的最终形态**:第一版临时方案 = 唯一 world GI 持两套 grid 切 active(§1② 注),用户明确非最优、未来优化、非本次核心。
- **`f(species, level)` 属性公式**:lab 标"等级是否线性加属性=待定";v1 可先最简单线性,公式调整不影响 entry 结构(只存 level)。
- **player-move 复用 hex-atb 的粒度**:occupant+控制器已定(§1①),控制器内部多大程度照搬 hex move 的 action/event 分阶段,未细化。
- **NPC「要触发流程」的返回机制**:training→战斗怎么从 handler 表达(我提的 intent 方案未经用户拍板,§5)。含返回形状(`{ok,message}` vs 加 intent)+ 谁消费 + 起 battle procedure 的调用链。
- **刻印的实现框架**:存储形状已定 = `[{engraving_id, target_slot}]`(§8c);**未定** = 实现走 LGF 被动 ability(hook 目标技能事件)还是挂在 skill_slot 上的 modifier(均我的推断,未拍板)。
