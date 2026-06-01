# Inkmon — Context

Godot 4.6 回合制 / ATB 战斗模拟框架 (Logic Game Framework)。三层架构: Core Logic (纯模拟) → Game Logic (战斗规则) → Presentation (VFX)。最终导出 Web/WASM, 也支持本地 headless。

## Language

**hex-atb-battle**:
回合制 + hex grid + Timeline 技能系统的 example。**定位 = 技能系统展示 + AI 技能沙盒**, 不是要平衡的可玩对战 (逻辑层零玩家输入; 消费方全是 AI-vs-AI demo + skill-preview 沙盒 + SkillValidator)。
_Avoid_: 把它当"可玩 1v1 对战"——那是 rts-auto-battle 的目标 (M2 milestone)。

**rts-auto-battle**:
实时连续坐标 + 自研 grid + A* 的 example。**定位 = 走向单人可玩 1v1 skirmish demo** (M2 milestone), 有玩家命令 / 经济 / AI 对手。
_Avoid_: 与 hex 的"沙盒"定位混淆。

**active ability (技能)**:
`class_name HexBattle*` 导出 `static var ABILITY := AbilityConfig.builder()...build()` 的声明式技能。无 .tres 数据层。执行链: `ABILITY_ACTIVATE_EVENT → active_use timeline → on_tag([Action]) → 共享 Action.execute → pre/post event`。
_Avoid_: skill (口语可用, 但代码里类名是 ability / AbilityConfig)。

**SkillValidator** (`scripts/SkillValidator.gd`):
校验 AI 生成技能脚本的五级验证器 (编译 → 接口 → 运行 → 结构 → advisory)。生产入口 = web JS 桥 `godot_validate_skill`。技能契约 = `static var ABILITY`。

**balance (在 hex 语境下)**:
因 hex 是沙盒, "balance" 验收标准 = **范式一致 + 行为可预测 + 可被 validator/AI introspect**, 不是"数值公平"。
_Avoid_: 把 hex 的 balance finding 当"调公平数值"的任务。

**InkMon (单位养成深度)**:
长期目标 = **深度英雄 (Dota 向)**: 每只多技能槽 + 6 装备 + 刻印 + 勋章 + 进化 stage。存档数据模型按这一档设计 (浅用法只是少填字段)。
_Avoid_: brief 第 16 行"云顶之弈式自走棋"是误导性比喻 —— InkMon **不是 TFT 浅棋子** (无羁绊/费用/reroll 设计意图); 真实形态 = "hex 棋盘上一队 Dota 深度英雄的 ATB 自走战" (2026-05-31 grill 拍板)。

**InkMonRosterEntry (存档单位)**:
一只己方 InkMon 的持久化表示, 非 battle actor。**核心原则 (2026-05-31 grill)**: 只存"身份+选择+进度", 不存"算出的最终值"。v1 目标字段 = `{entry_id, species, stage, level, exp, skill_slots:[{slot_index, skill_id}], engravings:[{engraving_id, target_slot}], equipment_container}`。
_Avoid_: 删现状三处错字段 —— `learned_skill_id` 单数 (改 `skill_slots` 集合)、`persistent_stats` 六维 (改 `f(species,stage,level)` 运行时派生, 不进 entry)、`medals` (勋章是**玩家级**, 移到 `InkMonPlayerState`)。技能 roll **不带数值变异** (变异 v1 砍掉, 未来可选; 个体独特性靠刻印/装备/技能选择); 详见 docs/L2-ARCHITECTURE.md §8c。

**存档兼容策略**:
**v1 存档永不需要向后兼容** (2026-05-31 grill 拍板)。`from_dict` 遇旧版直接丢弃重开即可, 不写迁移。
_Avoid_: 因"怕破坏存档"而不敢改数据模型字段 —— 在此前提下数据模型可放心边做边改 (这也降级了 `learned_skill_id` 单数的严重性: 它只是形状不对, 不是 hard-to-reverse 的坑)。

**主游戏层职责参照 (`no-game-no-life` 项目)**:
L2 主游戏层 (现 `app_root.gd` 1593 行 God object) 的重构参照系 = ngnl 的职责划分 (用户偏好)。ngnl 实形: `logic/presentation/shared` 三层 + 下行 Command 队列 + 上行全局 EventBus + System 分块。
借法已定 (2026-05-31 grill): **取形不取器** ——
- ✅ 借: `logic/presentation/shared` 三层划分; 两条边界纪律 (逻辑层不引用 UI / UI 不直接改逻辑); 规则归位 (NPC 规则住进各 handler, handler 只收 `session`)。
- ✅ 上行 (逻辑→UI) = **Godot 原生 signal** (session/各模块 emit, UI connect 被动刷新), 不建全局 EventBus autoload。
- ❌ 不借: Command queue (主游戏层操作是即时同步, 无需 ngnl 那种"延迟到 tick"的队列); 全局 EventBus autoload (会与 battle 层 LGF event 系统两套打架); System 基类 (规则用 handler 表达即可)。
_Avoid_: 把"喜欢 ngnl 划分"解读成照搬其运行时机制。详见 memory [[feedback_anti_overengineering_inkmon]]。

