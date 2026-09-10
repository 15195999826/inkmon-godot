extends Node
## 主游戏技能 manifest lint smoke
##
## 「同 id 异实例」没有运行时守卫：timeline id 只剩录像标签用途，两份不同节奏顶着同一个
## id 会让回放里的 timelineId 静默串味（复制技能文件忘改 TIMELINE_ID 就是这个形状）。
## 这道闸由静态检查把守，hex 与主游戏各自守自己的 manifest。
##
## 断言（全部走 core 的 AbilityConfig.lint_timelines）：
##   ① 每个 config 携带的 timeline validate() 为空
##   ② tags 已冻结（即必须经 builder.timeline(data) 声明，而非裸 .new()）
##   ③ 同 id 必须是同一实例


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - inkmon manifest lint: %d configs clean" % InkMonAllSkills.all_abilities().size())
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var configs := InkMonAllSkills.all_abilities()
	if configs.is_empty():
		return "InkMonAllSkills.all_abilities() 返回空 manifest"

	var failures := AbilityConfig.lint_timelines(configs)
	if not failures.is_empty():
		for f in failures:
			print("  [LINT] " + f)
		return "%d 条 timeline lint 违规" % failures.size()

	# 自证会红：故意造一个同 id 异实例，lint 必须抓到。
	# 不加这条的话，helper 哪天退化成空实现也没人发现。
	var probe := TimelineData.new(_first_timeline_id(configs), 123.0, {})
	var probe_config := (AbilityConfig.builder()
		.config_id("lint_selftest_probe")
		.active_use(ActiveUseConfig.builder().timeline(probe).build())
		.build())
	var probe_set: Array[AbilityConfig] = configs.duplicate()
	probe_set.append(probe_config)
	if AbilityConfig.lint_timelines(probe_set).is_empty():
		return "lint 自证失败: 注入同 id 异实例后仍报干净"

	return ""


## 取 manifest 里第一个 timeline 的 id，用于构造冲突探针。
func _first_timeline_id(configs: Array[AbilityConfig]) -> String:
	for cfg in configs:
		for timeline in cfg.collect_timelines():
			if timeline != null:
				return timeline.id
	return ""
