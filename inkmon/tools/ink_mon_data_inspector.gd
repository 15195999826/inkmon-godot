class_name InkMonDataInspector
extends Control
## 纯 UI 只读数据检查器(图鉴 / 道具 tab)。核对"服务器拉取的数据 → godot 侧转化"是否正确。
##
## 图鉴: 左 = 服务器原始 JSON(自行 re-parse `units[]`), 右 = godot 转化后(InkMonContentLoader
## 产出的 species_table), 并高亮 loader 丢弃的字段 + 展示进化边。绕过 InkMonSpeciesCatalog
## (避免静态缓存泄漏 + stub 合并污染)。道具: godot 自己的 InkMonItemCatalog(无服务器对照)。
##
## 独立 F6 场景, 不接 game session。动态列表用 instantiate 组件场景(§6)。


const CardScene := preload("res://inkmon/tools/components/inspector_card.tscn")
const KvRowScene := preload("res://inkmon/tools/components/inspector_kv_row.tscn")

## loader 保留进 species_table 的原始键。其余 raw 键 = 被转化丢弃(detail 高亮)。
const KEPT_RAW_KEYS: Array[String] = ["id", "display_name", "stage", "elements", "base_stats"]
const STAT_ORDER: Array[String] = ["max_hp", "ad", "ap", "armor", "mr", "speed"]
const STAT_LABELS: Dictionary = {
	"max_hp": "HP",
	"ad": "AD",
	"ap": "AP",
	"armor": "ARM",
	"mr": "MR",
	"speed": "SPD",
}
const ELEMENT_FILTERS: Array[String] = ["", "fire", "water", "wind", "earth", "light", "dark"]
const STAGE_FILTERS: Array[String] = ["", "baby", "mature", "adult"]

const ELEMENT_LABELS: Dictionary = {
	"fire": "火",
	"water": "水",
	"wind": "风",
	"earth": "土",
	"light": "光",
	"dark": "暗",
}

const STAGE_LABELS: Dictionary = {
	"baby": "幼年期",
	"mature": "成长期",
	"adult": "成熟期",
}

const INK_BLACK := Color(0.102, 0.102, 0.180)
const INK_MEDIUM := Color(0.059, 0.204, 0.376)
const PAPER_LIGHT := Color(0.980, 0.973, 0.953)
const PAPER_DARK := Color(0.910, 0.878, 0.816)
const PAPER_DEEPER := Color(0.867, 0.831, 0.745)
const TEXT_MUTED := Color(0.420, 0.435, 0.525)

const DROPPED_COLOR := Color(0.77, 0.28, 0.16)
const LABEL_COLOR := INK_BLACK
const DIM_COLOR := Color(0.231, 0.247, 0.341)

## 默认指向导入产物; 未导入(文件缺失)→ loader 回 stub 空集, 显示"未导入"态。
@export var content_path: String = "res://data/inkmon_content.json"

