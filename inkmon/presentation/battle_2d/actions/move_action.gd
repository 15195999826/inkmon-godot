## InkMonBattle2DMoveAction - 移动动作
##
## 把角色从一个格子移动到另一个格子。get_interpolated_hex 返回逻辑 axial（Vector2 = q,r），
## 像素转换在 animator→view 边界做。平移自 hex frontend（见 docs/adr/0006）。
class_name InkMonBattle2DMoveAction
extends InkMonBattle2DVisualAction


## 起始六边形坐标
var from_hex: HexCoord

## 目标六边形坐标
var to_hex: HexCoord

## 缓动函数
var easing: EasingType


func _init(
	p_actor_id: String,
	p_from_hex: HexCoord,
	p_to_hex: HexCoord,
	p_duration: float,
	p_easing: EasingType = EasingType.EASE_IN_OUT_QUAD,
	p_delay: float = 0.0
) -> void:
	super._init(ActionType.MOVE, p_duration, p_delay)
	actor_id = p_actor_id
	from_hex = p_from_hex
	to_hex = p_to_hex
	easing = p_easing


## 根据进度计算插值位置（逻辑 axial，浮点精度）
func get_interpolated_hex(progress: float) -> Vector2:
	var eased_progress := InkMonBattle2DVisualAction.apply_easing(progress, easing)
	return Vector2(
		InkMonBattle2DVisualAction.lerp_value(float(from_hex.q), float(to_hex.q), eased_progress),
		InkMonBattle2DVisualAction.lerp_value(float(from_hex.r), float(to_hex.r), eased_progress)
	)
