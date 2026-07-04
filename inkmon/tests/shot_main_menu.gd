extends Node
## 开窗截图自验工具 (非测试组): 主菜单渲染成什么样, 截 PNG 供人/AI 目检。
## 跑法: godot --path . inkmon/tests/shot_main_menu.tscn (不带 --headless)。
## 若无出发档会临时造一个占位文件让 Recover 分支入镜 (完整菜单形态), 截完即清理。


const SHOT_PATH := "res://.claude/tmp/shot_main_menu.png"


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _run()


func _run() -> void:
	var seeded := false
	if not FileAccess.file_exists(InkMonWorldHost.DEPARTURE_SAVE_PATH):
		# 菜单只判 file_exists, 占位内容即可; 截完删除, 不污染真实恢复提示。
		var file := FileAccess.open(InkMonWorldHost.DEPARTURE_SAVE_PATH, FileAccess.WRITE)
		file.store_string("{}")
		file.close()
		seeded = true
	var main := (preload("res://InkMonMain.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var image := get_viewport().get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(SHOT_PATH)
	image.save_png(absolute)
	if seeded:
		DirAccess.remove_absolute(InkMonWorldHost.DEPARTURE_SAVE_PATH)
	print("SHOT_SAVED: %s" % absolute)
	get_tree().quit(0)
