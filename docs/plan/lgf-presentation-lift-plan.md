# LGF 表演管线上提计划（刀 9，2026-09-24）

> 2026-09-24 用户 + fable 讨论定稿。范围：`addons/logic-game-framework/`（新建 `presentation/` + hex 示例 `frontend/` 改造 + `tests/`）+ 主仓 `docs/` / `CLAUDE.md`。**`inkmon/` 零改动**（冻结，见 task-queue 2e）。
> 来源：[`lgf-core-refactor-2026-09.md`](lgf-core-refactor-2026-09.md) §4 第一条「刀 9 表演管线上提：另开计划，前提是先对齐 hex 3D 与 inkmon 2D 两份分叉」。拍板记录见 [adr/0013](../adr/0013-presentation-pipeline-lift-to-lgf.md)。
> 状态：**PL0–PL3 已完成（2026-09-24），PL4 起未启动**。每阶段完成后在 §6 填 submodule / 主仓 SHA。
> 执行方式：与 core 重构同款——每阶段 fresh context、一个原子提交对（addons + 主仓）、失败即停、无人值守不 push。验收机械沿用 core 计划 §2，差异见本文 §2。

---

## 0. Context（讨论中读代码查到的事实）

- **两份分叉 = 同一骨架逐字拷贝**。去掉 `Frontend*` / `InkMonRender2D*` 前缀后，VisualAction（含 easing）/ ActionScheduler / VisualizerRegistry / BaseVisualizer / ActorRenderState / AnimationConfig / RenderData / 5 个共享 action（move / death / floating_text / procedural_vfx / apply_hp_delta）差异只剩 `Vector3 ↔ Vector2`；RenderWorld（776 vs 451 行）与 driver 的 tick 骨架（accum → drain 帧 → translate → enqueue → scheduler.tick → apply active+completed → cleanup → hp_lerp → flush）同一套。
- **唯一设计分歧 = 坐标出口**：hex 在 `VisualizerContext` / `RenderWorld` 里持 `GridLayout`，直接吐 `Vector3` 世界坐标；inkmon 核心只吐逻辑 axial `Vector2`，hex→像素转换收在 driver→view 边界一处。inkmon 这套 2D/3D 中立。
- **功能面差异**：hex RenderWorld 多 8 个 handler（attack_vfx / projectile / buff / shield / bump / facing / cone）+ `position_formats` 解释；inkmon 多 live 入口（`seed_actor` / `despawn_actor` / `cancel_for_actor` / `has_actor_action`）。
- **事件方言锁在翻译员子类**：hex 认 `BattleEvents.DAMAGE_EVENT` + `from_dict` 强类型；inkmon 认 `"inkmon_damage"` + raw dict。框架核心不认识任何方言词。
- **hex 录像已是 hex 格式**：`HexWorldGameplayInstance._get_position_formats()` 全员 `"hex"`（position = `[q, r, 0]`），`_extract_hex_position` 的 `"world"` 分支是死路。
- **依赖面**：核心只依赖 core 的 `PlaybackData` / `GameEvent`；`HexCoord`（ultra-grid-map）只在翻译员解析事件时出现。
- **消费方**：hex = demo × 2 + skill-preview + 14 个 frontend / skill-preview smoke（scripts/ 与 scenes/ 零引用）；inkmon = battle_2d animator + overworld live driver（11 个 smoke / shot 脚本引用，冻结）；kards-tavern 待用户接；dota2 是直绘快照的非管线 live 视图，不接。
- **三条既有立场**：adr/0006「暂弃抽到 `stdlib/frontend/` 共享，等第 3 个消费者」；glossary 1.2「表演层刻意不总结成框架复用」；inkmon 冻结（2e）。前两条由 adr/0013 取代，第三条本计划严守。
- **hex 侧改名爆炸半径**：`Frontend*` 共 51 个 class_name、约 800 处引用；其中要搬进框架的 core / actions / 基类约 25 个类，视图 / 翻译员留在 hex。
- **用户对框架的评价**（2026-09-24）：设计本身认可，问题在 AI 起的名字误导——`RenderWorld` 不是 world 是账本，`Scheduler` 不做调度是秒表表，`Visualizer` 不出视觉只出卡片，`Interpreter` 在编程语境里是执行不是翻译。新词表见 D3。

## 1. 固定决策（本轮 grill 已拍板，执行时不重开）

### 1.1 用户拍板的三题

| # | 决策 |
|---|---|
| U1 | **inkmon 重设计（2e）留不留这条管线：2e 启动时再定。** 本计划按「hex 是唯一确定消费者、inkmon 待定」规划；inkmon 现有 `render2d/` + `battle_2d/` + `overworld/` 拷贝维持到 2e，一行不动。 |
| U2 | **kards-tavern 用得上，但等这边框架改完，由用户单独去那个项目接。** 用户原话：「理论上未来我们所有基于本框架开发的项目，表演层都可以使用」——共享表演包定位为 **LGF 标配层**，不再是「三个再抽」的候选。 |
| U3 | **范围 = B：现在只把 hex 半边抽进 LGF。** 坐标约定改成 inkmon 那套；hex 自己成为第一个消费者。 |