**主世界 (InkMonWorld) + World Actor 层级**:
"主世界" = 非战斗的 hex 行走世界 (玩家 + 6 NPC)。代码前缀统一 `InkMonWorld*`,prose 用"主世界"。世界里**一切有位置的实体都是 `InkMonWorldActor`** (持 `hex_position`);战斗单位是它的特化,层级 = `InkMonWorldActor → InkMonBattleActor → InkMonUnitActor`。玩家/NPC = 直接 `InkMonWorldActor` (无 ability/timeline)。`hex_position` 住 `InkMonWorldActor` 基类 (位置是三者共有、也是 GI `actor_position_changed` 报告的东西);死亡 `_is_dead` 留 `InkMonBattleActor` (主世界实体不死)。
_Avoid_: 把"主世界 actor"与"battle actor"当两套不相干类型 (实为基类↔特化)。

**主世界 Command / Query (2026-06-01 grill 拍板)**:
L2 主世界 UI↔逻辑边界 = CQRS 式两条路。**Query (读)** = UI 同步调 WorldGI 只读方法渲染 (roster/gold/near-npc/列表 enabled),随便读。**Command (写)** = UI 改任何游戏/世界/存档状态的**唯一**入口,异步:enqueue → WorldGI tick 应用 → 结果经 event/signal 回流 → UI 被动刷 (不读返回值)。纯 UI 状态 (切 tab / 开关抽屉 / modal / 相机 / 菜单开着) 不算 command,留表演本地 (app_state 不独立存储 —— 战斗 MODE 由 WorldGI 的 `_active_instance_id` 派生,面板态 = 表演的 `_drawer_mode`)。详见 docs/L2-ARCHITECTURE.md §1。
⚠️ 与 battle 层区分:此 "Command" 是**主世界输入→世界写**,**不是** LGF battle 的 `Action` (战斗内 Command 模式) 或 `event_processor` 的 `ABILITY_ACTIVATE_EVENT`;两层各自独立,别混为一谈。
_Avoid_: UI 直接调逻辑 mutation / 同步拿写结果; 把主世界 command 与 battle Action/event 当一回事。

**主世界三层 + Host (2026-06-01 grill 拍板)**:
L2 主世界 = **三层**,非"逻辑 vs 表演"两层。**Host (导播 = `InkMonWorldHost`)** = composition root,在 logic/presentation **之上**:建两孩子 + 接线 (连 command↓ / event↑ 的线) + 拥有它们的生命周期 (save/load/new-game/reset = 重建孩子) + tick 泵 (`GameWorld.tick_all(FIXED_DT)`);**不参与** command/event 对等流。**Logic** = `GameWorld` (autoload: event_processor + instance registry) → `InkMonWorldGI` → {session, world actors, systems, overworld grid} (+ TimelineRegistry/ItemSystem/UGridMap 等 autoload)。**Presentation** = View3D/HUD/drawer/modal。
**两轴别混**:数据流 (运行时) = **双向** (command 下 / event 上 ⇒ "感觉平级");代码依赖 = **单向 DAG** (Presentation→Logic;Logic 谁都不依赖、永不引用 UI;Host→两者)。⇒ Logic 是地基,Presentation 长其上,Host 在两者之上。lifecycle 重建归 Host (它建了两孩子),**非**"表演层重建逻辑层"。嵌套两 Host (§6b):外 `InkMonMain` (切屏 + 选 session) / 内 `InkMonWorldHost` (游戏内组装 + lifecycle)。
_Avoid_: 把 Director 当"表演层" (它是 Host,在表演之上); 把 logic/presentation 当真·平级 (仅数据流平级,依赖不平级)。

## 主游戏层架构 (L2 — 2026-05-31 grill 拍板)

三块, 互不混 (对标 hex-atb-battle: 它只有 battle 那一块):

