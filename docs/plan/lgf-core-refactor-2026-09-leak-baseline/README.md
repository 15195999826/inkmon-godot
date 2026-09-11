# 泄漏直方图基线（LGF core 重构 2026-09，P1 开工前烤制）

四个代表场景各跑一次 `godot --headless --verbose`，按 `Leaked instance:` 行统计（脚本见计划 §2）。

| 文件 | 场景 |
|---|---|
| `core.hist.txt` | `addons/logic-game-framework/tests/run_tests.tscn` |
| `hex.hist.txt` | `example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn` |
| `dota2.hist.txt` | `example/dota2-auto-battle/tests/battle/smoke_lane_wave_engage.tscn`（P3 起零泄漏，文件为空） |
| `inkmon.hist.txt` | `inkmon/tests/smoke_m1_battle.tscn`（零泄漏，文件为空） |

格式约束：Godot 4.6 的 `Leaked instance:` 行只打原生类名（`RefCounted` / `Node` / `GDScript` / `WeakRef`），
不带脚本类名，所以直方图只能按原生类计数；LGF 类是否释放由
`tests/core/world/refcount_release_test.gd` 的 weakref 断言精确守。
每阶段验收：重跑同一脚本后 `diff` 本目录，计数只许持平或下降。

**下降后要棘轮**：某阶段把某场景的泄漏真降下来了，就把该场景的直方图更新进本目录——
否则后续阶段拿旧的高水位当基线，从新水位回涨的回归会被当成「仍低于基线」放行。

- 2026-09-10 / P2：`dota2.hist.txt` 由 `590 RefCounted / 66 GDScript / 15 WeakRef / 1 GDScriptNativeClass`
  降到 `170 / 61 / 15 / 1`——`Dota2AutoBattleProcedure` 关掉了它本就播不了的战斗录像
  （`BattleActor` 的默认录像订阅一旦生效，死兵走 `remove_actor` 而 recorder 无对应注销，
  订阅会一路留到战斗结束）。其余三份仍与 P1 基线逐字节一致。
- 2026-09-11 / P3：`dota2.hist.txt` 先由 `WeakRef` 15 降到 9（`AbilityExecutionInstance` 删掉了为取消路径兜底的
  provider `WeakRef` 字段），复审后**清零**（文件为空）。那批留到退出的对象并不是「非 LGF 泄漏」：hex / dota2 /
  inkmon 的 procedure 子类用强引用字段 `_world_instance` 回指 world，与 `WorldGameplayInstance._active_battle`
  成环；dota2 smoke 直接驱动 `procedure.finish()`、不走 `world.tick()` 收尾，于是 world、procedure 与整场
  actor / AbilitySet / Ability / execution 一起留到退出（残留的 9 个 WeakRef = 8 个单位的 ability 回指 + 1 个
  `BattleProcedure._world`）。procedure 子类改为经基类 WeakRef 回指 world（第三轮起是协变覆盖 `_get_world()`）后环消失（见计划 §6 ㉒ ㉓）。
  其余三份仍与基线逐字节一致。
