# Task Plan — Active: RTS Pathfinding M3 Epic(M8 group push pass active)

> **Active feature**: ⏳ **M8 group push pass + ✋5 体验点**(scope = M8 only;cleanup phase 留 M8 完成后再 plan;Epic-level archive 同样推迟)。2026-05-05 planner 启动。
>
> **Epic 状态**: M0-M7 done + archived(8/9 milestone)。当前 M8 active。剩 cleanup phase(M5.5b-e RtsBattleGrid 删除 + RtsNavAgent / RtsUnitSteering hard delete + vertex pathfinder simple-case 算法修 + smoke 阈值 restore)留 M8 完成后下一 feature。
>
> **下一步**:M8.1 — `RtsMotionComponent._init` 末尾调 `set_unit_control_group(tag, str(team_id))`(spec §2 M8.1)。
>
> **关键决策 confirm**(本轮 planner 锁定): N1 `push_factor = 0.5`(A) / N2 不区分 control_group(A)。
>
> **完整 spec**:[`m3-0ad-pathfinding-migration/milestones/M8-group-push.md`](m3-0ad-pathfinding-migration/milestones/M8-group-push.md)。

---

## 当前 active 索引

| 文档 | 角色 | 状态 |
|---|---|---|
| [`m3-0ad-pathfinding-migration/README.md`](m3-0ad-pathfinding-migration/README.md) | M3 Epic 总览(9 milestone + 5 体验点 + 11 决策)| ✅ Step A done, codex APPROVE |
| [`m3-0ad-pathfinding-migration/data-structures.md`](m3-0ad-pathfinding-migration/data-structures.md) | 全部新数据结构 + §12 determinism contract | ✅ Step A done, R1-R8 修订 |
| [`m3-0ad-pathfinding-migration/interfaces.md`](m3-0ad-pathfinding-migration/interfaces.md) | Component 公开 API | ✅ Step B done, R5-R7 修订 |
| [`m3-0ad-pathfinding-migration/validation-strategy.md`](m3-0ad-pathfinding-migration/validation-strategy.md) | trace schema + 体验点 + perf baseline | ✅ Step B done, R6 修订 |
| [`m3-0ad-pathfinding-migration/risks-and-rollback.md`](m3-0ad-pathfinding-migration/risks-and-rollback.md) | per-milestone rollback + stop-runner 条件 | ✅ Step B done, R5 修订 |
| [`m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`](m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md) | M0 Footprint 拆分 + Bug 1 修复(已 archived)| ✅ done → [archive](../archive/2026-05-04-rts-m3-m0-footprint-split/) |
| [`m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md`](m3-0ad-pathfinding-migration/milestones/M1-navcell-grid.md) | M1 Navcell Grid + Passability(已 archived)| ✅ done → [archive](../archive/2026-05-04-rts-m3-m1-navcell-grid/) |
| [`m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md`](m3-0ad-pathfinding-migration/milestones/M2-obstruction-manager.md) | M2 ObstructionManager + Spatial Index(已 archived)| ✅ done → [archive](../archive/2026-05-04-rts-m3-m2-obstruction-manager/) |
| [`m3-0ad-pathfinding-migration/milestones/M3-clearance.md`](m3-0ad-pathfinding-migration/milestones/M3-clearance.md) | M3 Clearance + 外扩(已 archived)| ✅ done → [archive](../archive/2026-05-04-rts-m3-m3-clearance/) |
| [`m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`](m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md) | M4 Hierarchical(已 archived)| ✅ done → [archive](../archive/2026-05-04-rts-m3-m4-hierarchical/) |
| [`m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md`](m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md) | M5 LongPathfinder(已 archived)| ✅ done → [archive](../archive/2026-05-04-rts-m3-m5-long-pathfinder/) |
| [`m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md`](m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md) | M6 VertexPathfinder(已 archived;simple-case 算法修留 cleanup)| ✅ done → [archive](../archive/2026-05-04-rts-m3-m6-vertex-pathfinder/) |
| [`m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md`](m3-0ad-pathfinding-migration/milestones/M7-unit-motion.md) | **M7 UnitMotion(已 archived 2026-05-05)** | ✅ done → [archive](../archive/2026-05-05-rts-m3-m7-unit-motion/) |
| [`m3-0ad-pathfinding-migration/milestones/M8-group-push.md`](m3-0ad-pathfinding-migration/milestones/M8-group-push.md) | **M8 push pass + group polish** | ⏳ **active**(2026-05-05 planner 启动;N1=0.5 / N2=同力度 confirm;AC8 demo 硬性验收追加) |
| [`m3-0ad-pathfinding-migration/deferred/0ad-formation-design.md`](m3-0ad-pathfinding-migration/deferred/0ad-formation-design.md) | Formation handoff(下个 Epic)| 📋 deferred |
| [`m2-roadmap.md`](m2-roadmap.md) | M2 milestone 路线图(已 done)| 稳定 spec, 历史参考 |

