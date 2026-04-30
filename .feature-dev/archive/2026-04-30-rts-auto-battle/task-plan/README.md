# Task Plan — rts-auto-battle (M0)

把 RTS 自动战斗最小可玩闭环拆成 9 个可独立验证的步骤。每步落地后跑窄验证（编辑器 F6 或 headless），更新 `Progress.md`，再进下一步。

## 参照范式

完全对标 `addons/logic-game-framework/example/hex-atb-battle/`：

- WorldGI 子类范式 → `core/hex_world_gameplay_instance.gd`
- BattleProcedure tick 循环范式 → `core/hex_battle_procedure.gd`
- Actor 子类含 AbilitySet 的范式 → `logic/character_actor.gd`
- Headless 入口范式 → `logic/demo_headless.gd` + `demo_headless.tscn`
- Smoke test 范式 → `tests/battle/smoke_skill_scenarios.tscn`
- Frontend demo 范式 → `frontend/demo_frontend.gd` + `demo_frontend.tscn`

新例子放 `addons/logic-game-framework/example/rts-auto-battle/`，三层结构对齐。

## Phase 拆分

### M0.1 — 目录骨架

- 建子目录：`example/rts-auto-battle/{core,logic,frontend,tests/battle,tests/frontend}/`
- 占位文件：每层一个 `README.md`（写"WIP M0"），`.gd` 文件先写 class_name + extends + 空 `_ready()`
- 验证：`godot --headless --path . --import` 通过；新目录下任意 `.tscn`（空场景）能 F6 启动不报错

### M0.2 — WorldGI + Procedure

- `core/rts_world_gameplay_instance.gd` extends `WorldGameplayInstance`
  - 不依赖 UGridMap / hex grid；自己管 `_actors_by_id` 已由父类提供
  - 暴露 map_size: Vector2、navigation_region: NavigationRegion2D（M0.4 注入）
- `core/rts_auto_battle_procedure.gd` extends `BattleProcedure`
  - tick(dt) 推进 cooldown / navigation
  - `_check_battle_end()` 一方全灭 → set winner
  - `MAX_TICKS` 安全上限（例：1000 ticks @ 50ms = 50s）
- 验证：单元测试或最小 smoke：实例化 WorldGI + 空 procedure，tick 1 次不崩

### M0.3 — Actor + Stats

- `logic/rts_battle_actor.gd` extends `Actor`（不继承 HexBattleActor，hex 含 hex_position）
  - 字段：`position: Vector2`、`velocity: Vector2`、`team_id: int`、`is_dead: bool`
- `logic/rts_character_actor.gd` extends `RtsBattleActor`
  - 字段：`unit_class: UnitClass`（enum: MELEE / RANGED）、`attack_cooldown_remaining: float`、`current_target: String`（敌方 actor id）
  - AbilitySet 创建：复用 LGF `AbilitySet.create_ability_set`，挂 attribute set
- `logic/rts_unit_attribute_set.gd` extends `RawAttributeSet`
  - 属性：`hp / max_hp / atk / def / move_speed / attack_speed / attack_range`
- `logic/config/rts_unit_class_config.gd` — 兵种数值表
  - MELEE: hp 200, atk 25, def 5, move_speed 80 px/s, attack_speed 1.0/s, attack_range 24 px
  - RANGED: hp 120, atk 18, def 2, move_speed 70 px/s, attack_speed 0.8/s, attack_range 120 px
- 验证：spawn 4v4 无报错，能从 logger 看到 8 个 actor 注册

### M0.4 — Navigation 接入

- `frontend/scene/rts_battle_map.tscn`：含 NavigationRegion2D + 几个 ColorPolygon2D 障碍物（500×500 边界 + 中央 2-3 块石头）
- `logic/components/rts_nav_agent.gd`（非 Component；纯封装类）：包 NavigationAgent2D 的初始化与 set_target
- 验证：单测脚本：spawn 一个单位在 (50,250)，目标 (450,250)，中央障碍 (200..300, 200..300)；run 5s tick；最终位置应抵达 target，且中途 position.x 出现过非线性 y（绕路证据）
- **headless 注意**：tick 前 `await get_tree().physics_frame` 让 NavigationServer 同步一次

### M0.5 — AI 行为循环

