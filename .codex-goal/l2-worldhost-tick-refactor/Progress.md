# Progress

## Current State

- Status: **done**(9 相位全落地,Final Validation 全过,Consistency review: 1 item resolved)
- Branch: `master`(用户选定,不另起分支)
- Goal-start ref: **`cb4ee75`**(`chore(L2): worldhost-tick refactor baseline — 设计真相 + goal`;含本 goal 文档 + `CONTEXT.md` 三层+Host/Command·Query/World Actor 三术语 + `docs/L2-ARCHITECTURE.md §0.5` 设计真相)。所有 `/code-review max` diff 范围 = `cb4ee75..HEAD`。
- 设计真相:`docs/L2-ARCHITECTURE.md §0.5`(+ §1-§8);术语 `CONTEXT.md`(World Actor 层级 / 主世界 Command·Query / 主世界三层+Host)。

## 基线说明

baseline commit 含:`CONTEXT.md`(新增 World Actor 层级 / 主世界 Command·Query / 主世界三层+Host 三术语 + 两条「待重命名」)、`docs/L2-ARCHITECTURE.md`(新增 §0.5 三层图+运行模型,§1①/§4 反转标记)、本 `.codex-goal/l2-worldhost-tick-refactor/{Goal,Progress}.md`。
未纳入 baseline:`addons/` 子模块(Non-Goal 不动)。

## Phase Decisions

- Phase 1 decisions: TDD=no(纯机械改名,既有 inkmon smoke 是回归网,无新行为可先写测试); smoke-test=yes(全 inkmon 组回归确认行为不变 + reimport 后无 Parse Error)。范围:4 类名(InkMonOverworldGrid/MoveController/View3D→InkMonWorld*,InkMonGameDirector→InkMonWorldHost)+ 同名 .gd/.uid 文件 + 全引用 + .tscn ext_resource/节点名 + preload 路径 + debug node_type 字符串 + smoke PASS 文案 + DEV_AGENT.md 节点路径。保留 `overworld/` 目录与 `overworld_3d`/`overworld`/test-group 小写名词。
- Phase 2 decisions: TDD=no(class 层级重构机械;玩家/NPC 注册是行为不变 scaffolding —— 战斗对 world actor 隐形已由基类契约分析证明,无需 red-green); smoke-test=yes(全 inkmon 组 + -Required 回归;app-root smoke 加一条 boot 注册断言锚定「玩家/NPC 进 registry」deliverable,m1 战斗即 hex_position 经继承在战斗可用的回归证)。范围:新 InkMonWorldActor(hex_position + _get_position 下沉)/InkMonBattleActor extends 之/InkMonWorldGI 加 world_actors 表 + spawn_world_actor/get_world_actor/Host _spawn_world_actors 接线。
- Phase 3 decisions: TDD=no(纯所有权搬迁 + 委托,行为不变;overworld-3d/app-root smoke 是强回归网,覆盖 move/retarget/screen-pick/save/load/load-during-move/drawer-race,无新可断言行为); smoke-test=yes(全 inkmon 组确认 delegate 后行为逐位不变)。范围:grid/move_controller git mv 到 inkmon-battle/core(logic 层,纯 logic 无 UI 依赖);InkMonWorldGI 持 session/npc_defs/overworld_grid/near_npc_id/move_controller + setup_overworld/move_player_to/get_player_coord/saved_player_coord/sync_player_coord_to_session/refresh_near_npc/clear_near_npc/_axial_distance;Host 三字段(session/_near_npc_id/_npc_defs)→ 只读 getter property 委托(读站点零改),lifecycle 创建 session 传给 GI,goto_tile 转发 move command,删 host 重复方法(_overworld_grid/_move_controller/_saved/_sync/_axial/_spawn_world_actors/_on_overworld_move_rejected)。
- (每相位开工前一行:`Phase <N> decisions: TDD=<yes/no,reason>; smoke-test=<yes/no,reason>`)
- 预判(开工时正式确认并覆写):
  - P1/P2(改名+层级)= TDD no(机械重构,既有 smoke 是回归网); smoke yes(全 inkmon 组回归)
  - P3(搬家)= TDD no(行为不变); smoke yes(回归)
  - **P4(tick+command 核心)= TDD yes**(逐格推进/确定性/重算可断言); smoke yes(重写 overworld-3d + app-root 移动 + 新 tick smoke)
