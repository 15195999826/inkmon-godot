# 主游戏架构 — 当前真相

> 本文 = 本仓**主游戏代码架构**的当前唯一真相。
> "主游戏" = 在 LGF 框架(`addons/logic-game-framework/`)之上自建的那一层:hex 行走世界 + 战斗 + 存档(git 历史里代号 "L2",本文不再用代号)。
> 范围:主游戏代码结构 / 所有权边界 / 运行模型。**不含**玩法数值设计(那部分真相在 lab 仓 inkmon-lab)、LGF 框架设计(在 `addons/logic-game-framework/docs/`)。
> 历史轨迹归 git;本文只描述现状。

---

## 0. 定位

主游戏架构是**长期地基,认真修**(非一次性脚手架)。

> 数据模型 = **统一 live-actor**（[adr/0001](adr/0001-unified-live-actor-model.md)，2026-06-03 落地）：游戏世界一切实体（玩家 / NPC / 出战 InkMon）都是常驻 `InkMonWorldGI` registry 的活 `InkMonWorldActor` 子类，从读档活到存档；battle 是跑在这些活 actor 上的短 procedure，原地改其状态，**无投影 / 无快照 / 无回写**；存档 = 各 actor 自序列化持久切片（含 current HP carryover）。详见 §2③ / §3 / §8c。

---

## 1. 主世界运行模型 = 同步 tick + command + 三层 Host

主世界采用 dota2-auto-battle 式同步 tick:输入 → `submit(command)` → 逻辑 tick drain 推进世界态 → 表演据 event 渲染。术语见 `glossary.md`(World Actor 层级 / 主世界 CQRS 三通道 / InkMonWorldCommand / IWorldQuery / 主世界三层+Host / InkMonWorldPresentation)。

### 三层 + Host（理想图）

```
外层 Host: InkMonMain (screen router) — 标题/菜单/选 session,建内层 (v1 直接进游戏,结构留好)
                        │ creates
                        ▼
╔═══════════════════════════════════════════════════════════════════════╗
║  Host (InkMonWorldHost) — composition root, 在 Logic/Presentation 之上    ║
║  ◇ 不在 CQRS 调用路径上 (不发 Query / 不收 Event), 但:                      ║
║  ① composition  建 Logic GI + Presentation 两孩子 + 接线 (signal→刷新)     ║
║  ② 控制面(Host 专属, 非 CQRS, 单向 Host→Logic):                            ║
║     · lifecycle  save/load/new-game/reset = 销毁/重建两孩子               ║
║     · flow       起/收 battle procedure; app_state 派生 (非独立状态机)      ║
║     · tick 泵    每帧 GameWorld.tick_all(FIXED_DT)  ◄── 命令生效时机在此     ║
╚═══════════╤═══════════════════════════════════════════╤═══════════════════╝
        creates                                      creates
            ▼                                            ▼
┌────────────────────────────┐                ┌──────────────────────────────┐
│ Logic (地基 · 不依赖任何上层)   │                │ Presentation                  │
│ GameWorld (autoload)        │                │ InkMonWorldPresentation (节点) │
│  └ InkMonWorldGI            │                │  持 View3D / HUD / drawer /    │
│    ┌ 两张脸 (facade seam):   │                │     modal / InkMonWorldPanelView│
│    │  concrete  → Host/内部  │                │  + layout/animation/build/     │
│    └  IWorldQuery → 表演只读  │                │     refresh                    │
│    持有:                     │                │  只握 IWorldQuery + submit     │
│     player_actor + roster    │  ① Query 同步读 │  绝不见 concrete GI / 域类型   │
│       (活 actor = 序列化根)    │ ◄────────────── │  (IWorldQuery facade 对象,见注)│
│     world actors             │   (IWorldQuery) │                              │
│     systems                  │   (IWorldQuery) │                              │
│      (CommandDrain→Movement) │                │                              │
│     overworld grid (域)       │  ② Command 异步 │                              │
│     npc handlers             │ ◄────────────── │                              │
│     _command_queue           │  submit(Command)│                              │
│      持 InkMonWorldCommand 对象│                │                              │
│      tick drain: cmd.apply(gi)│  ③ Event 上行    │                              │
│     (battle procedure)        │ ──────────────► │  (被动刷新, 不读返回值)        │
└────────────────────────────┘  mutation signal └──────────────────────────────┘
```

