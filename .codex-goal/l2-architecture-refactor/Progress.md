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
- **P8 内嵌决策 — 刻印实现框架 (game-architecture-patterns)**: chosen = **LGF 被动 ability**(复用既有 passive/event 系统)。Step-2 grep 实证:inkmon battle 已有 `InkMonDamageMathPassive`(granted passive,hook damage event)+ equip_abilities 的 grant_ability 机制;刻印 = 每条 engraving grant 一个 engraving 被动 hook target_slot 技能事件做强化(与 DamageMathPassive 同款)。rejected = skill_slot modifier(inkmon 无此 modifier 层,要新造一套;passive 复用既有零新系统)。边界: v1 engraving 被动效果最简(flat 强化 target 技能),真内容来 lab。
- **P8 内嵌决策 — 装备系统 (Phase-G 误归属修正)**: 关键发现 = lomolib **无** Phase-G(EquipmentManager/StatAggregator/AbilityGrantor 全在 hex-atb-battle 示例,Non-Goal 不动/不引;lomolib 只有 inventoryKit 容器层)。doc §8c「接 lomolib Phase-G」**误归属**(Phase-G 不在可复用 lib,是示例本地)。chosen = **项目本地装备 stat 聚合**(建在 lomolib inventoryKit 上,装备 stat_mods 折叠进 project_to_battle_snapshot 的 battle_stats),交付意图(装备数值生效)且守 Non-Goal(不改 addons / 不引 hex)。`get_item_stat_mods` stub 实际不存在(现状是 catalog inline stat_mods 无人消费)→ 真 gap = 投影时没折叠装备,补上折叠即收口。granted_abilities: v1 物品无,留结构扩展点。
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
- Phase 8 decisions: TDD=yes(装备 stat 折叠 + 刻印投影 + 多槽存档 = 数据/逻辑, 可断言); smoke-test=yes(inkmon/session[往返+装备折叠+刻印] + app-root[多槽 save/load 菜单] + m1)。
  - 实现:① 装备折叠:session.project_player_battle_roster 投影后, 按 entry 读 equipment_container items 求和 stat_mods 折进 battle_stats(项目本地, lomolib inventoryKit)。② 刻印:entry.engravings 投影进 snapshot;InkMonUnitActor 吸收 + equip_abilities 每条 engraving grant 一个 engraving 被动(LGF passive, hook target_slot 技能);v1 一个最简 engraving 强化效果可测。③ 多槽存档:save_game/load_game 带 slot, list_save_slots;save 菜单 modal 加槽位按钮。
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
- 2026-05-31 - phase 7 - commit 363c620 - review: pass(finder1=0 findings 23 条 get_node 路径全核对/.tscn 有效/layout_state 契约保留/chip stylebox 独立/mouse_filter+可见性正确; finder2=1 low 外观 TopLeftHud 固定 rect, 接受不改) - smoke: pass(inkmon/app-root[+router]+overworld-3d[HUD/drawer/modal/transition/layout_state/race-bug 回归]+session 全 PASS)
- 2026-05-31 - phase 8 - commit 05b4b27 - review: pass(两 finder 各 0 findings; 装备折叠 ref 语义正确+测证/engraving hook 组合 damage-math 无重入 source 过滤正确 stacking 文档化/多槽 index+路径+lambda 捕获正确 无残留 ref/.tscn 有效; v1 限制 engraving 全 outgoing+target_slot 未 slot-specific 已文档化为 intended) - smoke: pass(inkmon/session[装备折叠+刻印+集成]+app-root[多槽]+overworld-3d+m1+content 全 PASS)
- 2026-05-31 - phase 9(入口切换) - commit 666ca1b - review: pass(0 findings; rename 零残留 InkMonAppRoot/入口链 valid/无节点名冲突/dev-ops cast 成立/Simulation.tscn 完好) - smoke: pass(全 gate inkmon 5 组 7 scenes + -Required 9 scenes 全 PASS)

## Validation Results (gate, transcript 可观察)