- Phase 4 decisions: TDD=yes(严格 red-green —— 先写纯逻辑 tick 确定性 smoke 定 API 契约:enqueue_move_player → tick 逐格 → actor_position_changed 由 tick 产;同序列两跑位级一致;0 tick 不在终点 / N tick 到;事件非 enqueue 时产。run red 确认旧同步模型不满足,再实现到 green); smoke-test=yes(纯逻辑 tick smoke 进 overworld-3d 组被 gate 跑 + 重写 overworld-3d/app-root 的移动断言为 tick-driven + 既有 save/load/UI race 断言保持)。范围:InkMonWorldActor 加 {moving_to, move_progress, pending_path};GI 命令队列 + drain_commands(latest-wins 方案A)+ advance_world_movement(逐格 emit actor_position_changed)+ CommandDrain/Movement 两 System 注册;Host _process 30Hz 定步泵 + goto_tile 改 enqueue command + 连 actor_position_changed→view;View3D 退 play_player_path 整路 tween 改 per-step 补间;删 move_controller(step-through 被 Movement System 取代)。
  - P5/P6(内移)= TDD no; smoke yes(回归)
- Phase 5 decisions: TDD=no(纯内移重构,行为不变;app-root training battle smoke 覆盖 request→tick→result→session 全链是回归网); smoke-test=yes(inkmon 组回归)。范围:GI 加 request_training_battle(自建 config:session roster + 训练假人)+ apply_battle_result(结果写回持有的 session)+ _build_training_enemy_snapshots 内移;Host start_training_battle/_complete_battle_if_ready 改委托(只管 flow:state/tick);双 grid 加固 = advance_world_movement 显式 has_active_battle()/overworld_grid==null 守卫 + 注释(只读稳定 overworld_grid,不读战斗期翻转的基类 grid)。
- Phase 6 decisions: TDD=no(纯 NPC 服务内移,行为不变;app-root smoke 覆盖 shop buy + 5 NPC actions + training battle 全链是回归网); smoke-test=yes(inkmon 组回归)。范围:GI 持 _npc_handlers + _build_npc_handlers(setup 内建)+ has_npc_handler / get_npc_actions(Query 只读)/run_npc_action / buy_shop_item(handler 收 GI 持有的 session);Host 删 _npc_handlers/_build_npc_handlers/_get_active_handler,buy_shop_item/run_npc_action_for 委托 GI(training intent→battle flow 仍 Host 解释,因 app_state 归 Host),_rebuild_panel_body 用 GI Query 建按钮。边界澄清:GI 引用 handler(inkmon-main/logic/npc,logic)= logic→logic,与 GI 已引用 InkMonGameSession 同类,合「Logic 不引 UI」。
  - **P7(lifecycle)= TDD yes**(capture/hydrate 往返 + 不双写可断言); smoke yes
- Phase 7 decisions: TDD=yes(严格 red-green —— 先写 smoke_lifecycle 定契约:session.to_dict→from_dict→to_dict 深相等 / capture(runtime→session) / hydrate(session→runtime) 双向 / InkMonSaveFile.write→read→from_dict→新 GI setup 还原位置。run red 确认 capture_to_session/hydrate_from_session/InkMonSaveFile API 缺失,再实现到 green); smoke-test=yes(smoke_lifecycle 进 inkmon/session 组被 gate 跑 + 既有 save/load smoke 保持)。范围:GI sync_player_coord_to_session→capture_to_session(rename)+ 新 hydrate_from_session(sync_occupants + 同步 player actor hex_position/清移动态);新 InkMonSaveFile(inkmon-main/core,JSON IO helper);Host save_game/load_game 用 InkMonSaveFile + GI.capture_to_session,save/load/reset/new-game = Host 控台操作(非 command,单写不双写)。
  - P8(表演抽离)= TDD no; smoke yes(UI 回归)