- **三通道(运行时数据流)**:① **Query** = 表演经窄 `IWorldQuery` facade **同步读**(roster/gold/near-npc/npc actions);② **Command** = 表演 `submit(InkMonWorldCommand)` **异步入队**,Host tick drain 时 `cmd.apply(gi)` 生效;③ **Event** = Logic mutation signal **上行**,表演被动刷新。
- **两轴别混**:数据流(运行时)= **双向**(command 下 / event 上 ⇒ "感觉平级");代码依赖 = **单向 DAG**(Presentation→Logic;Logic 谁都不依赖、永不引用 UI;Host→两者)。⇒ Logic 是地基,Presentation 长其上,Host 在两者之上;lifecycle 重建归 Host(它建了两孩子),**非**"表演层重建逻辑层"。
- **Host 不在对等流上,但握命令生效时机**:Host 不发 Query、不收 Event(那是表演↔逻辑的事);它持**控制面**(lifecycle/flow/tick,单向 Host→Logic,非 CQRS),且 Command 的**生效时机 = Host 的 tick 泵 drain 那一刻**。
- **GI 两张脸(facade seam)**:Host/内部直接持 concrete `InkMonWorldGI`(含写/控制面);Presentation 只持一个独立的 **`IWorldQuery` facade 对象**(`RefCounted`,私有包 gi,只转发只读 query + `submit(cmd)`)。`IWorldQuery` 结构仿 LGF `BaseGeneratedAttributeSet`(持底层对象 + 暴露受控表面),但**无 `get_gi()` 逃逸口** → 表演**物理上够不到** concrete GI / flow / lifecycle(GDScript 无 interface 关键字 + GI 单继承位被占,故用此 Facade 对象实现"持接口不持实现")。⇒ 对 Presentation 是**结构隔离**(非纯约定级);Host 因合法持 concrete GI,其穿透仍靠纪律。mutation signal 由 Host 连 `gi.signal → Presentation._on_*`(表演不持 gi,故 signal 也不经表演连)。
- **嵌套两 Host**:外 `InkMonMain`(切屏 + 选 session)/ 内 `InkMonWorldHost`(建 world+presentation + lifecycle)。

### 读写 = CQRS（三通道）

- **Query(读)= 同步**:表演经 `IWorldQuery` facade 同步读 —— facade 直接转发 `player_actor` / `roster` / `near_npc_id` / `npc_defs` / `get_player_coord` / `get_world_actor` / `get_npc_actions` / `has_npc_handler`;gold / progression / medals 经 `player_actor` getter 读、roster 经 `roster` getter 读(均活 actor 字段)。
- **Command(写)= 异步唯一入口**:表演改任何游戏/世界态 → `submit(cmd)` 入队 → Host tick drain 应用(`cmd.apply(gi)`)→ 结果经 event/signal 回流 → 表演被动刷(**不读返回值**)。
  - **Command = 对象,不是无类型 dict**:`InkMonWorldCommand` 基类 + `InkMonMoveCommand`/`InkMonBuyCommand`/`InkMonNpcActionCommand` 子类;`drain_commands` 多态派发 `cmd.apply(gi)`(替掉 `{"kind":...}` dict + `if kind==` 阶梯)。move/buy/npc-action **全收进队列**(方案 A:世界一切 mutation 只在 tick 一处发生 = 单一变更时间线)。
  - 纯 UI 状态(切 tab / 抽屉 / modal / 相机)**不算 command**,留表演本地(故 app_state 不独立存储 —— 战斗 MODE = Host 控制面的 `_active_instance_id`(战斗 flow 真相)推入 Presentation 的 `_battle_active` 后派生,面板态 = 表演的 `_drawer_mode`;Presentation 据二者派生 `app_state`)。
