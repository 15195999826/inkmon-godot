# GI 组织:state 性质决定形态(纯函数 / RefCounted / data shape 三叉)

主游戏逻辑根 `InkMonWorldGI` 的内部组织规则:一段代码放哪,由它**需不需要保留自己的状态、状态进不进存档**唯一决定 —— 不需保留 → **static 纯函数**(收 gi/actor 当参数);需保留且不进存档(transient,每 session 重建)→ **GI 持有的 RefCounted**(tick 驱动则用 LGF `System`);需保留且进存档 → **不是 service**,是 **data shape**(活 actor 或 GI 持的纯数据类)。

承接 [adr/0001 统一 live-actor](0001-unified-live-actor-model.md)(持久真相单一表示、无投影/回写),本 ADR 回答"那非持久的逻辑/状态怎么摆",并据此把 god-object `InkMonWorldGI`([main-game-architecture.md](../main-game-architecture.md) §9 #3)从"一次大重构拆两域"重定义为"靠 routing 规则约束新代码增长方向"。

## 两句记忆口诀

1. **存档从 GI 序列化** —— GI 是唯一序列化根;只有 data shape(actor / GI 持的纯数据类)进存档;**service 永不进存档**(故两种 service 形式都不持久)。
2. **服务两种形式** —— ① static 纯函数(无状态)② RefCounted(自持 transient 私有状态,GI 启动时建、每 session 重建)。

两句切成"会持久的"(走第一句 = data shape,不是 service)和"是行为的"(走第二句 = 两种 service);"持久的 service"这个中间态被第一句禁掉,故无第三种。

## 不变量(铁律)

1. **持久只走 data shape,service 永不进存档** —— 换来"想知道存了啥只看 data shape"的一行存档审计,以及清晰的 data/logic 边界。
2. **actor = 完整游戏实体**(数据 + 逻辑 + 身份/registry/生命周期),**不是数据袋** —— 纯数据(全局世界时钟 / 商店库存等)用普通 RefCounted 数据类(GD 无 struct),由 GI 或某 actor 持有、序列化根捎带,**别为序列化硬塞成 actor**。
3. **傀儡测试** —— RefCounted service 升类的**两个**合法理由:① 自己要记 transient 私有状态;② **多态派发**(无状态 strategy / handler 实例,行为即身份 —— 如 6 个 NPC handler、battle AI strategy;GDScript static 做不了多态,拍平 = GI 内长 match 阶梯,违反"规则按模块分块"纪律)。两者皆无 → 退回 static 纯函数。傀儡的特征 = **持有** gi 字段空转;**收** gi 当参数的无状态多态实例不是傀儡。(② 为 2026-06-10 修订补充,原文只写 ①,字面会误伤 handler/strategy。)
4. **真正的约束是"被唯一序列化根够到",不是"必须挂 GI 字段"** —— GI 现在碰巧是那个根,持久数据才向它聚;数据绑的是"那个唯一的存档根",不是 GI 这个类。

## 推论:battle 与 overworld 对称 —— 都是 GI 的 world-host 职责,都不拆成域对象

`WorldGameplayInstance` 基类把 world-host 机器**钉死在 GI 上、拿不走**,且这套机器**同时**服务 battle 与 overworld:
- battle 宿主:`start_battle` / `has_active_battle` / `tick` 战斗分支 / `_create_battle_procedure` / `battle_finished`;
- overworld 宿主:`grid` 字段(overworld grid,战斗期翻转成 battle grid)/ `add_actor`·`remove_actor`(world actor registry)/ `actor_position_changed` signal(逐格移动输出)/ `add_system`·`tick`(驱动 CommandDrain→Movement)。

overworld 的 `world_actors` 只是基类 registry 上的二级索引;移动 System 靠基类 `add_system` 注册、基类 `tick` 驱动、基类 `actor_position_changed` 输出。⇒ 按"基类钉死宿主职责 → 拿不走"的同一逻辑,**overworld 与 battle 钉得一样死**,没有原则理由说 battle 不拆而 overworld 该拆。

两者的"杂活"都归 static service(battle:建队/布阵/发奖/清场 → `InkMonBattleSetup`);两者都**不**抽成有状态 RefCounted 域对象(硬抽只会得到揣 gi 空转的傀儡,违反上面 invariant #3)。overworld 唯一真正私有的 transient 状态是 grid,而它**早已**是独立对象 `InkMonWorldGrid`(grid 的 data-shape wrapper);near-npc 那一小撮顶多并进 `InkMonWorldGrid` 当 helper,够不上域对象。

⇒ GI 终态 = **registry + 序列化根 + CQRS 三通道基础设施 + world 宿主(battle + overworld,同一套基类机器)**。不是"薄协调器 over N 域"——未来长不出 N 个有状态域,只长出更多 stateless service + actor 多几个字段。"overworld vs battle"是 main-game-architecture.md §1 的命名/概念分层,**不是对象所有权边界**。§9 #3 早先"拆 overworld/battle 两域"、以及本 ADR 初稿"只抽 overworld"的非对称结论,均按此**作废**(修订于 2026-06-04):对称 —— 都不拆。

## 考虑过的另一派(rejected)

每个 service 都做成 GI 启动时创建、**自持数据(含持久)并自序列化**的 RefCounted(DDD aggregate 式"数据+逻辑同居")。否决理由:① 持久数据散进 N 个自序列化 service → 存档完整性不能一眼审(要逐 service 查有没有藏持久字段),且易漏接线静默丢档;② 模糊刚立的 data/logic 边界(与"actor≠数据袋"同种污染);③ 操作共享 `roster`/`player_actor` 的 service 会退化成揣 gi 的傀儡。保留"持久只走 data shape"换一行存档审计 + 清晰边界。该派在"某 service 确有大量自有 transient 状态 + 内聚逻辑"时仍可局部采用(= 上面 RefCounted 那叉),只是**不许碰持久**。

## 落地状态

规则即时生效(约束**新**代码 routing)。战斗无状态杂活已下沉 `InkMonBattleSetup` static service(`extract-battle-setup` goal,GI 862→723 行)。overworld **不再抽域对象**(见上「推论」修订);GI 内联持有 overworld 状态,与 battle 宿主对称。god-object 不靠一次拆解消除,靠 routing 规则约束增长,非大重构。
