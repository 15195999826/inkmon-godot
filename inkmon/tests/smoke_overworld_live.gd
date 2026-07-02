extends Node
## 主世界 live 表演管线冒烟（adr/0007）。直接驱动 InkMonOverworldLiveDriver（不接真实 view/GI）：
## seed player+npc → enqueue_move → 确定性 step() → 断言走的是共享 render_world 管线
## （MoveAction 220ms 内逻辑 axial 插值 + 落点 + dormant actor 存活无血条）。纯表演层。


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - overworld live driver interpolates moves through shared render_world pipeline")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# 坐标层 = baked 地图层（T2 契约）：world_main 静态地图 + 发布 tile set。
	var grid := InkMonRender2DBakedHexMap.new()
	add_child(grid)
	var bundle := InkMonMapLoader.load_bundle("world_main")
	if bundle.is_empty() or not grid.setup_from_bundle(bundle, 56.0):
		return "world_main bundle failed to load for the baked map layer"
	var units_root := Node2D.new()
	add_child(units_root)
	var fx_root := Node2D.new()
	add_child(fx_root)

	var driver := InkMonOverworldLiveDriver.new()
	add_child(driver)
	driver.setup(grid, units_root, fx_root)

	# seed：player(0,0) + npc(2,0)，overworld style（dormant hp，无血条）
	driver.seed_actor("player", "Hero", HexCoord.new(0, 0), InkMonRender2DAvatar.Style.overworld_player())
	driver.seed_actor("npc_shop", "Shop", HexCoord.new(2, 0), InkMonRender2DAvatar.Style.overworld_npc(Color(0.93, 0.64, 0.24)))

	var player_avatar := driver.get_avatar("player")
	var npc_avatar := driver.get_avatar("npc_shop")
	if player_avatar == null or npc_avatar == null:
		return "avatars should be lazily built on seed (player=%s npc=%s)" % [player_avatar, npc_avatar]
	# dormant：无 hp 条节点 + 存活不透明
	if player_avatar.get_node_or_null("HpFill") != null:
		return "overworld avatar should have NO hp bar (dormant hp)"
	if not is_equal_approx(player_avatar.modulate.a, 1.0):
		return "seeded actor should be alive (modulate.a==1), got %s" % str(player_avatar.modulate.a)

	# 起点逻辑坐标
	var start_axial := driver.get_actor_axial("player")
	if not (is_equal_approx(start_axial.x, 0.0) and is_equal_approx(start_axial.y, 0.0)):
		return "player should start at axial (0,0), got %s" % str(start_axial)

	# 入队一步 (0,0)->(1,0)，220ms 移动
	driver.enqueue_move("player", HexCoord.new(0, 0), HexCoord.new(1, 0))

	# 半程（110ms）：逻辑 axial 应在 0..1 之间 + 仍在移动
	driver.step(110.0)
	var mid_axial := driver.get_actor_axial("player")
	if not (mid_axial.x > 0.01 and mid_axial.x < 0.99):
		return "mid-move player axial.x should be between 0 and 1, got %s" % str(mid_axial.x)
	if not driver.is_actor_moving("player"):
		return "player should report moving mid-step"

	# 走完（再 110ms，累计 220ms）：落到 (1,0) + 停止移动
	driver.step(110.0)
	var end_axial := driver.get_actor_axial("player")
	if not (is_equal_approx(end_axial.x, 1.0) and is_equal_approx(end_axial.y, 0.0)):
		return "player should land on axial (1,0) after move duration, got %s" % str(end_axial)
	if driver.is_actor_moving("player"):
		return "player should NOT be moving after move completes"

	# 像素位置应等于 grid 对 (1,0) 的换算（唯一 hex→像素边界）
	var px := driver.get_actor_pixel("player")
	var expect_px := grid.coord_to_world(1, 0)
	if px.distance_to(expect_px) > 0.5:
		return "player pixel should match grid coord_to_world(1,0): got %s expect %s" % [str(px), str(expect_px)]

	# npc 未动，仍在 (2,0)
	var npc_axial := driver.get_actor_axial("npc_shop")
	if not (is_equal_approx(npc_axial.x, 2.0) and is_equal_approx(npc_axial.y, 0.0)):
		return "untouched npc should stay at axial (2,0), got %s" % str(npc_axial)

	return ""