- `./tools/run_tests.ps1 inkmon/m1 inkmon/session inkmon/content inkmon/app-root inkmon/overworld-3d` → **PASS 7/7** (含 smoke_progression + smoke_main_router)。
- `./tools/run_tests.ps1 -Required` → **PASS 9/9**(LGF 73 单测 + hex frontend/battle/skill-scenarios + dota2 lane + skill_validator;无 hex/core 回归)。
- save/load 往返深相等:`smoke_session_spine._assert_session_round_trip` 断言 `JSON.stringify(session.to_dict()) == JSON.stringify(from_dict(...).to_dict())` 通过(PASS)。
- grep 证明:`ink_mon_roster_entry.gd` 对 `persistent_stats|learned_skill_id|medals` **零匹配**。
- 玩家级 v1 loop DevAgent real-input 跑通(InkMonMain 入口):real 右键移动→(1,0) 近 shop / real prompt 点击开 shop 抽屉 + real 点 close 关 / trainer NPC→战斗(P5 intent)→奖励 gold 100→125 / save→reset(gold→100)→load(gold→125 还原) / 截图。
  - session 目录:`C:/Users/37065/AppData/Roaming/Godot/app_userdata/Inkmon/dev-agent/sessions/inkmon-l2-v1-loop`
  - 截图:`.../sessions/inkmon-l2-v1-loop/screenshots/25-capture.jpg`(HUD ●125 R1 + roster chips + tool buttons + hex 主世界 + 6 NPC + [E]Talk,均经新入口/薄场景/.tscn UI 渲染)
- `git diff 04380e5...HEAD -- addons/` **空**(Non-Goal 不改 addons 守住);hex-atb-battle 改动 **空**。

## Open Review Findings

- [P1, medium, deferred] `derive_battle_stats()` 对不在 catalog/`_configs()` 的 species(含 from_dict 缺字段时的空串)走 `Log.assert_crash(false)` 硬崩。P2 后 surface = `InkMonSpeciesCatalog.get_base_stats` → `_species_node`(catalog 是 8 baby + 进化形态的严格超集)。判定延后不阻塞:① 旧 `_normalize_stats({})` 在缺 stats 时同样崩;② v1 所有 roster species 都由 from_unit_config/from_birth/evolve 产生必在 catalog;③ 跨版本改物种属 Non-Goal「不写存档迁移」明确不支持;④ fail-fast 是既定错误模型。
- [P2, low, deferred] 多段进化链 X→X2 二次套用:cinder_kit→cinder_fox→cinder_drake 时,fox 阶段 slot1 若 roll 到 fireball,会在 drake 进化时再被 SKILL_EVOLUTIONS 升级成 chain_lightning。非崩溃、chain_lightning 在合法池内、语义可辩(进一步进化技能再强化)、仅 cinder 这一条两段链触发。v1 stub 接受;真内容来 lab 时再定 X→X2 是否只作用于"原始携带槽"。
- [P2→P3, low, note] `InkMonUnitActor.equip_abilities` 若 `learned_skill_id == inkmon_basic_attack` 会重复授予 basic(get_skill_config(basic) 再 grant 一次)。已通过"basic 不进技能池"在 P2 数据侧规避;P3 改 from_battle_snapshot/actor 时可顺手加 primary==basic 的防御(skip 重复 grant)。已在 P3 收口(equip_abilities 加 != basic guard)。
- [P7, low, accepted] hud_content.tscn 的 TopLeftHud 现为固定 rect(offset 24,24,320,120 = 296×120),旧代码是 position=(24,24) + PanelContainer auto-hug。纯外观差异:无裁剪(Container 不低于 content min)、无功能破坏、无 smoke 断言 HUD 几何。固定尺寸容纳金币/rank/roster chips 合理,盲改 auto-size 有 0 尺寸风险,接受不改。
- [pre-existing, low, not-P7] overworld-3d smoke 跑出 "Lambda capture at index 0 was freed" ×4(reset_session 边界);finder 核实 P7 前 baseline 同样存在,非本重构引入,不影响退出码。属既有 leak 类噪声(CLAUDE.md 既知坑)。
- [P4, low, awareness] 持久 world GI: 战后→下场战斗间, 上场 battle actor + 其 pre-event handler 滞留 world(_reset_battle_state 在下场开始才清)。当前不可触发(主世界层不 push 任何 event, world GI 无 system, base_tick 空转),但属 latent fragility: 未来主世界若引入走 event_processor 的 event, 旧 battle handler 会变 ghost 触发。届时需在 _on_battle_finished 即清 handler(而非延到下场 reset)。无当前触发, 不阻塞。

## Consistency Review

2026-05-31 - 重读 Goal.md + docs/L2-ARCHITECTURE.md §1-§8, 逐项与实现比对 (file:line 证据):

