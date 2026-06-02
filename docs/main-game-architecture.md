# 主游戏架构 — 当前真相

> 本文 = 本仓**主游戏代码架构**的当前唯一真相。
> "主游戏" = 在 LGF 框架(`addons/logic-game-framework/`)之上自建的那一层:hex 行走世界 + 战斗 + 存档(git 历史里代号 "L2",本文不再用代号)。
> 范围:主游戏代码结构 / 所有权边界 / 运行模型。**不含**玩法数值设计(那部分真相在 lab 仓 inkmon-lab)、LGF 框架设计(在 `addons/logic-game-framework/docs/`)。
> 历史轨迹归 git;本文只描述现状。

---

## 0. 定位

主游戏架构是**长期地基,认真修**(非一次性脚手架)。

---

## 1. 主世界运行模型 = 同步 tick + command + 三层 Host

主世界采用 dota2-auto-battle 式同步 tick:输入 → command → 逻辑 tick 推进世界态 → 表演据 event 渲染。术语见 `glossary.md`(World Actor 层级 / 主世界 Command·Query / 主世界三层+Host)。

### 三层 + Host

```
┌──────────────────────────────────────────────────┐
│  Host (InkMonWorldHost)                            │  composition root,在 logic/presentation 之上
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
   │       overworld grid /│          │                   │
   │       npc 服务         │          │                   │
   └──────────────────────┘          └──────────────────┘
```

- **两轴别混**:数据流(运行时)= **双向**(command 下 / event 上 ⇒ "感觉平级");代码依赖 = **单向 DAG**(Presentation→Logic;Logic 谁都不依赖、永不引用 UI;Host→两者)。⇒ Logic 是地基,Presentation 长其上,Host 在两者之上;lifecycle 重建归 Host(它建了两孩子),**非**"表演层重建逻辑层"。
- **嵌套两 Host**:外 `InkMonMain`(切屏 + 选 session)/ 内 `InkMonWorldHost`(建 world+view + lifecycle)。

### 读写 = CQRS

- **Query(读)= 同步**:UI 渲染直接调 WorldGI 只读方法(roster / gold / near-npc / npc actions)。
- **Command(写)= 异步唯一入口**:UI 改任何游戏/世界态 → enqueue → tick 应用 → 结果经 event/signal 回流 → UI 被动刷(**不读返回值**)。纯 UI 状态(切 tab / 抽屉 / modal / 相机)**不算 command**,留表演本地(故 app_state 不独立存储 —— 战斗 MODE 由 WorldGI 的 `_active_instance_id` 派生,面板态 = 表演的 `_drawer_mode`)。
- ⚠️ 此 "Command" ≠ battle 层 LGF `Action` / `ABILITY_ACTIVATE_EVENT`,两层独立。上行用 WorldGI mutation signal,**不建全局 EventBus**。
- **lifecycle(save/load/new-game/reset)= Host 控台操作,不进 command 队列**(它销毁/重建世界本身):save = `world.capture_to_session()` + `InkMonSaveFile.write`;load = `InkMonSaveFile.read` + `session.from_dict` + 重建 world + `world.hydrate_from_session()`。

### tick / 移动模型

- 逻辑 **固定 30Hz**(FIXED_DT)。Host 每帧 `GameWorld.tick_all(FIXED_DT)` → `WorldGI.tick` → 无战斗走 `base_tick` → tick 注册的 System(CommandDrain → Movement);有战斗走基类阻塞 battle 分支(一帧跑完,record-then-playback)。**零 addon 改动**(base_tick + mutation signal 都是基类现成的)。
- **玩家/NPC = `InkMonWorldActor`**(进 GI registry),移动用基类 mutation signal `actor_position_changed` 喂表演。
- **离散跳格 + view 补间**:world actor 逻辑态 = `{hex_position(=occupant), moving_to, move_progress∈[0,1), pending_path}`。每 tick `move_progress += dt / STEP_DURATION(0.22s)`;`≥1` → occupant 跨一格 + emit `actor_position_changed(cell, moving_to)`,view 在两格间补间(≤0.22s,View3D `MOVE_STEP_DURATION` 与逻辑 `STEP_DURATION` 对齐)。**逻辑真相永远是离散 hex 格**,只多一个进度标量,**非**连续浮点(sim-nav 不借)。
- **连点重算(latest-wins,方案 A)**:新 command → 走完正在进入的当前格(occupant 自然 flip 到 moving_to)→ moving_to 之后的旧路立刻丢弃换 `astar(moving_to, target)`。view 永不被打断(只补间相邻已提交格)⇒ 零 snap / 零竞态(load-during-move 那类 race 被结构性消灭),表演 correct-by-construction。

