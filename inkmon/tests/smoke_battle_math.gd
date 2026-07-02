extends Node
## 战斗数值层锚定 (架构优化 Wave 1 正确性护栏): 元素克制乘子逐对 + 减伤公式精确值 + 进化 stat-gate 纯成长口径。
## 纯逻辑, 不起整场战斗: chart 直接断言; 减伤走真实 pre-event 链路 (grant math passive → process_pre_event)。
## 锚定的隐藏语义 (改克制表 / 公式前先看这里):
##   - 光暗互克**双向 1.3** (damage_multiplier 的 advantage 分支先命中, 永不走 0.7) —— 有意, 勿"修对称"。
##   - element 空时 fallback 攻击者主元素 (InkMonDamageMathPassive._handle_pre_damage)。
##   - 进化 stat-gate 只看纯成长 (species base × growth_scale), 刻意不读 attribute_set (含装备)。


const EPS := 0.001
const BASE_DAMAGE := 100.0


func _ready() -> void:
	var status := _run()
	if status == "":
		print("SMOKE_TEST_RESULT: PASS - battle math anchored (chart pairs + mitigation exact values + pure-growth gate)")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_RESULT: FAIL - %s" % status)
		get_tree().quit(1)


func _run() -> String:
	var status := _test_element_chart_pairs()
	if status != "":
		return status
	status = _test_stat_gate_pure_growth()
	if status != "":
		return status
	status = _test_mitigation_formula()
	if status != "":
		return status
	return ""


## 克制环 wind>earth>water>fire>wind + 光暗互克; 克 1.3 / 被克 0.7 / 中性 1.0 / 空元素 1.0。
func _test_element_chart_pairs() -> String:
	var cases := [
		# [attacker, defender, expected]
		[InkMonElementChart.FIRE, InkMonElementChart.WIND, 1.3],
		[InkMonElementChart.WIND, InkMonElementChart.FIRE, 0.7],
		[InkMonElementChart.WIND, InkMonElementChart.EARTH, 1.3],
		[InkMonElementChart.EARTH, InkMonElementChart.WIND, 0.7],
		[InkMonElementChart.EARTH, InkMonElementChart.WATER, 1.3],
		[InkMonElementChart.WATER, InkMonElementChart.EARTH, 0.7],
		[InkMonElementChart.WATER, InkMonElementChart.FIRE, 1.3],
		[InkMonElementChart.FIRE, InkMonElementChart.WATER, 0.7],
		# 光暗互克: 双向都是 1.3 (advantage 分支先命中, 0.7 分支不可达) —— 有意语义。
		[InkMonElementChart.LIGHT, InkMonElementChart.DARK, 1.3],
		[InkMonElementChart.DARK, InkMonElementChart.LIGHT, 1.3],
		# 中性 (同元素 / 环上不相邻) 与空元素。
		[InkMonElementChart.FIRE, InkMonElementChart.FIRE, 1.0],
		[InkMonElementChart.FIRE, InkMonElementChart.EARTH, 1.0],
		["", InkMonElementChart.FIRE, 1.0],
		[InkMonElementChart.FIRE, "", 1.0],
	]
	for case_value in cases:
		var case := case_value as Array
		var got := InkMonElementChart.damage_multiplier(str(case[0]), str(case[1]))
		if absf(got - float(case[2])) > EPS:
			return "chart %s->%s expected x%.1f got x%.2f" % [str(case[0]), str(case[1]), float(case[2]), got]
	return ""


