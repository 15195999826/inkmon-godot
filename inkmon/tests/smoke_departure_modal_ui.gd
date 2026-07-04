extends Node
## M2.4 出发确认 modal UI 交互 smoke (real mouse input, view 级, 不碰 user:// 出发档):
##   +/- 步进 (0..MAX clamp) / 总价与余额显示 / gold 不足 Confirm 置灰 / Cancel 关闭不上抛 /
##   Confirm 上抛 confirmed(粮数) / 重开回默认粮数。
## 扣款/写档/start 顺序契约在 Host, 归 smoke_mission_departure 串行覆盖 —— 本 smoke 只焊 modal 交互。


const DepartureModalScene := preload("res://inkmon/presentation/ui/departure_modal.tscn")

var _confirmed_supplies: Array[int] = []


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var status: String = await _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - departure modal: supply stepper + gold gate + confirm/cancel (real mouse input)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var modal := DepartureModalScene.instantiate() as InkMonDepartureModal
	add_child(modal)
	await get_tree().process_frame
	modal.confirmed.connect(func(supplies: int) -> void:
		_confirmed_supplies.append(supplies))

	# gold 25: 默认 10 粮 (cost 20) 可付; +3 到 13 粮 (cost 26) 超余额 → Confirm 置灰。
	modal.open(25)
	await get_tree().process_frame
	await get_tree().process_frame
	var controls := modal.get_debug_controls()
	var plus := controls.get("plus_button", null) as Button
	var minus := controls.get("minus_button", null) as Button
	var confirm := controls.get("confirm_button", null) as Button
	var cancel := controls.get("cancel_button", null) as Button
	if modal.get_supplies() != InkMonMissionSetup.DEFAULT_SUPPLIES:
		return "modal should open at the default supply count"
	if confirm.disabled:
		return "default supply cost within gold must keep Confirm enabled"
	for _i in range(3):
		_click_at((plus.get_global_rect() as Rect2).get_center())
		await get_tree().process_frame
	if modal.get_supplies() != InkMonMissionSetup.DEFAULT_SUPPLIES + 3:
		return "plus should step supplies up (got %d)" % modal.get_supplies()
	if not confirm.disabled:
		return "cost above gold must disable Confirm"
	_click_at((minus.get_global_rect() as Rect2).get_center())
	await get_tree().process_frame
	if confirm.disabled:
		return "stepping back within budget must re-enable Confirm"

	# Cancel: 关闭且不上抛。
	_click_at((cancel.get_global_rect() as Rect2).get_center())
	await get_tree().process_frame
	if not _confirmed_supplies.is_empty():
		return "cancel must not emit confirmed"
	if modal.is_open():
		# 关闭动画中 panel 仍可见, 等 tween 收尾。
		for _i in range(30):
			await get_tree().process_frame
			if not modal.is_open():
				break
	if modal.is_open():
		return "cancel should close the modal"

	# 重开回默认 + Confirm 上抛选定粮数。
	modal.open(100)
	await get_tree().process_frame
	if modal.get_supplies() != InkMonMissionSetup.DEFAULT_SUPPLIES:
		return "reopen must reset supplies to default"
	_click_at((minus.get_global_rect() as Rect2).get_center())
	await get_tree().process_frame
	_click_at((confirm.get_global_rect() as Rect2).get_center())
	await get_tree().process_frame
	if _confirmed_supplies.size() != 1 or _confirmed_supplies[0] != InkMonMissionSetup.DEFAULT_SUPPLIES - 1:
		return "confirm must emit the chosen supply count (got %s)" % str(_confirmed_supplies)

	# 步进下界 clamp: 减到 0 不越界。
	modal.open(100)
	await get_tree().process_frame
	for _i in range(InkMonMissionSetup.DEFAULT_SUPPLIES + 5):
		_click_at((minus.get_global_rect() as Rect2).get_center())
	await get_tree().process_frame
	if modal.get_supplies() != 0:
		return "minus must clamp at zero supplies (got %d)" % modal.get_supplies()
	return ""


func _click_at(screen_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_pos
	press.global_position = screen_pos
	get_viewport().push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	get_viewport().push_input(release)
