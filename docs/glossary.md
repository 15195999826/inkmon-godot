# 术语表

> 本仓常用概念的速查定义。架构细节见 [`main-game-architecture.md`](main-game-architecture.md),全项目关系见 [`project-overview.md`](project-overview.md)。

## 1. 项目结构

**1.1 LGF(Logic Game Framework)** — `addons/logic-game-framework/`,纯模拟战斗框架(无渲染)。三层:Core Logic → Game Logic → Presentation,**上层依赖下层,下层绝不引用上层**。是本仓所有玩法的地基。

**1.2 示例(example)** — LGF 之上两个独立可跑示例,共享 LGF core:
- **hex-atb-battle** — 回合制 + hex grid + Timeline 技能。定位 = **技能系统展示 + AI 技能沙盒**(逻辑层零玩家输入;消费方 = AI-vs-AI demo + skill-preview 沙盒 + SkillValidator),**不是**要平衡的可玩对战。
- **dota2-auto-battle** — 实时固定 tick 30Hz / ARAM 单中路自动战斗 / controller-intent 模型 / sim-nav movement adapter(首个垂直切片)。

**1.3 主游戏** — 在 LGF 之上自建的那一层(hex 行走世界 + 战斗 + 存档),git 历史代号 "L2"。架构见 `main-game-architecture.md`。

## 2. 战斗 / 数值

**2.1 双通道 stats** — 物理 `ad` vs `armor`、法术 `ap` vs `mr`,两条独立减伤通道。

**2.2 元素克制** — 按克制表算伤害乘数(具体元素集与倍率以代码 `InkMonElementChart` 为准)。

**2.3 personality(AI 行为倾向,interim)** — `aggressive` / `frontline` / `support`,驱动战斗 AI 选 `choose_skill_target` 策略(`InkMonAIStrategyFactory`)。⚠️ 取代已废弃的 `role`(tank/dps/healer/flex 战斗定位,lab **adr/0008** 彻底废弃)。**当前是 godot-internal 临时实现**:由 species 派生(`get_personality_for_species`)+ 投影进 battle snapshot;adr/0008 的 proper 设计 = canon `personality` 字段投影到 godot,语义明确后再做(非 role 的重命名/兼容层)。

**2.4 stage(形态阶段)** — baby / mature / adult,随进化推进。

**2.5 balance(hex 沙盒语境)** — 验收标准 = **范式一致 + 行为可预测 + 可被 validator/AI introspect**,**不是**数值公平。判 hex 的 balance finding 时别当成"调公平数值"的任务。

## 3. 技能

**3.1 active ability(技能)** — 代码里类名是 **ability / AbilityConfig**(口语叫 "skill")。声明式:`static var ABILITY := AbilityConfig.builder()...build()`,无 .tres 数据层。执行链:`ABILITY_ACTIVATE_EVENT → active_use timeline → on_tag([Action]) → 共享 Action.execute → pre/post event`。

**3.2 SkillValidator**(`scripts/SkillValidator.gd`)— 校验 AI 生成技能脚本的五级验证器(编译 → 接口 → 运行 → 结构 → advisory)。生产入口 = web JS 桥 `godot_validate_skill`。技能契约 = `static var ABILITY`。

## 4. 主游戏概念(详见 `main-game-architecture.md`)

**4.1 World Actor 层级** — 主游戏一切有位置的实体都是 `InkMonWorldActor`(持 `hex_position`);层级 `InkMonWorldActor → InkMonBattleActor → InkMonUnitActor`,与玩家级 `InkMonPlayerActor`(亦 extends `InkMonWorldActor`)。一切实体 = 常驻 `InkMonWorldGI` registry 的活 actor(adr/0001)。玩家走路 avatar = `InkMonPlayerActor`(揣 gold/progression/medals/bag,无 ability/timeline);NPC = 直接 `InkMonWorldActor`;出战 InkMon = `InkMonUnitActor`(常驻 registry、跨战斗复用、自序列化)。`get_actor(id)` 取回任意 registry actor(广义 `InkMonWorldActor`);`get_battle_actor(id)` 窄化取战斗 actor。

**4.2 主世界 CQRS 三通道** — 表演↔逻辑三条路。**① Query(读)**= 表演经窄 `IWorldQuery` facade **同步**读(`player_actor`/`roster`/`near_npc_id`/`npc_defs`/player-coord/world-actor/npc-actions;gold/progression/medals 经 `player_actor` getter 读)。**② Command(写)**= 表演改任何游戏/世界/存档态的**唯一入口**,异步:`submit(InkMonWorldCommand)` 入队 → Host tick drain `cmd.apply(gi)` 应用 → event 回流 → 表演被动刷(不读返回值)。**③ Event(上行)**= Logic mutation signal 上行,表演被动刷新。纯 UI 态(tab/抽屉/modal/相机)不算 command。⚠️ 此 "Command" ≠ 战斗层 LGF `Action` / `ABILITY_ACTIVATE_EVENT`,两层独立。

**4.2a InkMonWorldCommand** — 主世界写路径的**对象化命令**:基类 + `InkMonMoveCommand`/`InkMonBuyCommand`/`InkMonNpcActionCommand` 子类。表演 `submit(cmd)` 入队,`drain_commands` 多态派发 `cmd.apply(gi)`(替代旧的无类型 `{"kind":...}` dict + `if kind==` 阶梯)。move/buy/npc-action 全收进队列(方案 A:世界一切 mutation 只在 tick 一处发生)。