## 进化 stat-gate 纯成长口径 (2026-07-02 拍板): gate = species_base × growth_scale(level),
## 刻意不读 attribute_set —— 实战属性灌到天上, gate 判定也不动。
func _test_stat_gate_pure_growth() -> String:
	var actor := _make_combat_unit("cinder_kit", [InkMonElementChart.FIRE], 0.0, 0.0)
	var base_ad := float(InkMonSpeciesCatalog.get_base_stats("cinder_kit").get("ad", 0.0))
	if base_ad <= 0.0:
		return "cinder_kit base ad should be positive (probe precondition)"
	var pure_growth_ad := base_ad * InkMonUnitActor.growth_scale(actor.level)
	# 实战 ad 灌爆, 若 gate 误读 attribute_set 会假通过。
	actor.attribute_set.set_ad_base(pure_growth_ad + 10000.0)
	var above := {"type": "stat", "params": {"stat": "ad", "cmp": ">=", "value": pure_growth_ad + 1.0}}
	if InkMonSpeciesCatalog.evaluate_evolution_condition(above, actor):
		return "stat gate must ignore attribute_set (pure growth): inflated combat ad passed the gate"
	var below := {"type": "stat", "params": {"stat": "ad", "cmp": ">=", "value": pure_growth_ad - 1.0}}
	if not InkMonSpeciesCatalog.evaluate_evolution_condition(below, actor):
		return "stat gate should pass when pure-growth value clears the threshold"
	return ""


## 减伤公式精确值 (真实 pre-event 链路): physical 用 armor / magical 用 mr / pure 无减伤;
## armor=mr=100 → 100/(100+100)=0.5; pure + element 空 → fallback 攻击者主元素后仍吃克制乘子。
func _test_mitigation_formula() -> String:
	GameWorld.init(EventProcessorConfig.new(20, 1))
	TimelineRegistry.reset()
	var gi := GameWorld.create_instance(func() -> GameplayInstance:
		return InkMonWorldGI.new()
	) as InkMonWorldGI
	gi.new_game()

	var attacker := _make_combat_unit("math_probe_atk", [InkMonElementChart.FIRE], 0.0, 0.0)
	var defender := _make_combat_unit("math_probe_def", [InkMonElementChart.WIND], 100.0, 100.0)
	gi.add_actor(attacker)
	gi.add_actor(defender)
	# 只授予被打方减伤 passive (最小事件面; 战斗里由 equip_abilities 对全体授予)。
	var math_passive := Ability.new(InkMonDamageMathPassive.ABILITY, defender.get_id())
	defender.ability_set.grant_ability(math_passive, gi)

	var cases := [
		# [damage_type, element, expected_mult, label]
		["physical", InkMonElementChart.FIRE, 0.5 * 1.3, "physical armor=100 fire->wind"],
		["physical", InkMonElementChart.WATER, 0.5 * 1.0, "physical armor=100 neutral element"],
		["magical", InkMonElementChart.WATER, 0.5 * 1.0, "magical mr=100 neutral element"],
		# 技能元素 earth 被防守方 wind 克 (wind>earth) → 攻方被克 0.7。
		["magical", InkMonElementChart.EARTH, 0.5 * 0.7, "magical mr=100 attacker (earth) disadvantaged vs wind"],
		# pure: 无减伤; element 空 → fallback 攻击者主元素 fire → 对 wind 仍 1.3。
		["pure", "", 1.0 * 1.3, "pure no mitigation + empty element falls back to attacker primary"],
	]
	for case_value in cases:
		var case := case_value as Array
		var pre := InkMonBattlePreEvents.PreDamageEvent.create(
			attacker.get_id(), defender.get_id(), BASE_DAMAGE, str(case[0]), str(case[1]))
		var mutable: MutableEvent = GameWorld.event_processor.process_pre_event(pre.to_dict(), gi)
		var final_damage: float = mutable.get_current_value("damage")
		var expected: float = BASE_DAMAGE * float(case[2])
		if absf(final_damage - expected) > EPS:
			GameWorld.shutdown()
			return "%s: expected %.2f got %.2f" % [str(case[3]), expected, final_damage]

	GameWorld.shutdown()
	return ""


func _make_combat_unit(species: String, unit_elements: Array, armor: float, mr: float) -> InkMonUnitActor:
	var elements_typed: Array[String] = []
	for element_value in unit_elements:
		elements_typed.append(str(element_value))
	return InkMonUnitActor.create_combat_unit({
		"species": species,
		"personality": InkMonUnitConfig.PERSONALITY_AGGRESSIVE,
		"elements": elements_typed,
		"skill_slots": [{"slot_index": 0, "skill_id": InkMonFireball.CONFIG_ID}],
		"battle_stats": {
			"max_hp": 100.0,
			"ad": 10.0,
			"ap": 10.0,
			"armor": armor,
			"mr": mr,
			"speed": 50.0,
		},
	})