@onready var _tab_species_btn: Button = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/ToolRow/TabSpecies"
@onready var _tab_items_btn: Button = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/ToolRow/TabItems"
@onready var _status_label: Label = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/TitleRow/TitleBlock/StatusLabel"
@onready var _refresh_btn: Button = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/TitleRow/RefreshButton"
@onready var _load_file_btn: Button = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/TitleRow/LoadFileButton"
@onready var _search_box: LineEdit = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/ToolRow/SearchBox"
@onready var _element_filter: OptionButton = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/ToolRow/ElementFilter"
@onready var _stage_filter: OptionButton = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/ToolRow/StageFilter"
@onready var _clear_filter_btn: Button = $"Background/Margin/Root/Header/HeaderMargin/HeaderRoot/ToolRow/ClearFilterButton"
@onready var _grid_view: ScrollContainer = $"Background/Margin/Root/Body/GridView"
@onready var _card_grid: HFlowContainer = $"Background/Margin/Root/Body/GridView/CardGrid"
@onready var _detail_view: ScrollContainer = $"Background/Margin/Root/Body/DetailView"
@onready var _back_btn: Button = $"Background/Margin/Root/Body/DetailView/DetailRoot/DetailHeader/DetailHeaderMargin/DetailHeaderRoot/BackButton"
@onready var _detail_title: Label = $"Background/Margin/Root/Body/DetailView/DetailRoot/DetailHeader/DetailHeaderMargin/DetailHeaderRoot/DetailTitleBlock/DetailTitle"
@onready var _detail_subtitle: Label = $"Background/Margin/Root/Body/DetailView/DetailRoot/DetailHeader/DetailHeaderMargin/DetailHeaderRoot/DetailTitleBlock/DetailSubtitle"
@onready var _raw_col_panel: PanelContainer = $"Background/Margin/Root/Body/DetailView/DetailRoot/CompareRow/RawColPanel"
@onready var _raw_col: VBoxContainer = $"Background/Margin/Root/Body/DetailView/DetailRoot/CompareRow/RawColPanel/RawColMargin/RawCol"
@onready var _converted_col: VBoxContainer = $"Background/Margin/Root/Body/DetailView/DetailRoot/CompareRow/ConvertedColPanel/ConvertedColMargin/ConvertedCol"
@onready var _evo_panel: PanelContainer = $"Background/Margin/Root/Body/DetailView/DetailRoot/EvolutionPanel"
@onready var _evo_section: VBoxContainer = $"Background/Margin/Root/Body/DetailView/DetailRoot/EvolutionPanel/EvolutionMargin/EvolutionSection"
@onready var _grid_message_panel: PanelContainer = $"Background/Margin/Root/Body/GridMessagePanel"
@onready var _grid_message_label: Label = $"Background/Margin/Root/Body/GridMessagePanel/GridMessageMargin/GridMessageLabel"
@onready var _file_dialog: FileDialog = $"FileDialog"

var _active_tab := "species"
var _content: Dictionary = {}
var _raw_root: Dictionary = {}
var _raw_units_by_id: Dictionary = {}


func _ready() -> void:
	_setup_filters()
	_tab_species_btn.pressed.connect(show_species_tab)
	_tab_items_btn.pressed.connect(show_items_tab)
	_back_btn.pressed.connect(_show_grid)
	_refresh_btn.pressed.connect(refresh)
	_load_file_btn.pressed.connect(_on_load_file_pressed)
	_search_box.text_changed.connect(_on_search_changed)
	_element_filter.item_selected.connect(_on_filter_selected)
	_stage_filter.item_selected.connect(_on_filter_selected)
	_clear_filter_btn.pressed.connect(_clear_filters)
	_file_dialog.file_selected.connect(_on_file_selected)
	refresh()


# ── 数据加载 ─────────────────────────────────────────────────────────────

func refresh() -> void:
	_content = InkMonContentLoader.load_static_content(content_path)
	_load_raw(content_path)
	_update_status()
	if _active_tab == "items":
		_build_items_grid()
	else:
		_build_species_grid()
	_show_grid()
	_update_tab_buttons()


func _load_raw(path: String) -> void:
	_raw_root = {}
	_raw_units_by_id = {}
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	_raw_root = parsed
	var units: Variant = _raw_root.get("units", [])
	if not (units is Array):
		return
	for unit_value in (units as Array):
		if not (unit_value is Dictionary):
			continue
		var species_id := str((unit_value as Dictionary).get("id", ""))
		if species_id != "":
			_raw_units_by_id[species_id] = unit_value


func _update_status() -> void:
	if bool(_content.get("loaded", false)):
		var count := (_content.get("species", []) as Array).size()
		_status_label.text = "已加载 %d 种 · %s · %s v%s" % [
			count,
			str(_content.get("source", "")),
			str(_raw_root.get("schema", "?")),
			str(_raw_root.get("version", "?")),
		]
	else:
		_status_label.text = "未导入：%s 不存在 — 跑 import 工具，或点『选择 JSON…』载入一份契约" % content_path
	_status_label.modulate = TEXT_MUTED


