# Current State — 2026-04-30（RTS 自动战斗 example 落地后）

inkmon-godot baseline 事实快照。开新 feature 前对齐用。

## 工程结构（已落地）

- 主仓 `C:\GodotPorjects\inkmon-godot`，Godot 4.6 项目
- `addons/` 是单一 git submodule（→ `godot-addons.git`），含三个 addon：
  - `logic-game-framework`（核心 LGF：Actor/AbilitySet/Action/Event/Buff/Timeline/Replay）
  - `lomolib`（工具库）
  - `ultra-grid-map`（hex 网格，**仅 hex-atb-battle 在用，RTS 例子不依赖**）
- 主仓 entry：`scenes/Simulation.tscn` + `scripts/SimulationManager.gd`（Web/headless 桥接）

## 现有 LGF 示例（2 个）

### hex-atb-battle（既有；hex grid + ATB 累积）

```
hex-atb-battle/
├── core/        WorldGI/Procedure 基类（hex 特化）
├── logic/       游戏规则（CharacterActor / AI / 技能 / config）
├── frontend/    表演层（3D + 投射物 + battle_animator）
├── skill-preview/  hex 子模式（技能预览沙盒）
└── tests/{battle,frontend,skill-preview}/  smoke 入口
```

### rts-auto-battle（**2026-04-30 新增**；连续 Vector2 + navmesh + 实时 cooldown）

```
rts-auto-battle/
├── core/        RtsWorldGI / RtsAutoBattleProcedure（连续 tick + cooldown 推进 + _check_battle_end）
├── logic/       Actor / AI / actions / config / logger / events
│   ├── rts_battle_actor.gd / rts_character_actor.gd
│   ├── ai/rts_basic_ai.gd
│   ├── actions/rts_basic_attack_action.gd
│   ├── components/rts_nav_agent.gd
│   ├── config/{rts_unit_class_config, rts_unit_attribute_set}.gd
│   ├── logger/rts_battle_logger.gd
│   └── rts_battle_events.gd
├── frontend/    最简 stub（圆形 + 队伍色 + hp Label，无动画 / 特效）
│   ├── scene/rts_battle_map.gd（编程式 NavigationPolygon，3×3 网格 8 polygon）
│   ├── visualizers/rts_unit_visualizer.gd
│   └── demo_rts_frontend.{gd,tscn}
└── tests/
    ├── battle/{smoke_skeleton, smoke_navigation, smoke_ai, smoke_attack, smoke_rts_auto_battle}.{gd,tscn}
    └── frontend/smoke_frontend_main.{gd,tscn}
```

两个示例都遵循三层依赖方向 `core ← logic ← frontend`。

| 维度 | hex-atb-battle | rts-auto-battle |
|---|---|---|
| 坐标系 | 离散 HexCoord（UGridMap） | 连续 Vector2（500×500 px） |
| 节奏 | ATB 累积 → 满后放技能 | 实时 `attack_cooldown` 倒计时 |
| 移动 | UGridMap 单格 | NavigationServer2D + NavigationAgent2D |
| 兵种 | 6 职业 + 完整技能池 | 2 兵种（melee/ranged）+ basic attack only |
| 单位规模 | 6v6（demo）| 4v4（M0 起步） |

## 测试基线（必须不退化）

| 入口 | 用途 | 当前状态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn` | hex ATB 战斗 headless smoke | battle 完成（约 170-190 帧到 left_win/right_win），但 **shutdown 时 signal 11 segfault**（exit 139）—— 既有 LGF leak，与 RTS 改动无关 |
| `addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn` | skill 数值/tag/effect 契约 | （未单独跑过，LGF 73/73 间接覆盖）|
| `addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn` | hex 前端 demo 冒烟（~80% 回归面）| 同上 |
| `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn` | **新增**：RTS 4v4 acceptance smoke | 战斗到 left_win/right_win，断言兵种行为 + 绕路证据，PASS（exit 0）|
| `addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn` | **新增**：RTS 前端 visualizer 冒烟 | 8 个 visualizer 节点构建成功，PASS |

## Git 状态（封板时 worktree 状态，未 commit）

- 主仓 `master` ahead origin/master 2 commits（同上一次 baseline）；新增 worktree 改动：
  - `M CLAUDE.md`（新增 RTS smoke 入口表行）
  - `m addons`（submodule 内有未 commit 改动）
  - `?? .feature-dev/`（自治协议工作产物）
- Submodule `addons/` ahead origin/master 1 commit；新增 worktree 改动：
  - `M CHANGELOG.md`（新增 2026-04-30 RTS 段）
  - `?? example/README.md`（新建 example index）
  - `?? example/rts-auto-battle/`（整个 RTS 示例）
- 所有改动均为 untracked / unstaged；未 commit / push（按硬约束，不主动 commit）

## 关键约束（开发新 example 时必须遵守）

1. **不修改 LGF submodule 的 core/ 与 stdlib/**：所有新代码进 `addons/logic-game-framework/example/<new-example>/`；本轮 RTS 新增已遵循
2. **三层架构**：新例子按 `core/logic/frontend/tests/` 拆分
3. **Headless 测试入口规范**：smoke 写 `print("SMOKE_TEST_RESULT: PASS|FAIL - <reason>")` + 退出码 0
4. **跑 headless 不要 pipe**：`godot --headless --path . <scene>.tscn > /tmp/out.txt 2>&1` 再读文件（pipe 会假卡死）
5. **不要 `godot --script <file>.gd`**：`--script` 模式不触发 autoload，必须用 `.tscn` 入口
6. **NavigationPolygon 编程式构造的端点匹配**（RTS 踩坑）：相邻 polygon 共享边的端点必须**精确对齐**，NavigationServer2D 才会把它们连成可达图；用顶点网格 + 索引数组比 `add_outline` 更安全