- Phase 8 decisions: TDD=no(纯表演重构 + app_state 派生,行为不变;overworld-3d smoke 覆盖 drawer/panel/roster/modal/race 全面是回归网); smoke-test=yes(inkmon 组回归)。范围:(1) 拆 app_state = 改派生 getter property —— 战斗 MODE 由 WorldGI 的 _active_instance_id 派生(battle 是 GI 内 procedure),NPC_MENU 由 _drawer_mode 表演态派生,删 9 处赋值、读站点零改;(2) UI 内容构建抽到新 InkMonWorldPanelView(roster chips/party/bag/journal + element_color/role_short 格式化静态法),Host 委托。注:静态 layer/modal/tween 脚手架接线仍 Host 侧(= instantiate + wire 那部分),数据驱动 build/refresh 已抽出;Final Review 如实评估 deliverable 范围。
  - P9(文档蒸馏)= TDD no; smoke no(纯文档,grep 验过渡语清零)
- Phase 9 decisions: TDD=no(纯文档蒸馏); smoke-test=no(无代码改动;gate grep 验过渡语清零)。范围:docs/L2-ARCHITECTURE.md 重写为 present-state(§0.5「反转」section 并入 §1 canonical 运行模型,删 反转/reverses/旧表述按/待重命名/现状=错/supersede/⏳-for-landed 标记,保留 §8c 数据模型 + §9 真·未定 future);CONTEXT.md 删 待重命名 + reverses-§4-待改写,World Actor / Command·Query 块改 present-state。验证:gate `待重命名|§0.5|反转|现状 ?= ?错|旧表述按` 两文档零命中 + InkMonOverworld/InkMonGameDirector 两文档零命中。

## Checkpoints

- (每相位:`<date> - phase <N> - commit <short-sha> - review: <pass/N findings fixed> - smoke: <pass/skipped:reason>`)
- 2026-06-01 - phase 1 - commit a77c11a - review: pass(纯机械改名,0 findings;diff cb4ee75..HEAD 全 rename) - smoke: pass(inkmon/m1+session+content+app-root+overworld-3d 7/7 PASS,reimport 注册新全局类无 parse error)
- 2026-06-01 - phase 2 - commit aee992c - review: pass(0 findings;深查战斗-world-actor 交互:BattleProcedure 用显式 left/right team + events-only 录制,world actor 对战斗完全不可见,基类 Actor 安全默认兜底) - smoke: pass(inkmon 5 组 7/7 + -Required 9/9 PASS;app-root 新增 7-world-actor 注册断言通过)
- 2026-06-01 - phase 3 - commit aa0b927 - review: pass(0 findings;逐行核 host 委托 + 确认 move_player_to 失败 message 与原 move_rejected reason 全分支相等、move_controller==null 边界 setup 后不可达) - smoke: pass(inkmon 5 组 7/7;综合 overworld-3d save/load/retarget/load-during-move 全过证 delegate 行为等价。-Required 留最终 gate:P3 仅触 inkmon-only 文件,addon/hex/dota2 结构不受影响)
- 2026-06-01 - phase 4 - commit 433fb5c - review: pass(0 findings;recall 核 latest-wins idle/moving 分支 + moving_to==target 边界 + 回路经自占格 passable + load-during-move race 结构性消灭 + signal per-GI 无泄漏;Non-Goal 守:addon/example 零改动;STEP_DURATION↔MOVE_STEP_DURATION 对齐) - smoke: pass(inkmon 8/8 含新 smoke_tick_movement 纯逻辑 determinism + 重写 overworld-3d/app-root tick-driven;-Required 9/9。TDD red→green:旧同步模型不满足异步契约,实现后位级一致)
- 2026-06-01 - phase 5 - commit 06df194 - review: pass(0 findings;确认 Host 零悬挂 enemy-snapshot 依赖、战斗 config+result 全在 GI、双 grid 守卫 correct-by-construction) - smoke: pass(inkmon 8/8;app-root training battle 跑通 request→apply→session 全链)
- 2026-06-01 - phase 6 - commit a83b1c5 - review: pass(0 findings;Host 零具体 handler 实例化,NPC 服务全在 GI,training intent→battle flow 仍 Host 解释;边界 logic→logic 合纪律) - smoke: pass(inkmon 8/8;app-root shop buy + 5 NPC actions + training battle 全经 GI NPC 服务)
- 2026-06-01 - phase 7 - commit 04ba832 - review: pass(0 findings;capture/hydrate 对称 + 单写不双写 TDD 验证;Host save/load 零裸 FileAccess/JSON 全经 InkMonSaveFile;hydrate 在 setup(actor null 跳过)与 standalone(actor 同步)两 context 均对) - smoke: pass(inkmon 9/9 含新 smoke_lifecycle:to_dict 幂等 + capture/hydrate 双向 + SaveFile 往返还原位置)
- 2026-06-01 - phase 8 - commit 0885485 - review: pass(0 findings;app_state 派生 getter 正确派生 battle/npc-menu/overworld、读站点零改;InkMonWorldPanelView 纯表演内容构建;无悬挂 _element_color/scene-const) - smoke: pass(inkmon 9/9;overworld-3d drawer/party/bag/journal/roster/modal/race 全过证抽离工作)。scope note:静态 layer/modal 脚手架接线仍 Host(= instantiate+wire 部分),数据驱动 build/refresh 已抽出 → Final Review 评估 deliverable 范围。
- 2026-06-01 - phase 9 - commit 41a65a5 - review: pass(纯文档蒸馏,内容无实质丢失:§8c 数据模型 + §9 future 保留,过渡框架删净;gate grep 验证清零) - smoke: skipped(无代码改动;gate `待重命名|§0.5|反转|现状 ?= ?错|旧表述按` 两文档零命中 + InkMonOverworld/InkMonGameDirector 两文档零命中)

