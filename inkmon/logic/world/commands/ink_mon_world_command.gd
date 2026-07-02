class_name InkMonWorldCommand
extends RefCounted
## 主世界写路径的对象化命令基类(CQRS Command 通道)。
##
## UI/Host `submit(cmd)` 入队 → tick 的 CommandDrain System 抽干 → `drain_commands` 多态 `cmd.apply(gi)`。
## 方案 A —— "世界一切 mutation 只在 tick 一处发生"(单一变更时间线):子类 apply 内做世界态变更;
## 需回流给表演的结果(buy/npc-action 的 message / flow intent)经 `gi.emit_command_applied(result)` 上行,
## **不走同步返回值**。move 类无 message,回流走 `actor_position_changed`。
## ⚠ 此 Command ≠ battle 层 LGF `Action` / `ABILITY_ACTIVATE_EVENT`,两层独立。


## tick drain 时由 drain_commands 调用;子类必须覆写做实际世界态变更。
## fail-fast: 到达基类 = 子类漏覆写 (原基类 no-op 会静默吞掉整条 command)。
func apply(_gi: InkMonWorldGI) -> void:
	Log.assert_crash(false, "InkMonWorldCommand", "apply() must be overridden by the concrete command")
