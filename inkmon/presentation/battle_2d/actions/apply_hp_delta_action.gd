## InkMonBattle2DApplyHPDeltaAction - HP 增减动作（瞬时）
##
## 表演层 hp 是 State（visual_hp 每 tick 朝 target_hp 收敛 lerp）。本 action 瞬时
## （duration=0）：apply 时把 actor.target_hp 加上 delta（伤害负、治疗正），由 RenderWorld
## 的 hp lerp 把 visual_hp 拉过去。多次伤害的连续性由「单一 target_hp + 连续 lerp」天然
## 保证。平移自 hex frontend（见 docs/adr/0006）。
class_name InkMonBattle2DApplyHPDeltaAction
extends InkMonBattle2DVisualAction


## hp 变化量（伤害负，治疗正）
var delta: float


func _init(
	p_actor_id: String,
	p_delta: float,
	p_delay: float = 0.0
) -> void:
	super._init(ActionType.APPLY_HP_DELTA, 0.0, p_delay)
	actor_id = p_actor_id
	delta = p_delta
