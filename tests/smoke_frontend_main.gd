## Smoke test: headless 模式下加载 frontend main.tscn，触发 Start Battle，播放到结束
##
## 目标：验证 frontend 完整链路（配置 UI → core 战斗 → replay 生成 → director 播放 → scheduler 排空）
##      不验证视觉正确性，只验证 "逻辑 + 表演调度" 跑通不崩。
##
## 覆盖的回归面：
##   - main.tscn 能在 headless 下实例化（无 Viewport 也不炸）
##   - _on_start_battle_button_pressed() 同步产出合法 replay
##   - Director tick + ActionScheduler 能把所有动作播到排空
##   - Unit view / Replay scene 生命周期无异常
##
## 不覆盖：像素渲染正确性、粒子视觉、相机跟随、音效
##
## 运行方式:
##   godot --headless --path . res://tests/smoke_frontend_main.tscn
##
## 退出码: 0 PASS / 1 FAIL, 输出标记: "SMOKE_TEST_RESULT: PASS|FAIL - <reason>"
extends Node


const MAIN_SCENE := "res://addons/logic-game-framework/example/hex-atb-battle-frontend/main.tscn"
## 超时时间（秒）。100x 加速下，典型一场 200 帧 battle 约 0.3s 真实时间。
const TIMEOUT_SEC := 30.0
## 播放加速倍率，压缩真实耗时。过高会让单帧推进的逻辑时间 > 动画持续时间导致视觉异常，
## 但 smoke test 不验证视觉，所以激进加速是安全的。
const PLAYBACK_SPEED := 100.0


var _main_scene: Node
var _replay_scene: FrontendBattleReplayScene
var _director: FrontendBattleDirector
var _elapsed: float = 0.0
var _finished: bool = false


func _ready() -> void:
	print("=== Smoke Test: Frontend Main Scene Flow ===")
	print("Scene: %s" % MAIN_SCENE)
	print("Timeout: %.0fs, Speed: %.0fx" % [TIMEOUT_SEC, PLAYBACK_SPEED])
	print("")

	# 静音 Log，避免淹没测试输出（push_error 仍会由 Godot 自己走 stderr）
	Log.set_level(Log.LogLevel.WARNING)

	# Step 1: 加载并实例化 main.tscn
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		_fail("Failed to load " + MAIN_SCENE)
		return
	_main_scene = packed.instantiate()
	if _main_scene == null:
		_fail("Failed to instantiate main scene")
		return
	add_child(_main_scene)

	# 让 main._ready 和 replay_scene._ready 跑完
	await get_tree().process_frame

	# Step 2: 定位 Director
	_replay_scene = _main_scene.get_node_or_null("BattleReplayScene") as FrontendBattleReplayScene
	if _replay_scene == null:
		_fail("BattleReplayScene node not found under Main")
		return
	_director = _replay_scene.get_director()
	if _director == null:
		_fail("Director not available from BattleReplayScene")
		return

	# Step 3: 同步触发 Start Battle（内部会跑 core battle + load_replay）
	print("Step 1: Triggering start battle...")
	_main_scene.call("_on_start_battle_button_pressed")

	var total := _director.get_total_frames()
	if total <= 0:
		_fail("Replay loaded but total_frames=%d (expected > 0)" % total)
		return
	var snapshot := _director.get_actors_snapshot()
	if snapshot.is_empty():
		_fail("No actors in snapshot after load_replay")
		return
	print("  + Replay loaded: %d frames, %d actors" % [total, snapshot.size()])

	# Step 4: 加速播放并等 playback_ended
	_director.playback_ended.connect(_on_playback_ended, CONNECT_ONE_SHOT)
	_director.set_speed(PLAYBACK_SPEED)
	_replay_scene.play()
	print("Step 2: Playing...")


func _process(delta: float) -> void:
	if _finished or _director == null:
		return
	_elapsed += delta
	if _elapsed >= TIMEOUT_SEC:
		_fail("Playback did not end within %.0fs (current_frame=%d/%d)" % [
			TIMEOUT_SEC,
			_director.get_current_frame(),
			_director.get_total_frames(),
		])


func _on_playback_ended() -> void:
	if _finished:
		return
	print("Step 3: playback_ended signal received, asserting invariants...")

	# Invariant 1: is_ended() == true
	if not _director.is_ended():
		_fail("playback_ended fired but is_ended() is false")
		return

	# Invariant 2: current_frame 推进到总帧数
	var cur := _director.get_current_frame()
	var tot := _director.get_total_frames()
	if cur < tot:
		_fail("current_frame (%d) < total_frames (%d) at end" % [cur, tot])
		return

	# Invariant 3: UnitsRoot 下至少有一个 unit view
	var units_root := _replay_scene.get_node_or_null("UnitsRoot")
	if units_root == null:
		_fail("UnitsRoot node not found")
		return
	var unit_count := units_root.get_child_count()
	if unit_count == 0:
		_fail("UnitsRoot has no children after playback")
		return

	# Invariant 4: 所有 actor 的 visual_hp ∈ [0, max_hp]
	var snapshot := _director.get_actors_snapshot()
	if snapshot.is_empty():
		_fail("actors_snapshot empty after playback")
		return
	for actor_id: String in snapshot.keys():
		var st: FrontendActorRenderState = snapshot[actor_id]
		if st.visual_hp < 0.0 or st.visual_hp > st.max_hp + 0.01:
			_fail("Actor %s hp out of range: %.2f / %.2f" % [actor_id, st.visual_hp, st.max_hp])
			return

	_pass(tot, cur, unit_count, snapshot.size())


func _pass(total_frames: int, current_frame: int, unit_count: int, actor_count: int) -> void:
	_finished = true
	print("  + is_ended         = true")
	print("  + frame            = %d / %d" % [current_frame, total_frames])
	print("  + unit views       = %d" % unit_count)
	print("  + actor snapshots  = %d" % actor_count)
	print("SMOKE_TEST_RESULT: PASS - frontend main scene flow ok")
	GameWorld.destroy()
	get_tree().quit(0)


func _fail(reason: String) -> void:
	_finished = true
	printerr("SMOKE_TEST_RESULT: FAIL - %s" % reason)
	GameWorld.destroy()
	get_tree().quit(1)
