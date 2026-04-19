## SkillScenario - 单技能逻辑断言场景基类
##
## 子类放在 `tests/skill_scenarios/*.gd`，自动被 runner 扫描执行。
##
## 一个 scenario 负责:
##   1. 声明场景(caster/allies/enemies/地图/目标)
##   2. 声明要装备的 ActiveUse 技能(+ 可选被动)
##   3. 在 assert_replay 里对产出的 replay 断言
##
## scenario 只做**逻辑验证**（伤害数值、事件序列、buff 生命周期）。
## 表演/视觉验证不在这一层，属于 SkillPreview 工具。
class_name SkillScenario
extends RefCounted


## 显示名（日志输出用）
func get_name() -> String:
	return get_script().resource_path.get_file().get_basename()


## 返回场景配置，格式见 SkillPreviewBattle.run_with_config 约定。
##
## 最小示例:
## [codeblock]
## return {
##     "map": {"rows": 3, "cols": 3},
##     "caster":  {"class": "WARRIOR", "pos": [0, 0]},
##     "enemies": [{"class": "WARRIOR", "pos": [1, 0], "hp": 1000}],
##     "target":  {"mode": "auto"},
## }
## [/codeblock]
func get_scene_config() -> Dictionary:
	return {}


## 返回要给 caster 装备的**ActiveUse** 技能 config（必须一个）
func get_active_skill() -> AbilityConfig:
	return null


## 返回给 caster 额外挂的被动技能（可空）
func get_passives() -> Array[AbilityConfig]:
	return []


## 最大 tick 数（防死循环）。超时计 FAIL。
func get_max_ticks() -> int:
	return 500


## 断言 replay 与场景状态。用 ctx 提供的工具做断言，任一失败 ctx.fail(...)
func assert_replay(_ctx: ScenarioAssertContext) -> void:
	push_error("[SkillScenario] assert_replay not implemented in %s" % get_name())
