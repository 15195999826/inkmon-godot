# 泄漏直方图基线（LGF core 重构 2026-09，P1 开工前烤制）

四个代表场景各跑一次 `godot --headless --verbose`，按 `Leaked instance:` 行统计（脚本见计划 §2）。

| 文件 | 场景 |
|---|---|
| `core.hist.txt` | `addons/logic-game-framework/tests/run_tests.tscn` |
| `hex.hist.txt` | `example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn` |
| `dota2.hist.txt` | `example/dota2-auto-battle/tests/battle/smoke_lane_wave_engage.tscn` |
| `inkmon.hist.txt` | `inkmon/tests/smoke_m1_battle.tscn`（零泄漏，文件为空） |

格式约束：Godot 4.6 的 `Leaked instance:` 行只打原生类名（`RefCounted` / `Node` / `GDScript` / `WeakRef`），
不带脚本类名，所以直方图只能按原生类计数；LGF 类是否释放由
`tests/core/world/refcount_release_test.gd` 的 weakref 断言精确守。
每阶段验收：重跑同一脚本后 `diff` 本目录，计数只许持平或下降。
