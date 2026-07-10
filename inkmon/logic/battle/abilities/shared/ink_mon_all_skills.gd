class_name InkMonAllSkills


## 单列 manifest: timeline 经 builder.timeline(data) 挂在 config 树上,
## register_all_timelines() 用 collect_timelines() 自动收集注册 —— 不手抄
## timeline 列表(与 hex HexBattleAllSkills 同款, 见 LGF CHANGELOG timeline 一体化)。
static func _build_manifest() -> Array[AbilityConfig]:
	var arr: Array[AbilityConfig] = []
	arr.append(InkMonMove.ABILITY)
	arr.append(InkMonBasicAttack.ABILITY)
	arr.append(InkMonFireball.ABILITY)
	arr.append(InkMonChainLightning.ABILITY)
	arr.append(InkMonPoison.ABILITY)
	arr.append(InkMonHolyHeal.ABILITY)
	arr.append(InkMonStun.ABILITY)
	arr.append(InkMonPoisonBuff.POISON_BUFF)
	arr.append(InkMonStunBuff.create_config(InkMonStunBuff.DEFAULT_DURATION_MS))
	arr.append(InkMonDamageMathPassive.ABILITY)
	return arr


static func register_all_timelines() -> void:
	for cfg in _build_manifest():
		for timeline in cfg.collect_timelines():
			TimelineRegistry.register(timeline)


## 查询从 _build_manifest() 单一清单线性扫描派生 —— 加技能只 append manifest 一行,
## 无平行 match 阶梯可漂移 (曾漂移: manifest 10 项 vs match 6 项)。
## 刻意不用 static var 缓存: 脚本 static 容器持 AbilityConfig 在引擎退出清理时析构顺序不定,
## headless 下退出段错误 (signal 11, 实测); n≈10 且仅备战期调用, 线性扫无性能代价。
static func _find_config(skill_id: String) -> AbilityConfig:
	for cfg in _build_manifest():
		if cfg.config_id == skill_id:
			return cfg
	return null


static func has_skill_config(skill_id: String) -> bool:
	return _find_config(skill_id) != null


static func get_skill_config(skill_id: String) -> AbilityConfig:
	var config := _find_config(skill_id)
	Log.assert_crash(config != null, "InkMonAllSkills", "unknown skill id: %s" % skill_id)
	return config