# ── tab / 视图切换 ───────────────────────────────────────────────────────

func show_species_tab() -> void:
	_active_tab = "species"
	_build_species_grid()
	_show_grid()
	_update_tab_buttons()


func show_items_tab() -> void:
	_active_tab = "items"
	_build_items_grid()
	_show_grid()
	_update_tab_buttons()


func _show_grid() -> void:
	_detail_view.visible = false
	_grid_view.visible = true


func _show_detail() -> void:
	_grid_message_panel.visible = false
	_grid_view.visible = false
	_detail_view.visible = true


func _update_tab_buttons() -> void:
	_apply_tab_style(_tab_species_btn, _active_tab == "species")
	_apply_tab_style(_tab_items_btn, _active_tab == "items")
	_element_filter.visible = _active_tab == "species"
	_stage_filter.visible = _active_tab == "species"
	_search_box.placeholder_text = (
		"搜索名称或图鉴号…" if _active_tab == "species" else "搜索道具 ID / 名称 / tag…"
	)


# ── 搜索 / 过滤 ─────────────────────────────────────────────────────────

func _setup_filters() -> void:
	_element_filter.clear()
	for element in ELEMENT_FILTERS:
		_element_filter.add_item("全部属性" if element == "" else str(ELEMENT_LABELS.get(element, element)))
		_element_filter.set_item_metadata(_element_filter.get_item_count() - 1, element)

	_stage_filter.clear()
	for stage in STAGE_FILTERS:
		_stage_filter.add_item("全部阶段" if stage == "" else str(STAGE_LABELS.get(stage, stage)))
		_stage_filter.set_item_metadata(_stage_filter.get_item_count() - 1, stage)


func _on_search_changed(_new_text: String) -> void:
	_rebuild_active_grid()


func _on_filter_selected(_index: int) -> void:
	_rebuild_active_grid()


func _clear_filters() -> void:
	_search_box.text = ""
	_element_filter.select(0)
	_stage_filter.select(0)
	_rebuild_active_grid()


func _rebuild_active_grid() -> void:
	if _active_tab == "items":
		_build_items_grid()
	else:
		_build_species_grid()
	_show_grid()


func _matches_species_filters(species_id: String, rec: Dictionary) -> bool:
	var query := _search_box.text.strip_edges().to_lower()
	var display_name := str(rec.get("display_name", "")).to_lower()
	if query != "" and not species_id.to_lower().contains(query) and not display_name.contains(query):
		return false

	var element_filter := _selected_filter_value(_element_filter)
	if element_filter != "":
		var elements: Array = rec.get("elements", [])
		if not element_filter in elements:
			return false

	var stage_filter := _selected_filter_value(_stage_filter)
	if stage_filter != "" and str(rec.get("stage", "")) != stage_filter:
		return false
	return true


func _matches_item_filters(config_id: String, config: Dictionary) -> bool:
	var query := _search_box.text.strip_edges().to_lower()
	if query == "":
		return true
	var haystack := "%s %s %s" % [
		config_id,
		str(config.get("display_name", "")),
		_join_elements(config.get("item_tags", [])),
	]
	return haystack.to_lower().contains(query)


func _selected_filter_value(button: OptionButton) -> String:
	if button.selected < 0:
		return ""
	var value: Variant = button.get_item_metadata(button.selected)
	return str(value) if value != null else ""


# ── 网格构建 ─────────────────────────────────────────────────────────────

