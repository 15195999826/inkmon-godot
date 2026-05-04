# Next Steps — 2026-05-04 (M6 done + archived;等用户授权 M7 启动)

## 当前目标

⏸ **等用户审 M6 archive + 授权启动 M7**(milestone-chain 协议:每 milestone 末等审阅再起下一个)。

> **M3 Epic 进度**: M0+M1+M2+M3+M4+M5+M6 已 archived(2026-05-04),7/9 milestone done。剩余 M7 (UnitMotion 整合双轨) / M8 (Group Push) + EPIC 末 cleanup phase (M5.5b-e RtsBattleGrid 完整删除)。
> Epic 总览 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。

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

**M7 — UnitMotion(整合 long+short 双轨)**(完整 spec [`task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md))。

M7 重写 unit motion 状态机替代 RtsNavAgent + RtsUnitSteering,把 LongPath(全图)+ ShortPath(VertexPath)双轨整合到统一 motion update tick;✋4 体验点 = 流畅 attack-move + 单位 chain motion 不卡。

**M7 触发 M6 deferred 项**:
- VertexPathfinder 真正进 production tick → ✋3 demo 看到效果
- baseline CSV short path 字段实填 → P1 接受新 baseline
- perf 实测(100 unit × 30 Hz)

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

由 `/autonomous-feature-runner` 接 **M7** 起步(用户授权后)。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条**(M7 是 R5 P1 #1 actor sort 漂 / R5 P1 #2 dirty lifecycle 高风险点)
3. **M6 末态 baseline 数据**:见 Current-State.md "测试基线" 表 + `archive/2026-05-04-rts-m3-m6-vertex-pathfinder/Summary.md`
4. 按 M7a → M7b → M7c → M7d 顺序推进(spec §M7,sub-phase 独立 rollback 点);每个子任务 done 时 update Progress.md
5. M7 全 AC 通过后:milestone-chain 协议 — 直接 archive M7 + 等用户审 ✋3 + ✋4 体验点(M7 一并兑现 M6 ✋3 + 自身 ✋4)→ 启动 M8

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