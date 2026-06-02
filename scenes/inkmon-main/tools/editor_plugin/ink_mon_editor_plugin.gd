@tool
extends EditorPlugin

const MENU_ITEM_SYNC_CONTENT := "InkMon: 同步服务器内容"
const MENU_ITEM_UPLOAD_SKILLS := "InkMon: 上传技能元数据"
const SMOKE_ENV := "INKMON_EDITOR_PLUGIN_SMOKE"
const SETTING_URL := "inkmon/content_sync/url"
const SETTING_SKILL_URL := "inkmon/skill_upload/url"
const SETTING_AUTH := "inkmon/content_sync/auth"

var _sync_in_progress := false
var _skill_upload_in_progress := false
var _dialog: ConfirmationDialog
var _url_edit: LineEdit
var _auth_edit: LineEdit
var _save_auth_check: CheckBox
var _status_label: Label
var _skill_dialog: ConfirmationDialog
var _skill_url_edit: LineEdit
var _skill_auth_edit: LineEdit
var _skill_save_auth_check: CheckBox
var _skill_status_label: Label


func _enter_tree() -> void:
	_build_sync_dialog()
	_build_skill_upload_dialog()
	add_tool_menu_item(MENU_ITEM_SYNC_CONTENT, Callable(self, "_on_sync_content_pressed"))
	add_tool_menu_item(MENU_ITEM_UPLOAD_SKILLS, Callable(self, "_on_upload_skills_pressed"))
	if OS.get_environment(SMOKE_ENV) == "1":
		_prepare_sync_dialog()
		_prepare_skill_upload_dialog()
		print(
			"[inkmon-editor-tools] registered Project > Tools menu items: %s, %s auth_prefilled=%s skill_url=%s"
				% [
					MENU_ITEM_SYNC_CONTENT,
					MENU_ITEM_UPLOAD_SKILLS,
					str(_auth_edit.text != ""),
					_skill_url_edit.text,
				]
		)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM_SYNC_CONTENT)
	remove_tool_menu_item(MENU_ITEM_UPLOAD_SKILLS)
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null
	if _skill_dialog != null:
		_skill_dialog.queue_free()
		_skill_dialog = null


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


func _on_upload_skills_pressed() -> void:
	if _skill_upload_in_progress:
		push_warning("[inkmon-skill-upload] skill metadata upload already running.")
		return
	_prepare_skill_upload_dialog()
	_skill_dialog.popup_centered()


func _on_skill_upload_confirmed() -> void:
	if _skill_upload_in_progress:
		return
	_skill_upload_in_progress = true
	await _upload_skills_from_dialog()
	_skill_upload_in_progress = false


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


func _build_skill_upload_dialog() -> void:
	_skill_dialog = ConfirmationDialog.new()
	_skill_dialog.title = "上传 InkMon 技能元数据"
	_skill_dialog.get_ok_button().text = "上传"
	_skill_dialog.get_cancel_button().text = "取消"
	_skill_dialog.confirmed.connect(_on_skill_upload_confirmed)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(520.0, 0.0)
	root.add_child(_label("Skill Upload URL"))
	_skill_url_edit = LineEdit.new()
	_skill_url_edit.placeholder_text = InkMonSkillMetadataUploadTool.DEFAULT_URL
	root.add_child(_skill_url_edit)

	root.add_child(_label("Basic Auth"))
	_skill_auth_edit = LineEdit.new()
	_skill_auth_edit.placeholder_text = "user:pass"
	_skill_auth_edit.secret = true
	root.add_child(_skill_auth_edit)

	_skill_save_auth_check = CheckBox.new()
	_skill_save_auth_check.text = "保存 auth 到本机 EditorSettings"
	root.add_child(_skill_save_auth_check)

	_skill_status_label = Label.new()
	_skill_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_skill_status_label)

	_skill_dialog.add_child(root)
	EditorInterface.get_base_control().add_child(_skill_dialog)


func _prepare_sync_dialog() -> void:
	_url_edit.text = _configured_url()
	_auth_edit.text = _configured_auth()
	_save_auth_check.button_pressed = _editor_setting_string(SETTING_AUTH, "") != ""
	_status_label.text = "同步后写入 res://data/inkmon_content.json；运行时只读这个本地文件。"
	if _auth_edit.text == "":
		_auth_edit.call_deferred("grab_focus")
	else:
		_dialog.get_ok_button().call_deferred("grab_focus")


func _prepare_skill_upload_dialog() -> void:
	_skill_url_edit.text = _configured_skill_url()
	_skill_auth_edit.text = _configured_auth()
	_skill_save_auth_check.button_pressed = _editor_setting_string(SETTING_AUTH, "") != ""
	var skills := InkMonL2ContentContract.skill_metadata_exports()
	_skill_status_label.text = "上传 %d 个技能的 metadata；不会上传 .gd 源码。" % skills.size()
	if _skill_auth_edit.text == "":
		_skill_auth_edit.call_deferred("grab_focus")
	else:
		_skill_dialog.get_ok_button().call_deferred("grab_focus")


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


func _upload_skills_from_dialog() -> void:
	var url := _skill_url_edit.text.strip_edges()
	if url == "":
		push_error("[inkmon-skill-upload] skill upload URL is empty.")
		return
	var auth := _skill_auth_edit.text.strip_edges()
	if auth == "":
		push_error("[inkmon-skill-upload] Basic Auth is required (expected 'user:pass').")
		return

	_save_editor_setting(SETTING_SKILL_URL, url)
	if _skill_save_auth_check.button_pressed:
		_save_editor_setting(SETTING_AUTH, auth)
	else:
		_save_editor_setting(SETTING_AUTH, "")

	var result: Dictionary = await InkMonSkillMetadataUploadTool.upload_skill_metadata(
		EditorInterface.get_base_control(),
		url,
		auth,
		InkMonL2ContentContract.skill_metadata_exports()
	)
	if not bool(result.get("ok", false)):
		push_error("[inkmon-skill-upload] %s" % str(result.get("error", "upload failed")))
		return
	print(InkMonSkillMetadataUploadTool.format_result_message(result))


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


func _configured_skill_url() -> String:
	var env_url := OS.get_environment("INKMON_SKILL_UPLOAD_URL")
	if env_url != "":
		return env_url
	var saved_url := _editor_setting_string(SETTING_SKILL_URL, "")
	if saved_url != "":
		return saved_url
	var local_url := InkMonContentImportTool.local_env_value("INKMON_SKILL_UPLOAD_URL", "")
	if local_url != "":
		return local_url
	var content_url := _configured_url()
	if content_url.ends_with("/contract"):
		return content_url.substr(0, content_url.length() - "/contract".length()) + "/skills"
	return InkMonSkillMetadataUploadTool.DEFAULT_URL


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