- ⚠️ 此 "Command" ≠ battle 层 LGF `Action` / `ABILITY_ACTIVATE_EVENT`,两层独立。上行用 WorldGI mutation signal,**不建全局 EventBus**。
- **lifecycle(save/load/new-game/reset)= Host 控制面操作,不进 command 队列**(它销毁/重建世界本身,非世界内 mutation):save = `gi.to_dict()`(遍历活 actor 序列化)+ `InkMonSaveFile.write`;load = `InkMonSaveFile.read` + 重建 GI + `gi.from_dict(data)`(据存档建活 actor);new-game = `gi.new_game()`;reset = 重建 GI + `new_game`。`InkMonSaveFile` 仅磁盘 IO(收/吐 Dictionary)。

### tick / 移动模型

- 逻辑 **固定 30Hz**(FIXED_DT)。Host 每帧 `GameWorld.tick_all(FIXED_DT)` → `WorldGI.tick` → 无战斗走 `base_tick` → tick 注册的 System(CommandDrain → Movement);有战斗走基类阻塞 battle 分支(一帧跑完,record-then-playback)。**零 addon 改动**(base_tick + mutation signal 都是基类现成的)。
- **玩家/NPC = `InkMonWorldActor`**(进 GI registry),移动用基类 mutation signal `actor_position_changed` 喂表演。
- **离散跳格 + view 补间**:world actor 逻辑态 = `{hex_position(=occupant), moving_to, move_progress∈[0,1), pending_path}`。每 tick `move_progress += dt / STEP_DURATION(0.22s)`;`≥1` → occupant 跨一格 + emit `actor_position_changed(cell, moving_to)`,view 在两格间补间(≤0.22s,View3D `MOVE_STEP_DURATION` 与逻辑 `STEP_DURATION` 对齐)。**逻辑真相永远是离散 hex 格**,只多一个进度标量,**非**连续浮点(sim-nav 不借)。
- **连点重算(latest-wins,方案 A)**:新 command → 走完正在进入的当前格(occupant 自然 flip 到 moving_to)→ moving_to 之后的旧路立刻丢弃换 `astar(moving_to, target)`。view 永不被打断(只补间相邻已提交格)⇒ 零 snap / 零竞态(load-during-move 那类 race 被结构性消灭),表演 correct-by-construction。

### 命名

- **概念分层(命名审计的轴)**:`InkMonWorld` = **世界容器** = overworld + battle + 持久层(活 actor registry / 序列化根,World-owns-Battle,§2);`overworld` = 容器内的"**行走域**",跟 battle 平级。⇒ overworld **不是残渣**,大体保留;容器层概念用 `World` 前缀(GI/Host/Command/Presentation/Actor 基类),纯 overworld 域专属的东西用 `overworld` 前缀(如只 overworld 用、battle 不碰的 3D view)。审计 = 逐标识符判它住容器层还是域层,只改**站错层**的名字。
- **`overworld_grid` 必留**:GI 持两套 grid(主世界 grid vs 战斗翻转 grid,§2②),`overworld_grid` 这名字正是区分二者的关键(`ink_mon_world_gi.gd` 主世界 movement 只读它,绝不读战斗期翻转的基类 `grid`)。**不做 overworld→world 全局 sed**。
- 主世界**容器层**代码前缀统一 `InkMonWorld*`。
- World actor 层级:`InkMonWorldActor`(持 `hex_position`)→ `InkMonBattleActor`(+ 死亡 / ability)→ `InkMonUnitActor`。玩家/NPC = `InkMonWorldActor`(直接,无 ability/timeline);`hex_position` 住基类(三者共有,也是 GI `actor_position_changed` 报告的东西)。
- Host = `InkMonWorldHost`(composition root,非表演层);Presentation 根 = `InkMonWorldPresentation`(节点,持全部 UI 子树)。

---

## 2. 三块架构(互不混)

对标 hex-atb-battle:它只有 ② battle 那一块;inkmon 主游戏多了 ① overworld 和 ③ 持久层(活 actor 序列化)。

### ① 主世界 (Overworld) — hex 网格世界

