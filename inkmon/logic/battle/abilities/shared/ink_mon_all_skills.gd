class_name InkMonAllSkills


class _Entry:
	extends RefCounted

	var ability: AbilityConfig
	var timelines: Array[TimelineData]

	func _init(p_ability: AbilityConfig, p_timelines: Array[TimelineData]) -> void:
		ability = p_ability
		timelines = p_timelines


static func _build_manifest() -> Array[_Entry]:
	var arr: Array[_Entry] = []
	arr.append(_Entry.new(InkMonMove.ABILITY, [InkMonMove.MOVE_TIMELINE]))
	arr.append(_Entry.new(InkMonBasicAttack.ABILITY, [InkMonBasicAttack.BASIC_ATTACK_TIMELINE]))
	arr.append(_Entry.new(InkMonFireball.ABILITY, [InkMonFireball.FIREBALL_TIMELINE]))
	arr.append(_Entry.new(InkMonChainLightning.ABILITY, [InkMonChainLightning.CHAIN_LIGHTNING_TIMELINE]))
	arr.append(_Entry.new(InkMonPoison.ABILITY, [InkMonPoison.POISON_TIMELINE]))
	arr.append(_Entry.new(InkMonHolyHeal.ABILITY, [InkMonHolyHeal.HOLY_HEAL_TIMELINE]))
	arr.append(_Entry.new(InkMonStun.ABILITY, [InkMonStun.STUN_TIMELINE]))
	arr.append(_Entry.new(InkMonPoisonBuff.POISON_BUFF, [InkMonPoisonBuff.POISON_TICK_TIMELINE]))
	arr.append(_Entry.new(InkMonStunBuff.create_config(InkMonStunBuff.DEFAULT_DURATION_MS), []))
	arr.append(_Entry.new(InkMonDamageMathPassive.ABILITY, []))
	return arr


static func register_all_timelines() -> void:
	for entry in _build_manifest():
		for timeline in entry.timelines:
			TimelineRegistry.register(timeline)


## 查询从 _build_manifest() 单一清单线性扫描派生 —— 加技能只 append manifest 一行,
## 无平行 match 阶梯可漂移 (曾漂移: manifest 10 项 vs match 6 项)。
## 刻意不用 static var 缓存: 脚本 static 容器持 AbilityConfig 在引擎退出清理时析构顺序不定,
## headless 下退出段错误 (signal 11, 实测); n≈10 且仅备战期调用, 线性扫无性能代价。
static func _find_config(skill_id: String) -> AbilityConfig:
	for entry in _build_manifest():
		if entry.ability.config_id == skill_id:
			return entry.ability
	return null


static func has_skill_config(skill_id: String) -> bool:
	return _find_config(skill_id) != null


static func get_skill_config(skill_id: String) -> AbilityConfig:
	var config := _find_config(skill_id)
	Log.assert_crash(config != null, "InkMonAllSkills", "unknown skill id: %s" % skill_id)
	return config
