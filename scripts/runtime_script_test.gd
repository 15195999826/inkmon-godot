## RuntimeScriptTest - 运行时 GDScript 加载验证
##
## 分三个级别验证 GDScript.new() 在 WASM 环境下的能力：
## - Level 1: 基础能力 (GDScript.new + source_code + reload)
## - Level 2: 引用 class_name 注册的框架类
## - Level 3: 构建完整的 AbilityConfig（技能定义）
class_name RuntimeScriptTest


## 运行所有测试，返回 JSON 结果
static func run_all() -> Dictionary:
	var results := {
		"level_1_basic": _test_level_1(),
		"level_2_class_ref": _test_level_2(),
		"level_3_ability_config": _test_level_3(),
	}
	
	var all_passed := true
	for key in results:
		if not results[key]["passed"]:
			all_passed = false
			break
	
	results["all_passed"] = all_passed
	results["platform"] = {
		"web": OS.has_feature("web"),
		"headless": OS.has_feature("headless"),
		"godot_version": Engine.get_version_info().string,
	}
	
	return results


# ============================================================
# Level 1: 基础能力 - GDScript.new() + source_code + reload()
# ============================================================

static func _test_level_1() -> Dictionary:
	print("\n[RuntimeScriptTest] Level 1: Basic GDScript.new()")
	
	var script := GDScript.new()
	script.source_code = _level_1_source()
	
	var err := script.reload()
	if err != OK:
		var msg := "reload() failed with error code: %d" % err
		print("  FAIL %s" % msg)
		return { "passed": false, "error": msg }
	
	var instance = script.new()
	if instance == null:
		print("  FAIL script.new() returned null")
		return { "passed": false, "error": "script.new() returned null" }
	
	var result: int = instance.calculate(17, 25)
	var info: Dictionary = instance.get_info()
	
	var passed: bool = (
		result == 42
		and info.get("greeting") == "Hello from runtime script!"
		and info.get("source") == "runtime"
	)
	
	if passed:
		print("  PASS - calculate(17,25)=%d, greeting=%s" % [result, info["greeting"]])
	else:
		print("  FAIL - result=%s, info=%s" % [str(result), str(info)])
	
	return { "passed": passed, "result": result, "info": info }


static func _level_1_source() -> String:
	return "\n".join([
		"extends RefCounted",
		"",
		'var greeting: String = "Hello from runtime script!"',
		"var computed: int = 0",
		"",
		"func calculate(a: int, b: int) -> int:",
		"\tcomputed = a + b",
		"\treturn computed",
		"",
		"func get_info() -> Dictionary:",
		"\treturn {",
		'\t\t"greeting": greeting,',
		'\t\t"computed": computed,',
		'\t\t"source": "runtime",',
		"\t}",
	])


# ============================================================
# Level 2: 引用 class_name 注册的框架类
# ============================================================

static func _test_level_2() -> Dictionary:
	print("\n[RuntimeScriptTest] Level 2: Reference class_name classes")
	
	var script := GDScript.new()
	script.source_code = _level_2_source()
	
	var err := script.reload()
	if err != OK:
		var msg := "reload() failed with error code: %d" % err
		print("  FAIL %s" % msg)
		return { "passed": false, "error": msg }
	
	var instance = script.new()
	if instance == null:
		print("  FAIL script.new() returned null")
		return { "passed": false, "error": "script.new() returned null" }
	
	# 调用测试方法
	var result: Dictionary = instance.test_class_references()
	
	var passed: bool = result.get("all_ok", false)
	if passed:
		print("  PASS - All class references resolved")
		for key in result:
			if key != "all_ok":
				print("    %s: %s" % [key, str(result[key])])
	else:
		print("  FAIL - Some class references failed")
		for key in result:
			if key != "all_ok":
				print("    %s: %s" % [key, str(result[key])])
	
	return { "passed": passed, "details": result }


static func _level_2_source() -> String:
	# 这个脚本尝试引用框架中的 class_name 类
	return "\n".join([
		"extends RefCounted",
		"",
		"func test_class_references() -> Dictionary:",
		"\tvar results := {}",
		"\tvar all_ok := true",
		"",
		"\t# Test 1: AbilityConfig (core framework class)",
		'\tvar config := AbilityConfig.new()',
		'\tresults["AbilityConfig"] = config != null',
		'\tif config == null: all_ok = false',
		"",
		"\t# Test 2: TimelineData (core framework class)",
		'\tvar timeline := TimelineData.new("test_tl", 500.0, {"start": 0.0, "end": 500.0})',
		'\tresults["TimelineData"] = timeline != null',
		'\tif timeline == null: all_ok = false',
		"",
		"\t# Test 3: TimelineTags (constants class)",
		'\tresults["TimelineTags.START"] = TimelineTags.START == "start"',
		'\tif TimelineTags.START != "start": all_ok = false',
		"",
		"\t# Test 4: Resolvers (static factory)",
		'\tvar float_r := Resolvers.float_val(42.0)',
		'\tresults["Resolvers"] = float_r != null',
		'\tif float_r == null: all_ok = false',
		"",
		"\t# Test 5: BattleEvents (hex-atb-battle class)",
		'\tresults["BattleEvents.DamageType"] = BattleEvents.DamageType.PHYSICAL == 0',
		'\tif BattleEvents.DamageType.PHYSICAL != 0: all_ok = false',
		"",
		"\t# Test 6: HexBattleTargetSelectors (hex-atb-battle class)",
		'\tvar selector := HexBattleTargetSelectors.current_target()',
		'\tresults["HexBattleTargetSelectors"] = selector != null',
		'\tif selector == null: all_ok = false',
		"",
		'\tresults["all_ok"] = all_ok',
		"\treturn results",
	])