- 形态:玩家角色行走、承载 6 个 System NPC 的 **hex 网格世界**(= lab 设计真相)。
- 移动:点目标 → **grid 插件 astar 寻路**(`InkMonWorldGrid.find_path` 走 `GridPathfinding.astar`)→ command 入队 → 30Hz tick 逐格推进 → `actor_position_changed` 驱动 view per-step 补间(§1)。
- **寻路边界(项目本地,刻意不外借)**:hex astar 来自 `ultra-grid-map` 插件;**不借** `addons/sim-nav-map`(那是 RTS 连续坐标寻路)、**不依赖** hex-atb-battle 的 Move 类、**不为**主世界另起独立 LGF GameplayInstance。
- **NPC 格阻塞 + 重定向**:NPC 占格不可走;右键点 NPC 格 / 任意阻塞格 → 解析到该格**最短可达空邻格**(`resolve_target_for_actor`),平手按 axial `(q, r)` 确定性 tie-break。落格后由 GI `refresh_near_npc` 重算邻近,view 永不直接调 NPC 服务。
- 玩家走路 avatar = `InkMonPlayerActor`(`InkMonWorldActor` 子类,进 GI registry,无 ability/timeline;揣玩家级 gold/progression/medals + bag 容器,见 §8c)。

### ② Battle — 唯一 world GI 内的 procedure(无独立 battle GI)

**LGF World-owns-Battle**:整个主游戏**只有一个** `InkMonWorldGI`(extends `WorldGameplayInstance`)承载逻辑 + 世界数据;**战斗是它内跑的 `InkMonBattleProcedure`**(短命 procedure),不是独立 GI。

- **复用**:`InkMonBattleProcedure` + 战斗数学(双通道伤害 / 6 元素 / 角色 AI / action / passive,首个里程碑已落地)。出战 `InkMonUnitActor` = **常驻 registry 的活 roster actor**(无投影/无快照,跨战斗复用);敌方训练假人 = 临时 `create_combat_unit`(battle 结束随 `_reset_battle_state` 整只移除,活 roster 留 registry)。
- **战斗触发 + 结果**:`InkMonWorldGI.request_training_battle()` 左队 = 活 roster 前 N 只(`InkMonBattleSetup.battle_roster_slice`,原地战斗)、右队 = 训练假人;`finalize_battle_rewards()` 战斗结束**直接把奖励落活 actor**(gold 加 `player_actor`、exp 加活 roster),无摘要回写。Host 只管 flow(app_state / tick)。
- **战斗呈现 = record-then-playback**:sim 瞬间同步算完 → 录 timeline → `FrontendBattleAnimator` 回放(复用 hex-atb animator/visualizer 栈)。不走 live-tick:auto-battler 无战斗中干预需求;暂停/倍速/重看免费;决定性天然;异步 PvP/Web 友好。

> ⚠️ **唯一 world GI 持两套 grid(主世界 + 战斗)战斗期切 active = 第一版临时方案**,非定稿(未来再优化,非核心)。边界加固:主世界 movement 只读 `overworld_grid`(稳定),绝不读战斗期翻转的基类 `grid`;且战斗期 base_tick 不跑 → movement 天然冻结。

### ③ 持久层 = 活 actor 自序列化(无独立 session 对象)

- **无** `InkMonGameSession` / `InkMonPlayerState` / `InkMonRosterEntry` 数据对象(adr/0001 删)。持久真相 = registry 里的活 actor:`InkMonPlayerActor`(gold/progression/medals/bag)+ `roster: Array[InkMonUnitActor]`(出战 InkMon,跨战斗复用)。`InkMonWorldGI` 持有它们,并作序列化根。
- overworld 与 battle **不互相引用**:battle 直接跑活 roster actor(原地改其 HP/状态),无投影 / 无快照 / 无回写;结果直接落活 actor。存档 = `gi.to_dict / from_dict`(遍历 player_actor + roster + 各 actor 容器内物品),详见 §3 / §8c。

---

## 3. 唯一真相 = 活 actor 运行时内存,不双写

