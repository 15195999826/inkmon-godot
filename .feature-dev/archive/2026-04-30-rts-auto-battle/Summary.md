# RTS 自动战斗最小可玩示例 — Summary (2026-04-30)

LGF 的第二个示例项目：连续 `Vector2` 坐标 + `NavigationServer2D` 寻路 + 实时 `attack_cooldown`，与既有 hex-atb-battle 的 hex grid + ATB 累积形成对比，验证 LGF 核心抽象（`WorldGameplayInstance` / `BattleProcedure` / `Actor` / `AbilitySet` / `EventProcessor`）对不同节奏 / 坐标系 / 寻路体系的复用面。

slug: `rts-auto-battle`；M0 起步规模 4v4，2 兵种（melee / ranged）+ basic attack，无新技能 / 无 buff / 无投射物。

## Acceptance 结论

- [x] **AC1 — Headless smoke 跑通到判胜负**
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/rts_smoke.txt 2>&1`
  - 结果: exit 0；末尾 `SMOKE_TEST_RESULT: PASS - left_win`
- [x] **AC2 — 单位走 navmesh 不穿墙**
  - 主断言: 4v4 战斗完整跑到判胜负（291 ticks）；spawn pattern slot 1/2 (y=230/270) 在中央障碍 (y in 200..300) 范围内，必绕路才能接敌
  - 辅助断言: detoured=1（至少 1 个起点被障碍挡的单位 max_y_deviation ≥ 30，证据存于 `RtsNavAgent.max_y_deviation`）
- [x] **AC3 — 兵种行为正确**
  - melee_max_dist=24.00 ≤ MELEE_RANGE_THRESHOLD × 1.05 = 25.20
  - ranged_max_dist=125.44 > MELEE_RANGE_THRESHOLD = 24.00（拉开了距离打）
  - melee=39 attacks, ranged=32 attacks
- [x] **AC4 — LGF 单元测试不退化**
  - 命令: `godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/lgf_unit.txt 2>&1`
  - 结果: 73/73 PASS（每个 M0.x phase 完成后 re-run 全程未退化）
- [~] **AC5 — Hex 例子不退化**（半通过）
  - 命令: `godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn > /tmp/hex_demo.txt 2>&1`
  - **Battle 契约满足**: 跑到 `结果: right_win 总帧数: 173`
  - **退出码 0 未满足**: exit 139（signal 11 shutdown segfault）—— 详见"残余风险"
  - 隔离测试结论: 把 RTS 目录移开后 segfault 仍复现，与 RTS 改动无关；归 LGF submodule 既有 leak 范畴

## 关键 artifact 路径

- **示例根**: `addons/logic-game-framework/example/rts-auto-battle/`
- **主入口**:
  - 编辑器 F6 demo: `frontend/demo_rts_frontend.tscn`（4v4 可视化 + 圆圈 visualizer）
  - Headless smoke (acceptance gate): `tests/battle/smoke_rts_auto_battle.tscn`
- **Phase smoke**:
  - `tests/battle/smoke_skeleton.tscn` — M0.1/M0.2/M0.3 渐进验证（actor / procedure / 4v4 spawn）
  - `tests/battle/smoke_navigation.tscn` — M0.4 单位绕障碍走 (50,250) → (450,250)
  - `tests/battle/smoke_ai.tscn` — M0.5 AI 让 1v1 melee 在 attack_range 内停下
  - `tests/battle/smoke_attack.tscn` — M0.6 1v1 attack/death/胜负
  - `tests/frontend/smoke_frontend_main.tscn` — M0.8 visualizer 节点构建
- **核心源**:
  - `core/rts_world_gameplay_instance.gd` + `core/rts_auto_battle_procedure.gd`
  - `logic/{rts_battle_actor, rts_character_actor}.gd`
  - `logic/{ai/rts_basic_ai, actions/rts_basic_attack_action, components/rts_nav_agent}.gd`
  - `logic/config/{rts_unit_class_config, rts_unit_attribute_set}.gd`
  - `logic/{logger/rts_battle_logger, rts_battle_events}.gd`
  - `frontend/scene/rts_battle_map.gd`（编程式 NavigationPolygon 3×3 网格）
  - `frontend/visualizers/rts_unit_visualizer.gd`

## 真实运行证据

| 命令 | 结果 |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `godot --headless --path . addons/.../tests/battle/smoke_skeleton.tscn` | exit 0 → `SMOKE_TEST_RESULT: PASS - skeleton 4v4 ok, stats ok, cooldown tick ok, _check_battle_end ok` |
| `godot --headless --path . addons/.../tests/battle/smoke_navigation.tscn` | exit 0 → `traveled=416 straight=400 ratio=1.040 max_y_dev=49.99 final=(449.98, 249.99)` |
| `godot --headless --path . addons/.../tests/battle/smoke_ai.tscn` | exit 0 → `final_dist=24.01 atk_range=24.00 left=(237.99, 200.35) right=(262.01, 200.34)` |
| `godot --headless --path . addons/.../tests/battle/smoke_attack.tscn` | exit 0 → `result=left_win ticks=83 attacks=3 deaths=1 melee_max_dist=24.01` |
| `godot --headless --path . addons/.../tests/battle/smoke_rts_auto_battle.tscn` | exit 0 → `result=left_win ticks=291 attacks=71 (melee=39 ranged=32) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.44 detoured=1` |
| `godot --headless --path . addons/.../tests/frontend/smoke_frontend_main.tscn` | exit 0 → `visualizers=8 alive_after_3.0s=8` |
| `godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn` | exit 0 → `总计: 73 \| 通过: 73 \| 失败: 0` |
| `godot --headless --path . addons/.../hex-atb-battle/logic/demo_headless.tscn` | **exit 139** → `右方胜利! 总帧数: 173 结果: right_win` 然后 signal 11 |

## 关键设计决定

1. **不修改 LGF submodule 的 core/ 与 stdlib/**：所有新代码进 `addons/logic-game-framework/example/rts-auto-battle/`，遵循硬约束 1
2. **AbilitySet 用 core `AbilitySet`，不复用 hex 的 `BattleAbilitySet`**：RTS 用 actor.attack_cooldown_remaining 自管 cooldown，不需要 BattleAbilitySet 的 tag-based cooldown 系统，避免不必要的耦合
3. **AttributeSet 直接 extends `BaseGeneratedAttributeSet`**：`_raw.apply_config({...})` 注册 RTS 属性，不走 LGF 代码生成（避免动 `example/attributes/attributes_config.gd` 这类共享文件）
4. **Attack action 不继承 BaseAction**：basic attack 不需要 `ExecutionContext` / `TargetSelector` / `AbilityRef` 这套抽象，改用静态 helper `RtsBasicAttackAction.execute(attacker, target, world)`，仍走 `EventProcessor.process_pre_event` / `process_post_event` 管线给 buff/passive 留 hook（M0 PreEvent handler 全空，M1 接入）
5. **NavigationAgent2D 是 Node**：因为 NavAgent 必须在场景树才能工作，单独抽出 `RtsNavAgent extends Node2D` 作为 actor 在场景树的 avatar。actor.id → RtsNavAgent / RtsBasicAI / RtsUnitVisualizer 由 demo / smoke 自己维护字典
6. **NavigationPolygon 编程式构造**：3×3 网格 8 polygon 显式拼出可走区域。第一版用 4 大条带因相邻 polygon 端点不重合（NavServer2D 要求精确匹配）导致路径在障碍前 198 px 处断开 —— 这是 RTS 阶段最大的踩坑，已写入 Current-State.md 第 6 条约束
7. **Spawn pattern 4-slot 用 y={80, 230, 270, 420}**：slot 1/2 落在中央障碍 y 范围内，强制至少 2 个单位接敌时绕路 —— 让 AC2 真正有判定意义（早期均分 spawn 时所有单位都直线接敌，AC2 检测不到任何绕路）

## 残余风险 / 已知 follow-up

- **AC5 hex demo shutdown segfault**：headless 退出时 signal 11 / exit 139。Battle 契约不退化（仍能跑到 winner），与 RTS 改动无关，归 LGF submodule 既有 leak 范畴。要排根需要进 LGF core 排 ObjectDB 在 ShutdownScene 的 destructor 顺序，违反硬约束 1（不修改 LGF submodule core/stdlib）。**等用户授权后单独立项处理**
- **Frontend demo 无肉眼 GUI 验证**：headless smoke 验证了 visualizer Node 树构建无误，但没人在编辑器里 F6 看过 8 个圆圈互相走 / 攻击。**待用户确认**
- **没有 commit / push / PR**：按硬约束 5，自治协议不主动 commit；用户可在审完后用 `/commit` 或 `commit-commands:commit` skill 手动提交
- **M1 候选**：扩到 8v8、加骑兵兵种、加投射物 entity（ranged 当前是即时伤害，无视觉弹道）、Avoid behavior（M0 关闭了 NavAgent 的 avoidance）、PreEvent / PostEvent handler 实例化（buff / passive 接入入口）

## Commits

无 —— 自治协议不主动 commit，所有改动均为 untracked / unstaged，待用户处理。worktree 状态（封板时 `git status -sb`）：
- 主仓: `M AGENTS.md`、`M CLAUDE.md`、`m addons`、`?? .feature-dev/`
- submodule (`addons/logic-game-framework`): `M CHANGELOG.md`、`?? example/README.md`、`?? example/rts-auto-battle/`

> 注: 之前的 `m addons` (lowercase m) 表示 submodule 内有 untracked / unstaged 内容。要 commit 的话需要先在 submodule 内 commit `M CHANGELOG.md` + `?? example/...`，然后回主仓 bump submodule pointer。
