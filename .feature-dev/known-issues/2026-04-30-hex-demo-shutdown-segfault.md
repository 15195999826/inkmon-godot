# Hex demo headless shutdown segfault (signal 11)

**发现日期**: 2026-04-30（在 RTS auto-battle feature 的 AC5 regression check 中暴露）
**状态**: 未修复，记录待后续处理
**严重度**: 中等 —— battle 契约不退化，但 headless 退出码 139 影响 CI / acceptance 检查

## 现象

```bash
godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn
```

战斗能正常打到判胜负（约 150-190 帧 → `结果: left_win` 或 `right_win`），紧接着 ItemSystem autoload 清理日志打出来，**然后 signal 11 段错误**，进程 exit code 139。

## 报错原文（关键片段）

```
========== Hex Demo Battle 结束 ==========
总帧数: 149
结果: right_win
========== 战斗运行完成 ==========
[INFO][ItemSystem] 物品系统开始清理
[INFO][ItemSystem] 物品系统已清理

CrashHandlerException: Program crashed with signal 11
Engine version: Godot Engine v4.6.stable.official (89cea143987d564363e15d207438530651d943ac)
Dumping the backtrace. ...
[1..54] error(-1): no debug info in PE/COFF executable
```

- **没有任何 GDScript SCRIPT ERROR**
- **没有 ObjectDB instances leaked / resources still in use 等 GDScript 层 warning**
- **没有 `GameWorld shutdown` 日志**（关键对照点 —— RTS smoke 因为显式 `GameWorld.destroy()` 会打这条日志）
- 纯 C++ 层 segfault；release build 无调试符号，无法拿到 backtrace 行号

## 直接定位的代码事实

`addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.gd` 的 headless 退出路径：

```gdscript
func _run_battle_sync() -> void:
    print("\n========== 同步运行战斗 ==========\n")
    var dt := 100.0
    for i in range(HexBattleProcedure.MAX_TICKS):
        GameWorld.tick_all(dt)
        if not GameWorld.has_running_instances():
            break
    print("\n========== 战斗运行完成 ==========")
    get_tree().quit()      # ← 没有 GameWorld.destroy()
```

对照 RTS smoke 的退出路径（`smoke_rts_auto_battle.gd` 等）：

```gdscript
_procedure.finish()
_world.end()
GameWorld.destroy()        # ← 显式销毁，让 _instances 字典清空
get_tree().quit(0)
```

RTS smoke 跑完日志里能看到 `[INFO][GameWorld] GameWorld shutdown`；hex demo 跑完看不到 —— **GameWorld 在 quit 时仍持有 `_active_battle = HexDemoWorldGameplayInstance`**。

## 推断的根因（待 debug build 验证）

Godot autoload 销毁顺序（`project.godot` 的 `[autoload]` 反序）：
```
UGridMap → ItemSystem → WaitGroupManager → TimelineRegistry → GameWorld → IdGenerator → Log
```

当 `get_tree().quit()` 被调时：

1. ItemSystem 清理：日志打出（最后一行可见日志）
2. WaitGroupManager / TimelineRegistry 销毁
3. **TimelineRegistry 销毁时**，GameWorld 还活着，仍持有 HexDemoWorldGameplayInstance → HexBattleProcedure → actor → ability → ability 引用 timeline data
4. GameWorld 销毁 → GDScript 字段析构 → ability 试图访问已销毁的 TimelineRegistry → **C++ 层 use-after-free**

是**推断**，不是确证。要确证需要：
- Godot debug build 跑出 backtrace 行号
- 或在 hex demo `_run_battle_sync()` 末尾 `get_tree().quit()` 之前加一行 `GameWorld.destroy()`，看 segfault 是否消失（消失 = 假设成立）

## 影响范围

- **AC5 in rts-auto-battle 系统功能验收 (2026-04-30)**: 半通过 —— battle 契约（跑到 `<winner>`）满足，退出码 0 不满足
- **任何调 hex demo headless smoke 的 CI / 自动化**：返回 exit 139 而非 0，被当作失败
- **RTS smoke / RTS frontend smoke / LGF unit tests / RTS phase smoke**: **不受影响**（exit 0 干净退出）

## 不修的成本 / 修的成本

不修:
- AC5 永远是半通过状态，每次 hex demo 跑都报 exit 139
- 误导新进来的开发者（CLAUDE.md 现写"既有 leak warning 不影响退出码 0"，但实际是退出码 139）

修（候选方案）:
1. **改 hex demo（最小改动）**: `_run_battle_sync` 末尾加 `GameWorld.destroy()` 在 `get_tree().quit()` 之前。属于 `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.gd`，是 LGF submodule 内 example 子目录。**需要用户授权解除"不修改 LGF submodule"硬约束**
2. **改 LGF core（彻底）**: `GameWorld._notification(NOTIFICATION_PREDELETE)` / `_exit_tree()` 自动调 `shutdown()`。让 autoload 反序销毁链更鲁棒，所有 example 受益。**需要用户授权进 LGF core**
3. **绕路（不改任何 LGF 代码）**: 写一个 wrapper smoke 入口，加载 `hex_demo_world_gameplay_instance.gd` 并跑，末尾自己调 `GameWorld.destroy()`。这相当于复制一份 demo headless 但不改原文件

## CLAUDE.md / AGENTS.md 描述需要修订

主仓 `CLAUDE.md` 与 `AGENTS.md` 都有这段：

> 退出时 `ObjectDB instances leaked` / `resources still in use` 是既有 leak，**不影响退出码**，修要去 LGF addon 内部排。

实际情况：**会影响退出码（139）**。等问题修复或定性后，把这段改成符合现实的描述。

## Follow-up 检查清单

- [ ] 在 Godot debug build 下复现，拿 backtrace 行号确证根因
- [ ] 选择修复方案（1 / 2 / 3 中之一），与用户对齐
- [ ] 修复后 RTS feature 的 AC5 自动转为完全通过
- [ ] 修订 CLAUDE.md / AGENTS.md 关于退出码的描述
- [ ] 检查其他 LGF example 的 headless 入口（如 `smoke_skill_scenarios.tscn` / `smoke_frontend_main.tscn`）是否有同样的 GameWorld 未 destroy 问题

## 引用

- 原始 evidence 文件: `/tmp/hex_crash.txt`、`/tmp/hex_demo.txt`（feature 进行中多次复跑均复现）
- RTS feature archive: `.feature-dev/archive/2026-04-30-rts-auto-battle/Summary.md`
- 相关 source: `addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.gd`、`addons/logic-game-framework/core/world/game_world.gd`