- 活 actor 内存即真相;**save 序列化一次(`gi.to_dict`),load 反序列化一次(`gi.from_dict` → 建活 actor),中间不来回同步**。无独立 session 数据对象,故**无"运行时↔存档"双写问题**(单一表示:actor 即真相)。
- 运行时玩家位置 = avatar(`player_actor`,即主世界 grid occupant)本身;`to_dict` 时把 grid occupant 真相同步进 avatar 再序列化(单写),移动期间不写任何独立存档字段。
- 当前 HP = 活 actor 的 `attribute_set.hp`,跨战斗 + 跨存档 carryover;派生六维(max_hp/ad/...)不进存档,读档时 `f(species, level)` 重算。

---

## 4. 职责纪律(借自 `no-game-no-life`,取形不取器)

借**职责边界纪律**,不照搬机制:

1. 逻辑层不引用 UI。
2. UI 不直接改逻辑(走 command / query 间接)。
3. 规则按模块分块(NPC 规则住进各 handler)。

- 上行(逻辑→UI)= signal:WorldGI mutation signal(`actor_position_changed` 等);UI connect 被动刷新。**不建全局 EventBus autoload**。
- 主世界下行用 **`submit(InkMonWorldCommand)` 入队 + System 驱动同步 tick**(CommandDrain `drain_commands` 多态 `cmd.apply(gi)` → Movement,复用 LGF `base_tick` 注册的 `System`,非另造一套)。

---

## 5. NPC handler 契约

- 6 handler 统一**收 `InkMonWorldGI` 自身**,规则住 handler 内;纯数据 NPC(shop / cultivation / guild / advancement / release_adopt)读写活 actor —— `gi.player_actor`(gold/progression/medals)+ `gi.roster` + 调 GI 的 `create_bag_item` / `adopt_unit` / `refresh_unit_stats`;第 6 个 `trainer` = training→战斗(command-as-data,见下条);handler **不碰 UI / flow**。
- handler 由 `InkMonWorldGI` 持有(`_npc_handlers`,setup 内建);UI 点击 → Presentation `submit(InkMonNpcActionCommand / InkMonBuyCommand)` → tick drain 时 `cmd.apply(gi)` 调 GI 的 `run_npc_action` / `buy_shop_item`(handler 收 GI 自身),结果经 `command_applied` 回流。
- training→战斗 = **command-as-data**:handler 返回 `{ok, message, intent?}`,training 的 `intent = {kind:"start_battle"}`(**无 config** —— 战斗 config 由 `InkMonWorldGI.request_training_battle()` 自建:左队 = 活 roster 切片 + 训练假人,不经 intent 携带)。回流路径多一跳:GI `command_applied(result)` → Host 连到 `Presentation._on_command_applied` → 表演检出 intent、经 `flow_intent_raised` signal 上抛给 Host(单向 DAG,表演不引用 Host)→ `Host._on_flow_intent_raised` 读 `intent.kind`,`call_deferred(_begin_training_battle_flow, _world_generation)` 起 battle flow(app_state / tick 归 Host);handler / command / 表演都不碰 flow。

---

## 6. UI 搭建

- 全 `.tscn`(尽量编辑器设计),代码只填文字 / 绑数据,动态列表(roster/bag/NPC 行)用 instantiate 组件场景。
- UI 在 presentation 层,只订阅 signal / 调窄 `IWorldQuery` + `submit(cmd)`,不直接改逻辑、不见 concrete GI。
- presentation 根 = `InkMonWorldPresentation`(节点),持 overworld view(`InkMonOverworldView`,3D 棋盘)/ HUD / drawer / modal / `InkMonWorldPanelView` 全部 UI 子树 + 其 layout/animation/build/refresh;Host 不再直接持 UI 节点 ref。
- 数据驱动内容构建(roster chips / party / bag / journal)抽在 `InkMonWorldPanelView`(纯表演 builder)。

### HUD 布局(corner-only;密集信息进单一右抽屉)