### 1.2 技术决策（用户全权委托 fable 定，只审结论）

| # | 决策 |
|---|---|
| D1 | **目录 = LGF 顶层新建 `presentation/`**（`core/` / `stdlib/` / `presentation/` / `example/`），不放 `stdlib/`。理由：它是三层架构的第三层，物理落地；含 `Node`（Director）与 signal，与 stdlib 全 RefCounted 逻辑电池性质不同。依赖方向 `presentation/ → core/`（`PlaybackData` / `GameEvent`）；**不依赖 `stdlib/`、不依赖 ultra-grid-map**。 |
| D2 | **坐标约定：框架只讲「逻辑平面坐标 `Vector2`」，含义由项目定**（hex 项目 = axial `(q, r)` 浮点；连续项目 = 世界 `(x, y)`）。`HexCoord` 不进 `presentation/`。卡片的所有位置字段（floating text / move from·to / projectile start·target / attack vfx source·target / bump offset·squish）都是逻辑 `Vector2`；欧氏派生量（方向 / 距离 / 多边形）在 view **投影后**算。`VisualStateQuery.get_actor_position() -> Vector2`（含在飞插值）。`GridLayout` / 像素 / 3D 投影只住项目 view 层（hex：`FrontendBattleAnimator._project(axial) -> Vector3` + views）。录像 `position` 默认取前两分量为逻辑坐标，框架留 `_parse_position(actor_init) -> Vector2` 钩子；`position_formats` 留在录像格式里不动，hex 的 `"world"` 分支删除。 |
| D3 | **词表**（框架件**无前缀**；项目件带项目前缀——hex `Frontend*`、inkmon `InkMon*`——看前缀就知道是不是框架件）：`VisualDirector`（表演实例，抽象 Node，tick 总负责）/ `ReplayDirector`（录像回放子类）· `Translator` + `TranslatorRegistry`（翻译员；`Visualizer` 一词退役）· `VisualAction` + 内置子类 `Visual*Action`（卡片）· `ActionStepper`（步进器；原 Scheduler）· `VisualState`（账本）+ `ActorVisualState`（每个进入过表演的逻辑 actor id 一条）+ `VisualStateQuery`（翻译员用的只读视图）· `VisualUpdater`（更新器）· `AnimationConfig` · `BuffSummary` / `ShieldSummary` · `VisualEffectPayload.*`（一次性效果 payload，原 `RenderData` 内嵌类）。Views 永远是项目件，框架不出。完整 old → new 映射见 §3 PL2。 |
| D4 | **卡片种类可扩展**：`VisualAction.kind: StringName`（替代闭合 enum），内置 kind 常量在 `VisualAction` 上；`VisualUpdater` 持 `kind → Callable` handler 表，内置 11 种默认注册，项目 `register_handler(kind, callable)` 加私有种类。hex 的 cone debug overlay 留在 hex（`FrontendConeDebugOverlayAction` + hex 侧注册 handler），作为「项目私有卡片」范例。弃选：多态 `action.apply(state)`——卡片保持纯数据、记账规则集中一处更贴用户心智模型。 |
| D5 | **信号面收成 7 条**（`VisualState` 发、Director 原样转发）：`actor_state_changed(id, state)` / `actor_spawned(id, state)` / `actor_died(id)` / `actor_despawned(id)` + `effect_spawned(kind, payload)` / `effect_updated(kind, id, progress, payload)` / `effect_removed(kind, id)`。取代今天的 `floating_text_created` / `attack_vfx_created·updated·removed` / `projectile_created·updated·removed` / `cone_debug_overlay_created` 8 条——项目私有效果种类不用改框架信号。hex `FrontendBattleAnimator` 按 kind 分发。 |
| D6 | **Director 骨架进框架**：`VisualDirector extends Node`（抽象）持 registry / stepper / state / updater / config，`pump(delta_ms, events: Array[Dictionary])` = 共享 tick 体（事件直改 → 翻译 → 入 stepper → advance_time → stepper.tick → apply active+completed → cleanup → hp_lerp → flush）；**只发信号，不持 view**。`ReplayDirector extends VisualDirector`：帧时钟（`tick_ms` 取 `record.meta.tick_interval`，缺省 100）+ 帧表 + `load_playback / play / pause / toggle / reset / step / set_speed / is_playing / is_ended / get_current_frame / get_total_frames` + `playback_state_changed / frame_changed / playback_ended` + 加载时一次事件覆盖分析。live 项目直接继承 `VisualDirector` 自己喂 `pump`（inkmon 2e 时 `InkMonOverworldLiveDriver` 改成这样）。live 入口进框架：`VisualState.seed_actor / despawn_actor`、`ActionStepper.cancel_for_actor / has_actor_action`（照 inkmon 现版抄）。hex `FrontendBattleDirector` 删除，`FrontendBattleAnimator` 持一个 `ReplayDirector`。 |
| D7 | **Updater 形态**：`VisualUpdater extends RefCounted`，除 handler 表外无状态；三类输入三个入口——`apply_actions(state, active: Array[ActionStepper.ActiveAction])`（action × 进度）/ `apply_event(state, event)`（事件直改：spawn / destroy / max_hp，必须在翻译前落账本）/ `tick_time(state, delta_ms)`（时间驱动：过期效果清理 + `visual_hp` 追赶）。handler 签名 `static func (state: VisualState, action: VisualAction, progress: float, action_id: String) -> void`。 |
| D8 | **文档与规则之家**：ADR-0013 + adr/0006 顶部标注 + glossary 1.2 改写 + task-queue 3d 登记（**本轮已落**）。执行期（PL4）：LGF `CLAUDE.md` 分层图加 `Presentation` 子图、「设计铁律」加三条（核心只讲逻辑平面 `Vector2`；框架不持 Node / view，Director 只发信号；卡片纯数据、记账规则只在 Updater）、新节「Presentation layer」= 词表 + tick 顺序 + 消费方接入清单；主仓 `CLAUDE.md` L11 Presentation 路径改 `addons/logic-game-framework/presentation/`；hex `frontend/README.md` 删「框架设计 / 四层管线 / 核心类说明」段改指向 LGF `CLAUDE.md`，保留响应式 wire / 目录结构 / 新技能表演层接入清单。不建 `presentation/README.md`（规则之家只有两个，P5.5 纪律）。 |
| D9 | **不做**见 §4。 |

