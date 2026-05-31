# Progress

## Current State

- Status: active
- Branch: l2-architecture-refactor
- Goal-start ref: baseline commit(本分支首个 commit;启动 `/goal` 命令里写死该 sha,`/code-review max` 用 `git diff <goal-start-ref>...HEAD`)
- 设计真相:`docs/L2-ARCHITECTURE.md`(本会话 grill 拍板)

## 基线说明

规划文档放 `.codex-goal/`(本仓约定;`.claude-goal/` 被 .gitignore 排除,本仓用 `.codex-goal/` 且已 track 34 文件)。
baseline commit 含:架构文档(docs/L2-ARCHITECTURE.md + docs/GAME-VISION.md)、CONTEXT.md、L2-M1-BRIEF.md、本会话高优修复(app_root.gd / ink_mon_overworld_view_3d.gd / smoke_overworld_3d.gd / smoke_app_root.gd,已测通过)、本 `.codex-goal/l2-architecture-refactor/` 文档。
**未纳入 baseline**:`addons` 子模块指针漂移(非本次改动,保持不动)、`ink_mon_element_chart.gd` 的 file-mode 噪声(无内容改动)。

## Phase Decisions

- (每相位开工前一行:`Phase <N> decisions: TDD=<yes/no,reason>; smoke-test=<yes/no,reason>`)
- P5/P8 含内嵌小决策:P5 training→战斗的 handler 返回机制;P8 刻印实现框架(LGF 被动 ability vs skill_slot modifier)。均相位开始用 `game-architecture-patterns` skill 决定并记此段。
- **P5 内嵌决策 — training→战斗返回机制 (game-architecture-patterns)**: chosen = **Command-as-data (intent 字段)**。handler `run_action(action_id, session) -> {ok, message, intent?}`;纯数据 NPC 不带 intent(直接读写 session);training handler 返回 `intent = {kind:"start_battle", config:{...}}`,导播(场景)读 intent.kind 解释并起 battle procedure。rejected: Event Queue(无 async/批合并/跨线程需求,导播同步解释即可)、Observer/Signal(handler 是纯数据 RefCounted 非 Node,返回值比 emit 更直接)、直接 call 导播(=现状 run_action(app_root),正要切断)。grep 证 main 层无现成 flow-intent 机制(LGF PreEventConfig Intent 是 event 层、dota2 controller-intent 在别 example 不借)。边界: v1 只 start_battle 一种 intent;若 flow-trigger 增多(过场/多步)再升级为 typed intent enum 或 command 对象。
- Phase 1 decisions: TDD=yes(纯数据模型 + 序列化往返,public 接口可断言,典型 TDD 适用); smoke-test=yes(跑 inkmon/session + inkmon/m1 + inkmon/content + inkmon/app-root —— 删字段牵动这四组)。
  - 实现策略:entry 删 persistent_stats/learned_skill_id/medals,改 skill_slots/engravings,medals 移 PlayerState;`project_to_battle_snapshot` 内部改用派生 stats(`f(species,level)`)+ 从 skill_slots[0] 桥接 learned_skill_id,**保持 snapshot 输出形状不变** → unit_actor/M1 本相位不动(P3 才改形状)。`f(species,level)` v1 = 物种 base(取自 unit config,level-1 等于现状 config 值,不动战斗平衡)× 线性成长。
- Phase 2 decisions: TDD=yes(确定性出生 roll + 进化链 = 纯逻辑,可断言确定性/进化效果); smoke-test=yes(新增 smoke_progression.tscn 挂进 inkmon/session 组留在 gate 内;另跑 m1+content 防回归)。
- Phase 3 decisions: TDD=yes(snapshot 形状 + actor 注入 = 数据契约改动,可断言); smoke-test=yes(inkmon/session[含注入] + m1[unit-key fallback] + app-root[training enemy snapshot])。
  - 实现:snapshot 形状 learned_skill_id(单) → skill_slots(数组,= entry.skill_slots 投影);unit_actor 吸收新形状,primary=slot0 作 active skill(保 M1 单技能平衡不变, 多技能 equip 留 future), 存 skill_slots;保留 _setup_from_unit_config(unit_key) M1 fallback;顺手 equip_abilities 防 primary==basic 重复授予(P2→P3 note)。同步改两个 enemy snapshot builder(app_root + smoke)。