3D 棋盘是主表面,常驻 UI 只占角落、紧凑;密集信息集中在一个共享右抽屉,不堆叠多窗。
- **左上**:玩家状态(头像占位 / rank / gold)+ party strip(≤6 roster 槽,带等级 + 紧凑 HP/进度条)。
- **右上**:工具按钮 Party / Bag / Journal / Menu。
- **世界定位**:靠近 NPC 浮出交互 prompt(不自动开抽屉)。
- **右抽屉(单一共享)**:scrim 挡住场景输入;Party/Bag/Journal 用 tab 栏;NPC 模式复用同一抽屉、隐藏 tab。
- **modal 层**:save/load 由 Menu / `Esc` 开。`Esc` 先关抽屉,抽屉已关才开 modal。
- 行为默认:首屏 HUD 可见 / 抽屉关 / 可移动;战斗奖励只刷 HUD 数值,不自动弹面板。

## 6b. 场景入口 / 接线层

- **薄场景 Node = 接线员**,不是 God object:只做 ① 开机(`GameWorld.init` + 建 world GI)② 接线(GI signal → UI view;玩家输入 → command)③ 切台(主世界 ↔ 战斗 ↔ NPC ↔ save)。
- **场景分层 = 两层**:外层 screen 路由 `InkMonMain`(标题 → 菜单 → 进游戏,v1 直接进游戏但结构留好);内层游戏导播 `InkMonWorldHost`(游戏内组装 + lifecycle),场景文件在 `scenes/inkmon-game/ink_mon_game.tscn`,由 `InkMonMain.tscn` instantiate。
- `project.godot run/main_scene` = `InkMonMain.tscn`;`Simulation.tscn` 退成纯 web 桥。

---

## 7. God object 拆解(已落地映射)

| 职责 | 去向 |
|---|---|
| NPC 规则(cultivate/advance/buy/adopt) | 各 NPC handler(收 InkMonWorldGI 自身,读写活 actor),由 InkMonWorldGI 持有 |
| 战斗实例生命周期 | 唯一 InkMonWorldGI 内的 InkMonBattleProcedure(无独立 battle GI) |
| overworld grid / move | InkMonWorldGrid + tick Movement System(InkMonWorldGI 持有) |
| UI 子树持有 + layout/animation/build/refresh | InkMonWorldPresentation(presentation 根节点) |
| 数据驱动 UI 内容 | InkMonWorldPanelView(presentation,由 Presentation 持有) |
| 持久数据(玩家级 + roster) | 活 actor:InkMonPlayerActor + roster(InkMonUnitActor),InkMonWorldGI 持有并作序列化根 |
| 序列化编排 | gi.to_dict / from_dict(遍历活 actor + ItemSystem 容器物品) |
| 存档 IO | InkMonSaveFile(仅磁盘 IO,收/吐 Dictionary) |

`InkMonWorldHost` 只剩:composition(建 world GI + `InkMonWorldPresentation` 两孩子、连 signal)+ 控制面(lifecycle 控台操作 + flow 切换 + tick 泵);**不再直接持 UI 节点 ref**(那归 Presentation)。输入→`submit(cmd)`、Query 读、Event 刷新全在 Presentation 与 Logic 之间走 CQRS 三通道,Host 不在其上。

---

## 8. 存档

- **手动存档点 + 可多槽**(主机 RPG 式,非防 save-scum):玩家开 save 菜单才存,可多槽,允许读档重刷。
- ⇒ 战斗结果**不自动落盘**:`finalize_battle_rewards` 只改内存里的活 actor(gold→player_actor、exp/HP→活 roster);玩家不手动存就不持久。
- 活 actor 内存是唯一真相;save = 某刻 `gi.to_dict()` 写一个槽,load = 读某槽 → 重建 GI → `gi.from_dict(data)` 据存档建活 actor(§3 不双写)。
- 存档**永不需要向后兼容**:`gi.from_dict` 遇 version 不符直接丢弃重开(`new_game`),不写迁移(`SAVE_VERSION` 当前 = 2)。

## 8c. 数据模型 — 活 actor 自序列化:存身份+选择+进度+当前HP,不存算出的派生六维

统一原则(adr/0001;技能 + stats 同构):**每只出战 InkMon = 常驻 registry 的活 `InkMonUnitActor`,自序列化"这只是谁 / 选了什么 / 练到哪 + 当前 HP",不存"由此算出的派生六维"**。派生六维 = `f(species, level)`,读档时 `apply_derived_stats(species_base)` 重算(+装备 stat_mods),不进存档。

