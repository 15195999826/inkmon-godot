class_name InkMonText
## 表现层文案唯一出口 (adr/0011): 玩家可见文案的 key 查表与组装全住这里, 底下走
## TranslationServer + 同目录 translations.csv。逻辑层出现本类引用 = 违例 (逻辑层只产语义数据)。
##
## 两类查询:
## - 固定 UI key: t()/tf() —— miss 时返回 key 本身 (漏翻上屏自曝, adr/0011 决定 4)。
## - 数据值派生 key (element / battle result / npc id 等): *_name() —— miss 回退原始值
##   (harness / 新内容注入未知值不炸 UI, 屏上原始英文串同样扎眼可见)。
## 内容文案 (species/item 名) 走 lab canon 数据字段透传; zh 字段随 lab 契约落地后在
## species_name / item_display 单点接入 (现 fallback en)。


static func t(key: String) -> String:
	return String(TranslationServer.translate(StringName(key)))


static func tf(key: String, params: Dictionary) -> String:
	return t(key).format(params)


# === quest (委托语义 dict = InkMonQuestDef.to_dict 投影) ===

static func quest_title(quest: Dictionary) -> String:
	var goal := int(quest.get("goal_count", 0))
	match str(quest.get("type", "")):
		InkMonQuestDef.TYPE_REACH:
			return tf("QUEST_TITLE_REACH", {"site": site_name(str(quest.get("target_site_id", "")))})
		InkMonQuestDef.TYPE_HUNT:
			return tf("QUEST_TITLE_HUNT", {"site": site_name(str(quest.get("target_site_id", "")))})
		InkMonQuestDef.TYPE_HUNT_COUNT:
			return tf("QUEST_TITLE_HUNT_COUNT_ONE" if goal == 1 else "QUEST_TITLE_HUNT_COUNT_MANY", {"n": goal})
		InkMonQuestDef.TYPE_CAPTURE_COUNT:
			return tf("QUEST_TITLE_CAPTURE_COUNT_ONE" if goal == 1 else "QUEST_TITLE_CAPTURE_COUNT_MANY", {"n": goal})
	return str(quest.get("quest_id", ""))


static func quest_reward(quest: Dictionary) -> String:
	var gold := int(quest.get("reward_gold", 0))
	if str(quest.get("reward_item_id", "")) != "":
		return tf("QUEST_REWARD_GOLD_ITEM", {"n": gold})
	return tf("QUEST_REWARD_GOLD", {"n": gold})


# === NPC 菜单 (action dict 语义字段 → 文案; 见 InkMonNpcHandler._action) ===

static func npc_action_label(action: Dictionary) -> String:
	if action.has("quest"):
		return quest_title(action["quest"] as Dictionary)
	if action.has("item_config_id"):
		return item_display(action)
	var action_id := str(action.get("id", ""))
	var key := "NPC_ACTION_" + action_id.to_upper()
	var variant := str(action.get("variant", ""))
	if variant != "":
		key += "_" + variant.to_upper()
	return _t_or(key, action_id)


static func npc_action_detail(action: Dictionary) -> String:
	if action.has("quest"):
		return tf("QUEST_BOARD_DETAIL", {"reward": quest_reward(action["quest"] as Dictionary)})
	if action.has("price"):
		return tf("NPC_ACTION_BUY_DETAIL", {"price": int(action.get("price", 0))})
	return _t_or("NPC_ACTION_" + str(action.get("id", "")).to_upper() + "_DETAIL", "")


static func npc_name(npc_id: String) -> String:
	return _t_or("NPC_" + npc_id.to_upper(), npc_id)


# === 名字 / 值映射 ===

## 内容轨 (adr/0011): species 名住 lab canon; zh 字段随 lab 契约落地后在此单点接入。
static func species_name(species_id: String) -> String:
	return InkMonSpeciesCatalog.get_display_name(species_id)


## 内容轨: item 名从携带内容字段的 dict 透传挑列 (display_name_zh 随 lab 契约落地)。
static func item_display(item: Dictionary) -> String:
	var zh := str(item.get("display_name_zh", ""))
	if zh != "" and TranslationServer.get_locale().begins_with("zh"):
		return zh
	return str(item.get("display_name", item.get("config_id", "")))


## "site_3" → SITE_LABEL 模板 (地标 id 是程序化编号, 非语义 slug)。
static func site_name(site_id: String) -> String:
	if site_id.begins_with("site_"):
		var number := site_id.substr(5)
		if number.is_valid_int():
			return tf("SITE_LABEL", {"n": number})
	return site_id.capitalize()


static func element_name(element: String) -> String:
	return _t_or("ELEM_" + element.to_upper(), element)


static func elements_line(elements: Array) -> String:
	var names: PackedStringArray = []
	for element_value in elements:
		names.append(element_name(str(element_value)))
	return ", ".join(names)


static func battle_result_name(result: String) -> String:
	return _t_or("BATTLE_RESULT_" + result.to_upper(), result)


static func team_name(team: String) -> String:
	return _t_or("UI_TEAM_" + team.to_upper(), team)


static func drawer_title(mode: String) -> String:
	return _t_or("UI_TAB_" + mode.to_upper(), mode.capitalize())


## 数据值派生 key 的查询: miss 不自曝 key, 回退原始值。
static func _t_or(key: String, fallback: String) -> String:
	var translated := t(key)
	return fallback if translated == key else translated
