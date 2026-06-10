extends Node

## iso 角度沙盒 smoke：投影纯函数往返自洽 + 绘制版沙盒（动态 pitch/yaw + 拾取）+
## TileMap 版沙盒（运行时 TileSet / 铺格 / 坐标往返）。

const AngleSandboxScene := preload("res://inkmon/tools/iso_sandbox/iso_angle_sandbox.tscn")
const TilemapSandboxScene := preload("res://inkmon/tools/iso_sandbox/iso_tilemap_sandbox.tscn")


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - iso sandbox (projection math + prism renderer + tilemap pipeline) passed")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var math_status := _assert_projection_math()
	if math_status != "":
		return math_status
	var angle_status := await _assert_angle_sandbox()
	if angle_status != "":
		return angle_status
	return await _assert_tilemap_sandbox()


func _assert_projection_math() -> String:
	var angle_sets: Array = [[30.0, 0.0], [35.26, 15.0], [50.0, -25.0]]
	var probes: Array[Vector2] = [
		Vector2.ZERO, Vector2(100.0, 40.0), Vector2(-77.0, 13.0), Vector2(5.0, -90.0), Vector2(-31.0, -2.0),
	]
	for angles_value in angle_sets:
		var angles := angles_value as Array
		var ground := InkMonRender2DIsoProjection.ground_basis(float(angles[0]), float(angles[1]))
		var inverse := ground.affine_inverse()
		for probe in probes:
			var roundtrip: Vector2 = inverse * (ground * probe)
			if roundtrip.distance_to(probe) > 0.01:
				return "projection roundtrip drifted at pitch %s yaw %s" % [angles[0], angles[1]]
	var straight := InkMonRender2DIsoProjection.ground_basis(30.0, 0.0)
	var yawed := InkMonRender2DIsoProjection.ground_basis(30.0, 20.0)
	if straight.x.distance_to(yawed.x) < 0.01:
		return "yaw must change the ground basis (yaw silently ignored)"
	if absf(InkMonRender2DIsoProjection.squish_of(30.0) - 0.5) > 0.001:
		return "squish_of(30 deg) should be exactly 0.5 (2:1 isometric)"
	return ""


func _assert_angle_sandbox() -> String:
	var sandbox := AngleSandboxScene.instantiate() as InkMonIsoAngleSandbox
	add_child(sandbox)
	await get_tree().process_frame
	await get_tree().process_frame
	var state := sandbox.get_debug_state()
	if int(state.get("tile_count", 0)) <= 0:
		return "angle sandbox should build demo tiles"
	if not bool(state.get("pick_roundtrip_ok", false)):
		return "angle sandbox pick roundtrip failed at default angles"
	sandbox.set_angles(45.0, 15.0)
	var after := sandbox.get_debug_state()
	if absf(float(after.get("pitch_deg", 0.0)) - 45.0) > 0.01 or absf(float(after.get("yaw_deg", 0.0)) - 15.0) > 0.01:
		return "set_angles must update pitch/yaw"
	if not bool(after.get("pick_roundtrip_ok", false)):
		return "pick roundtrip must stay consistent under yaw rotation"
	sandbox.queue_free()
	await get_tree().process_frame
	return ""


func _assert_tilemap_sandbox() -> String:
	var sandbox := TilemapSandboxScene.instantiate() as InkMonIsoTilemapSandbox
	add_child(sandbox)
	await get_tree().process_frame
	await get_tree().process_frame
	var state := sandbox.get_debug_state()
	if not bool(state.get("has_tile_set", false)):
		return "tilemap sandbox should build a runtime TileSet"
	if int(state.get("base_cell_count", 0)) <= 0:
		return "tilemap sandbox base layer should paint cells"
	if int(state.get("raised_cell_count", 0)) <= 0:
		return "tilemap sandbox should paint raised elevation cells"
	if not bool(state.get("map_roundtrip_ok", false)):
		return "tilemap map_to_local/local_to_map roundtrip failed"
	sandbox.queue_free()
	await get_tree().process_frame
	return ""
