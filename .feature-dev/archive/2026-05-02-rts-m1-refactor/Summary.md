# RTS Auto-Battle M1 架构重构 — Summary (2026-05-02)

把 RTS M0 (功能 spike) 演进为遵守 LGF 根原则、支持城堡战争玩法、流式 simulation + 决定性 replay 的工业级架构。

## Acceptance 结论

### Phase 1 — Foundation (✅ 9/9, 2026-05-01)

修 LGF 根原则硬偏离 (S1/S2/S3/M4) + 铺基础设施 (fixed-tick + grid wrapper + actor 三层基类)。

- [x] AC1-AC9 全过 — 详见 archive `Progress.md` §Phase 1

### Phase 2 — Core Systems (✅ 10/10, 2026-05-02)

城堡战争核心玩法支柱 (含飞行单位 + 单位攻击建筑)。

- [x] AC1 Activity 系统 — `smoke_activity_chain` PASS
- [x] AC2 避障 3 层 — `smoke_steering` + `smoke_stuck_recovery` PASS
- [x] AC3 AutoTargetSystem — `smoke_auto_target` 5 子测试 PASS
- [x] AC4 Production — `smoke_production` 双方各 spawn 7 melee
- [x] AC5 Player Command + Crystal Tower — 3 smoke 全过 (placement / ct-win / pc-production)
- [x] AC6 Frontend Director 流式 — `smoke_director_streaming` 0 处 polling
- [x] AC7 AIR layer + 飞行单位 — `smoke_flying_units` PASS
- [x] AC8 单位攻击建筑 — `smoke_castle_war_minimal` PASS (端到端城堡战争)
- [x] AC9 LGF 73/73 + 主战斗 0 退化
- [x] AC10 Bit-identical replay — `smoke_replay_bit_identical` deep-equal

### Phase 3 — Advanced (本轮 8/9, 2026-05-02)

Phase 3 子任务独立可选; 本轮选 P3.2 + P3.3 + 寻路验证 demo。

- [x] AC1 RtsScenarioHarness 框架跑通
- [x] AC2 RtsGroupFormation.assign_offsets (1/4/8/16 unit 合法 formation)
- [x] AC3 `smoke_move_units_command` PASS — MoveUnitsCommand + override_strategy
- [x] AC4-AC7 4 个寻路 scenario PASS — `smoke_pathfinding_validation`
- [x] AC8 LGF 73/73 + 全部 RTS smoke 0 退化 (含 bit-identical replay)
- [ ] **AC9 user-deferred** — F6 demo_rts_pathfinding 视觉验证未跑 (用户决定收尾不补)

**Phase 3 deferred (not-pursued)**:
- ❌ P3.1 Terrain Height + LOS — 用户决定不做
- ❌ P3.4 Fog of War — 用户决定不做 (依赖 P3.1)

## 关键 artifact 路径

- 主入口: `addons/logic-game-framework/example/rts-auto-battle/`
  - core: `core/{rts_world_gameplay_instance, rts_auto_battle_procedure, rts_demo_world_gameplay_instance}.gd`
  - logic: `logic/{rts_battle_actor, rts_unit_actor, rts_building_actor, movement_layer, rts_rng}.gd` + 子目录 (activity / movement / ai / actions / commands / buildings / production / scenario / config / weapons / target_selectors / logger)
  - frontend: `frontend/{world_view, scene/rts_battle_map, visualizers/*, core/rts_battle_director, demo_rts_frontend, demo_rts_pathfinding}.gd|tscn`
  - tests: `tests/battle/smoke_*.{gd,tscn}` + `tests/replay/smoke_*.{gd,tscn}` + `tests/frontend/smoke_*.{gd,tscn}` + `tests/battle/scenarios/*.gd`
- Autoload (新增): `RtsRng` (`logic/rts_rng.gd`)
- LGF stdlib: 全程未动 (root principle: example 目录下扩展)

## 真实运行证据

末态全过 smoke (Phase 3 收口跑过):