---

## 收口条件

**M0 sub-feature ✅ 完成 + archived**(2026-05-04):
- M0 §3 AC1-AC10 全部 ✅
- 14+1+1 项 smoke + LGF 73 + replay seed=42 0 漂移
- ✋1 体验点用户跑 demo 反馈通过
- archive entry: [`../archive/2026-05-04-rts-m3-m0-footprint-split/`](../archive/2026-05-04-rts-m3-m0-footprint-split/)

**M1 sub-feature ✅ 完成 + archived**(2026-05-04):
- M1 §3 AC1-AC10 全部 ✅(AC7 perf-trace 工具 follow-up 留 M5)
- 14 项 smoke + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)+ 新 navcell smoke 全过
- archive entry: [`../archive/2026-05-04-rts-m3-m1-navcell-grid/`](../archive/2026-05-04-rts-m3-m1-navcell-grid/)

**M2 sub-feature ✅ 完成 + archived**(2026-05-04):
- M2 §3 AC1-AC10 全部 ✅(AC6 Death unregister + AC9 perf-trace + AC5 rasterize 接入 follow-up 留 M5)
- 17 项 smoke + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical(882882 bytes)+ 3 新 obstruction_manager smoke 全过
- **dual-write 模式让 baseline 0 漂移**(spec §AC8 预期 trace 字段变化未发生,留 M5 切 pathfinder 时一次性接受)
- archive entry: [`../archive/2026-05-04-rts-m3-m2-obstruction-manager/`](../archive/2026-05-04-rts-m3-m2-obstruction-manager/)

**M3 sub-feature 完成标志**(待):
- M3 §3 AC 全部 ✅
- Validation 全套 17 项 smoke + LGF 73 + replay seed=42 deep-equal
- Baseline CSV(M3 引入 path 变化预期 P1,接受新 baseline)
- Perf vs M2:wall_clock ≤ +50%,tick_p99 ≤ 30 ms
- 不动 LGF submodule core/ stdlib/

**通用 milestone-chain archive 协议**(M1 → M2 / M2 → M3 / ... 重复):
- 创建 `archive/2026-XX-XX-rts-m3-mN-<slug>/`(完整拷贝当前 task-plan/m3-0ad-pathfinding-migration + Progress + Current-State + Next-Steps 快照 + 写 Summary.md)
- 当前 milestone spec 顶部标 `Status: ✅ done` + 链 archive 路径
- 下个 milestone spec 启动(本 task-plan/README.md 当前 sub-feature 改下一个)
- 主目录 Progress.md / Current-State.md / Next-Steps.md 全部 update 到下个 milestone active 状态
  - Progress.md 缩到 ~2K char(下个 milestone checklist + AC),旧 milestone 详情链 archive
  - Current-State.md 更新到刚 done milestone 的末态 baseline + 下个启动准备
  - Next-Steps.md 重写指向下个 milestone.1 起步动作