# ============================================================
# Level 3: 构建完整的 AbilityConfig（技能定义）
# ============================================================

static func _test_level_3() -> Dictionary:
	print("\n[RuntimeScriptTest] Level 3: Build full AbilityConfig")
	
	var script := GDScript.new()
	script.source_code = _level_3_source()
	
	var err := script.reload()
	if err != OK:
		var msg := "reload() failed with error code: %d" % err
		print("  FAIL %s" % msg)
		return { "passed": false, "error": msg }
	
	var instance = script.new()
	if instance == null:
		print("  FAIL script.new() returned null")
		return { "passed": false, "error": "script.new() returned null" }
	
	# 调用测试方法
	var result: Dictionary = instance.build_test_skill()
	
	var passed: bool = result.get("all_ok", false)
	if passed:
		print("  PASS - Full AbilityConfig built successfully")
		print("    config_id: %s" % result.get("config_id", ""))
		print("    display_name: %s" % result.get("display_name", ""))
		print("    tags: %s" % str(result.get("tags", [])))
		print("    has_active_use: %s" % str(result.get("has_active_use", false)))
	else:
		print("  FAIL - %s" % result.get("error", "unknown error"))
	
	return { "passed": passed, "details": result }


static func _level_3_source() -> String:
	# 这个脚本模拟 AI 生成的技能定义：一个完整的远程魔法攻击技能
	# 使用 AbilityConfig.builder() 链式调用 + ActiveUseConfig + Timeline + Actions
	var lines: Array[String] = []
	lines.append("extends RefCounted")
	lines.append("")
	lines.append("func build_test_skill() -> Dictionary:")
	lines.append("\tvar result := {}")
	lines.append("\tvar all_ok := true")
	lines.append("")
	lines.append("\t# Step 1: Build a Timeline")
	lines.append('\tvar timeline := TimelineData.new("skill_ice_bolt", 600.0, {')
	lines.append('\t\t"cast": 200.0,')
	lines.append('\t\t"hit": 400.0,')
	lines.append('\t\t"end": 600.0,')
	lines.append("\t})")
	lines.append('\tresult["timeline_ok"] = timeline != null and timeline.id == "skill_ice_bolt"')
	lines.append("\tif timeline == null: all_ok = false")
	lines.append("")
	lines.append("\t# Step 2: Build an AbilityConfig with ActiveUse")
	lines.append("\tvar config := AbilityConfig.builder() \\")
	lines.append('\t\t.config_id("skill_ice_bolt") \\')
	lines.append('\t\t.display_name("\u51B0\u971C\u5F39") \\')
	lines.append('\t\t.description("\u8FDC\u7A0B\u9B54\u6CD5\u653B\u51FB\uFF0C\u53D1\u5C04\u51B0\u971C\u5F39") \\')
	lines.append('\t\t.ability_tags(["skill", "active", "ranged", "magic", "enemy"]) \\')
	lines.append('\t\t.meta("range", 4) \\')
	lines.append("\t\t.active_use( \\")
	lines.append("\t\t\tActiveUseConfig.builder() \\")
	lines.append('\t\t\t.timeline_id("skill_ice_bolt") \\')
	lines.append("\t\t\t.on_timeline_start([StageCueAction.new( \\")
	lines.append("\t\t\t\tHexBattleTargetSelectors.current_target(), \\")
	lines.append('\t\t\t\tResolvers.str_val("magic_ice") \\')
	lines.append("\t\t\t)]) \\")
	lines.append("\t\t\t.on_tag(TimelineTags.HIT, [HexBattleDamageAction.new( \\")
	lines.append("\t\t\t\tHexBattleTargetSelectors.current_target(), \\")
	lines.append("\t\t\t\t65.0, \\")
	lines.append("\t\t\t\tBattleEvents.DamageType.MAGICAL \\")
	lines.append("\t\t\t)]) \\")
	lines.append("\t\t\t.build() \\")
	lines.append("\t\t) \\")
	lines.append("\t\t.build()")
	lines.append("")
	lines.append('\tresult["config_id"] = config.config_id')
	lines.append('\tresult["display_name"] = config.display_name')
	lines.append('\tresult["tags"] = config.ability_tags')
	lines.append('\tresult["has_active_use"] = config.active_use_components.size() > 0')
	lines.append('\tresult["meta_range"] = config.metadata.get("range", -1)')
	lines.append("")
	lines.append("\t# Validate")
	lines.append('\tall_ok = all_ok and config.config_id == "skill_ice_bolt"')
	lines.append('\tall_ok = all_ok and config.display_name == "\u51B0\u971C\u5F39"')
	lines.append("\tall_ok = all_ok and config.ability_tags.size() == 5")
	lines.append("\tall_ok = all_ok and config.active_use_components.size() > 0")
	lines.append('\tall_ok = all_ok and config.metadata.get("range", -1) == 4')
	lines.append("")
	lines.append('\tresult["all_ok"] = all_ok')
	lines.append("\treturn result")
	
	return "\n".join(lines)