### 命名

- 主世界代码前缀统一 `InkMonWorld*`。
- World actor 层级:`InkMonWorldActor`(持 `hex_position`)→ `InkMonBattleActor`(+ 死亡 / ability)→ `InkMonUnitActor`。玩家/NPC = `InkMonWorldActor`(直接,无 ability/timeline);`hex_position` 住基类(三者共有,也是 GI `actor_position_changed` 报告的东西)。
- Host = `InkMonWorldHost`(composition root,非表演层)。

---

## 2. 三块架构(互不混)

对标 hex-atb-battle:它只有 ② battle 那一块;inkmon 主游戏多了 ① overworld 和 ③ session。

### ① 主世界 (Overworld) — hex 网格世界

- 形态:玩家角色行走、承载 6 个 System NPC 的 **hex 网格世界**(= lab 设计真相)。
- 移动:点目标 → **grid 插件 astar 寻路**(`InkMonWorldGrid.find_path` 走 `GridPathfinding.astar`)→ command 入队 → 30Hz tick 逐格推进 → `actor_position_changed` 驱动 view per-step 补间(§1)。
- **寻路边界(项目本地,刻意不外借)**:hex astar 来自 `ultra-grid-map` 插件;**不借** `addons/sim-nav-map`(那是 RTS 连续坐标寻路)、**不依赖** hex-atb-battle 的 Move 类、**不为**主世界另起独立 LGF GameplayInstance。
- **NPC 格阻塞 + 重定向**:NPC 占格不可走;右键点 NPC 格 / 任意阻塞格 → 解析到该格**最短可达空邻格**(`resolve_target_for_actor`),平手按 axial `(q, r)` 确定性 tie-break。落格后由 GI `refresh_near_npc` 重算邻近,view 永不直接调 NPC 服务。
- 玩家 = 轻 `InkMonWorldActor`(进 GI registry,无 ability/timeline)。

### ② Battle — 唯一 world GI 内的 procedure(无独立 battle GI)

**LGF World-owns-Battle**:整个主游戏**只有一个** `InkMonWorldGI`(extends `WorldGameplayInstance`)承载逻辑 + 世界数据;**战斗是它内跑的 `InkMonBattleProcedure`**(短命 procedure),不是独立 GI。

- **复用**:`InkMonBattleProcedure` + 战斗数学(双通道伤害 / 6 元素 / 角色 AI / action / passive,首个里程碑已落地)。战斗 actor(`InkMonUnitActor`)从 roster snapshot 现造。
- **战斗触发 + 结果**:`InkMonWorldGI.request_training_battle()` 自建 config(player roster 投影自持有的 session + 训练假人)起 procedure;`apply_battle_result()` 战斗结束把结果写回持有的 session。Host 只管 flow(app_state / tick)。
- **战斗呈现 = record-then-playback**:sim 瞬间同步算完 → 录 timeline → `FrontendBattleAnimator` 回放(复用 hex-atb animator/visualizer 栈)。不走 live-tick:auto-battler 无战斗中干预需求;暂停/倍速/重看免费;决定性天然;异步 PvP/Web 友好。

> ⚠️ **唯一 world GI 持两套 grid(主世界 + 战斗)战斗期切 active = 第一版临时方案**,非定稿(未来再优化,非核心)。边界加固:主世界 movement 只读 `overworld_grid`(稳定),绝不读战斗期翻转的基类 `grid`;且战斗期 base_tick 不跑 → movement 天然冻结。

### ③ Session — 持久存档(独立于 ①②)

- `InkMonGameSession` 持 `roster / gold / progression`,是存档根,**由 `InkMonWorldGI` 持有**(Host 经只读 `session` getter 委托)。
- overworld 与 battle **不互相引用**,通过 session 间接连:进战斗从 session 投影 `InkMonBattleUnitSnapshot`;战斗结束 result 写回 session。

---

## 3. 唯一真相 = 运行时内存,不双写

- session 内存即真相;**save 序列化一次(capture_to_session),load 反序列化一次(hydrate_from_session),中间不来回同步**。
- 运行时世界态(玩家位置)只住主世界运行层(world GI 的 overworld grid occupant);存档字段只在 save(capture)/ load(hydrate)两端读写。移动期间绝不写 session。