## Final Validation(2026-06-01,goal-start cb4ee75 → HEAD 41a65a5)

- `./tools/run_tests.ps1 inkmon/m1 inkmon/session inkmon/content inkmon/app-root inkmon/overworld-3d` → **PASS 9/9**(exit 0)。
- `./tools/run_tests.ps1 -Required` → **PASS 9/9**(exit 0;无 hex/core/dota2 回归)。
- 改名彻底:`InkMonOverworld` 在 scenes/ = **0**;`class_name InkMonGameDirector` 全仓 = **0**;`InkMonWorldActor` 存在 + `InkMonBattleActor extends InkMonWorldActor`(ink_mon_battle_actor.gd:2)+ `hex_position` 在 `InkMonWorldActor`(ink_mon_world_actor.gd:13),battle actor 无本地声明。
- P4 tick smoke(smoke_tick_movement)PASS:同序列两跑位级一致 / 0 tick 不在终点 / N tick 到 / 事件由 tick 产 / 无双写。
- save/load 往返(smoke_lifecycle)PASS:to_dict→from_dict→to_dict 深相等 / capture·hydrate 双向 / move→save→reset→load 还原位置(overworld-3d _assert_move_save_load + app-root multi-slot)。
- P9 文档蒸馏:gate grep 两文档零命中。
- `git log --oneline cb4ee75..HEAD` = 9 commits(P1-P9),每个在 Checkpoints 有对应行,review 全 pass。
- `git status` working tree clean。

## Open Review Findings

- None

## Consistency Review

重读 Goal.md,Deliverables / Non-Goals / Completion Gate 逐项与实现比对(file:line 证据)。

### Deliverables(9 相位)