func _build_species_grid() -> void:
	_clear_dynamic(_card_grid)
	_grid_message_panel.visible = false
	var species_list: Array = _content.get("species", [])
	if species_list.is_empty():
		_add_grid_message("没有可显示的 species（未导入或文件为空）。点『选择 JSON…』载入一份契约。")
		return
	var table: Dictionary = _content.get("species_table", {})
	var shown_count := 0
	for species_id_value in species_list:
		var species_id := str(species_id_value)
		var rec: Dictionary = table.get(species_id, {})
		if not _matches_species_filters(species_id, rec):
			continue
		var elements: Array = rec.get("elements", [])
		var card := CardScene.instantiate() as PanelContainer
		card.name = "Card_%s" % species_id
		_populate_card(
			card,
			_dex_label(species_id),
			str(rec.get("display_name", species_id)),
			species_id,
			_stage_label(str(rec.get("stage", ""))),
			elements,
			_stats_summary(rec.get("base_stats", {})),
		)
		card.gui_input.connect(_on_species_card_input.bind(species_id))
		_card_grid.add_child(card)
		shown_count += 1
	if shown_count == 0:
		_add_grid_message("未找到匹配的 InkMon。")


func _build_items_grid() -> void:
	_clear_dynamic(_card_grid)
	_grid_message_panel.visible = false
	var catalog := InkMonItemCatalog.new()
	var ids := catalog.list_config_ids()
	if ids.is_empty():
		_add_grid_message("道具 catalog 为空。")
		return
	var shown_count := 0
	for config_id in ids:
		var config := catalog.get_config(config_id)
		if not _matches_item_filters(str(config_id), config):
			continue
		var equipable := bool(config.get("equipable", false))
		var card := CardScene.instantiate() as PanelContainer
		card.name = "Card_%s" % str(config_id)
		var tag_text := _join_elements(config.get("item_tags", []))
		if equipable:
			tag_text += "  · 可装备"
		_populate_card(
			card,
			"ITEM",
			str(config.get("display_name", config_id)),
			str(config_id),
			"catalog",
			[],
			tag_text,
			Color(0.82, 0.58, 0.18) if equipable else Color(0.42, 0.44, 0.52),
		)
		card.gui_input.connect(_on_item_card_input.bind(config))
		_card_grid.add_child(card)
		shown_count += 1
	if shown_count == 0:
		_add_grid_message("未找到匹配的道具。")


func _add_grid_message(message: String) -> void:
	_grid_message_label.text = message
	_grid_message_panel.visible = true


# ── 图鉴卡片样式 ─────────────────────────────────────────────────────────

func _populate_card(
	card: PanelContainer,
	dex_text: String,
	title: String,
	subtitle: String,
	stage_text: String,
	elements: Array,
	stat_text: String,
	override_color: Color = Color(0, 0, 0, 0)
) -> void:
	var tint := _card_tint(elements, override_color)
	(card.get_node("Margin/Inner/ImagePanel/ImageStack/ImageTint") as ColorRect).color = tint
	(card.get_node("Margin/Inner/ImagePanel/ImageStack/PortraitInitial") as Label).text = (
		_initial_letter(title)
	)
	(card.get_node("Margin/Inner/Content/MetaRow/DexLabel") as Label).text = dex_text
	(card.get_node("Margin/Inner/Content/MetaRow/StageLabel") as Label).text = stage_text
	(card.get_node("Margin/Inner/Content/TitleLabel") as Label).text = title
	(card.get_node("Margin/Inner/Content/SubtitleLabel") as Label).text = subtitle
	(card.get_node("Margin/Inner/Content/TagLabel") as Label).text = stat_text
	_set_card_badges(card, elements)
	_set_card_palette(card, elements, tint)


func _set_card_badges(card: PanelContainer, elements: Array) -> void:
	var badge_1 := card.get_node("Margin/Inner/Content/ElementRow/ElementBadge1") as PanelContainer
	var badge_2 := card.get_node("Margin/Inner/Content/ElementRow/ElementBadge2") as PanelContainer
	_set_badge(badge_1, str(elements[0]) if elements.size() > 0 else "")
	_set_badge(badge_2, str(elements[1]) if elements.size() > 1 else "")


func _set_badge(panel: PanelContainer, element: String) -> void:
	panel.visible = element != ""
	if element == "":
		return
	panel.add_theme_stylebox_override(
		"panel",
		_make_box_style(InkMonWorldPanelView.element_color(element), Color(0, 0, 0, 0.18), 1, 4)
	)
	var label := panel.get_node("Label") as Label
	label.text = str(ELEMENT_LABELS.get(element, element))
	var needs_light_text := element in ["earth", "dark"]
	label.add_theme_color_override(
		"font_color",
		Color(1, 1, 1, 1) if needs_light_text else Color(0.027, 0.071, 0.059, 1)
	)


