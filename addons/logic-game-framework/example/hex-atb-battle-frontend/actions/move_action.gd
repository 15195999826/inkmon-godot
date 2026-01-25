## MoveAction - 移动动作
##
## 将角色从一个格子移动到另一个格子
class_name FrontendMoveAction
extends FrontendVisualAction


# ========== 属性 ==========

## 起始六边形坐标
var from_hex: Vector2i

## 目标六边形坐标
var to_hex: Vector2i

## 缓动函数
var easing: EasingType


# ========== 构造函数 ==========

func _init(
	p_actor_id: String,
	p_from_hex: Vector2i,
	p_to_hex: Vector2i,
	p_duration: float,
	p_easing: EasingType = EasingType.EASE_IN_OUT_QUAD,
	p_delay: float = 0.0
) -> void:
	super._init(ActionType.MOVE, p_duration, p_delay)
	actor_id = p_actor_id
	from_hex = p_from_hex
	to_hex = p_to_hex
	easing = p_easing


## 根据进度计算插值位置（六边形坐标）
func get_interpolated_hex(progress: float) -> Vector2:
	var eased_progress := FrontendVisualAction.apply_easing(progress, easing)
	return Vector2(
		FrontendVisualAction.lerp_value(float(from_hex.x), float(to_hex.x), eased_progress),
		FrontendVisualAction.lerp_value(float(from_hex.y), float(to_hex.y), eased_progress)
	)