- `logic/ai/rts_basic_ai.gd`：每 tick：
  1. 若 `current_target` 死或丢失 → `find_nearest_enemy`
  2. 距离 ≤ `attack_range` → 停止移动（清空 nav target），cooldown 到时触发 attack
  3. 距离 > `attack_range` → 设 nav target = enemy.position（每 200ms 刷新一次，避免每帧重算）
- 没用 LGF 的 `AIStrategy` 接口（hex 那套基于 ATB tick 的策略与 RTS 连续 tick 不同），新写一个轻量 ai 类即可

### M0.6 — Attack action / death / 胜负判定

- `logic/actions/rts_basic_attack_action.gd` extends `BaseAction`
  - 复用 LGF 现有 DamageAction 路径（调用 `damage_utils` 跑 attacker.atk vs target.def 公式）
  - 触发完整 EventProcessor pre/post 管线（让 buff/passive 有 hook 接入空间）
- `logic/rts_battle_pre_events.gd`：仅注册必要的 pre-event handler（M0 可空，留 hook 给 M1）
- `_check_battle_end` 每 tick 跑一次：所有 left_team / right_team 都死 → set winner
- 验证：单测 spawn 1 melee 攻击 1 dummy，dummy 在 N 次 attack 内 hp ≤ 0 标记 is_dead

### M0.7 — Headless smoke + 兵种行为断言

- `tests/battle/smoke_rts_auto_battle.gd` + `.tscn`：
  - spawn 4v4（左队 2 melee + 2 ranged，右队对称）
  - run 直到 `_check_battle_end` 触发或 MAX_TICKS
  - 收尾断言：
    - 必过：winner ∈ {left, right}，print `SMOKE_TEST_RESULT: PASS - <winner>`
    - 兵种行为：扫 logger 中所有 attack 事件，按 attacker.unit_class 分组：
      - 所有 MELEE attack 的 dist ≤ melee_attack_range × 1.05（容差）
      - 所有 RANGED unit 至少出现 1 次 dist > melee_attack_range
    - 任一断言失败 → print `SMOKE_TEST_RESULT: FAIL - <reason>`，退出码 1
- 障碍物布局：左军在 x≈50 区，右军在 x≈450 区，中央 (200..300, 200..300) 一块石头，强制绕行

### M0.8 — Frontend stub visualizer

- `frontend/visualizers/rts_unit_visualizer.gd`：Sprite2D 或 Polygon2D，按 team_id 染色（左红右蓝）+ 圆形 + 当前 hp 文本
- `frontend/demo_rts_frontend.gd` + `demo_rts_frontend.tscn`：
  - 加载 `frontend/scene/rts_battle_map.tscn`
  - 创建 RtsWorldGI，spawn 4v4
  - `_process(dt)` 推进 procedure tick
  - 把 actor.position sync 到 visualizer.position
- 不要：动画、攻击特效、HUD、相机控制（M0 静态俯视即可）
- 验证：编辑器 F6 跑 `demo_rts_frontend.tscn`，肉眼看单位走动 / 互相攻击 / 死亡消失

### M0.9 — 文档同步

- `addons/logic-game-framework/example/README.md`（如不存在则按需创建）增补 RTS 例子条目
- 主仓 `CLAUDE.md` 的"测试 / 三个入口"表 → 增补 RTS smoke 入口（或者写说明文：RTS 例子是 M1 候选位置）
- `addons/logic-game-framework/CHANGELOG.md` `[Unreleased]` 段加一条 `Added` 条目

## 收口条件

`Next-Steps.md` 的 5 条验收准则全过 + Phase 进度 9/9 + 文档同步完成 → archive + 切到等待状态。

## 顺序依赖

```
M0.1 骨架 → M0.2 WorldGI/Procedure → M0.3 Actor/Stats
                                          ↓
                                      M0.4 Navigation
                                          ↓
                                      M0.5 AI loop
                                          ↓
                                      M0.6 Attack/Death
                                          ↓
                                      M0.7 Smoke ← acceptance gate (AC1, AC2, AC3)
                                          ↓
                                      M0.8 Frontend stub
                                          ↓
                                      M0.9 Docs sync ← acceptance gate (AC4, AC5 final re-check)
```

每个 phase 完成都要 re-run AC4（LGF 73/73）确保不退化；AC5（hex demo）每 3 个 phase 跑一次即可。