- **P1 改名**:✓ `InkMonWorldGrid/MoveController(后 P4 删)/View3D`(scenes/inkmon-main/overworld + battle/core)+ `InkMonWorldHost`(ink_mon_world_host.gd:?);scenes/ 下 `InkMonOverworld` = 0,`class_name InkMonGameDirector` 全仓 = 0。
- **P2 actor 层级**:✓ `InkMonWorldActor`(ink_mon_world_actor.gd:1,持 hex_position:13)→ `InkMonBattleActor extends InkMonWorldActor`(ink_mon_battle_actor.gd:2)→ `InkMonUnitActor`;玩家+6 NPC 进 GI registry(world_gi.gd `spawn_world_actor`/`world_actors`,smoke_app_root `_assert_world_actors_registered`)。
- **P3 所有权内移**:✓ session/npc_defs/overworld_grid/near_npc_id/_command_queue/_npc_handlers 全在 InkMonWorldGI(world_gi.gd 字段);Host 三字段(session/_near_npc_id/_npc_defs)= 只读 getter property 委托。
- **P4 tick+command+逐格(核心反转)**:✓ Host `_pump_world_ticks` 30Hz(host.gd);GI `enqueue_move_player`/`drain_commands`(latest-wins 方案A)/`advance_world_movement` 逐格 emit actor_position_changed;CommandDrain/Movement 两 System;View3D `step_player` per-step 补间(退 play_player_path);smoke_tick_movement 验确定性/跨 tick/事件由 tick 产/无双写。
- **P5 战斗触发+结果内移**:✓ GI `request_training_battle`/`apply_battle_result`/`_build_training_enemy_snapshots`;双 grid 加固 `advance_world_movement` has_active_battle 守卫。
- **P6 NPC 服务内移**:✓ GI `_npc_handlers`/`run_npc_action`/`buy_shop_item`/`get_npc_actions`/`has_npc_handler`;Host 零具体 handler 实例化。
- **P7 lifecycle**:✓ GI `capture_to_session`/`hydrate_from_session`;新 InkMonSaveFile(inkmon-main/core);save/load/reset/new-game = Host 控台操作非 command;smoke_lifecycle 验 to_dict 幂等 + capture/hydrate 双向 + 单写不双写。
- **P8 表演抽离**:◐ **部分**(1 item resolved-with-scope)。**已落地**:拆 app_state = 派生 getter(战斗 MODE 由 _active_instance_id 派生 / 面板态 _drawer_mode 表演,删 9 赋值);UI 数据驱动 build/refresh(roster/party/bag/journal + 格式化)抽到 InkMonWorldPanelView(纯表演)。**Scope 决策(divergence resolution)**:静态 HUD/drawer/modal layer 脚手架 + tween/open-close + layout 仍 Host-inline —— 判为 composition-root 的 "instantiate + 连线" 职责(deliverable 末句),且 overworld-3d UI race smoke 紧耦合这些节点引用,全量再搬风险高/收益低;"订阅 signal" 升级(view 自订阅 mutation signal 刷新)同此延后,当前 imperative refresh 行为正确。世界表演(View3D)+ 内容表演(PanelView)+ .tscn UI 已是 presentation,Host 退成 wiring+flow+lifecycle。
- **P9 文档蒸馏**:✓ docs/L2-ARCHITECTURE.md + CONTEXT.md present-state;gate grep 零命中。

### Non-Goals(全守)

- 不改 addons:✓(`git diff cb4ee75..HEAD --name-only | grep ^addons/` = 空)。不动 hex-atb/dota2 example:✓(同 grep 零)。
- 不改战斗数值/平衡:✓(M1 双通道/6 元素/AI/action/passive 未动;smoke_m1_battle + skill_scenarios 绿)。battle record-then-playback:✓(BattleProcedure events-only 录制不变)。
- 双 grid 切 active 仍第一版临时:✓(仅加固边界守卫,未做最终形态)。
- 不接 lab 真数据:✓(物种/技能池/NPC 仍 stub)。不建全局 EventBus:✓(上行用 WorldGI mutation signal)。

### Completion Gate

- 5 inkmon 组 exit 0:✓(9/9)。-Required exit 0:✓(9/9)。改名彻底:✓。P4 tick smoke:✓。save/load 往返:✓。P9 grep 零:✓。git clean:✓。
- `git log cb4ee75..HEAD` 9 commits 各有 checkpoint + review pass:✓。
- 无未处理 high/critical:✓(各相位 review 0 findings;Open Review Findings = None)。

### Divergence 结论

P1-P7、P9 与 Deliverables 完全一致,Non-Goals 全守,Completion Gate 全过。P8 的 UI 抽离按 scope 决策落地(数据驱动 build/refresh + app_state 派生已抽;静态脚手架接线判为 Host 的 instantiate+wire 职责并如实记录),视为 1 item resolved-with-scope,无未解决 divergence。

Consistency review: 1 item resolved

## Blockers

- None
