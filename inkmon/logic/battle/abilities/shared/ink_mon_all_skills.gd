class_name InkMonAllSkills


## 单列 manifest: timeline 经 builder.timeline(data) 挂在 config 树上直传执行期,
## 不手抄 timeline 列表(与 hex HexBattleAllSkills 同款)。
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


## 返回 manifest 里所有 AbilityConfig(含 skill / buff / passive)。
## 供 manifest lint 等工具层枚举, 与 hex HexBattleAllSkills.all_abilities() 对称。
static func all_abilities() -> Array[AbilityConfig]:
	return _build_manifest()


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
