extends Node
## 大地图风格预设契约 (adr/0012 决定五):
##   1. ORDER 完整循环: next_style 从默认出发走 ORDER.size() 步不提前回头、终点回到默认。
##   2. 每个预设形状: name_key 非空 / uniforms 非空 / 河流配色字段在。
##   3. user:// 偏好 roundtrip + 未知值回退默认 (损坏配置不炸)。
##   4. view.set_map_style 生效: map_style_id 更新、uniform 下发不炸 (含 codex 预设)。
## 本 smoke 是 user:// 偏好文件唯一写手 (其余 smoke 只读), 可并行; 收尾删文件保洁净。


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - map style presets: order cycle + preset shape + pref roundtrip + view apply")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# 1+2. ORDER 循环与预设形状。
	var seen: Dictionary = {}
	var cursor := InkMonMapStylePresets.DEFAULT_STYLE
	for _step in range(InkMonMapStylePresets.ORDER.size()):
		if seen.has(cursor):
			return "next_style cycled back early at %s" % cursor
		seen[cursor] = true
		var preset := InkMonMapStylePresets.preset(cursor)
		if str(preset.get("name_key", "")) == "":
			return "preset %s missing name_key" % cursor
		if (preset.get("uniforms", {}) as Dictionary).is_empty():
			return "preset %s missing uniforms" % cursor
		if not preset.has("rivers") or not preset.has("river_core"):
			return "preset %s missing river fields" % cursor
		cursor = InkMonMapStylePresets.next_style(cursor)
	if cursor != InkMonMapStylePresets.DEFAULT_STYLE:
		return "order cycle must return to default (got %s)" % cursor
	if seen.size() != InkMonMapStylePresets.ORDER.size():
		return "order cycle must visit every style"

	# 3. 偏好 roundtrip + 未知值回退。
	InkMonMapStylePresets.save_pref(InkMonMapStylePresets.STYLE_FLAT)
	if InkMonMapStylePresets.load_pref() != InkMonMapStylePresets.STYLE_FLAT:
		return "pref roundtrip lost saved style"
	var corrupt := ConfigFile.new()
	corrupt.set_value(InkMonMapStylePresets.PREF_SECTION, InkMonMapStylePresets.PREF_KEY, "no_such_style")
	corrupt.save(InkMonMapStylePresets.PREF_PATH)
	if InkMonMapStylePresets.load_pref() != InkMonMapStylePresets.DEFAULT_STYLE:
		return "unknown pref value must fall back to default"

	# 4. view 应用 (含 codex 预设; headless 下 uniform 下发/redraw 不炸即约)。
	var view := InkMonMissionMapView.new()
	add_child(view)
	for style_id in InkMonMapStylePresets.ORDER:
		view.set_map_style(style_id)
		if view.map_style_id != style_id:
			return "view.set_map_style(%s) did not stick" % style_id
	view.queue_free()

	# 收尾: 删偏好文件 (保持环境洁净, 其余 smoke 读到的是"无偏好"默认态)。
	DirAccess.remove_absolute(ProjectSettings.globalize_path(InkMonMapStylePresets.PREF_PATH))
	return ""