**技能槽 = 存"哪槽选了哪技能",不存变异数值**:
- 结构:`skill_slots: Array[{slot_index:int, skill_id:String}]`。
- 出生唯一随机 = "每槽 roll 中哪个技能";技能本身**无数值变异**。个体独特性来自 ①槽内 roll 选中谁 ②刻印 ③装备。
- 读档直接读 `skill_slots`,不依赖技能池在场,不重 roll。
- 进化:旧 slot 保留;新阶段新增 slot → roll 一次写 skill_id。
- 出战授予的 primary skill 从 `skill_slots[0]` **单一真相**派生(`get_primary_skill_id()`,`equip_abilities` 时取),无独立缓存 —— 局内进化改写 slot0 后下一场即生效。

**技能代码/元数据流向(adr/0009)**:
- 技能实现 = Godot 内的 `AbilityConfig` / GDScript 代码,住本仓并编译进 export;运行时不从 server 拉 `.gd`,不动态加载。
- server 只存 skill metadata:`id` / `implementation_key` / `display_name` / `element` / `channel` / `icon_key?`,供 lab 展示和 `skill_pools` 引用。
- 流向与 inkmon/item 相反:skill metadata 是 `godot -> server -> lab`;Godot editor menu `Project -> Tools -> InkMon: 上传技能元数据` 主动 POST 到 server。

**进化 = species 字段改写 + edge-list 森林(adr/0010)**:
- 身份 = `species_id`(= 活 actor 的 `species`,全局唯一不可变 `mon_NNNN`,住 canon);`name_en` 降级为可改显示名。进化 = `InkMonSpeciesCatalog.evolve_actor(actor)` **原地变身**活 actor:改写 `actor.species`(及 display_name/stage)成所选下一形态,actor 实例不换(同一只,无 entry_id)。
- 拓扑 = 解耦的 **edge-list 森林**:每条边 `(parent_species_id, child_species_id, trigger{level, condition?})`,住 canon、经 editor import 写入本地静态 content `res://data/inkmon_content.json`,由 `InkMonSpeciesCatalog` 读取。一个低阶可多子分支;孤儿 = 无边物种。权威是 **per-species**:某物种在边表中→用边表;不在→降级用 stub `_build_table` 的 `evolves_to` 单边 fallback(故加载部分 content 不会让 stub/领养物种丢失自己的进化链)。
- **阈值 `trigger.level` = 设计数据,住 canon**(adr/0010 修订 0007);godot 只持有单位**运行时 current level**(`actor.level`)。进化触发 = `actor.level >= trigger.level`。
- **分支确定性选边住 godot**:在 level 达标的边里 —— 有 `condition` 且评估通过者优先 → 否则取无 condition 的默认枝(canon 语义盲)。`condition {type, params}` 按 `type` 分派评估(`element`/`stat` 真评估,stat 用 species_base × 等级缩放;`item` 待 item 域迁 server,先 stub false)。
- 每形态 = 一条独立 species 数据(独立立绘/名/属性档/技能池/槽数)。属性派生 key = `species_id`,即 `f(species_id, level)`。
- 升级/进化后 `gi.refresh_unit_stats(actor)` 按新 species+level 重算派生六维(carryover HP 保留)。

**stats = 派生 + current HP carryover**:
- 自序列化 `{species_id, name_en, stage, elements, level, exp, ...}` + **当前 HP**;派生六维 = `f(species, level)` 读档 `apply_derived_stats` 重算(+装备),不进存档。
- 当前 HP **进存档**(carryover,跨战斗 + 跨存档);死单位 HP=0 留 registry + 进存档,`sync_downed_state` 保 `is_dead()` 与 HP 一致(死者留 registry 不变量见 `glossary.md` §6.1)。
- 培养(花金币)= +level(+刻印),`refresh_unit_stats` 重算派生,不直接改属性数。