---

## 4. 职责纪律(借自 `no-game-no-life`,取形不取器)

借**职责边界纪律**,不照搬机制:

1. 逻辑层不引用 UI。
2. UI 不直接改逻辑(走 command / query 间接)。
3. 规则按模块分块(NPC 规则住进各 handler)。

- 上行(逻辑→UI)= signal:WorldGI mutation signal(`actor_position_changed` 等);UI connect 被动刷新。**不建全局 EventBus autoload**。
- 主世界下行用 **command 队列 + System 驱动同步 tick**(CommandDrain → Movement,复用 LGF `base_tick` 注册的 `System`,非另造一套)。

---

## 5. NPC handler 契约

- 6 handler 统一**只收 `session`**,规则住 handler 内;纯数据 NPC(shop / cultivation / guild / advancement / release_adopt)直接读写 session;handler **不碰 UI / flow**。
- handler 由 `InkMonWorldGI` 持有(`_npc_handlers`,setup 内建);Host 转发 UI 点击为 `run_npc_action` / `buy_shop_item` 调用。
- training→战斗 = **command-as-data**:handler 返回 `{ok, message, intent?}`,training 的 `intent = {kind:"start_battle", config}`;Host 读 `intent.kind` 解释起 battle flow(app_state / tick 归 Host),handler 自己绝不碰 flow。

---

## 6. UI 搭建

- 全 `.tscn`(尽量编辑器设计),代码只填文字 / 绑数据,动态列表(roster/bag/NPC 行)用 instantiate 组件场景。
- UI 在 presentation 层,只订阅 signal / 调窄 API,不直接改逻辑。
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
- **场景分层 = 两层**:外层 screen 路由 `InkMonMain`(标题 → 菜单 → 进游戏,v1 直接进游戏但结构留好);内层游戏导播 `InkMonWorldHost`(游戏内组装 + lifecycle)。
- `project.godot run/main_scene` = `InkMonMain.tscn`;`Simulation.tscn` 退成纯 web 桥。

---

## 7. God object 拆解(已落地映射)

| 职责 | 去向 |
|---|---|
| NPC 规则(cultivate/advance/buy/adopt) | 各 NPC handler(收 session),由 InkMonWorldGI 持有 |
| 战斗实例生命周期 | 唯一 InkMonWorldGI 内的 InkMonBattleProcedure(无独立 battle GI) |
| overworld grid / move | InkMonWorldGrid + tick Movement System(InkMonWorldGI 持有) |
| 数据驱动 UI 内容 | InkMonWorldPanelView(presentation) |
| 持久数据 | InkMonGameSession(InkMonWorldGI 持有) |
| 存档 IO | InkMonSaveFile |

`InkMonWorldHost` 只剩:wiring(建 world GI/view、连 signal、挂 UI)+ 输入转发为 command + flow 切换(主世界 ↔ 在同一 world GI 内起 battle procedure)+ lifecycle 控台操作。

---

## 8. 存档

- **手动存档点 + 可多槽**(主机 RPG 式,非防 save-scum):玩家开 save 菜单才存,可多槽,允许读档重刷。
- ⇒ 战斗结果**不自动落盘**:`apply_battle_result` 只改内存 session;玩家不手动存就不持久。
- session 内存是唯一真相;save = 某刻 `capture_to_session` + `to_dict` 写一个槽,load = 读某槽 `from_dict` + `hydrate_from_session` 重建内存(§3 不双写)。
- 存档**永不需要向后兼容**:`from_dict` 遇旧版直接丢弃重开,不写迁移。

## 8c. 数据模型 — RosterEntry = 存身份+选择+进度,不存算出的最终值

统一原则(技能 + stats 同构):**entry 只存"这只是谁 / 选了什么 / 练到哪",不存"由此算出的运行时数值"**。

**技能槽 = 存"哪槽选了哪技能",不存变异数值**:
- 结构:`skill_slots: Array[{slot_index:int, skill_id:String}]`。
- 出生唯一随机 = "每槽 roll 中哪个技能";技能本身**无数值变异**。个体独特性来自 ①槽内 roll 选中谁 ②刻印 ③装备。
- 读档直接读 `skill_slots`,不依赖技能池在场,不重 roll。
- 进化:旧 slot 保留;新阶段新增 slot → roll 一次写 skill_id。

