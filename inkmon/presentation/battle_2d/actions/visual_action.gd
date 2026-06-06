## InkMonBattle2DVisualAction - 视觉动作基类（等轴 2D 表演框架）
##
## 描述原子级的视觉效果，由 Visualizer 从战斗事件翻译而来。声明式，描述"做什么"
## 而非"怎么做"，由 RenderWorld 应用到 render-state 上。
##
## 平移自 hex-atb-battle frontend（见 docs/adr/0006）：纯数据对象、不持有 Node 引用、
## 坐标全用逻辑 axial（Vector2 = q,r），hex→像素转换只在 animator→view 边界做。
class_name InkMonBattle2DVisualAction
extends RefCounted


# ========== 动作类型枚举 ==========
# 完整列举所有类型（含 dormant），便于日后 JIT 补 handler；首版 RenderWorld 只处理
# MOVE / APPLY_HP_DELTA / FLOATING_TEXT / PROCEDURAL_VFX / DEATH。
enum ActionType {
	MOVE,
	APPLY_HP_DELTA,  # 瞬时:把 hp delta 累到 actor.target_hp,visual_hp 由 RenderWorld lerp
	FLOATING_TEXT,
	MELEE_STRIKE,
	PROCEDURAL_VFX,
	DEATH,
	ATTACK_VFX,
	PROJECTILE,
	APPLY_BUFF_STATE,
	APPLY_SHIELD_STATE,
	BUMP,
	APPLY_FACING_STATE,
	CONE_DEBUG_OVERLAY,
}


# ========== 缓动函数枚举 ==========

enum EasingType {
	LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	EASE_IN_QUAD,
	EASE_OUT_QUAD,
	EASE_IN_OUT_QUAD,
	EASE_IN_CUBIC,
	EASE_OUT_CUBIC,
	EASE_IN_OUT_CUBIC,
}


# ========== 基础属性 ==========

## 动作类型
var type: ActionType

## 关联的 Actor ID（可选，某些全局效果无需）
var actor_id: String = ""

## 动画持续时间（毫秒）
var duration: float = 0.0

## 延迟执行时间（毫秒），默认 0
var delay: float = 0.0


# ========== 构造函数 ==========

func _init(p_type: ActionType, p_duration: float, p_delay: float = 0.0) -> void:
	type = p_type
	duration = p_duration
	delay = p_delay


# ========== 缓动函数实现 ==========

## 应用缓动函数
static func apply_easing(progress: float, easing: EasingType) -> float:
	match easing:
		EasingType.LINEAR:
			return progress
		EasingType.EASE_IN:
			return progress * progress
		EasingType.EASE_OUT:
			return progress * (2.0 - progress)
		EasingType.EASE_IN_OUT:
			if progress < 0.5:
				return 2.0 * progress * progress
			return -1.0 + (4.0 - 2.0 * progress) * progress
		EasingType.EASE_IN_QUAD:
			return progress * progress
		EasingType.EASE_OUT_QUAD:
			return progress * (2.0 - progress)
		EasingType.EASE_IN_OUT_QUAD:
			if progress < 0.5:
				return 2.0 * progress * progress
			return -1.0 + (4.0 - 2.0 * progress) * progress
		EasingType.EASE_IN_CUBIC:
			return progress * progress * progress
		EasingType.EASE_OUT_CUBIC:
			var t := progress - 1.0
			return t * t * t + 1.0
		EasingType.EASE_IN_OUT_CUBIC:
			if progress < 0.5:
				return 4.0 * progress * progress * progress
			var t := progress - 1.0
			return (t * 2.0) * (t * 2.0) * (t * 2.0) + 1.0
		_:
			return progress


## 线性插值（标量）
static func lerp_value(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


## 线性插值（Vector2）
static func lerp_vector2(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a + (b - a) * t
