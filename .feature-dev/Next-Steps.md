# Next Steps — 2026-05-05 (M7 UnitMotion 进行中;M7a+M7b+M7c done,M7d 起步)

## 当前目标

🚀 **M7 UnitMotion**(整合 long+short 双轨)— `/autonomous-feature-runner` 实施中。M7a Path Storage(2026-05-04)+ M7b Lifecycle / Failed Movements(2026-05-05)+ M7c Movement / Obstruction Sync (parallel wire)(2026-05-05) done,进入 M7d(Activity 集成 + RtsNavAgent 删除)。

> **M3 Epic 进度**: M0+M1+M2+M3+M4+M5+M6+M7a 已 done。剩余 M7b/c/d / M8 (Group Push) + EPIC 末 cleanup phase (M5.5b-e RtsBattleGrid 完整删除)。
> Epic 总览 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> M7 spec [`task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md)。

**M6 末态 baseline**(M7 出发点):
- VertexPathfinder 算法层完整(detail #1-#9 全实现)+ Liang-Barsky segment-vs-OBB 精确化 + axis-aligned fast-path + enclose-radius 早出
- RtsPathGoal CIRCLE/SQUARE/INVERTED_CIRCLE/INVERTED_SQUARE 几何 nearest_point_on_goal + distance_to_point
- RtsPathfinderFacade `compute_short_path_immediate(req, obstr_mgr)` API ready;`world.vertex_pathfinder` 一等公民字段
- **production callsite 暂不消费 vertex pathfinder**(activity / nav_agent / move_units_command 仍走 LongPath)→ baseline CSV byte-identical 968343 bytes(同 M5)
- 16 RTS pathfinding smoke 全 PASS(M5 13 + M6 4:vertex_static_obb / vertex_virtual_goal / vertex_corner_walking / vertex_group_filter)
- LGF 73/73 + replay seed=42 frames=11 events=24 deep-equal;9 条 stop runner 全 clear

**M6 deferred → M7 wire 触发**:
- ✋3 体验点 demo F6 visual 验证 — M6c.4 facade wire 仅 API,production callsite 不接;M7 UnitMotion 整合 long+short 双轨后 demo 看到自然绕角效果
- baseline CSV `short_path_size` / `short_path_wp_json` 字段从占位 -1 变实填(P1 漂,M7 production wire 后接受新 baseline)
- perf tick_p99 / tick_max ≤ +50% vs M5(M7 实测)

详见 [`archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md`](archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md)。

## 下一步

**M7d — Activity 集成 + RtsNavAgent / RtsUnitSteering 删除**(spec §M7d)。

M7d 把 production callsite 切 motion + 删旧 nav_agent / steering。RtsActivity 子类(MoveTo / Attack / Gather / Build / ReturnAndDrop / AttackMove / Idle)逐个切 motion.move_to_* API + motion abort 时 emit "motion_move_failed" event 给 activity,activity 接事件后 abort/retry。`_create_unit` spawner 设 actor.motion_component → procedure._world_tick step 4g 真激活 → motion-bearing actor 真 tick。

**M7d 子任务**(spec §M7d.1-3 + 拆分自 M7c.4):
1. RtsActivity 子类 API 迁移(`_nav_agent.set_target` → `motion.move_to_*`):attack / gather / build / move_to_order / idle / return_and_drop / attack_move
2. motion abort emit `motion_move_failed` event(走 LGF event 系统给 actor → activity 监听);activity 接事件后 re-acquire target / abort / reset state
3. _create_unit spawner 设 actor.motion_component(RtsCharacters / production_system._unit_spawner / 各 smoke 自己的 spawner)
4. 删除 `logic/components/rts_nav_agent.gd` + `logic/movement/rts_unit_steering.gd`(确认 grep 0 callsite 后)+ 把 M2.3 stuck_detector / push_out 部分逻辑迁到 motion._handle_obstructed_move(spec §M7c.4 mention)
5. 新 smoke `smoke_motion_activity_integration`(完整 demo 1 局 — 类似 smoke_rts_auto_battle 4v4 + buildings,验 attack/gather/build/spawn/die 全套行为正常)

**风险点 / Stop runner 触发**:
- 🔴 baseline CSV 漂 → 实填 short_path_size / short_path_wp_json / clearance / failed_movements / ticket_state(预期变化,P1 接受新 baseline 走流程)
- 🔴 replay seed=42 deep-equal 可能漂(motion 引入的 ticket / activity 切顺序变化)— stop runner 后定位是字段实填还是真漂
- 🟡 perf vs M5(spec AC10 允许 ≤ +50%;真 motion tick + obstr 同步比老 nav_agent 多步;若超 stop 调优)
- 🟡 ✋3(贴墙绕角)+ ✋4(100 unit 流畅)— 用户跑 demo 反馈

**Scope 拆分提醒**:M7d 工作量大(~49 文件涉及 RtsNavAgent),建议 mini-phase 推进(activity 一个一个切 + smoke 验证 + 小 commit)。

## 验收准则

M7 完整 AC 见 spec;Progress.md §2 由 runner 启动时镜像填入。

### 关键过线条件(M7)

- ✅ UnitMotion 双轨整合:LongPath 全图规划 + VertexPath 段间短路径绕避 + chain motion follow countdown
- ✅ 玩家 click move + AI attack-move 都走双轨;流畅过弯不卡
- ✅ ✋4 体验点 — 100 unit 大规模 attack-move 流畅(spec §M7d 末)
- ✅ Validation 全套 + LGF 73 + replay seed=42 deep-equal
- ✅ baseline CSV(M7 short path 字段实填 + 路径形状变化 P1 预期,接受新 baseline)
- ✅ Perf vs M5:`tick_p99 / tick_max` ≤ +50%
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ **M7 runner 启动前必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**(尤其 R5 P1 #1 actor sort 字典序漂 — M7 引入 motion update 顺序时风险高)。

## 非下一步

- ❌ 不启动 M8(每个 milestone 末等用户授权再起下一个)
- ❌ 不实现 Push pass(M8)
- ❌ 不在 M7 中做 RtsBattleGrid 删除(推到 EPIC 末 cleanup phase)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 push commit(commit 是本地节点,push 等用户)

## 等待动作

🛑 **2026-05-05 第 2 会话 STOP RUNNER**:M7d.1 done + M7d.2 cutover 实施完成但 4 critical smoke FAIL functional regression。**等待用户决策**。详见 `Progress.md` "M7d Stop Runner" 段。

### 用户三选一

1. **深入诊断 + 修 4 FAIL**(目标 -Required 12/12 PASS + 接受新 baseline)
2. **回退到 M7d.1 末态 + 重新设计 cutover**(dual-wire 渐进式)
3. **缩小 scope 单 long path motion**(永久禁 vertex 集成,✋3 贴墙绕角延后)

### M7d cutover 已完成内容(submodule commit `949b6eb`,主仓未 bump)

- Logic 层 5 activity + Controller + procedure + stuck_detector 全切 `motion_component` API
- Spawner / smoke / scenario / frontend 30 callsite 改 `RtsMotionComponent.attach_default(actor, world)`(替 `RtsNavAgent.new + bind_actor + attach_pathfinder` 4 行)
- `RtsMotionComponent.attach_default` static factory 加(motion + actor.motion_component 自动 wire)
- procedure step 4a/b/c 删(motion 接管),step 4f motion-bearing skip,step 4g 末加 motion_failed event dispatch
- vertex pathfinder simple-case 返空 path 已识别 + 加 fallback(short empty 时 push long next_wp)

### M7d cutover 4 smoke FAIL(主仓 -Required 8/12)

- smoke_rts_auto_battle: AC2 wall detour(`_check_detour_for_blocked_units` Agent stub 返空)
- smoke_castle_war_minimal: 600 ticks battle 不结束
- smoke_ai_vs_player_full_match: AI unit 没攻 ct(ai_unit_to_ct_attacks=0)
- smoke_ai_vs_ai_observe: combat 不接敌(combat→combat attacks=0)

**smoke_ai 1v1 PASS** = motion 简单场景 work;复杂场景集成 bug 未确诊。

### 下次 session 启动方式(等用户选 1/2/3 决策)

- **选 1**:`/autonomous-feature-runner 接 M7d 4 FAIL 诊断`
- **选 2**:`git reset --hard 1eca563 && cd addons/logic-game-framework && git reset --hard 0646c31` 然后 `/next-feature-planner 重新设计 M7d`(dual-wire 渐进式 cutover)
- **选 3**:`/autonomous-feature-runner 接 M7d 缩小 scope`(单 long path 不集成 vertex,✋3 延后)

### 主仓 / submodule sha checkpoint

- **主仓**:`1eca563`(M7d.1 末态;phase B 在 submodule worktree dirty + submodule commit 但**未 bump 主仓 pointer**,让回退方便)
- **submodule**:`e1929b5`(M7d.1)→ **`949b6eb`(M7d.2 WIP/BROKEN cutover)**

## 期间踩坑提醒(累积)

- **M0-M4 累积坑** 见 [`archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md`](archive/2026-05-04-rts-m3-m4-hierarchical/Next-Steps.md) "期间踩坑提醒"
- **M5 累积坑** 见 [`archive/2026-05-04-rts-m3-m5-long-pathfinder/Summary.md`](archive/2026-05-04-rts-m3-m5-long-pathfinder/Summary.md)
- **M6 累积坑**(本 milestone):
  - **GDScript class_name cache race(再次踩)** — 加新 class(M6a 4 个 + M6b 0 个 + M6c 0 个)首次 smoke 报"Identifier not declared"。**Lesson**:加新 class_name 后必须先 `godot --headless --path . --import` 让 cache stabilize 才跑 smoke
  - **Bash `cd submodule_root` 漂 cwd** — `cd addons/logic-game-framework && git status` 后再调 godot,主仓 project.godot 找不到 → headless 假卡死。**Lesson**:godot 调用永远用绝对路径 `--path D:/...inkmon-godot`
  - **浮点 distance round-off visibility A* path 不"最短"** — start, bounds_TL, goal 三点共线时(几何 corner case),A* 选 via-bounds_TL(累加浮点 sum 反比 direct distance 小 1 ulp),path size=2 而非 1。**Lesson**:visibility A* 路径形状对几何 corner case 敏感但语义等价(unit 走轨迹相同),smoke 不应 hard-assert "size=1"
  - **Liang-Barsky 浮点除零 epsilon** — segment 几乎平行轴时 `dx`/`dy` 极小但非 0,`1.0/dx` 爆无穷大 → t1/t2 误判 → 段-AABB 相交错判。**Lesson**:浮点 sentinel 用 `absf(dx) > 1e-9` 而非 `dx != 0.0`
  - **best-so-far 严格 < 比较保 deterministic** — `if nb_h < best_dist:` 而非 `<=`,等距时按 expansion 顺序保 deterministic;否则同距离 tie-break 走 nb_idx 字面值,跨 run 不稳定
  - **best-so-far start_idx 兜底返空** — A* open 耗尽 + best_idx 仍 = start_idx 意味"start 没邻居可见"(完全 enclosed),返非空 path = [start] 让 caller 把 unit 留在原地空转;直接返空让 caller 进 stuck 状态有意义 — M6a `_test_fully_enclosed_returns_empty` 行为保留
  - **spec AC11 baseline diff vs M6c.4 facade wire 范围内部不一致** — spec §AC11 期望 baseline `short_path_*` 字段从占位变实填(production 已消费),但 §M6c.4 文字仅写"facade 加 API"。M6 milestone 按保守解读(facade API only,production 不接)收口,baseline 0 漂;✋3 + AC11 完整 baseline 漂 + perf 实测都延后到 M7 production wire