## 2. 每阶段验收协议（沿用 core 计划 §2 机械，只列差异）

**全量测试组**（PowerShell tool，两条分开调用，各 timeout 600000，不与其他调用同批）：

```powershell
./tools/run_tests.ps1 -Required
./tools/run_tests.ps1 hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env
```

- `hex/all` 含 `frontend`（9）/ `random-frontend` / `random-frontend-20`（180s）/ `skill-preview`（9）/ `regression` / `skills` / `random-golden`——表演改动的主回归面。
- **新增**：`core/unit` 挂 `tests/presentation/*_test.gd`（`run_tests.gd` 的 `TEST_PATHS` 手动追加）；`hex/frontend` 组加 `frontend/smoke_presentation_golden.tscn`。
- **inkmon 冻结守卫**：`inkmon/all` 绿 **且** `git status --porcelain -- inkmon/` 为空，写进每阶段完成定义。

**钉子（PL0 建，改代码前在旧代码上跑绿）**：

1. **表演 golden** `smoke_presentation_golden`：取 `hex/random-frontend` 的固定 seed 录像，用 Director 的 `step()` 逐帧推到 `playback_ended`，记录 ① 每帧翻译出的卡片序列 `(frame, kind, actor_id, delay, duration)` ② 每帧 flush 后各 actor `(actor_id, position 取整为 hex 整数, target_hp, round(visual_hp), is_alive, buff ids, shield ids)` ③ 每帧一次性效果 spawn / remove 计数 → 一个指纹整数 + 明文 dump（`.claude/tmp/presentation-golden/`，差分归因用）。**位置从第一天就按 hex 整数比较**，PL1 改 `Vector2` 不该漂移。kind 名在 PL2 改名时按映射表换算后比较（golden 脚本内置 old→new 表）。
2. **单测**（`tests/presentation/`）：Stepper（delay / duration / progress 0→1 / completed_this_tick / cancel_all）、Updater（hp delta 死亡 sticky、buff / shield ADD·UPDATE·REMOVE 顺序契约与 noop guard、bump 完成 snap 回零、facing 瞬时）、Registry collect-all 与 `has_translator_for`、State 事件直改（spawn / destroy / max_hp clamp）。
3. **leak 直方图基线**：`smoke_frontend_main` 一份，存 `docs/plan/lgf-presentation-lift-leak-baseline/hex-frontend.hist.txt`。表演框架类（Director / State / Stepper / Registry / Translator 子类 / VisualAction 子类 / Updater）计数只许持平或下降；Node 类既有泄漏不在本轮修。

**golden 变红通则**：红 = 表演行为变了。能证明是计划明写的变化（如 PL2 信号面合并导致 effect 计数口径变）→ 偏离记录一条后重烤；不能证明 → 取保住今日行为的改法；都做不到 → BLOCKED。`hex/random-golden`（逻辑 golden）与 inkmon golden **一律不许重烤**——本计划不碰逻辑层。

