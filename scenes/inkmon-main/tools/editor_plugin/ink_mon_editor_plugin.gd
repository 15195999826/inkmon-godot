@tool
extends EditorPlugin

const MENU_ITEM_SYNC_CONTENT := "InkMon: 同步服务器内容"
const SMOKE_ENV := "INKMON_EDITOR_PLUGIN_SMOKE"
const SETTING_URL := "inkmon/content_sync/url"
const SETTING_AUTH := "inkmon/content_sync/auth"

var _sync_in_progress := false
var _dialog: ConfirmationDialog
var _url_edit: LineEdit
var _auth_edit: LineEdit
var _save_auth_check: CheckBox
var _status_label: Label


func _enter_tree() -> void:
	_build_sync_dialog()
	add_tool_menu_item(MENU_ITEM_SYNC_CONTENT, Callable(self, "_on_sync_content_pressed"))
	if OS.get_environment(SMOKE_ENV) == "1":
		_prepare_sync_dialog()
		print(
			"[inkmon-editor-tools] registered Project > Tools menu item: %s auth_prefilled=%s"
				% [MENU_ITEM_SYNC_CONTENT, str(_auth_edit.text != "")]
		)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM_SYNC_CONTENT)
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func _on_sync_content_pressed() -> void:
	if _sync_in_progress:
		push_warning("[inkmon-import] content sync already running.")
		return
	_prepare_sync_dialog()
	_dialog.popup_centered()


func _on_sync_confirmed() -> void:
	if _sync_in_progress:
		return
	_sync_in_progress = true
	await _sync_content_from_dialog()
	_sync_in_progress = false


func _build_sync_dialog() -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = "同步 InkMon 内容"
	_dialog.get_ok_button().text = "同步"
	_dialog.get_cancel_button().text = "取消"
	_dialog.confirmed.connect(_on_sync_confirmed)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(520.0, 0.0)
	root.add_child(_label("Contract URL"))
	_url_edit = LineEdit.new()
	_url_edit.placeholder_text = InkMonContentImportTool.DEFAULT_URL
	root.add_child(_url_edit)

	root.add_child(_label("Basic Auth"))
	_auth_edit = LineEdit.new()
	_auth_edit.placeholder_text = "user:pass"
	_auth_edit.secret = true
	root.add_child(_auth_edit)

	_save_auth_check = CheckBox.new()
	_save_auth_check.text = "保存 auth 到本机 EditorSettings"
	root.add_child(_save_auth_check)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	_dialog.add_child(root)
	EditorInterface.get_base_control().add_child(_dialog)


func _prepare_sync_dialog() -> void:
	_url_edit.text = _configured_url()
	_auth_edit.text = _configured_auth()
	_save_auth_check.button_pressed = _editor_setting_string(SETTING_AUTH, "") != ""
	_status_label.text = "同步后写入 res://data/inkmon_content.json；运行时只读这个本地文件。"
	if _auth_edit.text == "":
		_auth_edit.call_deferred("grab_focus")
	else:
		_dialog.get_ok_button().call_deferred("grab_focus")


func _sync_content_from_dialog() -> void:
	var url := _url_edit.text.strip_edges()
	if url == "":
		push_error("[inkmon-import] contract URL is empty.")
		return
	var auth := _auth_edit.text.strip_edges()
	if auth == "":
		push_error("[inkmon-import] Basic Auth is required (expected 'user:pass').")
		return

	_save_editor_setting(SETTING_URL, url)
	if _save_auth_check.button_pressed:
		_save_editor_setting(SETTING_AUTH, auth)
	else:
		_save_editor_setting(SETTING_AUTH, "")

	var result: Dictionary = await InkMonContentImportTool.import_contract(
		EditorInterface.get_base_control(),
		url,
		auth
	)
	if not bool(result.get("ok", false)):
		push_error("[inkmon-import] %s" % str(result.get("error", "import failed")))
		return
	InkMonSpeciesCatalog.clear_static_content_cache()
	print(InkMonContentImportTool.format_result_message(result))


func _configured_url() -> String:
	var env_url := OS.get_environment("INKMON_CONTRACT_URL")
	if env_url != "":
		return env_url
	var saved_url := _editor_setting_string(SETTING_URL, "")
	if saved_url != "":
		return saved_url
	return InkMonContentImportTool.local_env_value(
		"INKMON_CONTRACT_URL",
		InkMonContentImportTool.DEFAULT_URL
	)


func _configured_auth() -> String:
	var env_auth := OS.get_environment("INKMON_CONTRACT_AUTH")
	if env_auth != "":
		return env_auth
	var saved_auth := _editor_setting_string(SETTING_AUTH, "")
	if saved_auth != "":
		return saved_auth
	return InkMonContentImportTool.local_env_value("INKMON_CONTRACT_AUTH", "")


func _editor_setting_string(key: String, fallback: String) -> String:
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(key):
		return str(settings.get_setting(key))
	return fallback


func _save_editor_setting(key: String, value: String) -> void:
	EditorInterface.get_editor_settings().set_setting(key, value)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