| 入口 | 结果 |
|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 73/73 PASS |
| `tests/battle/smoke_rts_auto_battle.tscn` | left_win, ticks=347, melee_max_dist=24.00, ranged_max_dist=125.75 (P2.8 baseline 0 退化) |
| `tests/battle/smoke_castle_war_minimal.tscn` | left_win, ticks=193, unit_to_building_attacks=4, archer_anti_air=1 |
| `tests/battle/smoke_flying_units.tscn` | scout_hp=15, archer_hits=3, melee_hits_scout=0 |
| `tests/battle/smoke_pathfinding_validation.tscn` | 4/4 scenarios PASS |
| `tests/battle/smoke_move_units_command.tscn` | ticks=100 alive=4 min_pair_dist=26.54 |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42, frames=10, events=20 deep-equal |
| `tests/replay/smoke_determinism.tscn` | seed=12345, run1=run2=(left_win, 347), tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 alive_after_3.0s=10 |

详细 evidence path / 命令 / 输出 — 见 archive `Progress.md`。

## 13 条架构决策 (跨 Phase 锁定)

详见 archive `task-plan/architecture-baseline.md`。Phase 2 收口时 D1-D4/D3-A/D3-B/D3-C/D3-D/D3-F/D3-G/E/F/G/H 全部落地; D3-E (terrain height + LOS) Phase 3 P3.1 deferred。

## 残余风险 / 已知 follow-up (留给 M2+)

1. **AC9 视觉验证未跑** — `demo_rts_pathfinding.tscn` 拖框 / 右键 / 4 验证点的视觉链路未在编辑器手动验证; 仅 headless smoke (smoke_move_units_command + smoke_pathfinding_validation) 覆盖逻辑层。后续 M2 demo 用到这块可顺便 sanity check。
2. **Phase 3 P3.1 deferred** — 现有寻路无 terrain height / LOS resolver, AIR 层走 _direct_path 不走 A* (P2.8 既定); 若 M2 需要高低差战术 (砲塔射程穿丘陵 / 地形阻挡视野), 需要单开 phase。
3. **Phase 3 P3.4 deferred** — Fog of War / Vision 系统未实现, 全图可见; 单人对 AI 的"未知地图"体验会缺失。
4. **AutoTargetSystem 不打 buildings (历史 limitation)** — P2.8 已让单位可选 building 当目标, 但 castle_war_minimal smoke 验证的是端到端胜负判定; 4v4 主 smoke 仍只在 unit-vs-unit 场景 (smoke 不传 team_configs → fallback 全灭判定)。M2 引入更多建筑互动时需要 sanity check。
5. **录像 wrapper deferred** — RTS 走 stdlib BattleRecorder 输出 timeline + procedure.finish 注 player_commands + rng_seed 进 record dict; 没有 RtsRecording 强类型 wrapper 类。当前 dict 注入足以支撑 bit-identical replay 验证 (AC10 P2.7), 后续若做 replay 播放 UI 再考虑封装。
6. **Production 系统不调 RNG** — production_system.tick 决定性安全 (按 cycle 加 progress, 满即 spawn); 如果 M2 加"产能波动" (随机 spawn 时刻), 要走 RtsRng autoload。
7. **既有 LGF leak warning** — `ObjectDB instances leaked / resources still in use` 退出时 warning 是 LGF stdlib 内部 leak, RTS 没引入新 leak; 退出码 0, 不影响 smoke PASS 判定。

## Commits

主仓 (master, ahead origin 7 commit):
- `3fc44f7` feat(rts-m1): P3.2/P3.3 done — bump addons + 同步 .feature-dev
- `549188d` feat(rts-m1): P2.8 done — Phase 2 收口 (10/10 AC)
- `7005d6e` feat(rts-m1): P2.7 frontend Director done
- `2a7e674` feat(rts-m1): bump addons + update .feature-dev for P2.6 completion
- `4e73782` docs(rts-m1): plan RTS M1 refactor, track P1 + P2.1-P2.4 progress
- (`12ba506` docs CLAUDE.md sync; `5e0f5aa` hex skill manifest fix — 同期但不属本 feature)

Submodule `addons/logic-game-framework` (累计 4 个 RTS M1 commit):
- `503cd25` feat(rts-m1): P3.2 + P3.3 done — group formation + ScenarioHarness + pathfinding scenarios
- `2859a57` feat(rts-m1): P2.8 AIR layer + 单位攻击建筑 — Phase 2 收口 (10/10 AC)
- `d2c4413` feat(rts-m1): P2.7 frontend BattleDirector + 流式 events 接入 + bit-identical replay
- `4afe6ef` feat(rts): RTS auto-battle M1 architecture refactor (Phase 1 + Phase 2 P2.1-P2.6)