**第 2 关**：完成定义逐条勾选 + 两问自查（① 新增的每张表 / 注册 / 缓存在 `reset` / `load_playback` / `clear` / `_exit_tree` 四个出口是否对称清掉；② 新增或改动的每个循环遍历的是不是快照）+ 偏离记录写 [`lgf-presentation-lift-deviations.md`](lgf-presentation-lift-deviations.md)（本轮已建空表；格式 `- PL<n>-<序号> / 做了什么 / 为什么`，每条 ≤ 200 字）。范围外发现记本文 §6「后续观察」一行，不顺手修。

**第 3 关**：无。PL5 对 PL1–PL4 累计 diff 做一次整体审。

**提交协议**：同 core 计划（submodule `refactor(lgf): PL<n> <标题>`；主仓 `refactor: LGF 表演上提 PL<n> <标题> (addons → <sha>)`，路径 add：`addons docs CLAUDE.md tests tools`；不 push；master）。新 `.gd` 的 `.gd.uid` 随 commit 一起提，没生成先跑一次 headless 让 Godot 生成、不手造；搬家的脚本旧 `.uid` 随文件一起 `git mv`。

## 3. 阶段

### PL0 钉子先行

**改法**：§2 三件钉子。不改任何 `frontend/` 源码。
**完成定义**：golden 指纹在 `hex/random-frontend` 固定 seed 上两次运行相同；单测全绿；leak 基线落盘；submodule `test(lgf): PL0 presentation pins`；主仓 commit 带基线目录 + §6。

### PL1 坐标对齐（hex 原地改，不搬家）

**目标**：把 D2 落到 hex 现有代码上，让核心与 3D 脱钩，是「先对齐两份分叉」的实质。
**改法**：
1. `visualizer_context.gd`：删 `_layout`、`hex_to_world`、`get_layout`；`get_actor_position() -> Vector2`（axial 浮点，含在飞插值）；`get_actor_hex_position` 保留一版返回 `HexCoord`（hex 翻译员解析事件用）。
2. `render_world.gd`：删 `_layout` / `_position_formats` / `get_grid_layout` / `get_actor_world_position` / `_extract_hex_position` 的 `"world"` 分支；`get_actor_axial(id) -> Vector2`（照 inkmon）。
3. actions：`floating_text.position` / `attack_vfx.source·target_position` / `projectile.start·target_position` / `bump.offset·squish` → `Vector2`；`lerp_vector3` → `lerp_vector2`；`attack_vfx.get_direction·get_distance` 与 `projectile.get_direction` 删除（欧氏量到 view 算）；`cone_debug_overlay` 的 `cell_polygons` / `boundary_segments` 改成 axial 单元格列表 + axial 线段，view 端建多边形。
4. visualizers：`push_blocked` / `stage_cue` / `projectile` 改用 axial；`stage_cue` 的 `context.get_layout()` 用法改为在卡片里带 hex 单元格，让 view 投影。
5. `battle_animator.gd` / `world_view.gd` / `scene/*`：新增 `_project(axial: Vector2) -> Vector3`（从 `GridLayout` 双线性插值，逻辑照抄今日 `get_actor_world_position`）；所有 `Vector3` 消费点改在这里投影；`battle_director.gd` 的 `get_actor_world_position` / `get_grid_layout` 移到 animator。
6. `view_logic_reconciler.gd` 的 `expected_alive_pos: Vector3` 改比较 hex 坐标。
**钉子**：golden 零漂移（位置口径本就 hex 整数）；`hex/frontend` `hex/random-frontend-20` `hex/skill-preview` 全绿；`smoke_world_view` / `smoke_facing_indicator` / `smoke_shield_layout` 这些看像素的 smoke 若红，先看是否只是投影入口换了位置。
**完成定义**：`grep -rn 'Vector3\|GridLayout' frontend/core frontend/actions frontend/visualizers` 为零；全量组绿；inkmon 守卫；两仓 commit；§6。

### PL2 搬家 + 改名 + 扩展缝