**① Battle = 唯一 InkMonWorldGI 内的 procedure (无独立 battle GI)**:
目标 = LGF World-owns-Battle: 整个主游戏**只有一个** `InkMonWorldGI` (extends WorldGameplayInstance) 承载逻辑+世界数据; **战斗是它内跑的 `InkMonBattleProcedure`**, 非独立 GI (用户原话"battle 是 procedure 模式, 没有 battle GI")。
- ✅ 复用(对): `InkMonBattleProcedure` + M1 战斗数学 (双通道伤害/6 元素/角色 AI/action/passive) 全保留。
- ❌ 合并掉(错): `InkMonBattleWorldGI` (codex 造成"一场战斗=一个独立 world 实例 create→destroy") = "战斗 owns 世界"老式, 职责并进唯一 InkMonWorldGI, 战斗只留 procedure。
_Avoid_: 别再把 `InkMonBattleWorldGI` 当对的去保留 —— 它要被合并。(我曾写"非债别合并", 是错的, 与用户"合并进 InkMonWorldGI"决定相反, 已纠正。)
> ⚠️ 一个 GI 持两套 grid (overworld+battle) 切 active = **第一版临时方案, 非最优, 用户未来再优化; 非本次核心** (核心 = God object 拆 + 三块边界 + 职责纪律)。

**② 主世界 (Overworld) = hex 网格世界 (现状方向基本对)**:
玩家角色行走、承载 6 个 System NPC 的 **hex 网格世界** (= lab 设计真相 "主世界 = hex 网格世界")。移动 = 点目标 → **grid 插件寻路** (非自研 BFS, 非 NavMesh 自由移动) → 沿路径动画。实现**参考 hex-atb-battle 的 move 方案**, 移动动画同款。
_Avoid_: **(2026-05-31 纠正 hallucination)** 本会话我曾写"主世界 hex 是设计错误 / 整套作废 / 改自由移动 3D" —— **用户从未这么说, 是我把诱导性选项描述当成了确认**。lab CONTEXT 明确主世界 = hex 网格世界, 用户确认移动走 grid 寻路。两个提交 (64a8452 / 47e7e73) 的 hex-grid-移动**地基方向对**, 只是有 UI 层 race bug (drawer ghost / overlay 层级 / load-during-move), 修 bug 而非废地基。术语统一用**主世界**, 不用英文 overworld。

**③ Session = 持久存档 (独立于①②)**:
`InkMonGameSession` 持 roster / gold / progression, 是存档根。进战斗: 从 session 投影 snapshot 喂给 battle GI; 战斗结束: battle result 写回 session。overworld 与 battle 通过 session 间接连, 不互相引用。

**唯一真相 = 运行时内存, 不双写** (2026-05-31): session 内存即真相; save 序列化一次, load 反序列化一次, 中间不来回同步。主世界玩家位置等世界态运行时只住主世界运行层 (GI/grid), 存档字段只在 save/load 两端读写。

**职责纪律 (借自 ngnl, 取形不取器)**: ① 逻辑层不引用 UI; ② UI 不直接改逻辑; ③ 规则按模块分块。上行 (逻辑→UI) = signal (battle 用 WorldGI 内建 signal; overworld 用普通 Godot signal), UI connect 被动刷新, **不建全局 EventBus**。详见 memory [[feedback_anti_overengineering_inkmon]]。

**NPC handler 契约**: 6 handler 统一 = 收 `session`, 返回 `{ok, message, intent?}`。纯数据 NPC 直接改 session; training→战斗返回 `intent`(start_battle+config), 由场景层解释 → 起 battle GI。
_Avoid_: 现状 `run_action(app_root)` 让 handler 反向持 God object —— 切断。

**God object (`app_root` 1593 行) 要拆**: 规则→handler, 战斗→battle GI/procedure, overworld→3D 场景, 持久数据→session, UI→presentation view (.tscn)。场景根 Node 只剩 wiring + 输入转发 + flow 切换 (overworld ↔ 起 battle GI)。

**UI 搭建**: 全 `.tscn` (尽量编辑器), 代码只填文字/绑数据, 动态列表用 instantiate 组件场景。UI 在 presentation 层, 只订阅 signal / 调窄 API。
_Avoid_: 现状 100% 代码 `Button.new()` + 零 UI .tscn, 要改。

## Relationships

- **hex-atb-battle** 与 **rts-auto-battle** 是两个独立 example, 共享 LGF core; 定位不同 (沙盒 vs 可玩)。
- **SkillValidator** 校验的技能必须符合 **active ability** 的 `static var ABILITY` 契约。
- 死者 (hp≤0) **留在 world registry** (`get_actor()` 非 null, `hex_position` 字段保留), 只清 grid occupant — 见 design-note 2026-04-26。这条是判"目标死亡→技能 fizzle?"类 finding 的不变量。

## Flagged ambiguities

- "balance" 在 hex 语境被澄清: 沙盒定位下 = 一致性/可预测/可introspect, 非数值公平 (2026-05-31 grill 确认)。

## 文档约定

本仓库的 ADR 等价物 = LGF 既有的 `addons/logic-game-framework/docs/design-notes/YYYY-MM-DD-<topic>.md` (CLAUDE.md 规定)。不另起 `docs/adr/`。
