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


static func get_skill_config(skill_id: String) -> AbilityConfig:
	match skill_id:
		InkMonStun.CONFIG_ID:
			return InkMonStun.ABILITY
		InkMonFireball.CONFIG_ID:
			return InkMonFireball.ABILITY
		InkMonHolyHeal.CONFIG_ID:
			return InkMonHolyHeal.ABILITY
		InkMonChainLightning.CONFIG_ID:
			return InkMonChainLightning.ABILITY
		InkMonPoison.CONFIG_ID:
			return InkMonPoison.ABILITY
		InkMonBasicAttack.CONFIG_ID:
			return InkMonBasicAttack.ABILITY
		_:
			Log.assert_crash(false, "InkMonAllSkills", "unknown skill id: %s" % skill_id)
			return null