func _set_card_palette(card: PanelContainer, elements: Array, fallback_color: Color) -> void:
	var colors := _palette_colors(elements, fallback_color)
	for i in range(4):
		var swatch := card.get_node(
			"Margin/Inner/Content/PaletteRow/PaletteSwatch%d" % (i + 1)
		) as Panel
		swatch.visible = i < colors.size()
		if i < colors.size():
			swatch.add_theme_stylebox_override(
				"panel",
				_make_box_style(colors[i], Color(1, 1, 1, 0.35), 1, 4)
			)


func _palette_colors(elements: Array, fallback_color: Color) -> Array[Color]:
	var colors: Array[Color] = []
	for element_value in elements:
		colors.append(InkMonWorldPanelView.element_color(str(element_value)))
	if colors.is_empty():
		colors.append(fallback_color)
	if colors.size() == 1:
		colors.append(_mix_color(colors[0], PAPER_LIGHT, 0.28))
		colors.append(_mix_color(colors[0], INK_BLACK, 0.18))
	var limited: Array[Color] = []
	for i in range(mini(colors.size(), 4)):
		limited.append(colors[i])
	return limited


func _card_tint(elements: Array, override_color: Color) -> Color:
	if override_color.a > 0.0:
		return override_color
	if elements.is_empty():
		return PAPER_DEEPER
	return InkMonWorldPanelView.element_color(str(elements[0]))


func _apply_tab_style(button: Button, is_active: bool) -> void:
	var bg_color := INK_MEDIUM if is_active else PAPER_LIGHT
	var hover_color := INK_BLACK if is_active else PAPER_DEEPER
	var font_color := PAPER_LIGHT if is_active else INK_BLACK
	button.add_theme_stylebox_override("normal", _make_box_style(bg_color, INK_BLACK, 2, 5))
	button.add_theme_stylebox_override("hover", _make_box_style(hover_color, INK_BLACK, 2, 5))
	button.add_theme_stylebox_override("pressed", _make_box_style(bg_color, INK_BLACK, 2, 5))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)