**进化 = species_id 字段改写 + edge-list 森林(adr/0010)**:
- 身份 = `species_id`(全局唯一不可变 `mon_NNNN`,住 canon);`name_en` 降级为可改显示名。进化时 entry 的 `species_id`(及 `name_en`/`stage`)改写成所选下一形态,`entry_id` 不变(同一只)。
- 拓扑 = 解耦的 **edge-list 森林**:每条边 `(parent_species_id, child_species_id, trigger{level, condition?})`,住 canon、经 contract 投影灌入 `InkMonSpeciesCatalog.register_evolution_edges`。一个低阶可多子分支;孤儿 = 无边物种。权威是 **per-species**:某物种在边表中→用边表;不在→降级用 stub `_build_table` 的 `evolves_to` 单边 fallback(故灌入部分 contract 不会让 stub/领养物种丢失自己的进化链)。
- **阈值 `trigger.level` = 设计数据,住 canon**(adr/0010 修订 0007);godot 只持有单位**运行时 current level**(`entry.level`)。进化触发 = `entry.level >= trigger.level`。
- **分支确定性选边住 godot**:在 level 达标的边里 —— 有 `condition` 且评估通过者优先 → 否则取无 condition 的默认枝(canon 语义盲)。`condition {type, params}` 按 `type` 分派评估(`element`/`stat` 真评估;`item` 待 item 域迁 server,先 stub false)。
- 每形态 = 一条独立 species 数据(独立立绘/名/属性档/技能池/槽数)。属性派生 key = `species_id`,即 `f(species_id, level)`。

**stats = 派生,只存 level,不存六维**:
- entry 存 `{species_id, name_en, stage, level, exp}`;六维属性 = `f(species_id, level)` 运行时派生,不进 entry。
- 培养(花金币)= +level(+刻印),不直接改属性数。

**刻印 = v1 只做"技能强化"**:
- 刻印强化某一个具体技能(给它加额外效果 / 数值增强)。
- 存储形状:`engravings: [{engraving_id, target_slot}]` —— 每条显式指明强化哪个 skill_slot。
- 刻印**不进 battle_stats 数值折叠**(它改技能行为)。

**装备 = 项目本地 stat 折叠(非 lomolib Phase-G)**:
- lomolib 只有 inventoryKit,**无 Phase-G**(`EquipmentManager`/`StatAggregator`/`AbilityGrantor` 只存在于 hex-atb-battle 示例 = Non-Goal,不引入主游戏)。
- 装备数值生效 = 投影时 `InkMonGameSession._fold_equipment_stats`:遍历 entry 的 `equipment_container` 物品,把各物品 config 的 `stat_mods` flat 累加进 `battle_stats`(× 数量)。
- 装备**授予 ability**(granted_abilities)= 设计意图,**主游戏暂未落地**(示例层有参考实现);v1 装备只做数值。

**battle_stats 折叠**:
- `battle_stats = base(f(species, level)) + 装备 stat_mods 累加`(项目本地 `_fold_equipment_stats`,flat 加法)。
- ability 来源(走 grant,不进 stats 折叠):skill_slots 技能 + 普攻 + 刻印被动(+ 未来:装备授予 ability)。
- 折叠发生在 `project_to_battle_snapshot`(投影时算,不存进 entry,合 §3)。

**RosterEntry v1 目标字段**:
```
{ entry_id, species_id, name_en, stage, level, exp,
  skill_slots: [{slot_index, skill_id}],     # 无 variance
  engravings: [{engraving_id, target_slot}], # 刻印(v1 只强化某技能)
  equipment_container: "equip:<id>",         # 逻辑容器名
}
```
六维 stats = `f(species_id, level)` 运行时派生,不进 entry;`medals` 归 `InkMonPlayerState`(玩家级)。

---

## 9. 待用户给设计后再定(未覆盖)

- **PlayerState 结构**:`medals`(玩家级)+ `progression`(无类型 Dict 袋子)要不要类型化。
- **主世界双 grid 共存的最终形态**:第一版临时方案 = 唯一 world GI 持两套 grid 切 active(§2② 注),未来优化。
- **`f(species, level)` 属性公式**:lab 标"等级是否线性加属性=待定";v1 先最简单线性,公式调整不影响 entry 结构。
- **刻印的实现框架**:存储形状已定;实现走 LGF 被动 ability(hook 目标技能事件)还是挂在 skill_slot 上的 modifier,留实现时定。