**改法**：
1. 目录：`example/hex-atb-battle/frontend/{core,actions}` + `visualizers/{base_visualizer,visualizer_registry}` → `presentation/{core,actions}`（`git mv` 连 `.uid`）；`presentation/` 下不留任何 hex 词（`HexCoord` / `BattleEvents` / `HexFacing` 一律不许出现，lint 断言）。
2. 改名映射（class_name + 文件名）：`FrontendVisualAction → VisualAction` · `FrontendActionScheduler → ActionStepper` · `FrontendVisualizerRegistry → TranslatorRegistry` · `FrontendBaseVisualizer → Translator` · `FrontendVisualizerContext → VisualStateQuery` · `FrontendRenderWorld → VisualState`（数据半边）+ `VisualUpdater`（apply 半边，新文件）· `FrontendActorRenderState → ActorVisualState` · `FrontendAnimationConfig → AnimationConfig` · `FrontendRenderData → VisualEffectPayload` · `FrontendBuffSummary / ShieldSummary → BuffSummary / ShieldSummary` · 内置卡片 `FrontendMoveAction → VisualMoveAction` / `ApplyHPDelta → VisualHpDeltaAction` / `FloatingText → VisualFloatingTextAction` / `ProceduralVFX → VisualProceduralVfxAction` / `Death → VisualDeathAction` / `AttackVFX → VisualAttackVfxAction` / `Projectile → VisualProjectileAction` / `ApplyBuffState → VisualBuffStateAction` / `ApplyShieldState → VisualShieldStateAction` / `Bump → VisualBumpAction` / `ApplyFacingState → VisualFacingStateAction`。hex 留下的：12 个 `Frontend*Visualizer → Frontend*Translator`；`FrontendDefaultRegistry` 保留名字改建 `TranslatorRegistry`；`FrontendConeDebugOverlayAction` 留 hex；视图 / `FrontendBattleAnimator` / `FrontendWorldView` / `FrontendPlaybackControls` 名字不动。
3. D4：`kind: StringName` + `VisualUpdater` handler 表；hex 侧 `FrontendBattleAnimator` 在建 Director 时 `register_handler(&"cone_debug_overlay", FrontendConeDebugOverlayAction.apply)`。
4. D5：信号面收成 7 条；`FrontendBattleAnimator` 的 11 个 `_on_*` 收成按 kind 分发。
5. `demo_frontend.tscn` / `demo_random_frontend.tscn` 与 tests 的脚本路径改；跑一次 `godot --headless --import` 让 uid 缓存重建。
6. `tests/presentation/*_test.gd` 路径与类名同步；golden 脚本换用映射表。
**钉子**：golden 零漂移（effect 计数口径若因 D5 合并而变，偏离记录写明后重烤，仅此一处允许）。
**完成定义**：`presentation/` 内 lint 断言通过；`grep -rn 'Visualizer' presentation example/hex-atb-battle/frontend` 为零；全量组绿；inkmon 守卫；两仓 commit；§6。

### PL3 Director 骨架 + live 入口

**改法**：`presentation/core/visual_director.gd`（`pump` 共享体，D6）+ `replay_director.gd`（帧时钟等，从 `battle_director.gd` 抽）；删 `example/.../frontend/core/battle_director.gd`，`FrontendBattleAnimator` 持 `ReplayDirector`；`VisualState.seed_actor / despawn_actor` + `ActionStepper.cancel_for_actor / has_actor_action` 照 inkmon 现版进框架；`skill_preview.gd` 引用同步。
**测试**：`tests/presentation/visual_director_test.gd`——一个不带帧时钟的最小子类喂两条 move 事件 `pump` 到完成，断言 state 位置与 `has_actor_action` 翻转；`replay_director_test.gd`——固定 record 的 `step` 帧推进 / `playback_ended` / `reset` 幂等。
**钉子**：golden 零漂移；`hex/skill-preview` 全绿（skill-preview 是 Director 的第二个消费点）。
**完成定义**：hex `frontend/core/` 目录为空并删除；全量组绿；inkmon 守卫；两仓 commit；§6。

### PL4 文档与规则之家

**改法**：D8 执行期部分（LGF `CLAUDE.md` 三处 + 主仓 `CLAUDE.md` L11 + hex `frontend/README.md` 精简 + task-queue 3d 状态）。LGF `CLAUDE.md`「Presentation layer」节必须含：词表六件 + 一行职责、`pump` 的 8 步顺序、7 条信号、消费方接入清单（§7）。
**完成定义**：指针表无死链（`enforcing-lgf` SKILL.md「Where to look」若列了 frontend 路径同步）；两仓 commit；§6。

### PL5 整体审与收口

**改法**：对 PL1–PL4 累计 diff 做一次 `/code-review`（fable；submodule 内 `git diff <PL0 sha>..HEAD -- presentation example/hex-atb-battle/frontend tests`），只报 CONFIRMED 且 severity ≥ medium，修完不复审；leak 直方图与 PL0 基线比对；§6 收口；附 push 命令给用户。
**完成定义**：CONFIRMED ≥ medium 全部修完或偏离记录写明不修理由；全量组绿；直方图持平或下降；两仓 commit；不 push。

## 4. 明确不做（本轮认可，勿重开）

