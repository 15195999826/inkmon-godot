extends Node
## 战斗行为金样 (golden replay): 固定默认阵容打一场标准 4v4, 对事件流做指纹回归断言 ——
## 在数值层 (smoke_battle_math) 之外把 "谁在何时对谁做了什么" 的整个行为面钉住。
## 一场标准战斗即覆盖当前全部 manifest 项: ATB 调度 / AI 三策略 / 技能选择与目标 /
## 伤害·治疗·buff·死亡事件序 / 死亡清理。
##
## 指纹变红的两种情况:
##   1. 你**有意**改了战斗行为 (技能数值/AI/调度/新技能) → 预期内: 核对下方 GOLDEN_ACTUAL
##      日志行的摘要合理后, 用它打印的新值回填 GOLDEN_* 常量。
##   2. 你**没碰**战斗它却红了 → 抓到回归: 别处的改动漏了副作用进战斗行为。
##
## meta (含墙钟 recorded_at) 与 configs 刻意不进指纹 (非确定 / 非行为)。
## 本 smoke 必须是进程内第一个建 actor 的场景 (IdGenerator 计数进事件流, 独立 scene 天然满足)。


## 金样基线 (2026-07-02 录制; 行为有意变更时按 GOLDEN_ACTUAL 日志回填)。
const GOLDEN_HASH := 3476249305
const GOLDEN_RESULT := "left_win"
const GOLDEN_TICKS := 159
const GOLDEN_EVENT_FRAMES := 78


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - battle behavior fingerprint matches the golden replay")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()

	var battle := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	if battle == null:
		return "failed to create InkMonWorldGI"

	battle.start_battle_procedure({})
	GameWorld.tick_all(BattleProcedure.DEFAULT_TICK_INTERVAL)
	if battle.has_active_battle():
		return "battle did not finish in one world tick"

	var replay := battle.get_replay_data()
	if replay.is_empty():
		return "no replay data recorded"

	# 只取行为面: initial_actors + timeline (meta 含墙钟时间戳, 排除)。
	var behavior := {
		"initial_actors": replay.get("initial_actors", []),
		"timeline": replay.get("timeline", []),
	}
	var actual_hash := JSON.stringify(behavior).hash()
	var result := battle.get_result()
	var ticks := battle.tick_count
	var event_frames := (replay.get("timeline", []) as Array).size()
	print("GOLDEN_ACTUAL: hash=%d result=%s ticks=%d event_frames=%d" % [
		actual_hash, result, ticks, event_frames])

	GameWorld.shutdown()

	if GOLDEN_HASH == 0:
		return "golden baseline not recorded yet — fill GOLDEN_* consts from the GOLDEN_ACTUAL line above"
	if actual_hash != GOLDEN_HASH:
		return ("behavior fingerprint changed: hash %d != golden %d (result=%s ticks=%d frames=%d)" +
			" — 有意改动则按 GOLDEN_ACTUAL 更新常量, 否则是行为回归") % [
			actual_hash, GOLDEN_HASH, result, ticks, event_frames]
	if result != GOLDEN_RESULT:
		return "result drifted: %s != golden %s" % [result, GOLDEN_RESULT]
	if ticks != GOLDEN_TICKS or event_frames != GOLDEN_EVENT_FRAMES:
		return "summary drifted: ticks=%d/%d frames=%d/%d" % [
			ticks, GOLDEN_TICKS, event_frames, GOLDEN_EVENT_FRAMES]
	return ""
