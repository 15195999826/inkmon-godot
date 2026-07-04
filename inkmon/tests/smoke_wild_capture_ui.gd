extends Node
## M2.3 战后捕捉 UI 交互 smoke (real mouse input, view 级):
##   假 replay (一只气绝野生) + 捕捉池 → 播完前点无效 → 播完窗口开 →
##   真鼠标点气绝个体 → capture_requested(slot) 上抛 → 推回成功结果 → 落标出现 + 同只再点不再上抛。
## GI 捕捉语义在 smoke_wild_battle; 本 smoke 只焊 view 的点选/去重/反馈交互。
## UI 交互 smoke 约定: _ready 首行 ensure window size; PASS 带 "(real mouse input)" 标记。


var _requested_slots: Array[int] = []


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var status: String = await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - wild capture view: click fainted wild throws once, dedup + feedback (real mouse input)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var view := InkMonBattle2DView.new()
	add_child(view)
	await get_tree().process_frame
	view.capture_requested.connect(func(slot_index: int) -> void:
		_requested_slots.append(slot_index))

	var pool: Array[Dictionary] = [{
		"slot_index": 0,
		"actor_id": "wild_0",
		"species_id": "cinder_kit",
		"roll_seed": 7,
		"display_name": "Wild Kit",
		"attempted": false,
		"captured": false,
	}]
	view.play_replay(_fake_record(), {"result": "left_win"}, {}, pool)
	await get_tree().process_frame

	# 播完前点击不上抛 (捕捉窗口 = 播完后)。
	var pos_before := view.capture_unit_screen_position(0)
	if not pos_before.is_finite():
		return "capture unit screen position should resolve while pool is set"
	_click_at(pos_before)
	await get_tree().process_frame
	if not _requested_slots.is_empty():
		return "clicks before playback ends must not request captures"

	# 快进播完 → 窗口开; 死亡淡出后的气绝目标必须被拉回可见 (codex P1: 隐形目标点不着)。
	view.get_animator().step(1_000_000.0)
	await get_tree().process_frame
	if not bool(view.get_debug_state().get("ended", false)):
		return "animator should be ended after fast-forward"
	if not bool(view.get_debug_state().get("capture_window_open", false)):
		return "capture window should open after playback ends"
	var wild_avatar := view.get_node_or_null("Stage/UnitsRoot/Unit_wild_0") as Node2D
	if wild_avatar == null:
		return "wild unit view should exist"
	if wild_avatar.modulate.a <= 0.05:
		return "fainted capture target must be visible after death fade (alpha %f)" % wild_avatar.modulate.a
	var marks_root := view.get_node_or_null("Stage/CaptureMarksRoot") as Node2D
	if marks_root == null or marks_root.get_child_count() != 1:
		return "a throw marker should appear on the capture target"

	# 真鼠标点气绝个体 → 恰好一次上抛。
	_click_at(view.capture_unit_screen_position(0))
	await get_tree().process_frame
	if _requested_slots.size() != 1 or _requested_slots[0] != 0:
		return "clicking the fainted wild should request capture for slot 0 (got %s)" % str(_requested_slots)

	# 推回成功结果 → 落标出现 + 窗口关闭 (池只有这一只) + 再点不再上抛。
	view.apply_capture_result({
		"ok": true, "slot_index": 0, "captured": true,
		"species_id": "cinder_kit", "display_name": "Wild Kit", "chance": 0.5,
	})
	await get_tree().process_frame
	var marks := view.get_node_or_null("Stage/CaptureMarksRoot") as Node2D
	if marks == null or marks.get_child_count() != 1:
		return "a capture mark should appear after the throw result"
	if bool(view.get_debug_state().get("capture_window_open", false)):
		return "capture window should close once every wild is attempted"
	_click_at(view.capture_unit_screen_position(0))
	await get_tree().process_frame
	if _requested_slots.size() != 1:
		return "an attempted wild must not accept a second throw"
	return ""


## 单只野生 (wild_0, 战中被击倒 → 真死亡淡出链路) + 单只己方; 快进即完。
## death 事件必须在: 复现"死亡 visualizer 把捕捉目标淡出隐形"的真实胜局形态 (codex P1)。
func _fake_record() -> Dictionary:
	# FrameData.events 是类型化 Array[Dictionary] —— 字面量必须先落类型化变量再塞 (对齐 shot harness 约定)。
	var death_events: Array[Dictionary] = [
		{"kind": "inkmon_death", "actor_id": "wild_0", "killer_actor_id": "u_l"},
	]
	return {
		"meta": {"tickInterval": 100, "totalFrames": 5},
		"world_snapshot": {"actors": [
			{"id": "u_l", "team": 0, "displayName": "L", "position": [-3, 0, 0], "attributes": {"hp": 30, "max_hp": 30}},
			{"id": "wild_0", "team": 1, "displayName": "Wild Kit", "position": [3, 0, 0], "attributes": {"hp": 20, "max_hp": 20}},
		]},
		"timeline": [
			{"frame": 2, "events": death_events},
		],
	}


func _click_at(screen_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	get_viewport().push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	get_viewport().push_input(release)
