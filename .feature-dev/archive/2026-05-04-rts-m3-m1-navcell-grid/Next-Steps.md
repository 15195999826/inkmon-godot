# Next Steps — 2026-05-04 (M3 Epic / M0 archived; M1 active 等 runner 启动)

## 当前目标

**RTS Pathfinding M3 Epic — M1 sub-feature**: Navcell Grid + 16-bit Passability Class — 数据层重构,把 `RtsBattleGrid` 内部 `Dictionary[Vector2i, RtsCell]` 替换为 `RtsNavcellGrid`(`PackedInt32Array` 16-bit 位掩码),引入 `RtsPassabilityClassRegistry`(本 Epic 实际用 default/ground + air 两 class,留 14 bit 给将来)。

> M3 Epic = "RTS 寻路全面迁移到 0 A.D. 方案",分 9 个 milestone(M0-M8)+ Formation 推到下个 Epic。
> Epic 总览见 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md)。
> Epic 经过 codex Round 1-8 审查,Step A + Step B 全部 APPROVE,**M0 已 archived 于 2026-05-04**。

**当前 active sub-feature = M1**(完整 spec: [`task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md))。

## 下一步

启动 **M1.1 — 引入 PassabilityClassConfig + Registry**:

1. 新建 `addons/.../logic/grid/rts_passability_class_config.gd`(Resource,字段 class_name_id / bit_index=-1 / clearance=14.0 / max_water_depth / min_water_depth / min_shore_distance)
2. 新建 `addons/.../logic/grid/rts_passability_class_registry.gd`(RefCounted,16 bit,SPECIAL_PASS_CLASS_INDEX=15,register / get_class / get_mask / max_clearance API)
3. `rts_auto_battle_procedure.gd` 启动时按固定顺序 `register(default)` → `register(air)`(R5 决策:bit_index 自动分配顺序固化;先 default 0x1 后 air 0x2)
4. `rts_world.passability_registry` 字段挂上

**完成标志**:`get_mask("default") == 0x1` / `get_mask("air") == 0x2`,duplicate 时 `Log.assert_crash`。

后续 M1.2 → M1.5 见 Progress.md §1。

## 验收准则

完整 AC1-AC10 见 [`M1-navcell-grid.md §3`](task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md);Progress.md §2 镜像 checklist。

### 关键过线条件

- ✅ `smoke_navcell_grid_passability` PASS
- ✅ Validation 全套 14 项 0 漂移 + LGF 73/73 + replay seed=42 deep-equal + baseline CSV byte-identical(M1 不引入 trace 新字段)
- ✅ Perf vs M0:wall_clock ≤ +50%,tick_p99 ≤ 30 ms
- ✅ 现有 `GridPathfinding.find_path` 内部改 `grid.is_blocking(c)`,路径输出与 M0 bit-identical
- ✅ 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core/ stdlib/

### Stop Runner 触发条件

⚠️ **runner 启动前必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 完整 9 条**(包括 perf 主指标 `tick_p99/tick_max` ≥ 100% 增长 / R5 P1 #2 dirty lifecycle invariant 违反 / R5 P1 #1 actor sort 用字典序而非 `(kind, spawn_seq)` 数值 key 等)。

任一触发立即停下问用户。**不在本文件内联枚举**(避免双源漂移),risks-and-rollback §3 是唯一权威。runner 必须显式读完该 9 条后再启动 M1.1。

## 非下一步

- ❌ 不启动 M2-M8(每个 milestone 末等 codex / 用户授权再起下一个)
- ❌ 不实现 ObstructionManager / Pathfinder / Hierarchical / Formation(分别在 M2 / M5-M6 / M4 / 下个 Epic)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不主动跑 `/ultrareview` 或 commit(运行至子任务 done 时由 runner 按协议 commit)

## 等待动作

由 `/autonomous-feature-runner` 接 M1.1 起步。runner 进入后应:

1. 先读 [`task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md`](task-plan/m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md) **顶部 Status block + §0 + §1 + §2 子任务 + §3 AC + §6 风险**(spec ~17 KB,token-conscious 可只读这几节;状态指明 M1 active,M1.1 起步)
2. **必读** [`task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md`](task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md) **§3 stop runner 9 条触发条件**(本 Next-Steps 不内联,避免双源漂移)
3. 顺手过 [`task-plan/m3-0ad-pathfinding-migration/data-structures.md`](task-plan/m3-0ad-pathfinding-migration/data-structures.md) §1(Grid 层 PassabilityClassConfig / Registry / NavcellGrid 字段定义)+ §12(determinism contract,AC9 bit-identical 关键)
4. **M0 末态 baseline 数据**(AC6 0 漂移基准):见 `Current-State.md` "测试基线" 表 — 14+1+1 项 + LGF 73 + replay seed=42 deep-equal
5. 按 M1.1 → M1.2 → M1.3 → M1.4 → M1.5 顺序推进;每个子任务 done 时 update Progress.md(checkbox + AC 状态同步)
6. M1 全部 AC 通过后:milestone-chain 协议(详见 [`task-plan/README.md`](task-plan/README.md) §收口条件)— 直接 archive M1 + 启动 M2,**不**逐 milestone reset Progress/Current-State,Epic 级 reset 留到 M8 完成后
