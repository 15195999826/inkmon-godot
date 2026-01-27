@tool
extends EditorScript
class_name AttributeSetGeneratorScript

const CONFIG_PATH := "res://logic-game-framework-config/attributes/attributes_config.gd"
const OUTPUT_DIR := "res://logic-game-framework-config/attributes/generated"
const EXAMPLE_CONFIG_PATH := "res://addons/logic-game-framework/example/attributes/attributes_config.gd"
const EXAMPLE_OUTPUT_DIR := "res://addons/logic-game-framework/example/attributes/generated"
const _SHADOWED_GLOBAL_IDENTIFIERS := ["range", "min", "max", "clamp"]

func _run() -> void:
	print("[LGF] Attribute generation started")
	var generated: Array[String] = []
	if _generate_from_config(CONFIG_PATH, OUTPUT_DIR):
		generated.append("project")
	if _generate_from_config(EXAMPLE_CONFIG_PATH, EXAMPLE_OUTPUT_DIR):
		generated.append("example")

	if generated.is_empty():
		push_error("No attribute sets were generated")
		return
	print("[LGF] Attribute sets generated for: %s" % ", ".join(generated))

func _generate_from_config(config_path: String, output_dir: String) -> bool:
	if not ResourceLoader.exists(config_path):
		push_error("AttributesConfig not found: %s" % config_path)
		return false
	print("[LGF] Generating from %s -> %s" % [config_path, output_dir])
	var config: GDScript = load(config_path) as GDScript
	if config == null:
		push_error("AttributesConfig not found: %s" % config_path)
		return false

	var sets: Dictionary = config.SETS
	if typeof(sets) != TYPE_DICTIONARY:
		push_error("AttributesConfig.SETS must be Dictionary: %s" % config_path)
		return false

	var dir := DirAccess.open("res://")
	if dir == null:
		push_error("Failed to open res://")
		return false

	var result := dir.make_dir_recursive(output_dir)
	if result != OK:
		push_error("Failed to create output dir: %s" % output_dir)
		return false

	var set_names: Array = sets.keys()
	set_names.sort()

	for set_name in set_names:
		var attr_defs = sets[set_name]
		if typeof(attr_defs) != TYPE_DICTIONARY:
			push_error("Attribute set %s must be Dictionary" % str(set_name))
			continue
		_generate_set(str(set_name), attr_defs, output_dir)

	print("Generated %d sets from %s" % [set_names.size(), config_path])
	return true

func _generate_set(set_name: String, attr_defs: Dictionary, output_dir: String) -> void:
	var set_class_name := "%sAttributeSet" % set_name
	var file_path := "%s/%s.gd" % [output_dir, set_class_name]
	var lines: Array[String] = []

	lines.append("extends RefCounted")
	lines.append("class_name %s" % set_class_name)
	lines.append("")
	lines.append("var _raw: RawAttributeSet")
	lines.append("")
	lines.append("func _init() -> void:")
	lines.append("\t_raw = RawAttributeSet.new()")
	lines.append("\t_raw.apply_config({")
	
	var attr_names: Array = attr_defs.keys()
	attr_names.sort()
	for attr_name in attr_names:
		var attr_key := str(attr_name)
		var cfg: Dictionary = attr_defs[attr_name]
		var line := "\t\t\"%s\": { \"baseValue\": %s" % [attr_key, _value_to_string(cfg.get("baseValue", 0.0))]
		if cfg.has("minValue") and cfg["minValue"] != null:
			line += ", \"minValue\": %s" % _value_to_string(cfg["minValue"])
		if cfg.has("maxValue") and cfg["maxValue"] != null:
			line += ", \"maxValue\": %s" % _value_to_string(cfg["maxValue"])
		line += " },"
		lines.append(line)

	lines.append("\t})")
	lines.append("")

	for attr_name in attr_names:
		var attr_key := str(attr_name)
		var safe_key: String = _escape_identifier(attr_key)
		var capitalized: String = _capitalize_attr(attr_key)
		lines.append("")
		lines.append("var %s: float:" % safe_key)
		lines.append("\tget:")
		lines.append("\t\treturn _raw.get_current_value(\"%s\")" % attr_key)
		lines.append("var %sBreakdown: Dictionary:" % safe_key)
		lines.append("\tget:")
		lines.append("\t\treturn _raw.get_breakdown(\"%s\")" % attr_key)
		lines.append("func get%sBreakdown() -> Dictionary:" % capitalized)
		lines.append("\treturn _raw.get_breakdown(\"%s\")" % attr_key)
		lines.append("const %sAttribute := \"%s\"" % [safe_key, attr_key])

		lines.append("func set%sBase(value: float) -> void:" % capitalized)
		lines.append("\t_raw.set_base(\"%s\", value)" % attr_key)
		lines.append("func on%sChanged(callback: Callable) -> Callable:" % capitalized)
		lines.append("\tvar filtered_listener := func(event: Dictionary) -> void:")
		lines.append("\t\tif event.get(\"attributeName\", \"\") == \"%s\":" % attr_key)
		lines.append("\t\t\tcallback.call(event)")
		lines.append("\t_raw.add_change_listener(filtered_listener)")
		lines.append("\treturn func() -> void:")
		lines.append("\t\t_raw.remove_change_listener(filtered_listener)")

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write file: %s" % file_path)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()

func _escape_identifier(name: String) -> String:
	if _SHADOWED_GLOBAL_IDENTIFIERS.has(name):
		return "%s_" % name
	return name

func _capitalize_attr(name: String) -> String:
	if name.is_empty():
		return name
	return name.left(1).to_upper() + name.substr(1)

func _value_to_string(value: Variant) -> String:
	match typeof(value):
		TYPE_STRING:
			return "\"%s\"" % value.c_escape()
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT, TYPE_FLOAT:
			return str(value)
		TYPE_NIL:
			return "null"
		_:
			return str(value)