- **inkmon 一行不改**：`inkmon/presentation/{render2d,battle_2d,overworld}` 拷贝维持到 2e；inkmon golden / 指纹不变。2e 启动时再定留不留（U1）。
- **不接 kards**：用户改完框架后自己去 kards 接（U2），§7 只给清单。
- **不做「effects map 统一」**（把 floating_texts / attack_vfx / projectiles / cone 四份簿记合成一张 `effects{id → EffectState}` 表、走 actor 同款 dirty flush）——记 §6 候选后续，PL2 只统一信号面（D5）。
- **不改录像格式**：`position_formats` / `world_snapshot` / `timeline` 原样；不做 B 层 deterministic replay。
- **不给 dota2 接管线**：它是直绘逻辑快照的非管线 live 视图，留作对照。
- **不动翻译员的事件方言**：hex 仍 `BattleEvents` 强类型 `from_dict`，inkmon 仍 raw dict；框架不定义事件 schema。
- **Views 永不进框架**：`UnitView` / `Avatar` / 飘字节点 / 投影函数全是项目件。
- **不重设计动画语义**：hp 追赶、并行 + delay、死亡 sticky、buff / shield 顺序契约全部照搬。

## 5. 启动指令

两种方式等价，都是**每阶段一个 fresh context**：用户逐阶段开新会话粘贴「阶段 prompt」；或开一个总控会话粘贴「总控 prompt」按序派子 agent。总控须开 bypass permissions，电脑不能睡眠；无人值守期间**不 push**。子 agent 用 fable（表演层改造 + 整体审）。

**总控 prompt**：

```
你是 LGF 表演管线上提的总控，只派活不干活。读 docs/plan/lgf-presentation-lift-plan.md 的 §5 与 §6 状态表，找到第一个状态不是「已完成」的阶段（顺序 PL0 → PL1 → PL2 → PL3 → PL4 → PL5）。对该阶段用 Agent 工具派一个子 agent：subagent_type general-purpose，model fable，run_in_background false（工具不允许长阻塞则改 true，收到完成通知再继续），prompt 用 §5「阶段 prompt」原文填入阶段号。子 agent 返回后：读它的回报；跑 git -C addons log -1 --oneline 与 git log -1 --oneline 核对两仓各有本阶段的 commit；读 §6 确认该行已填「已完成」；跑 git status --porcelain -- inkmon/ 确认为空。四项都对 → 派下一阶段；回报是 BLOCKED、或核对不符 → 停链，把回报原样转给用户。全部完成后汇总并附 push 命令（git -C addons push origin master，再 git push origin master）。你自己不读源码、不跑测试、不改文件、不 push；不把两个阶段合给一个子 agent。
```

**阶段 prompt**（填 `<n>`）：

```
你在 D:\GodotProjects\inkmon\inkmon-godot（主仓 master；addons/ 是 submodule godot-addons）执行 LGF 表演管线上提的阶段 PL<n>。先完整读 docs/plan/lgf-presentation-lift-plan.md（§1 固定决策不重开、§2 验收协议、§3 你的阶段、§4 不做）与 docs/adr/0013-presentation-pipeline-lift-to-lgf.md；再读 CLAUDE.md 与 addons/logic-game-framework/CLAUDE.md。然后按 §3 PL<n>「改法」执行，按 §2 验收（钉子先行、全量组两条命令分开跑、inkmon 守卫、两问自查、偏离记录），按 §2 提交协议两仓各一个 commit，不 push。inkmon/ 目录一行不许改。完成后在 §6 状态表填本阶段 SHA 与「已完成」，范围外发现记 §6「后续观察」一行不顺手修。任何一关红且两轮修不绿 → 按 BLOCKED 处理：不 commit 半成品、§6 写 BLOCKED 原因与建议、停止。回报格式：阶段号 / 两仓 SHA / 测试结果一行 / 偏离条数 / 后续观察条数。
```

## 6. 状态与偏离记录