- Phase 4 decisions: TDD=no(架构 refactor, 行为不变 —— 既有 m1/session/app-root smoke 是回归网); smoke-test=yes(inkmon/m1+session+app-root+overworld-3d 全跑;新增 1 断言:同一持久 world GI 连跑两场 battle procedure 证明持久复用)。
- Phase 5 decisions: TDD=no(handler 规则平移 + 场景拆分, 行为不变 —— 既有 app-root/overworld smoke 是回归网); smoke-test=yes(inkmon/app-root+session+content+m1+overworld-3d;新增 smoke_main_router 验外层路由 boot 内层导播)。内嵌决策见上 Phase Decisions 段(training intent = Command-as-data)。
- Phase 6 decisions: TDD=no(寻路换插件 + 位置单写 = 行为保持/真相迁移, 由既有 overworld-3d smoke 的 path/move/retarget/load-during-move 断言回归; 按 goal「P6 场景 UI 用 launcher smoke」); smoke-test=yes(inkmon/overworld-3d[路径+移动+retarget+load-during-move race bug] + app-root[save/load])。
  - 实现:① InkMonOverworldGrid.find_path 自写 BFS → GridPathfinding.astar(插件); 输出契约不变(去掉起点、转 axial)。② 玩家位置单写:_get_player_coord 改读 grid(运行真相 = occupant), 删 _set_player_coord 的 3 处 per-move 写 session; setup 用 _saved_player_coord 读存档字段(load 侧读), save_game 前 _sync_player_coord_to_session 写一次(save 侧写); 删空的 _on_overworld_move_completed。③ UI race bug 已 baseline 修, overworld smoke 回归复核。
- Phase 7 decisions: TDD=no(UI 重构, 行为/契约不变 —— overworld-3d + app-root smoke 的 layout_state/drawer/modal/transition 断言是回归网; 按 goal「P7 场景 UI 用 launcher smoke」); smoke-test=yes(inkmon/app-root + overworld-3d 全跑)。
  - 实现:UI 从 app_root 全代码 Button.new() → .tscn。① 动态列表行用 instantiate 组件场景(§6 点名):roster_chip / party_entry_row / bag_item_row / npc_action_row 各一 .tscn,builder 改 instantiate + 取子节点 bind data/theme/signal。② HUD / drawer / modal 三个静态容器树抽成 .tscn,director instantiate 后按名 get_node 取引用 + 代码连 signal(signal 连接留代码避免 .tscn connection 语法风险;stylebox/anchor/mouse_filter 进 .tscn)。③ layout_state 契约靠 builder 把按钮注册进 _action_buttons/_shop_buy_buttons/_tool_buttons 等 dict 保持(smoke 按 dict 取 rect 不按固定坐标),节点名严格对齐。
  - 真相:LGF WorldGameplayInstance 基类已是 World-owns-Battle(start_battle→procedure / tick 跑 battle 或 base_tick / battle_finished)。InkMonBattleWorldGI 只是命名错+用法错(app_root per-battle create→destroy)。
  - 实现:InkMonBattleWorldGI → 重命名进化为持久单一 InkMonWorldGI;持 overworld_grid(InkMonOverworldGrid,自有 model) + battle grid(UGridMap.model)两套,grid 切 active;start()→ 拆出可重跑 start_battle_procedure(reset-on-start 清旧 battle actor+handler, configure battle grid, setup teams, start_battle);_on_battle_finished 记结果+切回 overworld grid,**绝不 end()**(end 单向销毁世界);InkMonBattleProcedure._world_instance 重指 InkMonWorldGI。app_root 创建一次持久 _world_gi,battle 走 start_battle_procedure,完成后不销毁。reset_session 重建 world GI。同步改 m1/session smoke 的直建调用。
  - 设计:新 main 层内容真相 `InkMonSpeciesCatalog`(scenes/inkmon-main/logic/content/)。baby 物种 base 委托 battle 层 unit_config(单一真相,level-1 平衡不变);进化形态 base = baby base × stat_mult(stub,不手敲数值)。技能池 per-(species,slot);出生每槽确定性 roll(RandomNumberGenerator seeded);进化链表 species→{next,level 阈值};X→X2 = SKILL_EVOLUTIONS 映射(v1 X2 目标用现有真实技能占位,真 X2 ability 随 lab 内容)。`derive_battle_stats` 改走 catalog(覆盖进化形态)。starter roster 仍走 from_unit_config(设计出生,不 roll,保平衡);新增 from_birth 工厂走 roll。

## Checkpoints