**4.2b IWorldQuery** — Logic 暴露给 Presentation 的**只读 query + submit facade 对象**(`RefCounted`,私有包 `InkMonWorldGI`,转发 `player_actor`/`roster`/`near_npc_id`/`npc_defs`/`get_player_coord`/`get_world_actor`/`get_npc_actions`/`has_npc_handler` 读 + `submit(cmd)` 写;gold/progression/medals 经 `player_actor` 读、roster 经 `roster` 读)。结构仿 LGF `BaseGeneratedAttributeSet`(持底层对象 + 受控表面),但**无 `get_gi()` 逃逸口** → Presentation 物理上够不到 concrete GI / flow / lifecycle(**结构隔离**,非纯约定级)。GDScript 无 interface 关键字 + GI 单继承位被 `WorldGameplayInstance` 占,故用此 Facade 实现"持接口不持实现";mutation signal 由 Host 连(表演不持 gi)。

**4.3 主游戏三层 + Host** — Host(`InkMonWorldHost`)= composition root,在 Logic / Presentation **之上**:建两孩子 + 接线 + 控制面(lifecycle/flow/tick)。**Host 不在 CQRS 调用路径上**(不发 Query / 不收 Event),但握**命令生效时机**(Command 在 Host tick 泵 drain 那一刻生效)。数据流**双向**(command↓ / event↑),代码依赖**单向 DAG**(Presentation→Logic;Logic 谁都不引用;Host→两者)。

**4.3a InkMonWorldPresentation** — Presentation 层根节点,持 overworld view(`InkMonOverworldView`,3D 棋盘)/ HUD / drawer / modal / `InkMonWorldPanelView` 全部 UI 子树 + layout/animation/build/refresh。只握 `IWorldQuery` facade(类型层面够不到 concrete GI);mutation signal 由 Host 连;Host 不再直接持 UI 节点 ref。

**4.3b InkMonWorld 容器 vs overworld 域** — `InkMonWorld` = **世界容器**(overworld + battle + 持久层/活 actor 序列化根,World-owns-Battle);`overworld` = 容器内"行走域",跟 battle **平级**(不是残渣)。容器层概念用 `World` 前缀,纯 overworld 域专属的用 `overworld` 前缀(如 battle 不碰的 3D view)。`overworld_grid` 必留(区分主世界 grid vs 战斗翻转 grid)。**两条轴别混**:命名轴上 overworld 与 battle **平级**;本体轴上 **`InkMonWorldGI` 即 overworld 实体** —— 持久常在者 = 行走世界,battle 只是它原地跑、无持久实体的短 procedure,从属本体、命名仍一等。

**4.4 InkMonPlayerActor**(adr/0001)— 玩家走路 avatar = 常驻 `InkMonWorldGI` registry 的活 `InkMonWorldActor` 子类,揣玩家级数据 `gold / progression / medals` + bag 容器 id(runtime,不进存档)。同时进 `world_actors["player"]`(位置/移动)。自序列化 `to_dict/from_dict`(gold/progression/medals/coord;bag 物品由容器捕获)。取代旧 `InkMonGameSession`/`InkMonPlayerState` 的玩家级数据职责。

**4.5 出战 InkMon 自序列化(`InkMonUnitActor` 持久切片)**(adr/0001)— 一只己方 InkMon = 常驻 registry 的活 `InkMonUnitActor`(跨战斗复用、battle 原地改、死留 registry/HP=0)。核心原则:**只存"身份+选择+进度"+当前 HP(carryover),不存算出的派生六维**。`to_dict` 存 `species_id / name_en / stage / elements / level / exp / skill_slots / engravings / 当前HP / 装备物品`;派生六维 = `f(species, level)` 读档时 `apply_derived_stats(species_base)` 重算(+装备 stat_mods),不进存档。取代旧 `InkMonRosterEntry`(投影/快照/回写全删);字段细节见 `main-game-architecture.md` §8c。

## 5. 设计取向

**5.1 InkMon(养成深度)** — 长期目标 = **深度英雄(Dota 向)**:每只多技能槽 + 装备 + 刻印 + 勋章 + 进化 stage。**不是** TFT 浅棋子(无羁绊/费用/reroll)。真实形态 = "hex 棋盘上一队 Dota 深度英雄的 ATB 自走战"。存档数据模型按这一档设计(浅用法只是少填字段)。

**5.2 存档兼容策略** — **v1 永不需要向后兼容**:`from_dict` 遇旧版直接丢弃重开,不写迁移。⇒ 数据模型可放心边做边改。

**5.3 职责纪律(借自 no-game-no-life,取形不取器)** — ① 逻辑层不引用 UI ② UI 不直接改逻辑(走 command/query)③ 规则按模块分块(NPC 规则住各 handler,收 `InkMonWorldGI` 自身 —— 读写 `player_actor`/`roster` + 调 GI 的物品/领养/进化方法)。上行(逻辑→UI)用 Godot signal / WorldGI mutation signal,**不建全局 EventBus autoload**。

## 6. 关键不变量

**6.1 死者留 registry** — 战斗中 hp≤0 的单位**留在 world registry**(`get_actor()` 非 null、`hex_position` 字段保留),只清 grid occupant。这是判"目标死亡 → 技能 fizzle?"类问题的不变量。adr/0001 下延伸到持久层:死 roster `InkMonUnitActor` 留 registry(HP=0)+进存档,不移除;读档/战斗复用经 `sync_downed_state()` 按 HP 重建 `is_dead()`,保 `is_dead()` 与 carryover HP 一致。revive/permadeath = 游戏设计层(待定)。