| 阶段 | 状态 | addons SHA | 主仓 SHA | 备注 |
|---|---|---|---|---|
| PL0 钉子先行 | 已完成 2026-09-24 | `bc385e6` | `fac6aaf6`（本行由随后的 docs 提交回填） | 验收：`-Required` 21 scene + `hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env` 78 scene 全 PASS（core 单测 285→312：ActionScheduler 5 / VisualizerRegistry 4 / RenderWorld 记账 12 / 事件直改 6；`hex/frontend` +1 `smoke_presentation_golden`）/ golden 三个 seed 各三次运行指纹与 dump 逐字节一致（651143 / 900127 / 900191，指纹 466926191 / 4212318930 / 2532673107）/ leak 基线 `hex-frontend.hist.txt` 为空（零泄漏）/ inkmon 守卫空。不改任何 `frontend/` 源码。偏离见 deviations 文件 PL0-1–5 |
| PL1 坐标对齐 | 已完成 2026-09-24 | `7c2ae56` | `faf96a47`（本行由随后的 docs 提交回填） | 验收：`-Required` 21 scene + `hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env` 78 scene 全 PASS（core 单测 312→316：新增 `visualizer_coordinates_test` 投射物 / bump / cone / 飘字坐标口径 4 条）/ golden 三 seed 指纹零漂移（466926191 / 4212318930 / 2532673107，dump 逐字节同 PL0）/ leak 直方图仍为空与基线一致 / 完成定义 grep `frontend/core actions visualizers` 零 `Vector3|GridLayout` / inkmon 守卫空。两问自查：新增的唯一缓存是 animator `_grid_layout`（RefCounted，每次 `load` 随录像重建、无回指，随节点释放）；新增循环只遍历本地数组 / payload 数组，无回调重入。偏离见 deviations 文件 PL1-1–8 |
| PL2 搬家 + 改名 + 扩展缝 | 已完成 2026-09-24 | `a0c9330` | `97519924`（本行由随后的 docs 提交回填） | 验收（隔离 worktree `../inkmon-godot-pl2`，两仓 HEAD + 本阶段路径）：`-Required` 21 scene + `hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env` 78 scene 全 PASS（core 单测 316→319：ActionStepper 5 / TranslatorRegistry 4 / VisualUpdater 13 / VisualState 6 / hex 翻译员坐标 4 / presentation lint 2）/ golden 三 seed 指纹零漂移（466926191 / 4212318930 / 2532673107，dump 逐字节同 PL1）/ leak 直方图仍为空与基线一致 / 完成定义 grep：`presentation` + hex `frontend` 零 `Visualizer`，`presentation/` 零 HexCoord / BattleEvents / HexFacing / Vector3 / GridLayout（lint 单测常驻）/ inkmon 守卫空。两问自查：新增的表 = `VisualState._effects`（`initialize_from_replay` 清，`reset_to` / `load_playback` 经它清，Director `_exit_tree` 置空）与 `VisualUpdater._handlers`（随 Director 生命周期，`_exit_tree` 置空，hex 只在 `_ready` 登记一次）；新增循环 `expire_effects` / `_expire` / `_lerp_hp` 都遍历 `keys()` / `get_actor_ids()` 快照，`apply_actions` 遍历步进器交出的结果数组。偏离见 deviations 文件 PL2-1–12 |
| PL3 Director 骨架 + live 入口 | 已完成 2026-09-24 | `5a60ae2` | `d61b3af7`（本行由随后的 docs 提交回填） | 验收：`-Required` 21 scene + `hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env` 78 scene 全 PASS（core 单测 319→332：VisualDirector 5 / ReplayDirector 5 / ActionStepper +2 / VisualState +1）/ golden 三 seed 指纹零漂移（466926191 / 4212318930 / 2532673107，dump 逐字节同 PL2）/ leak 直方图仍为空与基线一致 / 完成定义：hex `frontend/core/` 已删、`presentation/` 零禁词（lint 常驻）、全仓零 `FrontendBattleDirector` 引用/ inkmon 守卫空。两问自查：新增的表 = `ReplayDirector._frame_data_map` + `_record`（`load_playback` 重建、`_exit_tree` 清空置空；`reset` 有意保留录像）与 `VisualState.seed_actor` 入账项（`initialize_from_replay` / `despawn_actor` 清，despawn 连在飞插值与脏标记一起抹）；Director 四件 `_init` 建、`_exit_tree` 拆（沿旧 Director）。新增循环：`cancel_for_actor` 先收 id 再删（两趟）、`has_actor_action` 只读、`_advance` 的 while 只攒时间、`pump` 遍历调用方交来的本趟事件数组（ReplayDirector 每趟新建），回调改不到。偏离见 deviations 文件 PL3-1–10 |
| PL4 文档与规则之家 | 未开始 | | | |
| PL5 整体审与收口 | 未开始 | | | |

**后续观察**（范围外发现记一行，不顺手修）：

