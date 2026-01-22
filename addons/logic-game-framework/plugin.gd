@tool
extends EditorPlugin

const MENU_NAME := "LGFramework"
const MENU_ITEM_GENERATE := 1
const GENERATOR_SCRIPT := "res://addons/logic-game-framework/scripts/AttributeSetGeneratorScript.gd"

const AUTOLOAD_LOG := "Log"
const AUTOLOAD_LOG_PATH := "res://addons/logic-game-framework/logic/utils/Logger.gd"
const AUTOLOAD_ID_GENERATOR := "IdGenerator"
const AUTOLOAD_ID_GENERATOR_PATH := "res://addons/logic-game-framework/logic/utils/IdGenerator.gd"
const AUTOLOAD_GAME_WORLD := "GameWorld"
const AUTOLOAD_GAME_WORLD_PATH := "res://addons/logic-game-framework/logic/world/GameWorld.gd"
const AUTOLOAD_TIMELINE_REGISTRY := "TimelineRegistry"
const AUTOLOAD_TIMELINE_REGISTRY_PATH := "res://addons/logic-game-framework/logic/timeline/Timeline.gd"

var _menu: PopupMenu

func _enter_tree() -> void:
	_register_autoloads()
	_menu = PopupMenu.new()
	_menu.add_item("生成属性集", MENU_ITEM_GENERATE)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_tool_submenu_item(MENU_NAME, _menu)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _menu:
		_menu.queue_free()
		_menu = null
	_unregister_autoloads()

func _on_menu_id_pressed(id: int) -> void:
	if id == MENU_ITEM_GENERATE:
		_run_attribute_set_generator()

func _run_attribute_set_generator() -> void:
	var script := load(GENERATOR_SCRIPT)
	if script == null:
		push_error("Generator script not found: %s" % GENERATOR_SCRIPT)
		return
	var instance: Object = script.new()
	if instance == null or not instance.has_method("_run"):
		push_error("Generator script does not implement _run(): %s" % GENERATOR_SCRIPT)
		return
	instance._run()

func _register_autoloads() -> void:
	_ensure_autoload(AUTOLOAD_LOG, AUTOLOAD_LOG_PATH)
	_ensure_autoload(AUTOLOAD_ID_GENERATOR, AUTOLOAD_ID_GENERATOR_PATH)
	_ensure_autoload(AUTOLOAD_GAME_WORLD, AUTOLOAD_GAME_WORLD_PATH)
	_ensure_autoload(AUTOLOAD_TIMELINE_REGISTRY, AUTOLOAD_TIMELINE_REGISTRY_PATH)

func _unregister_autoloads() -> void:
	_remove_autoload_if_matches(AUTOLOAD_LOG, AUTOLOAD_LOG_PATH)
	_remove_autoload_if_matches(AUTOLOAD_ID_GENERATOR, AUTOLOAD_ID_GENERATOR_PATH)
	_remove_autoload_if_matches(AUTOLOAD_GAME_WORLD, AUTOLOAD_GAME_WORLD_PATH)
	_remove_autoload_if_matches(AUTOLOAD_TIMELINE_REGISTRY, AUTOLOAD_TIMELINE_REGISTRY_PATH)

func _ensure_autoload(name: String, path: String) -> void:
	if ProjectSettings.has_setting("autoload/%s" % name):
		return
	add_autoload_singleton(name, path)

func _remove_autoload_if_matches(name: String, path: String) -> void:
	var key := "autoload/%s" % name
	if not ProjectSettings.has_setting(key):
		return
	if ProjectSettings.get_setting(key) != path:
		return
	remove_autoload_singleton(name)
