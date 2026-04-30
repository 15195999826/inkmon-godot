# Progress — rts-auto-battle (M0)

**Status**: planned / acceptance criteria locked / 等待用户确认后启动 M0.1

## 验收准则 checklist

- [x] **AC1 — Headless smoke**：`smoke_rts_auto_battle.tscn` 输出 `SMOKE_TEST_RESULT: PASS - <winner>` 退出码 0
  - 命令：`godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/rts_smoke.txt 2>&1`
  - Evidence: `/tmp/rts_smoke.txt` 末尾 `SMOKE_TEST_RESULT: PASS - left_win`，exit 0（M0.7）
- [x] **AC2 — 不穿墙绕路**：障碍物挡路布局下战斗完整打完
  - Evidence: 4v4 战斗完成 + slot 1/2 起点在 y=230/270 (障碍 y 范围内)，detoured=1 表明 max_y_deviation ≥ 30 绕过了 navmesh（M0.7）
- [x] **AC3 — 兵种行为正确**：melee 距离 ≤ melee_range；ranged 至少 1 次 attack 距离 > melee_range
  - Evidence: melee_max_dist=24.00 (≤24×1.05)；ranged_max_dist=125.44 > 24；melee=39 attacks ranged=32 attacks（M0.7）
- [x] **AC4 — LGF 单元测试 73/73 PASS**
  - 命令：`godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/lgf_unit.txt 2>&1`
  - Baseline: 73/73 PASS（截至 commit `4a9d72f`）
  - Evidence: 每个 M0.x 完成后 re-run，全程 73/73 PASS
- [~] **AC5 — Hex 例子不退化**：`hex-atb-battle/logic/demo_headless.tscn` 跑到 `left_win|right_win`
  - 命令：`godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn > /tmp/hex_demo.txt 2>&1`
  - Baseline: 122 帧 right_win，exit 0
  - Evidence: M0.7 复跑战斗结果 `右方胜利! 总帧数: 190 结果: right_win`，但退出码 **139**（signal 11 shutdown segfault）
  - 状态: **半通过** —— battle 契约不退化（仍能跑到 winner），但严格意义上 AC5 要求退出码 0 未满足。详见"残余风险"段，与 RTS 改动无关，归 LGF submodule 既有 leak 范畴

## Phase 进度（详见 task-plan/README.md）

- [x] M0.1 目录骨架
  - 命令: `godot --headless --path . --import` → exit 0；`godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_skeleton.tscn`
  - Evidence: `/tmp/import.txt`（exit 0），`/tmp/rts_skeleton.txt` 末尾含 `SMOKE_TEST_RESULT: PASS - skeleton loaded`
  - AC4 re-run: 73/73 PASS（`/tmp/lgf_unit.txt`）
  - Artifact: `addons/logic-game-framework/example/rts-auto-battle/{core,logic,frontend,tests}/` + 4 README + `tests/battle/smoke_skeleton.{gd,tscn}`
- [x] M0.2 WorldGI + Procedure
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_skeleton.tscn`
  - Evidence: `/tmp/rts_skeleton.txt` 末尾 `SMOKE_TEST_RESULT: PASS - skeleton loaded`，验证 1v1 stub actor + procedure tick 1 次正常 + 杀死 left 后 `_check_battle_end → right_win`
  - AC4 re-run: 73/73 PASS（`/tmp/lgf_unit.txt`）
  - Artifact: `core/rts_world_gameplay_instance.gd`、`core/rts_auto_battle_procedure.gd`、`logic/rts_battle_actor.gd`（stub）；smoke_skeleton 升级为 1v1 procedure 验证
- [x] M0.3 Actor + Stats
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_skeleton.tscn`
  - Evidence: `/tmp/rts_skeleton.txt` 末尾 `SMOKE_TEST_RESULT: PASS - skeleton 4v4 ok, stats ok, cooldown tick ok, _check_battle_end ok`，验证 4v4 (各 2 melee + 2 ranged) spawn / attribute_set 数值 / cooldown 推进 / 杀完左方判 right_win
  - AC4 re-run: 73/73 PASS（`/tmp/lgf_unit.txt`）
  - AC5 re-run: hex demo battle 完成（`左方胜利! 总帧数: 118 结果: left_win`），但 exit 139（signal 11 shutdown segfault）。**残余风险见下**
  - Artifact: `logic/config/rts_unit_class_config.gd`、`logic/config/rts_unit_attribute_set.gd`、`logic/rts_character_actor.gd`