- 候选：effects map 统一（§4 第三条）——四份一次性效果簿记除 dedupe / 过期外无人读取，合成一张表后 view 可按 id 懒建、与 actor 同款 flush。
- 候选：`AnimationConfig.from_dict` 无人调用（hex `create_default` 唯一入口），上提后若仍无消费方可删。
- PL0 记：`FrontendStageCueVisualizer.EXECUTE_KILL_VFX_DURATION = 0.8` / `EXECUTE_KILL_VFX_DELAY = 0.15` 疑似按秒写——表演层时间单位是 ms，斩杀特效 0.8 ms 内建了又删（golden 651143 第 18 帧 `attack_vfx delay=0.15 dur=0.80`，同步 +1/-1）。改值会动 golden，等用户拍板后重烤。
- PL0 记：三个 golden seed 的 6 张投射物卡 duration 全被 300 ms 下限夹住（demo 地图 hex size 1，世界距离 / 20 单位每秒 ≤ 300 ms）——golden 钉不住 `FrontendProjectileAction.calculate_duration` 的距离公式；PL1 改投射物距离口径（D2）时另用单测钉今日「世界距离 / 速度」的数值，或加一个大地图 seed。
- PL0 记：`FrontendVisualAction.ActionType.MELEE_STRIKE` 无翻译员产出、RenderWorld 无分支，golden 的 KIND_NAMES 里那一条是死项；PL2 D4 内置 11 种 kind 本就不含它，改名时顺手不带。
- PL1 记：hex 逻辑层把投射物位置打包成 `Vector3(q, r, 0)`（`HexBattleSkillHelpers.owner_position_resolver`），`ProjectileSystem` 的飞行时间 / `hit_distance` 都按 axial 平面欧氏度量（各向异性：六个邻格里 (1,-1) 比 (1,0) 远 41%）；表演层 PL1 起与它同口径。逻辑层若改成 hex 步数度量，翻译员 `calculate_duration` 那一处同步即可。
- PL1 记：`FrontendAnimationConfig.projectile_default_speed` 与 `FrontendProjectileAction.get_trail_length` 无人调用（速度从事件读、拖尾长度 view 自己定），PL2 改名时顺手不带。
- PL1 记：`FrontendFacingIndicatorView` 仍自己拿 `GridLayout` 算朝向向量（邻格像素差），可改用 `FrontendHexProjection.delta_to_world` 统一投影入口，视觉无差；view 层的事，不急。
- PL2 记：`BuffVisualizer` 一词仍留在逻辑层注释里：`core/events/game_event.gd`、`core/playback/recording_utils.gd`、hex `logic/abilities/active/surge.gd` / `buffs/surge_buff.gd` / `actions/surge_tick_action.gd`、`tests/battle/skill_scenarios/{poison,surge}_scenario.gd`——不在 PL2 清单（其中两个是定向投递刀同日在改的文件），PL4 文档阶段顺手扫成 `BuffTranslator`。
- PL2 记：`VisualState.set_actor_hp / set_actor_position / set_actor_dead` 三个直接状态更新只有单测在用（production 无消费方）；PL3 照 inkmon 抄 `seed_actor / despawn_actor` 时一并定去留。
- PL2 记：`FrontendBattleDirector` 的组件在 `_ready` 才建（`updater` 也是），animator 只能在 `add_child` 之后 `register_handler`；PL3 抽 `VisualDirector` 时把 registry / stepper / state / updater 挪到 `_init` 建，让「建好 Director 再登记私有卡片」不依赖入树顺序。
- PL3 记：`ReplayDirector.step()` 在 `playback_ended` 之后每调一次都重发 `playback_ended` / `playback_state_changed(false)`（`_process` 路径被 `_is_playing` 挡住，手动步进没挡；沿旧 `_tick`）；golden 停在首个 ended 不受影响。改成只发一次动播放语义，PL5 整体审时定。
- PL3 记：`VisualUpdater.apply_move` 先写在飞插值再查 actor 是否在账上，despawn 后 / 未知 actor 的 move 卡会给 `_interpolated_positions` 留一条幽灵项直到下次 `initialize_from_replay`；live 项目 despawn 前 `cancel_for_actor` 即可避开，框架侧候选加 `has_actor` 守卫。
- PL3 记：三个白盒 smoke（buff_pipeline / facing_indicator / regeneration）手抄的 `_run_frame` 现在可直接喂 `VisualDirector.pump`（PL2-9 时框架尚无 Director），候选顺手改，本轮不动。
- PL3 记：Director 四件在 `_init` 建、`_exit_tree` 拆（沿旧 Director）——移出树再加回即不可用；现无消费方这么用，若要支持改成 `NOTIFICATION_PREDELETE` 拆或干脆不拆（Node 目标的信号连接随 free 自动断，无 RefCounted 环）。
- PL3 记：`[Frontend:FrameDiag]`（unit_view / animator）与 `[Presentation:ReplayDirector]` 诊断打印无人消费（全仓零 grep），候选清理。

## 7. 消费方接入清单（给 kards / 2e 的 inkmon）

1. bump submodule 到 PL5 收口 SHA。
2. **事件源**：回放 → 继承 `ReplayDirector`，`load_playback(record)` 喂 `PlaybackData.BattleRecord`；live → 继承 `VisualDirector`，自己攒本帧事件 dict 后调 `pump(delta_ms, events)`。
3. **翻译员**：每种事件 kind 一个 `<Proj>XxxTranslator extends Translator`，`can_handle` 认自己的 kind，`translate` 只读 `VisualStateQuery`、只出内置卡片（位置一律逻辑 `Vector2`）；用工厂函数装一个 `TranslatorRegistry` 交给 Director。
4. **视图**：一个 view binder（Node）监听 Director 的 7 条信号；`actor_state_changed` 首次出现即懒建单位节点，之后照 `ActorVisualState` 更新；`effect_spawned` 按 kind 建效果节点；每帧用自己的投影函数把 `get_actor_position()` 的逻辑坐标换成像素 / 3D。
5. **私有卡片**（可选）：`<Proj>XxxAction extends VisualAction` 定义新 kind + `static apply(state, action, progress, id)`，Director 建好后 `updater.register_handler(kind, callable)`。
6. **钉子**：照 hex `smoke_presentation_golden` 给自己录一份 golden。