**Deliverables (Goal.md §Deliverables):**
- P1 数据模型 ✅ — `ink_mon_roster_entry.gd:8-18` 字段 {entry_id,species,stage,role,elements,level,exp,skill_slots,engravings,equipment_container}; `derive_battle_stats()` f(species,level) 派生(:75-83); 删 persistent_stats/learned_skill_id/medals(grep 0 匹配); medals → `ink_mon_player_state.gd:17`; to_dict/from_dict 同步(:53-77)。
- P2 出生+进化 ✅ — `ink_mon_species_catalog.gd`: 技能池 per-(species,slot)(_build_table); 确定性 roll(roll_skill_for_slot/roll_birth_skill_slots,RNG seeded); 进化链 evolve_entry(species 改写+保留旧 slot+X→X2+新 slot roll); X→X2 = SKILL_EVOLUTIONS。
- P3 战斗注入 ✅ — `ink_mon_roster_entry.gd` project_to_battle_snapshot 投影 skill_slots + 派生 stats; `ink_mon_unit_actor.gd` _setup_from_battle_snapshot 吸收(primary=slot0); M1 unit-key fallback 保留(_setup_from_unit_config,M1 smoke 验)。
- P4 战斗合并 ✅ — `ink_mon_world_gi.gd` 唯一持久 InkMonWorldGI(World-owns-Battle); 战斗 = InkMonBattleProcedure(start_battle_procedure); 双 grid(overworld_grid_model + battle UGridMap)切 active; 绝不 end()。运行时 inkmon_world_0 boot 实证。
- P5 God object 拆解 ✅ — 6 NPC handler 收 session 自含规则(`logic/npc/*.gd` run_action(session)); 切断 run_action(app_root); training intent=Command-as-data(`ink_mon_training_npc_handler.gd` INTENT_START_BATTLE → director run_npc_action_for 解释); 两层薄场景(外层 `ink_mon_main.gd` + 内层 director)。
- P6 主世界 ✅ — `ink_mon_overworld_grid.gd` find_path = GridPathfinding.astar(插件); 玩家位置单写(`ink_mon_game_director.gd` _get_player_coord 读 grid, save 侧 _sync_player_coord_to_session 一次); UI race bug baseline 已修 + overworld-3d 回归。
- P7 UI .tscn ✅(F3 已收口) — HUD/drawer/modal = `ui/{hud_content,right_drawer,save_load_modal}.tscn`; 动态列表 + journal/panel-message = `ui/components/{roster_chip,party_entry_row,bag_item_row,npc_action_row,journal_panel,panel_message}.tscn` instantiate; director 取引用+绑 data+连 signal+驱动 transition。仅剩 4 CanvasLayer(运行时分层基建) + prompt button(随 NPC 世界坐标跑位)用代码——合理 infra 非设计态 UI 自绘(见 Resolved F3)。
- P8 装备+刻印+存档 🔧(Phase-G 误归属 + F2 已修; F1 占位,见下 Known Divergences) — 装备 stat 折叠 `ink_mon_game_session.gd` _fold_equipment_stats ✅; 刻印 LGF 被动 `ink_mon_engraving_passive.gd`(projection→actor→grant)🔧 v1 占位未 slot-specific = **F1**; 多槽 save_to_slot/load_from_slot/list_save_slots + `save_load_modal.tscn` 槽行 ✅; 旧档丢弃重开 ✅(**F2 已修**:from_dict 缺/旧 version → begin_new_game)。
- 入口切换 ✅ — `project.godot:14` run/main_scene → InkMonMain.tscn; Simulation.tscn 留为 web 桥(未改); 删 app_root 概念(InkMonAppRoot→InkMonGameDirector,grep 零残留)。

**Non-Goals (均未违反):** 不改 addons(`git diff 04380e5...HEAD -- addons/` 空)✅; 不动 hex-atb-battle(空)✅; lab 数据=手搓 stub ✅; 无技能数值变异(roll 只选 skill_id)✅; 无 PvP/网络/IV ✅; 不调平衡(level-1 derive==config base,smoke 断言)✅; from_dict 无迁移代码 ✅ + 「遇旧版直接丢弃重开」✅(F2 已修:缺/旧 version → begin_new_game + smoke 断言)。

