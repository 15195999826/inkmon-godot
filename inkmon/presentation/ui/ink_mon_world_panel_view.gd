class_name InkMonWorldPanelView
extends RefCounted
## P8 表演抽离:主世界 HUD / 抽屉的数据驱动内容构建(roster chips / party / bag / journal)。
##
## 纯表演 —— 只收 IWorldQuery 出的 **snapshot Dictionary**(Wave 3: 不再收活 actor 引用, 也不直触
## ItemSystem —— 展示字段由 query 投影), 不持 flow / 命令态(那些归 Host)。
## Host instantiate 一份并调用;动态列表用 instantiate 组件场景(§6)。


const RosterChipScene := preload("res://inkmon/presentation/ui/components/roster_chip.tscn")
const PartyEntryRowScene := preload("res://inkmon/presentation/ui/components/party_entry_row.tscn")
const BagItemRowScene := preload("res://inkmon/presentation/ui/components/bag_item_row.tscn")
const JournalPanelScene := preload("res://inkmon/presentation/ui/components/journal_panel.tscn")
const PanelMessageScene := preload("res://inkmon/presentation/ui/components/panel_message.tscn")


## 顶部 roster chips(描边色 = 首元素;样式在 .tscn 的 local-to-scene StyleBox)。收 roster snapshot。
func build_roster_chips(container: HBoxContainer, roster_snapshot: Array[Dictionary]) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	for i in range(roster_snapshot.size()):
		var entry := roster_snapshot[i]
		var elements := entry.get("elements", []) as Array
		var chip := RosterChipScene.instantiate() as PanelContainer
		chip.name = "RosterChip_%d" % i
		var style := chip.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = element_color(str(elements[0]) if not elements.is_empty() else "")
		(chip.get_node("ChipLabel") as Label).text = "%s\nLv%d" % [
			short_name(InkMonText.species_name(str(entry.get("species_id", "")))),
			int(entry.get("level", 1))]
		container.add_child(chip)


## 队伍面板: 每条 snapshot 一行。六维显示 stats 投影 (= f(species,level) + 装备实时值)。
func build_party_panel(container: VBoxContainer, roster_snapshot: Array[Dictionary]) -> void:
	for i in range(roster_snapshot.size()):
		var entry := roster_snapshot[i]
		var elements := entry.get("elements", []) as Array
		var row := PartyEntryRowScene.instantiate() as HBoxContainer
		row.name = "PartyEntry_%d" % i
		(row.get_node("ElementSwatch") as ColorRect).color = element_color(
			str(elements[0]) if not elements.is_empty() else "")

		var label := row.get_node("PartyEntryLabel") as Label
		label.text = "%s  Lv%d\n%s" % [
			InkMonText.species_name(str(entry.get("species_id", ""))),
			int(entry.get("level", 1)),
			InkMonText.tf("UI_PARTY_META", {
				"elements": InkMonText.elements_line(elements),
				"exp": int(entry.get("exp", 0)),
				"skill": str(entry.get("primary_skill_id", "")),
			}),
		]
		label.modulate = Color(0.92, 0.88, 0.78)

		var stats := row.get_node("StatsLabel") as Label
		var live := entry.get("stats", {}) as Dictionary
		stats.text = "%s\n%s" % [
			InkMonText.tf("UI_STATS_ROW_1", {
				"hp": int(float(live.get("max_hp", 0.0))),
				"ad": int(float(live.get("ad", 0.0))),
				"ap": int(float(live.get("ap", 0.0))),
			}),
			InkMonText.tf("UI_STATS_ROW_2", {
				"armor": int(float(live.get("armor", 0.0))),
				"mr": int(float(live.get("mr", 0.0))),
				"spd": int(float(live.get("speed", 0.0))),
			}),
		]
		stats.modulate = Color(0.82, 0.78, 0.68)
		container.add_child(row)


## 背包面板: 收 bag snapshot (display_name/description 已由 query 从 item config 投影)。
func build_bag_panel(container: VBoxContainer, bag_items: Array) -> void:
	if bag_items.is_empty():
		var empty := PanelMessageScene.instantiate() as Label
		empty.name = "BagEmptyLabel"
		empty.text = InkMonText.t("UI_BAG_EMPTY")
		container.add_child(empty)
		return

	for item_value in bag_items:
		var item := item_value as Dictionary
		if item == null:
			continue
		var row := BagItemRowScene.instantiate() as HBoxContainer
		row.name = "BagItem_%s" % str(item.get("config_id", "unknown"))
		var label := row.get_node("BagItemLabel") as Label
		var description := str(item.get("description", ""))
		if description == "":
			description = InkMonText.t("UI_ITEM_NO_DESC")
		label.text = "%s x%d\n%s" % [
			InkMonText.item_display(item),
			int(item.get("count", 1)),
			description,
		]
		label.modulate = Color(0.92, 0.88, 0.78)
		container.add_child(row)


## journal 概要 + 系统菜单按钮(on_system_menu = 打开 save/load 的 Host 回调)。
func build_journal_panel(container: VBoxContainer, progression: Dictionary, last_battle: Dictionary, on_system_menu: Callable) -> void:
	var lines := PackedStringArray([
		InkMonText.tf("UI_JOURNAL_RANK", {"n": int(progression.get("trainer_rank", 1))}),
		InkMonText.t("UI_JOURNAL_GUILD_YES" if bool(progression.get("guild_joined", false)) else "UI_JOURNAL_GUILD_NO"),
		InkMonText.tf("UI_JOURNAL_CULTIVATION", {"n": int(progression.get("cultivation_points", 0))}),
		InkMonText.tf("UI_JOURNAL_TASKS", {"n": int(progression.get("guild_tasks_completed", 0))}),
	])
	if not last_battle.is_empty():
		lines.append(InkMonText.tf("UI_JOURNAL_LAST_BATTLE", {
			"result": InkMonText.battle_result_name(str(last_battle.get("result", ""))),
			"team": InkMonText.team_name(str(last_battle.get("winner_team", ""))),
		}))
	var panel := JournalPanelScene.instantiate()
	(panel.get_node("JournalSummary") as Label).text = "\n".join(lines)
	(panel.get_node("OpenSystemMenu") as Button).pressed.connect(on_system_menu)
	container.add_child(panel)


static func element_color(element: String) -> Color:
	match element:
		InkMonElementChart.FIRE:
			return Color(0.85, 0.30, 0.18)
		InkMonElementChart.WATER:
			return Color(0.18, 0.62, 0.66)
		InkMonElementChart.LIGHT:
			return Color(0.92, 0.74, 0.24)
		InkMonElementChart.DARK:
			return Color(0.44, 0.30, 0.66)
		InkMonElementChart.WIND:
			return Color(0.42, 0.66, 0.34)
		InkMonElementChart.EARTH:
			return Color(0.65, 0.50, 0.35)
		_:
			return Color(0.72, 0.68, 0.56)


## roster chip 紧凑标签 (adr/0008 显示单位名): 中文名取前 2 字; 拉丁名取首词前 4 字母大写。
static func short_name(display: String) -> String:
	var trimmed := display.strip_edges()
	if trimmed == "":
		return "???"
	if _has_cjk(trimmed):
		return trimmed.substr(0, 2)
	var first_word := trimmed.split(" ", false)[0] as String
	return first_word.substr(0, 4).to_upper()


static func _has_cjk(text: String) -> bool:
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false