**刻印 = v1 只做"技能强化"**:
- 刻印强化某一个具体技能(给它加额外效果 / 数值增强)。
- 存储形状:`engravings: [{engraving_id, target_slot}]` —— 每条显式指明强化哪个 skill_slot。
- 刻印**不进派生六维数值折叠**(它改技能行为);equip 时每条 grant 一个刻印被动。

**装备 = 项目本地 stat 折叠(非 lomolib Phase-G)**:
- lomolib 只有 inventoryKit,**无 Phase-G**(`EquipmentManager`/`StatAggregator`/`AbilityGrantor` 只存在于 hex-atb-battle 示例 = Non-Goal,不引入主游戏)。
- 装备数值生效 = **equip/load 时** `InkMonUnitActor.apply_derived_stats`:遍历该 actor 装备容器物品,把各物品 config 的 `stat_mods` flat 累加进 attribute base(× 数量,取代旧投影期折叠)。每只 actor 持 equipment 容器 id;物品实例住中央 `ItemSystem`(InventoryKit 原生),actor 只持容器 id 引用。
- 装备**授予 ability**(granted_abilities)= 设计意图,**主游戏暂未落地**(示例层有参考实现);v1 装备只做数值。

**派生六维计算**:
- `attribute base = species_base(f(species, level)) + 装备 stat_mods 累加`(`apply_derived_stats`,flat 加法,equip/level-up/读档时重算,**幂等**;重算 max_hp 后回钳当前 HP ∈ [0, max])。
- ability 来源(走 grant,不进 stats 折叠):skill_slots 技能 + 普攻 + 刻印被动(+ 未来:装备授予 ability)。

**UnitActor 持久切片(自序列化形状)**:
```
{ species_id, name_en, stage, elements, level, exp,
  skill_slots: [{slot_index, skill_id}],     # 无 variance
  engravings: [{engraving_id, target_slot}], # 刻印(v1 只强化某技能)
  hp,                                          # 当前 HP carryover(派生 max_hp 等不进存档)
  equipment: [{config_id, count, slot_index}], # 装备容器内物品快照(容器 id runtime 不进存档)
}
```
派生六维 = `f(species_id, level)` 读档重算,不进存档。**无 `entry_id`**(活 actor 即身份,roster 数组序即顺序)。`gold` / `progression` / `medals` 归 `InkMonPlayerActor`(玩家级,亦活 actor 自序列化)。

---

## 9. 待用户给设计后再定(未覆盖)

- **InkMonWorldGI god-object(#3)= routing 规则约束,非大重构**(决策见 [adr/0002](adr/0002-gi-organization-state-decides-form.md)):拆法是**非对称**的 —— battle 宿主职责由 `WorldGameplayInstance` 基类钉死在 GI 上、拿不走,battle 杂活(建队/布阵/发奖)是无状态逻辑归 static service(如 `InkMonBattleSetup`);**唯一真有状态、值得拎成域对象的是 overworld**。GI 终态 = registry + 序列化根 + CQRS 基础设施 + battle 宿主 +(可选)overworld transient 域对象。god-object 不靠一次拆解消除,靠"新逻辑按 state 性质 routing(不需保留态→static 纯函数 / 需保留且 transient→GI 持的 RefCounted / 需保留且持久→data shape,非 service)"约束其增长。存量 GI 仍 863 行,battle 杂活下沉 static service + overworld 域对象抽取按需逐步落地。
- **PlayerActor 内的无类型 Dict 袋子**:`InkMonPlayerActor` 的 `gold`/`medals` 已 typed;待定的是 `progression`(+原 `overworld` flags)无类型 Dict 袋子要不要进一步类型化。
- **主世界双 grid 共存的最终形态**:第一版临时方案 = 唯一 world GI 持两套 grid 切 active(§2② 注),未来优化。
- **`f(species, level)` 属性公式**:lab 标"等级是否线性加属性=待定";v1 先最简单线性(`apply_derived_stats` 的 `LEVEL_GROWTH`),公式调整不影响持久切片结构。
- **刻印的实现框架**:存储形状已定;实现走 LGF 被动 ability(hook 目标技能事件)还是挂在 skill_slot 上的 modifier,留实现时定。
