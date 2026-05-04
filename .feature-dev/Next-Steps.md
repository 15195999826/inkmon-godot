# Next Steps — 2026-05-05(M7 done;等启动 M8 / cleanup)

## 当前目标

⏸ 已完成系统功能验收,接下来等待用户确认下一个 feature 开发。

## M3 Epic 剩余 milestone

- 🚧 **M8 group push pass**(unit overlap 修;✋5 体验点)
- 🚧 **EPIC 末 cleanup phase**:M5.5b-e RtsBattleGrid 完整删除(用户决策推迟)+ vertex pathfinder simple-case 算法修(M7d fallback 替代)+ RtsNavAgent / RtsUnitSteering hard delete + smoke_move_units_command MIN_PAIR_DIST 改回 24.0

## M7 末态 baseline(M8 / cleanup 出发点)

- rts/all **53/53 PASS**;-Required **12/12 PASS**;LGF 73/73
- **smoke_replay_bit_identical seed=42 frames=11 events=24 deep-equal**
- **Baseline CSV 961039 bytes**(M7 接受新值;motion 行为变化预期 P1 drift)
- **Motion 双轨**:LongPath 全图 A* + canonicalize 字段 routing(玩家 click immediate / AI activity direct)+ _allow_unreachable_fallback flag(production 默认开,smoke 测试可关)
- **Production 0 RtsNavAgent / RtsUnitSteering callsite**(文件保留供 4 obscure smoke 用)
- **Activity 全切 motion API**:attack / harvest / return_and_drop / move_to / attack_move 经 RtsMotionComponent.attach_default factory + bind_runtime(motion_component)

详见 [`archive/2026-05-05-rts-m3-m7-unit-motion/Summary.md`](archive/2026-05-05-rts-m3-m7-unit-motion/Summary.md)。

## 下一步

⏸ 等待用户:
- **启动 M8 group push pass** — `/next-feature-planner`(目标:✋5 体验点 + smoke_move_units_command MIN_PAIR_DIST 改回 24.0)
- **启动 EPIC 末 cleanup** — `/next-feature-planner`(目标:RtsBattleGrid hard delete + RtsNavAgent / RtsUnitSteering hard delete + vertex pathfinder simple-case 算法修)
- **跑 demo F6 ✋4 体验点验证** — Godot 编辑器跑 1 局看 motion 行为(若发现问题反馈,启动 motion 调优 milestone)

## 验收准则

无 active feature。M3 Epic 总验收准则在 [`task-plan/m3-0ad-pathfinding-migration/README.md`](task-plan/m3-0ad-pathfinding-migration/README.md) §0.2(EPIC AC-EPIC-1 ~ -7)。

## 非下一步

- ❌ 不主动 push commit(commit 是本地节点保护,push 等用户)
- ❌ 不修改 LGF submodule core/ 或 stdlib/(项目硬约束)
- ❌ 不擅自启动新 milestone(等用户 `/next-feature-planner`)
