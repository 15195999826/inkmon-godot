extends RefCounted
class_name Logger

const CATEGORY_EXECUTION := "execution"
const CATEGORY_TIMELINE := "timeline"
const CATEGORY_ACTION := "action"
const CATEGORY_ABILITY := "ability"
const CATEGORY_ATTRIBUTE := "attribute"
const CATEGORY_TAG := "tag"

class ConsoleLogger:
	var _prefix: String

	func _init(prefix: String = "[BattleFramework]"):
		_prefix = prefix

	func debug(message: String, data := null) -> void:
		print("%s %s" % [_prefix, message], data)

	func info(message: String, data := null) -> void:
		print("%s %s" % [_prefix, message], data)

	func warn(message: String, data := null) -> void:
		push_warning("%s %s" % [_prefix, message])
		if data != null:
			print(data)

	func error(message: String, data := null) -> void:
		push_error("%s %s" % [_prefix, message])
		if data != null:
			print(data)

class SilentLogger:
	func debug(_message: String, _data := null) -> void:
		pass

	func info(_message: String, _data := null) -> void:
		pass

	func warn(_message: String, _data := null) -> void:
		pass

	func error(_message: String, _data := null) -> void:
		pass

static var _debug_enabled := false
static var _debug_categories: Array = []
static var _debug_handler: Callable = Callable()
static var _logger = ConsoleLogger.new()

static func configure_debug_log(config: Dictionary) -> void:
	if config.has("enabled"):
		_debug_enabled = bool(config["enabled"])
	if config.has("categories"):
		_debug_categories = config["categories"]

static func get_debug_log_config() -> Dictionary:
	return {
		"enabled": _debug_enabled,
		"categories": _debug_categories.duplicate(),
	}

static func set_debug_log_handler(handler: Callable) -> void:
	_debug_handler = handler

static func debug_log(category: String, message: String, context: Dictionary = {}) -> void:
	if not _is_category_enabled(category):
		return
	if _debug_handler.is_valid():
		_debug_handler.call(category, message, context)
		return
	print("[%s] %s" % [category, message])

static func set_logger(logger) -> void:
	_logger = logger

static func get_logger():
	return _logger

static func _is_category_enabled(category: String) -> bool:
	if not _debug_enabled:
		return false
	if _debug_categories.is_empty():
		return true
	return _debug_categories.has(category)
