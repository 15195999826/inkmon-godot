extends Node
## 走格单位动画冒烟（T7 M4 接线验收）:overworld live driver + 注入 unit_visual
## 的玩家 avatar —— 断言 idle ↔ walk 状态切换、六向朝向(mirror 向 flip_h +
## 翻转剪影影动画)、speed_scale 速度绑定(走格 220ms/格 vs v2 walk d3 自然步速
## 0.467×12/21 ≈ 0.267 w/s → raw ≈29×,
## v1 封顶 UNIT_WALK_SPEED_SCALE_CAP=3.0——观感终审留验收任务)。
## smoke_overworld_live 同款确定性 step() 驱动,不开 live。
##
## `--walk-shot`(非 headless 跑):断言全过后再走一步,mid-walk 定格截一张
## world_main 真地图上的走格观感(验收存档;观感终审归验收任务)。

const SHOT_PATH := "res://.claude/tmp/ui-shots/overworld_unit_walk.png"

var _driver: InkMonOverworldLiveDriver = null
var _grid: InkMonRender2DBakedHexMap = null


func _ready() -> void:
	var status := _run()
	if status == "" and OS.get_cmdline_user_args().has("--walk-shot"):
		await _take_walk_shot()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - overworld walk drives unit idle/walk animation with direction + capped speed_scale")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


## world_main 真地图 + 相机对准玩家,mid-walk 定格截图。
func _take_walk_shot() -> void:
	get_window().size = Vector2i(1280, 720)
	var camera := Camera2D.new()
	camera.position = _driver.get_actor_pixel("player") + Vector2(0.0, -30.0)
	camera.zoom = Vector2(1.6, 1.6)
	add_child(camera)
	camera.make_current()
	_driver.enqueue_move("player", HexCoord.new(0, 1), HexCoord.new(-1, 2))
	_driver.step(110.0)
	for _i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot_dir := ProjectSettings.globalize_path(SHOT_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	print("  [smoke_overworld_unit_walk] walk shot -> %s (err=%d)" % [SHOT_PATH, err])


func _run() -> String:
	var grid := InkMonRender2DBakedHexMap.new()
	add_child(grid)
	var bundle := InkMonMapLoader.load_bundle("world_main")
	if bundle.is_empty() or not grid.setup_from_bundle(bundle, 56.0):
		return "world_main bundle failed to load"
	_grid = grid
	var units_root := Node2D.new()
	add_child(units_root)
	var fx_root := Node2D.new()
	add_child(fx_root)
	var driver := InkMonOverworldLiveDriver.new()
	add_child(driver)
	driver.setup(grid, units_root, fx_root)
	_driver = driver

	# 玩家 style + 单位素材注入（view._player_style() 同构）。
	var units := InkMonUnitSetLoader.load_set("inkmon-units-main")
	if not units.has("mon_0001"):
		return "inkmon-units-main/mon_0001 should load"
	var visual := units["mon_0001"] as InkMonUnitSetLoader.UnitVisual
	var style := InkMonRender2DAvatar.Style.overworld_player()
	style.unit_visual = visual
	style.unit_scale = grid.edge_px() / visual.px_per_unit
	style.lift = 0.0
	style.idle_bob = false
	driver.seed_actor("player", "Hero", HexCoord.new(0, 0), style)

	var avatar := driver.get_avatar("player")
	if avatar == null or not avatar.has_unit_visual():
		return "player avatar should be in unit-visual mode"
	var body := avatar.get_node_or_null("VisualRoot/Body") as AnimatedSprite2D
	if body == null:
		return "Body should be an AnimatedSprite2D under VisualRoot (唯一替换位)"
	var shadow := avatar.get_node_or_null("Shadow") as AnimatedSprite2D
	if shadow == null:
		return "programmatic Shadow sprite should be present (loader 预推)"
	if avatar.get_node_or_null("VisualRoot/Head") != null:
		return "占位盘 Head 不得混进单位动画模式 (codex M4 medium)"
	# seed 落点同步一次后应处于 idle。
	driver.step(16.0)
	if str(body.animation) != "idle_d3":
		return "seeded player should idle on d3 (真帧向), got %s" % str(body.animation)
	if not body.is_playing():
		return "idle animation should be playing"

	# ---- 走 d5(mirror 向,delta (1,0)):walk + flip_h + speed_scale 封顶 ----
	driver.enqueue_move("player", HexCoord.new(0, 0), HexCoord.new(1, 0))
	driver.step(110.0)
	if not driver.is_actor_moving("player"):
		return "player should be moving mid-step"
	if str(body.animation) != "walk_d3":
		return "walk should reuse true-frame animation walk_d3, got %s" % str(body.animation)
	if not body.flip_h:
		return "direction 5 is mirror_of 3 → flip_h should be true"
	# 影:恒不 flip(世界光向恒定);mirror 向播翻转剪影影动画(二轮验收修正)。
	if shadow.flip_h:
		return "shadow sprite must never flip_h (影斜向不随镜像)"
	if str(shadow.animation) != "walk_d5":
		return "d5 shadow should play mirrored-silhouette animation walk_d5, got %s" % str(shadow.animation)
	# 速度绑定:raw = 走速/自然步速 ≈ (√3 / 0.22s) / 0.267 ≈ 29.5 → 封顶 3.0
	# (v2 walk d3 stride 0.467、21 帧;0.382 是 v1 canonical 旧值)。
	if absf(body.speed_scale - 3.0) > 0.01:
		return "walk speed_scale should be capped at 3.0, got %f" % body.speed_scale
	if shadow.frame != body.frame:
		return "shadow frame should track body frame"

	# ---- 走完:回 idle,朝向保持 d5(mirror 仍 flip) ----
	driver.step(130.0)
	if driver.is_actor_moving("player"):
		return "player should stop after move duration"
	if str(body.animation) != "idle_d3":
		return "player should return to idle after the step, got %s" % str(body.animation)
	if not body.flip_h:
		return "idle should keep last facing (d5 mirror → flip_h stays true)"
	if str(shadow.animation) != "idle_d5":
		return "idle-after-d5 shadow should switch to idle_d5, got %s" % str(shadow.animation)
	if absf(body.speed_scale - 1.0) > 0.01:
		return "idle speed_scale should be 1.0 (素材原生踏步率), got %f" % body.speed_scale

	# ---- 走 d3(真帧向,delta (-1,+1)):不翻转 ----
	driver.enqueue_move("player", HexCoord.new(1, 0), HexCoord.new(0, 1))
	driver.step(110.0)
	if body.flip_h:
		return "direction 3 is the true-frame direction → flip_h should be false"
	driver.step(130.0)

	return ""
