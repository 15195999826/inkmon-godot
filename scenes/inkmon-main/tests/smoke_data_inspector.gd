extends Node
## Smoke: data inspector UI builds the species grid (raw↔converted compare + evolution)
## and the items grid from the static catalog, exercising a REAL mouse click into a card
## (Viewport.push_input → PanelContainer gui_input → detail open), not a signal shortcut.


const InspectorScene := preload("res://scenes/inkmon-main/tools/ink_mon_data_inspector.tscn")
const FIXTURE := "res://scenes/inkmon-main/tests/fixtures/sample_creature_contract.json"

var _inspector: InkMonDataInspector = null


func _ready() -> void:
	var status := await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - data inspector builds species/items + raw↔converted compare (real mouse input)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	# headless default window is 64x64 → centered Control rects fall outside the viewport and
	# mouse hit-testing misses every card. Size up BEFORE layout so card global_rects are on-screen.
	get_window().size = Vector2i(1280, 800)

	_inspector = InspectorScene.instantiate() as InkMonDataInspector
	if _inspector == null:
		return "scene did not instantiate as InkMonDataInspector"
	_inspector.content_path = FIXTURE
	add_child(_inspector)
	await get_tree().process_frame
	await get_tree().process_frame

	# (1) species grid: one card per fixture unit (mon_0001/0002/0007/0009).
	var grid := _inspector.get_card_grid()
	if grid == null:
		return "card grid node missing"
	if grid.get_child_count() != 4:
		return "species grid should have 4 cards, got %d" % grid.get_child_count()

	# (2) REAL mouse click into the first card → detail opens, converted column shows the
	#     fixture's explicit mon_0001 max_hp=111 (proves data flowed through the loader, not a stub).
	var first_card := grid.get_child(0) as Control
	if first_card == null:
		return "first card is not a Control"
	_click_control(first_card)
	await get_tree().process_frame
	if not _inspector.is_detail_visible():
		return "real click on a species card should open the detail view"
	var converted := _inspector.get_converted_col()
	if not _tree_text(converted).contains("111"):
		return "converted column should show mon_0001 max_hp=111, got: %s" % _tree_text(converted)

	# (3) branch root mon_0002 → evolution shows both edges with per-edge levels (18 / 12).
	_inspector.select_species("mon_0002")
	await get_tree().process_frame
	var evo_text := _tree_text(_inspector.get_evolution_section())
	for needle in ["mon_0007", "mon_0009", "18", "12"]:
		if not evo_text.contains(needle):
			return "evolution section missing '%s', got: %s" % [needle, evo_text]

	# (4) items tab: one card per catalog config id.
	_inspector.show_items_tab()
	await get_tree().process_frame
	var want_items := InkMonItemCatalog.new().list_config_ids().size()
	if grid.get_child_count() != want_items:
		return "items grid should have %d cards, got %d" % [want_items, grid.get_child_count()]

	return ""


func _click_control(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	for is_pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = is_pressed
		event.position = center
		event.global_position = center
		get_viewport().push_input(event)


func _tree_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text = (node as Label).text
	for child in node.get_children():
		text += " " + _tree_text(child)
	return text
