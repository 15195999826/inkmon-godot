class_name InkMonMissionHud
extends Control
## 出征 HUD 子场景控制器 (M2.4, 尾项⑤; docs §6 下放): 剩余粮 + 队伍 HP 概览 + 放弃出征按钮。
## 数据由 root 推入 (refresh); 放弃走两击确认 (误触 = 丢整趟, 3 秒回弹) 后上抛 abandon_requested,
## 执行归 Host (load 出发档 lifecycle)。


signal abandon_requested


## 两击确认回弹时长 (秒)。
const ABANDON_CONFIRM_WINDOW := 3.0
const HP_BAR_SIZE := Vector2(120.0, 10.0)
const COLOR_HP_BACK := Color(0.16, 0.15, 0.14)
const COLOR_HP_FILL := Color(0.42, 0.78, 0.42)
const COLOR_HP_LOW := Color(0.85, 0.42, 0.3)


var _supplies_label: Label
var _quest_rows: VBoxContainer
var _party_rows: VBoxContainer
var _abandon_button: Button
var _abandon_armed := false
var _abandon_rearm_timer: SceneTreeTimer = null


func _ready() -> void:
	_supplies_label = get_node("MissionPanel/MissionBox/SuppliesLabel") as Label
	_quest_rows = get_node("MissionPanel/MissionBox/QuestRows") as VBoxContainer
	_party_rows = get_node("MissionPanel/MissionBox/PartyRows") as VBoxContainer
	_abandon_button = get_node("MissionPanel/MissionBox/AbandonButton") as Button
	_abandon_button.pressed.connect(_on_abandon_pressed)


## root 推入刷新 (出征开始 / 每步 progressed / 战斗离场回大地图)。
## quests (Phase 3): [{title, role, progress, goal_count}] —— 主委托一行 + 副委托进度行。
func refresh(supplies: int, roster_snapshot: Array[Dictionary], quests: Array[Dictionary] = []) -> void:
	if _supplies_label != null:
		_supplies_label.text = "Supplies: %d" % supplies
		_supplies_label.add_theme_color_override("font_color",
			Color(0.9, 0.45, 0.35) if supplies <= 0 else Color(0.92, 0.9, 0.85))
	_rebuild_quest_rows(quests)
	_rebuild_party_rows(roster_snapshot)


func _rebuild_quest_rows(quests: Array[Dictionary]) -> void:
	if _quest_rows == null:
		return
	for child in _quest_rows.get_children():
		child.queue_free()
	for quest in quests:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 13)
		var is_main := str(quest.get("role", "")) == "main"
		var goal := int(quest.get("goal_count", 0))
		if is_main:
			row.text = "★ %s" % str(quest.get("title", ""))
			row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		else:
			var progress := mini(int(quest.get("progress", 0)), goal)
			row.text = "• %s (%d/%d)" % [str(quest.get("title", "")), progress, goal]
			row.add_theme_color_override("font_color",
				Color(0.55, 0.85, 0.6) if progress >= goal else Color(0.75, 0.73, 0.68))
		_quest_rows.add_child(row)


func _rebuild_party_rows(roster_snapshot: Array[Dictionary]) -> void:
	if _party_rows == null:
		return
	for child in _party_rows.get_children():
		child.queue_free()
	for entry in roster_snapshot:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(72.0, 0.0)
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.text = str(entry.get("display_name", ""))
		row.add_child(name_label)
		var max_hp := maxf(1.0, float(entry.get("max_hp", 1.0)))
		var ratio := clampf(float(entry.get("hp", 0.0)) / max_hp, 0.0, 1.0)
		var bar_back := ColorRect.new()
		bar_back.custom_minimum_size = HP_BAR_SIZE
		bar_back.color = COLOR_HP_BACK
		bar_back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bar_fill := ColorRect.new()
		bar_fill.color = COLOR_HP_LOW if ratio <= 0.3 else COLOR_HP_FILL
		bar_fill.size = Vector2(HP_BAR_SIZE.x * ratio, HP_BAR_SIZE.y)
		bar_back.add_child(bar_fill)
		row.add_child(bar_back)
		_party_rows.add_child(row)


func _on_abandon_pressed() -> void:
	if not _abandon_armed:
		# 第一击只上膛: 文案变确认, 3 秒不二击自动回弹 (丢整趟不能单击误触)。
		_abandon_armed = true
		_abandon_button.text = "Abandon?! (click again)"
		_abandon_rearm_timer = get_tree().create_timer(ABANDON_CONFIRM_WINDOW)
		_abandon_rearm_timer.timeout.connect(_disarm_abandon)
		return
	_disarm_abandon()
	abandon_requested.emit()


func _disarm_abandon() -> void:
	_abandon_armed = false
	if _abandon_button != null:
		_abandon_button.text = "Abandon Mission"


## smoke / dev-agent 读口。
func get_debug_controls() -> Dictionary:
	return {
		"supplies_label": _supplies_label,
		"abandon_button": _abandon_button,
		"party_rows": _party_rows,
	}