**Completion Gate:** 5 inkmon 组退 0(7/7)✅; -Required 退 0(9/9)✅; save/load 深相等断言通过 ✅; grep 证 RosterEntry 无三字段 ✅; v1 loop DevAgent real-input 跑通(session 目录+截图 见 Validation Results)✅; git 工作树 clean ✅; 9 commit 各有 checkpoint ✅。

**Resolved item (1):** P8 装备「接 lomolib Phase-G(EquipmentManager/StatAggregator/AbilityGrantor)」与「弃 get_item_stat_mods stub」—— Step-2 grep 实证 lomolib **无** Phase-G(三类全在 hex-atb-battle 示例=Non-Goal 不动/不引;lomolib 仅 inventoryKit)且 get_item_stat_mods stub 不存在(现状是 catalog inline stat_mods 无人消费)。doc §8c「接 lomolib Phase-G」为**误归属**。RESOLVED:守 Non-Goal 改**项目本地装备 stat 折叠**(建在 lomolib inventoryKit 上),交付同一意图(装备数值生效)。详见 Phase Decisions 段 P8 内嵌决策。

**Resolved (since first consistency review):**

- **F2 — 旧存档「丢弃重开」** (RESOLVED 2026-06-01) — 原缺口:`from_dict` 缺 version 默认当前版**静默放行**,旧档缺 skill_slots → `ink_mon_roster_entry.gd:64` 空数组 → 注入侧 `ink_mon_unit_actor.gd:75` `assert_crash`(既不丢弃也不重开,而是崩)。修:`ink_mon_game_session.gd:19-34` `from_dict` 改返回 bool,version 缺失(默认 -1)或 != SAVE_VERSION → `Log.warning` + `begin_new_game()` + return false(提前 return,不触旧形状解析);`ink_mon_game_director.gd:548/561` load_game 接 bool,丢弃时返回区分 message(已起新游戏)。测:`smoke_session_spine._assert_old_save_discarded`(无 version + 未来 version 两档均断言「丢弃 → 重开 4-roster → 不留旧 gold」)→ inkmon/session PASS。
- **F3 — P7 残留运行时自绘** (RESOLVED 2026-06-01) — 原:director 用代码搭 per-chip `StyleBoxFlat` + journal 面板(`Label`+`Button`)+ 空态 `Label`("Bag is empty."/"System linked"),未尽 arch §96「零自绘」。修:① roster 描边烤进 `roster_chip.tscn`(local-to-scene StyleBox,代码只填 border_color);② 新建 `journal_panel.tscn`(summary label + Save/Load 按钮)+ `panel_message.tscn`(空态/占位文字),director 改 instantiate。仅剩 4 CanvasLayer(运行时分层) + prompt button(随 NPC 跑位)用代码——合理 infra 非设计态 UI。测:inkmon/app-root + overworld-3d(roster/journal/bag/save-load 全开)PASS。

**Known Divergences (1, accepted for v1 — 无 pending fix):**

- **F1 — 刻印 target_slot scoping 延后 (accepted / v1 占位)** — 要求:Goal.md:16「v1 只强化指定 skill_slot 的技能」+ docs/L2-ARCHITECTURE.md:160「强化某一个具体技能,target_slot 对应 skill_slots[].slot_index」。现状:`ink_mon_engraving_passive.gd:32-42` passive 仅过滤 `source_actor_id==owner`,对所有 outgoing damage ×1.25 不区分技能;`ink_mon_unit_actor.gd:120-122` 每条 engraving grant 同款 passive,target_slot 未传入;`ink_mon_battle_pre_events.gd:7-13` PreDamageEvent 不带 skill/ability id(scoping 所需身份未投影)。处置:**用户拍板接受延后** —— v1 刻印 = 占位(无差别伤害增强),per-skill 精确 scoping 留待实现;代码注释已标(`ink_mon_engraving_passive.gd:7`)。复核结论:**非 ✅ 兑现 Goal 字面**,属已知接受延后。
Consistency review: 3 resolved (P8 Phase-G 误归属 → 项目本地等价实现; F2 旧存档丢弃重开已修+测; F3 P7 残留自绘搬 .tscn + 测); 1 accepted divergence (F1 刻印 target_slot v1 占位)。**无 pending divergence** —— F1 经用户拍板接受为 v1 scope(详见 docs/future/v1-placeholders.md)。Gate:inkmon 5 组 7/7 + -Required 9/9 全退 0(F2/F3 fix 后复跑 PASS)。

## Blockers

- None
