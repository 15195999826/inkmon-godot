# Next Steps — 2026-05-04 (M3 Epic / M2 active;M2.4 done,推 M2.5)

## 当前目标

**RTS Pathfinding M3 Epic — M2 sub-feature**: ObstructionManager (Shape 数据库) — 引入 `RtsObstructionManager` 单例,统一管理所有 obstruction shape(单位圆 + 建筑 OBB),替换 M0/M1 阶段"actor 自管 obstruction_shape + grid 自管 placement_map"的散乱状态。M2 引入完整 EFlags 枚举(6 flag)+ spatial index(uniform grid bucket)+ 替换 `RtsBattleGrid.place_building` 为 `add_static_shape` + rasterize。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,**M0 + M1 已 archived 于 2026-05-04**。

**当前 active sub-feature = M2**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md))。

**M2 进度**: M2.1 ✅ + M2.2 ✅ + M2.3 ✅ + M2.4 ✅ + M2.5 ✅ done(2026-05-04 — 数据结构 + Manager 单例 + Building / Unit 链路全接 manager;dual-write 兼容;Death unregister deferred 到 M5;Validation 0 漂移)。

## 下一步

启动 **M2.6 — 新 smoke 3 个 + Validation 全套 + commit**(spec: [`M2-obstruction-manager.md §M2.6`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md#m26--新-smoke--validation-全套--commit)):

### M2.6 步骤

1. **`smoke_obstruction_manager_register.tscn/.gd`**:
   - 创建 ObstructionManager + grid + registry(独立, 不走 procedure)
   - `add_unit_shape` × 5 + `add_static_shape` × 3 → 验证 tag 1..8 单调递增
   - 验证 `manager.size() == 8`
   - `get_obstructions_in_range(中心, 大半径)` 返回 8 shape, 按 tag 升序

2. **`smoke_obstruction_manager_query.tscn/.gd`**:
   - 加 unit + 建筑各若干, 含同 group / 异 group 测试用例
   - `test_unit_shape(only_blocking_movement(), pos, clearance)` 检验单位想走到某点是否撞建筑 / 单位
   - `test_static_shape(skip_control_group("0"), ...)` 检验同队建筑不算冲突
   - **完整 SAT 4 case 单元覆盖** (R1 缓解):轴对齐 / 旋转 45° / 边接触 / 角接触 OBB-OBB

3. **`smoke_obstruction_manager_remove.tscn/.gd`**:
   - add → remove → 验证 _shapes / _spatial_index 都清掉(`manager.size() == 0`)
   - remove 不存在的 tag 不 crash(幂等)

4. **跑 17 项 baseline + 3 新 smoke** = 20 项;期望 0 漂移(M2.6 不动 production code)

5. **baseline CSV byte-identical** spot 检 (882882 bytes)

6. **submodule commit + LGF CHANGELOG + 主仓 bump**:
   - submodule commit message: `feat(rts-m3): M2 done — ObstructionManager (Shape 数据库 + Spatial Index)`
   - LGF CHANGELOG.md 加 M2 段(Unreleased / 2026-05-04 / Added 段下列 4 个 obstruction 文件 + 1 spatial_index + 1 manager + 字段加项 + procedure tick step 4f)
   - 主仓 bump submodule pointer + commit `feat(rts-m3): M2 done — bump submodule → <new sha>`

### M2.6 完成后

按 milestone-chain 协议(README §收口条件)— 直接 archive M2 + 启动 M3,**不**逐 milestone reset Progress/Current-State,Epic 级 reset 留到 M8 完成后:

- archive entry `.feature-dev/archive/2026-05-04-rts-m3-m2-obstruction-manager/`
- 主仓目录 docs reset 到 M3 active:Progress.md / Next-Steps.md / Current-State.md / task-plan/README.md / m3 README progress 行
- 不开 M3 实施,等用户 / codex 确认

## 期间踩坑提醒

- M2.2 期间 bash cwd 漂到 submodule → godot 静默 hang。**已解**;后续严禁 cd 不回。
- M2.3 期间新加 class_name (`RtsObstructionManager`) 后第一波 4 godot 并行,GDScript class_name cache race — 先启动的进程读旧 cache → Parse Error → smoke FAIL;后启动的进程拿到 refresh 后 cache → PASS。**Lesson**: M2.4+ 后续若再加 class_name (M2.4 不加,M2.5 也不应加;M2.6 smoke .gd 文件不算),首次跑 baseline 先单跑 1 个 smoke 让 cache stabilize 再批量并行。

## 验收准则

完整 AC1-AC10 见 [`M2-obstruction-manager.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md);Progress.md §2 镜像 checklist。

### 关键过线条件

- ✅ 3 个 smoke PASS(`smoke_obstruction_manager_register / _query / _remove`)
- ✅ Validation 全套 14 项 + LGF 73/73 + replay seed=42 deep-equal
- ✅ Baseline CSV(M2 引入 obstruction trace 字段从占位 -1 / "" 变实填,**P2 预期变化**,接受新 baseline;详见 [risks-and-rollback §1.3](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md))
- ✅ Perf vs M1:wall_clock ≤ +50%,tick_p99 ≤ 30 ms
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ **runner 启动前必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 完整 9 条**(包括 perf 主指标 `tick_p99/tick_max` ≥ 100% 增长 / R5 P1 #2 dirty lifecycle invariant 违反 / R5 P1 #1 actor sort 用字典序而非 `(kind, spawn_seq)` 数值 key 等)。

任一触发立即停下问用户。**不在本文件内联枚举**(避免双源漂移),risks-and-rollback §3 是唯一权威。runner 必须显式读完该 9 条后再启动 M2.1。

## 非下一步

- ❌ 不启动 M3-M8(每个 milestone 末等 codex / 用户授权再起下一个)
- ❌ 不实现 Clearance 外扩 / Hierarchical / LongPath / VertexPath / Motion(分别在 M3 / M4 / M5 / M6 / M7)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 commit(运行至子任务 done 时由 runner 按协议 commit)

## 等待动作

由 `/autonomous-feature-runner` 接 M2.1 起步。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md) **顶部 Status block + §0 + §1 + §2 子任务 + §3 AC + §6 风险**(spec 较长,token-conscious 可先读这几节)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**
3. 顺手过 [`task-plan/m3-0ad-pathfinding-migration/data-structures.md`](task-plan/m3-0ad-pathfinding-migration/data-structures.md) §2(Obstruction 层 EFlags / Filter / SpatialIndex / Manager 字段定义)+ §12(determinism contract)
4. **M1 末态 baseline 数据**(AC8 0 漂移基准):见 `Current-State.md` "测试基线" 表 — 14+1+1+1 项 + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)
5. 按 M2.1 → M2.2 → M2.3 → M2.4 → M2.5 → M2.6 顺序推进;每个子任务 done 时 update Progress.md(checkbox + AC 状态同步)
6. M2 全部 AC 通过后:milestone-chain 协议(详见 [`task-plan/README.md`](task-plan/README.md) §收口条件)— 直接 archive M2 + 启动 M3,**不**逐 milestone reset Progress/Current-State,Epic 级 reset 留到 M8 完成后