- ⚠️ M3 Epic 整体未完成,中间 milestone archive 不全空白 reset Progress / Current-State(continuing milestone-chain),只更新到 next active 状态

**Epic 收口**(M0-M8 全 done + 5 ✋ 体验点全过):
- Epic 整体 archive `archive/2026-XX-XX-rts-m3-0ad-pathfinding-migration/`
- 启动 Formation Epic(下个 Epic,设计文档已就绪)
- 完整 reset Progress.md / Current-State.md 为 baseline-only state(等待 next Epic)

---

## 历史 archive

| 文档 | 角色 |
|---|---|
| [`../archive/2026-05-05-rts-m3-m7-unit-motion/`](../archive/2026-05-05-rts-m3-m7-unit-motion/) | **M7 UnitMotion 双轨整合 cutover(M3 Epic 第八个 milestone)— 最近** |
| [`../archive/2026-05-04-rts-m3-m6-vertex-pathfinder/`](../archive/2026-05-04-rts-m3-m6-vertex-pathfinder/) | M6 VertexPathfinder 算法层(M3 Epic 第七个 milestone)|
| [`../archive/2026-05-04-rts-m3-m5-long-pathfinder/`](../archive/2026-05-04-rts-m3-m5-long-pathfinder/) | M5 LongPathfinder + Facade(M3 Epic 第六个 milestone)|
| [`../archive/2026-05-04-rts-m3-m4-hierarchical/`](../archive/2026-05-04-rts-m3-m4-hierarchical/) | M4 HierarchicalPathfinder(M3 Epic 第五个 milestone)|
| [`../archive/2026-05-04-rts-m3-m3-clearance/`](../archive/2026-05-04-rts-m3-m3-clearance/) | M3 Clearance + 外扩(M3 Epic 第四个 milestone)|
| [`../archive/2026-05-04-rts-m3-m2-obstruction-manager/`](../archive/2026-05-04-rts-m3-m2-obstruction-manager/) | M2 ObstructionManager + Spatial Index(M3 Epic 第三个 milestone)|
| [`../archive/2026-05-04-rts-m3-m1-navcell-grid/`](../archive/2026-05-04-rts-m3-m1-navcell-grid/) | M1 Navcell Grid + Passability(M3 Epic 第二个 milestone)|
| [`../archive/2026-05-04-rts-m3-m0-footprint-split/`](../archive/2026-05-04-rts-m3-m0-footprint-split/) | M0 Footprint 拆分 + Bug 1 修复(M3 Epic 第一个 milestone)|
| [`../archive/2026-05-03-rts-m2-3-ui-hud/`](../archive/2026-05-03-rts-m2-3-ui-hud/) | M2.3 UI / HUD / Build Panel / 关卡完整归档(旧 RTS M2 milestone 收口章节)|
| [`../archive/2026-05-02-rts-m2-2-ai-opponent/`](../archive/2026-05-02-rts-m2-2-ai-opponent/) | M2.2 AI 对手 |
| [`../archive/2026-05-02-rts-m2-1-economy/`](../archive/2026-05-02-rts-m2-1-economy/) | M2.1 经济 |
| [`../archive/2026-05-02-rts-m1-refactor/`](../archive/2026-05-02-rts-m1-refactor/) | M1 RTS 重构 |
| [`../archive/2026-04-30-rts-auto-battle/`](../archive/2026-04-30-rts-auto-battle/) | 早期 RTS 例子骨架 |

---

## Handoff 入口(给 codex / 历史参考)

- [`../Handoff-2026-05-03-0ad-migration-planning.md`](../Handoff-2026-05-03-0ad-migration-planning.md) — Step A handoff + R1-R4 闭环记录
- [`../Handoff-2026-05-03-step-b-codex-review.md`](../Handoff-2026-05-03-step-b-codex-review.md) — Step B handoff + R5/R6/R7/R8 闭环记录(含 4 P1 + 多 P2 已修订)