- [x] M0.4 Navigation 接入
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_navigation.tscn`
  - Evidence: `/tmp/rts_nav.txt` 末尾 `SMOKE_TEST_RESULT: PASS - nav 50,250 → 450,250 around obstacle`，`traveled=416 straight=400 ratio=1.040 max_y_dev=49.99 final=(449.98, 249.99)` —— 单位从 (50,250) 抵达 (450,250) ± 10 px，期间 y 偏离起点最多 49.99 px (绕过中央 (200..300, 200..300) 障碍证据)
  - AC4 re-run: 73/73 PASS（`/tmp/lgf_unit.txt`）
  - Artifact: `logic/components/rts_nav_agent.gd`、`frontend/scene/rts_battle_map.gd`、`tests/battle/smoke_navigation.{gd,tscn}`
  - 设计 note：navmesh 用 3×3 = 8 polygon 显式拼出可走区域，跳过中央障碍格。第一版用 4 大条带因相邻 polygon 端点不重合（NavServer 要求精确匹配）导致路径在障碍前 198 px 处断开
- [x] M0.5 AI 行为循环
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_ai.tscn`
  - Evidence: `/tmp/rts_ai.txt` 末尾 `SMOKE_TEST_RESULT: PASS - 1v1 melee engage at attack_range`，`final_dist=24.01 atk_range=24.00 left=(237.99, 200.35) right=(262.01, 200.34)` —— 双方各自走到中央障碍上方相遇，停在 attack_range 边界上不再前进，连续 5 帧 in_range
  - AC4 re-run: 73/73 PASS
  - AC5 re-run: hex demo 完成 `结果: right_win 总帧数: 173`，segfault 残余风险持续（exit 139, 见上文），battle 契约不退化
  - Artifact: `logic/ai/rts_basic_ai.gd`、`tests/battle/smoke_ai.{gd,tscn}`
- [x] M0.6 Attack action / death / 胜负判定
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_attack.tscn`
  - Evidence: `/tmp/rts_attack.txt` 末尾 `SMOKE_TEST_RESULT: PASS - 1v1 melee left wins by killing right`，`result=left_win ticks=83 attacks=3 deaths=1 melee_max_dist=24.01`
  - AC4 re-run: 73/73 PASS
  - Artifact: `logic/rts_battle_events.gd`、`logic/actions/rts_basic_attack_action.gd`、`logic/logger/rts_battle_logger.gd`、`tests/battle/smoke_attack.{gd,tscn}`
  - 设计 note：attack action 不继承 BaseAction —— BaseAction 需要 ExecutionContext / TargetSelector / AbilityRef 这套，对 M0 basic attack 太重；改用静态 helper `RtsBasicAttackAction.execute(attacker, target, world)`，仍走 EventProcessor pre/post 管线（pre_damage 留 hook 给 buff/passive，M0 PreEvent handler 全空）
- [x] M0.7 Headless smoke + 兵种行为断言（acceptance gate AC1/AC2/AC3）
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn`
  - Evidence: `/tmp/rts_smoke.txt` 末尾 `SMOKE_TEST_RESULT: PASS - left_win`，明细 `result=left_win ticks=291 attacks=71 (melee=39 ranged=32) deaths=6 melee_max_dist=24.00 ranged_max_dist=125.44 detoured=1`
  - **AC1 ✓**：smoke 输出 `SMOKE_TEST_RESULT: PASS - left_win`，退出码 0
  - **AC2 ✓**：spawn 时 slot 1/2 都在 y=230/270 (障碍 y 范围 200..300 内)；detoured=1 表明至少 1 个起点被障碍挡住的单位的 max_y_deviation ≥ 30，绕过了 navmesh
  - **AC3 ✓**：melee_max_dist=24.00 ≤ MELEE_RANGE_THRESHOLD×1.05=25.2；ranged_max_dist=125.44 > MELEE_RANGE_THRESHOLD=24（拉开了距离打）
  - AC4 re-run: 73/73 PASS
  - AC5 re-run: hex demo 完成（190 ticks right_win），仍 exit 139，残余风险持续
  - Artifact: `tests/battle/smoke_rts_auto_battle.{gd,tscn}`；map spawn pattern 修改：4-slot 模式 y={80, 230, 270, 420} 强制中央两 slot 接敌绕路
