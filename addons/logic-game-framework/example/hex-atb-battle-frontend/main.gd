## Main - 战斗回放前端示例入口
##
## 演示如何使用表演框架播放战斗录像
extends Node


# ========== 节点引用 ==========

var _replay_scene: FrontendBattleReplayScene
var _controls: FrontendReplayControls


# ========== 生命周期 ==========

func _ready() -> void:
	print("\n========== Hex ATB Battle Frontend Demo ==========\n")
	
	# 创建回放场景
	_replay_scene = FrontendBattleReplayScene.new()
	_replay_scene.name = "BattleReplayScene"
	add_child(_replay_scene)
	
	# 创建 UI 控制
	_setup_ui()
	
	# 连接信号
	var director := _replay_scene.get_director()
	director.playback_state_changed.connect(_on_playback_state_changed)
	director.frame_changed.connect(_on_frame_changed)
	director.playback_ended.connect(_on_playback_ended)
	
	# 尝试加载最新的录像
	_load_latest_replay()


func _setup_ui() -> void:
	_controls = FrontendReplayControls.new()
	_controls.name = "ReplayControls"
	_controls.anchor_left = 0.0
	_controls.anchor_top = 0.0
	_controls.anchor_right = 0.3
	_controls.anchor_bottom = 0.3
	add_child(_controls)
	
	# 连接 UI 信号
	_controls.play_pressed.connect(_on_play_pressed)
	_controls.pause_pressed.connect(_on_pause_pressed)
	_controls.reset_pressed.connect(_on_reset_pressed)
	_controls.speed_changed.connect(_on_speed_changed)


# ========== 录像加载 ==========

func _load_latest_replay() -> void:
	# 尝试从 user://Replays/ 目录加载最新的录像
	var replays_dir := "user://Replays/"
	var dir := DirAccess.open(replays_dir)
	
	if dir == null:
		print("[Main] No replays directory found, using demo data")
		_load_demo_replay()
		return
	
	# 查找最新的录像文件
	var latest_file := ""
	var latest_time := 0
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path := replays_dir + file_name
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file:
				var modified_time := FileAccess.get_modified_time(file_path)
				if modified_time > latest_time:
					latest_time = modified_time
					latest_file = file_path
				file.close()
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if latest_file.is_empty():
		print("[Main] No replay files found, using demo data")
		_load_demo_replay()
		return
	
	print("[Main] Loading replay: %s" % latest_file)
	_load_replay_file(latest_file)


func _load_replay_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[Main] Failed to open replay file: %s" % file_path)
		_load_demo_replay()
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("[Main] Failed to parse replay JSON: %s" % json.get_error_message())
		_load_demo_replay()
		return
	
	var replay_data: Dictionary = json.data
	print("[Main] Replay loaded successfully")
	print("  - Total frames: %d" % replay_data.get("meta", {}).get("totalFrames", 0))
	print("  - Actors: %d" % replay_data.get("initialActors", []).size())
	
	_replay_scene.load_replay(replay_data)


func _load_demo_replay() -> void:
	# 创建演示用的回放数据
	var demo_replay := _create_demo_replay()
	print("[Main] Using demo replay data")
	_replay_scene.load_replay(demo_replay)


func _create_demo_replay() -> Dictionary:
	# 创建一个简单的演示回放
	return {
		"version": "2.0",
		"meta": {
			"battleId": "demo_battle",
			"recordedAt": Time.get_unix_time_from_system(),
			"tickInterval": 100,
			"totalFrames": 50,
			"result": "demo",
		},
		"configs": {},
		"initialActors": [
			{
				"id": "actor_1",
				"configId": "warrior",
				"displayName": "Warrior",
				"team": 0,
				"position": { "hex": { "q": -2, "r": 0 } },
				"attributes": { "hp": 100.0, "maxHp": 100.0 },
				"abilities": [],
				"tags": {},
			},
			{
				"id": "actor_2",
				"configId": "mage",
				"displayName": "Mage",
				"team": 1,
				"position": { "hex": { "q": 2, "r": 0 } },
				"attributes": { "hp": 80.0, "maxHp": 80.0 },
				"abilities": [],
				"tags": {},
			},
		],
		"timeline": [
			{
				"frame": 5,
				"events": [
					{
						"kind": "move_start",
						"actor_id": "actor_1",
						"from_hex": { "q": -2, "r": 0 },
						"to_hex": { "q": -1, "r": 0 },
					},
				],
			},
			{
				"frame": 10,
				"events": [
					{
						"kind": "damage",
						"target_actor_id": "actor_2",
						"damage": 25.0,
						"damage_type": "physical",
						"source_actor_id": "actor_1",
						"is_critical": false,
						"is_reflected": false,
					},
				],
			},
			{
				"frame": 20,
				"events": [
					{
						"kind": "heal",
						"target_actor_id": "actor_2",
						"heal_amount": 15.0,
						"source_actor_id": "actor_2",
					},
				],
			},
			{
				"frame": 30,
				"events": [
					{
						"kind": "damage",
						"target_actor_id": "actor_2",
						"damage": 50.0,
						"damage_type": "physical",
						"source_actor_id": "actor_1",
						"is_critical": true,
						"is_reflected": false,
					},
				],
			},
			{
				"frame": 40,
				"events": [
					{
						"kind": "damage",
						"target_actor_id": "actor_2",
						"damage": 30.0,
						"damage_type": "physical",
						"source_actor_id": "actor_1",
						"is_critical": false,
						"is_reflected": false,
					},
					{
						"kind": "death",
						"actor_id": "actor_2",
						"killer_actor_id": "actor_1",
					},
				],
			},
		],
	}


# ========== 信号处理 ==========

func _on_playback_state_changed(is_playing: bool) -> void:
	_controls.update_playback_state(is_playing)


func _on_frame_changed(current_frame: int, total_frames: int) -> void:
	_controls.update_frame_info(current_frame, total_frames)


func _on_playback_ended() -> void:
	_controls.set_ended_state()
	print("[Main] Playback ended")


func _on_play_pressed() -> void:
	_replay_scene.play()


func _on_pause_pressed() -> void:
	_replay_scene.pause()


func _on_reset_pressed() -> void:
	_replay_scene.reset()
	_controls.update_playback_state(false)
	_controls.update_frame_info(0, _replay_scene.get_director().get_total_frames())


func _on_speed_changed(speed: float) -> void:
	_replay_scene.set_speed(speed)


# ========== 输入处理 ==========

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				_replay_scene.toggle()
			KEY_R:
				_on_reset_pressed()
			KEY_1:
				_replay_scene.set_speed(0.5)
			KEY_2:
				_replay_scene.set_speed(1.0)
			KEY_3:
				_replay_scene.set_speed(2.0)
			KEY_4:
				_replay_scene.set_speed(4.0)