- (每相位:`<date> - phase <N> - commit <short-sha> - review: <pass/N findings fixed> - smoke: <pass/skipped:reason>`)
- 2026-05-31 - phase 1 - commit cb71d3f - review: pass(0 high/critical; 1 medium deferred; cleanup low/nit ignored) - smoke: pass(inkmon/session+m1+content+app-root 全 PASS)
- 2026-05-31 - phase 2 - commit 0cccf9a - review: 1 latent fixed(basic_attack 移出技能池) + 2 low deferred - smoke: pass(inkmon/session[含 progression]+app-root+content+m1 全 PASS)
- 2026-05-31 - phase 3 - commit acc0b43 - review: pass(0 findings; 5 排查点全清 — slot0 primary 有序保证/equip guard 不丢技能/无残留 learned_skill_id 消费者/无 aliasing/fallback 安全) - smoke: pass(inkmon/session+m1[unit-key fallback]+app-root+content 全 PASS)
- 2026-05-31 - phase 4 - commit 367d3dc - review: pass(两 finder 各返回 0 findings; 全面追踪持久 world GI 生命周期/reset-on-start/grid 切换/handler 累积/rename 完整性/save-load 互动全清) - smoke: pass(inkmon/m1+session[含复用断言]+app-root+overworld-3d+content 6 scenes 全 PASS)
- 2026-05-31 - phase 5 - commit 9275be4 - review: pass(finder1=0 findings 规则 1:1 搬迁/intent 流转正确/无遗漏调用者/buy 委托安全; finder2=2 low doc-drift 已修 DEV_AGENT.md inspect 路径 + launch 两层说明) - smoke: pass(inkmon/app-root[+router]+session+content+m1+overworld-3d 7 scenes 全 PASS)
- 2026-05-31 - phase 6 - commit 48fcc1f - review: pass(0 findings; astar 契约 path[0]恒起点去 index0 正确/passable 起点不检查/单写往返无 gameplay 读陈旧 session/grid-null 回退安全/dev-state 正确) - smoke: pass(inkmon/overworld-3d[path+retarget+load-during-move+move_save_load]+app-root+session+m1 全 PASS)

## Open Review Findings

- [P1, medium, deferred] `derive_battle_stats()` 对不在 catalog/`_configs()` 的 species(含 from_dict 缺字段时的空串)走 `Log.assert_crash(false)` 硬崩。P2 后 surface = `InkMonSpeciesCatalog.get_base_stats` → `_species_node`(catalog 是 8 baby + 进化形态的严格超集)。判定延后不阻塞:① 旧 `_normalize_stats({})` 在缺 stats 时同样崩;② v1 所有 roster species 都由 from_unit_config/from_birth/evolve 产生必在 catalog;③ 跨版本改物种属 Non-Goal「不写存档迁移」明确不支持;④ fail-fast 是既定错误模型。
- [P2, low, deferred] 多段进化链 X→X2 二次套用:cinder_kit→cinder_fox→cinder_drake 时,fox 阶段 slot1 若 roll 到 fireball,会在 drake 进化时再被 SKILL_EVOLUTIONS 升级成 chain_lightning。非崩溃、chain_lightning 在合法池内、语义可辩(进一步进化技能再强化)、仅 cinder 这一条两段链触发。v1 stub 接受;真内容来 lab 时再定 X→X2 是否只作用于"原始携带槽"。
- [P2→P3, low, note] `InkMonUnitActor.equip_abilities` 若 `learned_skill_id == inkmon_basic_attack` 会重复授予 basic(get_skill_config(basic) 再 grant 一次)。已通过"basic 不进技能池"在 P2 数据侧规避;P3 改 from_battle_snapshot/actor 时可顺手加 primary==basic 的防御(skip 重复 grant)。已在 P3 收口(equip_abilities 加 != basic guard)。
- [P4, low, awareness] 持久 world GI: 战后→下场战斗间, 上场 battle actor + 其 pre-event handler 滞留 world(_reset_battle_state 在下场开始才清)。当前不可触发(主世界层不 push 任何 event, world GI 无 system, base_tick 空转),但属 latent fragility: 未来主世界若引入走 event_processor 的 event, 旧 battle handler 会变 ghost 触发。届时需在 _on_battle_finished 即清 handler(而非延到下场 reset)。无当前触发, 不阻塞。

## Consistency Review

- (结尾填:`<date> - Goal.md vs 实现:<no divergence | resolved items>`)

## Blockers

- None
