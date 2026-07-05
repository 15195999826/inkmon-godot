extends Node
## 本地化纪律 smoke (adr/0011 决定 8, 机器可验):
##   ① CSV 结构 (3 列 / key 全大写唯一 / en+zh 双列非空)
##   ② 代码字面 key 必在 CSV (扫 presentation + host + ink_mon_main 的 t("KEY")/tf("KEY"))
##   ③ 派生 key 枚举齐全 (NPC_<id> / NPC_ACTION_<id>[+variant/_DETAIL] / ELEM_<x> / UI_TAB_<mode>)
##   ④ .tscn text 纪律 (presentation 场景 text 只能是 CSV key 或无字母符号)
##   ⑤ zh/en 组装 sanity (locale 切换真出对应语言)


const CSV_PATH := "res://inkmon/presentation/text/translations.csv"
const CODE_SCAN_ROOTS: Array[String] = ["res://inkmon/presentation", "res://inkmon/host", "res://ink_mon_main.gd"]
## 无字母符号之外允许留在 .tscn 的非 key 文本。
const TSCN_TEXT_ALLOW: Array[String] = ["X"]


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - localization: csv shape + literal keys + derived keys + tscn text discipline + zh/en assembly")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# === ① CSV 结构 ===
	var keys := {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return "translations.csv missing"
	var header := file.get_csv_line()
	if header.size() < 3 or header[1] != "en" or header[2] != "zh":
		return "csv header must be keys,en,zh (got %s)" % ",".join(header)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != 3:
			return "csv row must have 3 columns: %s" % ",".join(row)
		var key := row[0]
		if key != key.to_upper() or key == "":
			return "csv key must be non-empty upper snake: %s" % key
		if keys.has(key):
			return "duplicate csv key: %s" % key
		if row[1].strip_edges() == "" or row[2].strip_edges() == "":
			return "csv key %s must fill both en and zh" % key
		keys[key] = true
	file.close()

	# === ② 代码字面 key ===
	var key_regex := RegEx.new()
	if key_regex.compile("\\btf?\\(\"([A-Z][A-Z0-9_]*)\"") != OK:
		return "key regex failed to compile"
	for root in CODE_SCAN_ROOTS:
		for path in _collect_files(root, ".gd"):
			var source := FileAccess.get_file_as_string(path)
			for found in key_regex.search_all(source):
				var literal_key := found.get_string(1)
				if not keys.has(literal_key):
					return "code references missing csv key %s (%s)" % [literal_key, path]

	# === ③ 派生 key 枚举 ===
	for npc_id in InkMonNpcRegistry.defs().keys():
		if not keys.has("NPC_" + str(npc_id).to_upper()):
			return "missing NPC_ key for npc id %s" % npc_id
	var plain_actions: Array[String] = [
		InkMonGuildNpcHandler.ACTION_START_MISSION,
		InkMonCultivationNpcHandler.ACTION_CULTIVATE_LEAD,
		InkMonAdvancementNpcHandler.ACTION_RANK_UP,
		InkMonTrainingNpcHandler.ACTION_START_BATTLE,
		InkMonReleaseAdoptNpcHandler.ACTION_ADOPT,
	]
	for action_id in plain_actions:
		for suffix in ["", "_DETAIL"]:
			if not keys.has("NPC_ACTION_" + action_id.to_upper() + suffix):
				return "missing NPC_ACTION_ key for %s%s" % [action_id, suffix]
	for guild_key in ["NPC_ACTION_GUILD_TASK_JOIN", "NPC_ACTION_GUILD_TASK_CLAIM", "NPC_ACTION_GUILD_TASK_DETAIL"]:
		if not keys.has(guild_key):
			return "missing guild task key %s" % guild_key
	var elements: Array[String] = [InkMonElementChart.FIRE, InkMonElementChart.WATER,
		InkMonElementChart.LIGHT, InkMonElementChart.DARK, InkMonElementChart.WIND, InkMonElementChart.EARTH]
	for element in elements:
		if not keys.has("ELEM_" + element.to_upper()):
			return "missing ELEM_ key for %s" % element
	for mode in ["party", "bag", "journal"]:
		if not keys.has("UI_TAB_" + mode.to_upper()):
			return "missing UI_TAB_ key for %s" % mode

	# === ④ .tscn text 纪律 ===
	var text_regex := RegEx.new()
	if text_regex.compile("(?m)^text = \"([^\"]*)\"") != OK:
		return "tscn regex failed to compile"
	var letters := RegEx.new()
	if letters.compile("[A-Za-z]") != OK:
		return "letters regex failed to compile"
	for path in _collect_files("res://inkmon/presentation", ".tscn"):
		var scene_source := FileAccess.get_file_as_string(path)
		for found in text_regex.search_all(scene_source):
			var text_value := found.get_string(1)
			if TSCN_TEXT_ALLOW.has(text_value) or letters.search(text_value) == null:
				continue
			if not keys.has(text_value):
				return "tscn text must be a csv key or symbol, got \"%s\" (%s)" % [text_value, path]

	# === ⑤ zh/en 组装 sanity ===
	var saved_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh")
	var hunt_title := InkMonText.quest_title({"type": InkMonQuestDef.TYPE_HUNT, "target_site_id": "site_3", "goal_count": 0})
	if not hunt_title.contains("讨伐") or not hunt_title.contains("3号据点"):
		return "zh hunt title assembly broken: %s" % hunt_title
	if InkMonText.npc_action_label({"id": "guild_task", "variant": "join"}) != "加入公会":
		return "zh guild join label broken"
	if InkMonText.element_name(InkMonElementChart.FIRE) != "火":
		return "zh element name broken"
	TranslationServer.set_locale("en")
	if InkMonText.npc_action_label({"id": "guild_task", "variant": "join"}) != "Join Guild":
		return "en guild join label broken"
	var reward := InkMonText.quest_reward({"reward_gold": 40, "reward_item_id": "item_0001"})
	if reward != "40 gold + item":
		return "en reward assembly broken: %s" % reward
	TranslationServer.set_locale(saved_locale)
	return ""


func _collect_files(root: String, extension: String) -> Array[String]:
	var result: Array[String] = []
	if root.ends_with(extension):
		result.append(root)
		return result
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				result.append_array(_collect_files(path, extension))
		elif entry.ends_with(extension):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