- [x] M0.8 Frontend stub visualizer
  - 命令: `godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn`
  - Evidence: `/tmp/rts_frontend.txt` 末尾 `SMOKE_TEST_RESULT: PASS - frontend stub renders 4v4 without script error`，`visualizers=8 alive_after_3.0s=8`
  - AC4 re-run: 73/73 PASS
  - Artifact: `frontend/visualizers/rts_unit_visualizer.gd`、`frontend/demo_rts_frontend.{gd,tscn}`、`tests/frontend/smoke_frontend_main.{gd,tscn}`
  - 编辑器 F6 验证 (用户): 待用户在 GUI Godot 里打开 `demo_rts_frontend.tscn` 肉眼确认 8 个圆圈互相走 / 攻击 / 死掉消失（headless 只能验证 Node 树构建无误，看不见画面）
- [x] M0.9 文档同步
  - 主仓 `CLAUDE.md` "测试 / 几个入口" 表新增 RTS 主 smoke + RTS 前端 smoke 两行（保留原 hex 三行）
  - `addons/logic-game-framework/example/README.md` 新建（之前 example/ 没有 index），列出 hex / rts 两示例对比表
  - `addons/logic-game-framework/CHANGELOG.md` 加 `[Unreleased] — 2026-04-30 RTS 自动战斗示例` 段，按 LGF Keep-a-Changelog 约定写 Added / Changed / Notes
  - 收口 AC1-AC5 final sweep（详见上方 checklist）：4/5 PASS，AC5 半通过

## 关键 artifact 路径

| 类型 | 路径 |
|---|---|
| RTS 示例根 | `addons/logic-game-framework/example/rts-auto-battle/` |
| Headless smoke | `…/tests/battle/smoke_rts_auto_battle.tscn` |
| Frontend demo（M0.8 stub）| `…/frontend/demo_rts_frontend.tscn` |
| 战斗 log 输出 | `user://logs/rts_*.log`（参照 hex 例子约定）|
| 战斗 replay | `user://replays/rts_*.json`（参照 hex 例子）|

## 残余风险 / 已知坑

- **AC5 hex demo segfault on shutdown**（M0.3 发现）：
  - 现象：`godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn` 战斗能正常打到 `结果: left_win` / `right_win`，但 `get_tree().quit()` 后 Godot 进程 signal 11，exit 139
  - 隔离测试结论：与 RTS 代码无关（RTS 文件只是 class_name 注册，hex demo 不引用任何 Rts* 类型）
  - 与 Autonomous-Work-Protocol.md 的"既有 leak 不影响退出码 0"描述不一致 —— 退出码确实被影响
  - 可能根因：LGF object 在 headless ShutdownScene 时 destructor 触发 use-after-free。要排根需要进 LGF submodule（违反硬约束 1）
  - 当前处置：M0 期间记为残余风险，battle 跑完判胜负的契约部分不退化即可；AC5 在收口时如果 user 坚持退出码 0，需要重启 LGF submodule 修复授权
- **Submodule 修改风险**：M0 设计上不动 `addons/logic-game-framework/core/` 与 `…/stdlib/`。若实现中发现 LGF 基类暴露不够（例：BattleProcedure tick 接口与连续时间不兼容），停下来跟用户确认是改 submodule 还是绕路。
- **NavigationServer2D 在 headless 下行为**：Godot 4.x navigation 在 headless 下需要至少跑一帧 sync map，smoke 入口要 `await get_tree().physics_frame` 一次再开始 tick；否则 path query 返回空。M0.4 落地时验证。
- **既有 leak warning**：退出时 `ObjectDB instances leaked` 是 LGF 现存 leak，不影响退出码 0；不要被它误导成 RTS 引入的新 leak。
- **UGridMap autoload 不接入**：`project.godot` 的 UGridMap 是 hex 专用，RTS 例子完全不调用它，但 autoload 仍在场景生命周期里——确认 autoload 默认 idle 不会干扰 RTS smoke。

## 决定记录（plan 阶段做出的默认）

- M0 起步规模 4v4（不是 8v8）；跑稳后再考虑扩
- 兵种 2 种（melee + ranged），骑兵推迟
- 不穿墙断言用「能完整打完」间接证明 + 可选路径长度比；不做几何级 trajectory 断言
- 表演层 stub 是 M0.8 的最小可识别 visualizer，不做美化
- 不实例化新技能 / buff（basic attack only）
