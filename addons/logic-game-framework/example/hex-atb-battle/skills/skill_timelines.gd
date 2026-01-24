## 技能 Timeline 定义
##
## Timeline 描述技能执行的时间轴，定义各个动作点（Tag）的时间。
class_name HexBattleSkillTimelines
extends RefCounted


# ========== Timeline ID 常量 ==========

const TIMELINE_ID := {
	# 行动
	"MOVE": "action_move",
	# 技能
	"SLASH": "skill_slash",
	"PRECISE_SHOT": "skill_precise_shot",
	"FIREBALL": "skill_fireball",
	"CRUSHING_BLOW": "skill_crushing_blow",
	"SWIFT_STRIKE": "skill_swift_strike",
	"HOLY_HEAL": "skill_holy_heal",
}


# ========== Timeline 定义 ==========

## 移动 Timeline（两阶段）
## - 0ms: 开始移动，预订目标格子（激活时立即触发）
## - 100ms: 应用移动，实际到达目标格子
## - 200ms: 结束
static var MOVE_TIMELINE := {
	"id": "action_move",
	"totalDuration": 200.0,
	"tags": {
		"start": 0.0,      # 0ms 时执行 StartMoveAction（立即预订）
		"execute": 100.0,  # 100ms 时执行 ApplyMoveAction（实际移动）
		"end": 200.0,
	},
}


## 横扫斩 Timeline
## - 近战攻击，0.3s 时命中
static var SLASH_TIMELINE := {
	"id": "skill_slash",
	"totalDuration": 500.0,
	"tags": {
		"hit": 300.0,  # 300ms 时造成伤害
		"end": 500.0,
	},
}


## 精准射击 Timeline
## - 远程攻击，0.3s 发射箭矢，0.5s 时命中
static var PRECISE_SHOT_TIMELINE := {
	"id": "skill_precise_shot",
	"totalDuration": 800.0,
	"tags": {
		"launch": 300.0,  # 300ms 时发射箭矢
		"hit": 500.0,     # 500ms 时命中（如果是瞬时伤害的话）
		"end": 800.0,
	},
}


## 火球术 Timeline
## - 远程魔法，0.4s 发射火球，0.8s 时命中
static var FIREBALL_TIMELINE := {
	"id": "skill_fireball",
	"totalDuration": 1200.0,
	"tags": {
		"cast": 200.0,    # 施法动作
		"launch": 400.0,  # 400ms 时发射火球
		"hit": 800.0,     # 800ms 时命中（如果是瞬时伤害的话）
		"end": 1200.0,
	},
}


## 毁灭重击 Timeline
## - 近战重击，0.6s 时命中
static var CRUSHING_BLOW_TIMELINE := {
	"id": "skill_crushing_blow",
	"totalDuration": 1000.0,
	"tags": {
		"windup": 300.0,  # 蓄力
		"hit": 600.0,     # 命中
		"end": 1000.0,
	},
}


## 疾风连刺 Timeline
## - 快速近战，多段伤害
static var SWIFT_STRIKE_TIMELINE := {
	"id": "skill_swift_strike",
	"totalDuration": 400.0,
	"tags": {
		"hit1": 100.0,  # 第一击
		"hit2": 200.0,  # 第二击
		"hit3": 300.0,  # 第三击
		"end": 400.0,
	},
}


## 圣光治愈 Timeline
## - 远程治疗，0.4s 时生效
static var HOLY_HEAL_TIMELINE := {
	"id": "skill_holy_heal",
	"totalDuration": 600.0,
	"tags": {
		"heal": 400.0,  # 治疗生效
		"end": 600.0,
	},
}


## 所有 Timeline
static func get_all_timelines() -> Array:
	return [
		MOVE_TIMELINE,
		SLASH_TIMELINE,
		PRECISE_SHOT_TIMELINE,
		FIREBALL_TIMELINE,
		CRUSHING_BLOW_TIMELINE,
		SWIFT_STRIKE_TIMELINE,
		HOLY_HEAL_TIMELINE,
	]


## 根据 ID 获取 Timeline
static func get_timeline(timeline_id: String) -> Dictionary:
	for timeline in get_all_timelines():
		if timeline["id"] == timeline_id:
			return timeline
	return {}