func _make_box_style(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius + 2
	style.corner_radius_bottom_right = max(1, radius - 1)
	style.corner_radius_bottom_left = radius + 3
	return style


func _mix_color(a: Color, b: Color, weight: float) -> Color:
	return Color(
		lerpf(a.r, b.r, weight),
		lerpf(a.g, b.g, weight),
		lerpf(a.b, b.b, weight),
		1.0
	)


# ── 卡片点击 ─────────────────────────────────────────────────────────────

func _on_species_card_input(event: InputEvent, species_id: String) -> void:
	if _is_left_click(event):
		select_species(species_id)


func _on_item_card_input(event: InputEvent, config: Dictionary) -> void:
	if _is_left_click(event):
		select_item(config)


func _is_left_click(event: InputEvent) -> bool:
	return (event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)


# ── detail 构建 ──────────────────────────────────────────────────────────

func select_species(species_id: String) -> void:
	var table: Dictionary = _content.get("species_table", {})
	var rec: Dictionary = table.get(species_id, {})
	_detail_title.text = str(rec.get("display_name", species_id))
	_detail_subtitle.text = "species_id: %s   ·   stage: %s   ·   elements: %s" % [
		species_id, _stage_label(str(rec.get("stage", ""))), _join_elements(rec.get("elements", []))]
	_raw_col_panel.visible = true
	_evo_panel.visible = true
	_set_column(_raw_col, "服务器原始 JSON (units[])", _raw_pairs(species_id), _dropped_keys(species_id))
	_set_column(_converted_col, "godot 转化后 (species_table)", _converted_pairs(species_id, rec), [])
	_build_evolution(species_id)
	_show_detail()


func select_item(config: Dictionary) -> void:
	_detail_title.text = str(config.get("display_name", config.get("id", "?")))
	_detail_subtitle.text = "id: %s   （道具为 godot 自有数据，无服务器对照）" % str(config.get("id", ""))
	_raw_col_panel.visible = false
	_evo_panel.visible = false
	var pairs: Array = []
	for key in config:
		pairs.append([str(key), _stringify(config[key])])
	_set_column(_converted_col, "道具配置 (InkMonItemCatalog · godot 源)", pairs, [])
	_show_detail()


func _converted_pairs(species_id: String, rec: Dictionary) -> Array:
	return [
		["species_id", species_id],
		["display_name", str(rec.get("display_name", ""))],
		["stage", str(rec.get("stage", ""))],
		["elements", _join_elements(rec.get("elements", []))],
		["base_stats", _stats_summary(rec.get("base_stats", {}))],
	]


func _raw_pairs(species_id: String) -> Array:
	var raw_unit: Dictionary = _raw_units_by_id.get(species_id, {})
	if raw_unit.is_empty():
		return [["(无原始记录)", "raw units[] 中找不到 %s" % species_id]]
	var pairs: Array = []
	for key in raw_unit:
		pairs.append([str(key), _stringify(raw_unit[key])])
	return pairs


func _dropped_keys(species_id: String) -> Array:
	var raw_unit: Dictionary = _raw_units_by_id.get(species_id, {})
	var dropped: Array = []
	for key in raw_unit:
		if not str(key) in KEPT_RAW_KEYS:
			dropped.append(str(key))
	return dropped


func _build_evolution(species_id: String) -> void:
	_clear_dynamic(_evo_section, &"EvoHeader")
	var edges_map: Dictionary = _content.get("evolution_edges", {})
	var children: Array = edges_map.get(species_id, [])
	var has_any := false
	# 进化自(扫全图找以本种为 child 的边)。
	for parent_id_value in edges_map:
		for edge_value in (edges_map[parent_id_value] as Array):
			var edge: Dictionary = edge_value
			if str(edge.get("child_species_id", "")) == species_id:
				_add_evo_row("← 进化自 %s" % str(parent_id_value), _trigger_label(edge.get("trigger", {})))
				has_any = true
	# 进化为(本种的出边)。
	for edge_value in children:
		var edge: Dictionary = edge_value
		_add_evo_row("→ 进化为 %s" % str(edge.get("child_species_id", "")), _trigger_label(edge.get("trigger", {})))
		has_any = true
	if not has_any:
		_add_evo_row("（无进化关系 / orphan）", "")


func _trigger_label(trigger_value: Variant) -> String:
	var trigger: Dictionary = trigger_value if trigger_value is Dictionary else {}
	var label := "Lv.%d" % int(trigger.get("level", 0))
	var condition: Dictionary = trigger.get("condition", {})
	if not condition.is_empty():
		label += " · %s" % str(condition.get("type", ""))
		var params: Dictionary = condition.get("params", {})
		if not params.is_empty():
			label += " %s" % _stringify(params)
	return label


func _add_evo_row(left: String, right: String) -> void:
	var row := KvRowScene.instantiate() as HBoxContainer
	(row.get_node("KeyLabel") as Label).text = left
	(row.get_node("KeyLabel") as Label).modulate = LABEL_COLOR
	(row.get_node("ValueLabel") as Label).text = right
	_evo_section.add_child(row)


## 用 pairs(Array of [key, value]) 填一列; dropped 中的键高亮标红。
func _set_column(col: VBoxContainer, header: String, pairs: Array, dropped: Array) -> void:
	(col.get_node("ColHeader") as Label).text = header
	_clear_dynamic(col, &"ColHeader")
	for pair in pairs:
		var key := str(pair[0])
		var row := KvRowScene.instantiate() as HBoxContainer
		var key_label := row.get_node("KeyLabel") as Label
		var value_label := row.get_node("ValueLabel") as Label
		var is_dropped := key in dropped
		key_label.text = "%s%s" % [key, "  (loader 丢弃)" if is_dropped else ""]
		value_label.text = str(pair[1])
		key_label.modulate = DROPPED_COLOR if is_dropped else LABEL_COLOR
		value_label.modulate = DROPPED_COLOR if is_dropped else DIM_COLOR
		col.add_child(row)


# ── FileDialog ───────────────────────────────────────────────────────────

func _on_load_file_pressed() -> void:
	_file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	content_path = path
	refresh()


# ── 工具 ─────────────────────────────────────────────────────────────────

## 清掉容器里除 keep 外的所有子节点(remove_child 立即生效, child count 即时正确)。
func _clear_dynamic(parent: Node, keep: StringName = &"") -> void:
	for child in parent.get_children():
		if child.name == keep:
			continue
		parent.remove_child(child)
		child.queue_free()


func _stringify(value: Variant) -> String:
	# 检查器本职 = 暴露坏数据。非有限浮点(NaN/±inf)不是合法 JSON: JSON.stringify 会把它静默
	# 洗成 null 并触发一次性引擎警告。所以一旦含非有限值, 改用自渲染保留可见的 ⚠ 标记。
	if value is Dictionary or value is Array:
		if _has_non_finite(value):
			return _to_display(value)
		return JSON.stringify(value)
	if value is float and not is_finite(value):
		return _float_token(value)
	return str(value)


func _has_non_finite(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return not is_finite(value)
		TYPE_DICTIONARY:
			for key in (value as Dictionary):
				if _has_non_finite((value as Dictionary)[key]):
					return true
			return false
		TYPE_ARRAY:
			for element in (value as Array):
				if _has_non_finite(element):
					return true
			return false
		_:
			return false


## 类 JSON 渲染, 但保留 NaN/±inf 可见(JSON.stringify 会替换成 null)。
func _to_display(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict_parts := PackedStringArray()
			for key in (value as Dictionary):
				dict_parts.append('"%s": %s' % [str(key), _to_display((value as Dictionary)[key])])
			return "{%s}" % ", ".join(dict_parts)
		TYPE_ARRAY:
			var arr_parts := PackedStringArray()
			for element in (value as Array):
				arr_parts.append(_to_display(element))
			return "[%s]" % ", ".join(arr_parts)
		TYPE_FLOAT:
			return _float_token(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return '"%s"' % str(value)
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_NIL:
			return "null"
		_:
			return str(value)


func _float_token(value: float) -> String:
	if is_nan(value):
		return "NaN ⚠"
	if value == INF:
		return "+inf ⚠"
	if value == -INF:
		return "-inf ⚠"
	return str(value)


func _dex_label(species_id: String) -> String:
	if species_id.begins_with("mon_"):
		return "#%03d" % int(species_id.substr(4))
	return "#---"


func _stage_label(stage: String) -> String:
	return str(STAGE_LABELS.get(stage, stage))


func _initial_letter(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed == "":
		return "?"
	return trimmed.substr(0, 1).to_upper()


func _stats_summary(stats_value: Variant) -> String:
	var stats: Dictionary = stats_value if stats_value is Dictionary else {}
	var parts := PackedStringArray()
	for key in STAT_ORDER:
		if stats.has(key):
			var stat := float(stats[key])
			parts.append("%s %s" % [
				str(STAT_LABELS.get(key, key)),
				("%d" % int(stat)) if is_finite(stat) else _float_token(stat),
			])
	return "  ".join(parts)


func _join_elements(value: Variant) -> String:
	var parts := PackedStringArray()
	if value is Array:
		for element_value in (value as Array):
			parts.append(str(element_value))
	return ", ".join(parts)


# ── 测试访问器 ───────────────────────────────────────────────────────────

func get_card_grid() -> HFlowContainer:
	return _card_grid


func get_converted_col() -> VBoxContainer:
	return _converted_col


func get_evolution_section() -> VBoxContainer:
	return _evo_section


func is_detail_visible() -> bool:
	return _detail_view.visible
