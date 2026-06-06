## InkMonRender2DFloatingTextAction - 飘字动作
##
## 在指定位置显示飘字（伤害 / 治疗数字）。position 是逻辑 axial（Vector2 = q,r），
## 像素转换在 animator→view 边界做。平移自 hex frontend（见 docs/adr/0006）。
class_name InkMonRender2DFloatingTextAction
extends InkMonRender2DVisualAction


# ========== 飘字样式枚举 ==========

enum FloatingTextStyle {
	NORMAL,
	CRITICAL,
	HEAL,
	MISS,
}


# ========== 属性 ==========

var text: String
var color: Color
## 逻辑 axial 位置（q,r）
var position: Vector2
var style: FloatingTextStyle


# ========== 构造函数 ==========

func _init(
	p_actor_id: String,
	p_text: String,
	p_color: Color,
	p_position: Vector2,
	p_style: FloatingTextStyle,
	p_duration: float,
	p_delay: float = 0.0
) -> void:
	super._init(ActionType.FLOATING_TEXT, p_duration, p_delay)
	actor_id = p_actor_id
	text = p_text
	color = p_color
	position = p_position
	style = p_style


## 根据样式获取默认颜色
static func get_style_color(p_style: FloatingTextStyle) -> Color:
	match p_style:
		FloatingTextStyle.NORMAL:
			return Color.WHITE
		FloatingTextStyle.CRITICAL:
			return Color(1.0, 0.8, 0.0)  # 金色
		FloatingTextStyle.HEAL:
			return Color(0.2, 1.0, 0.2)  # 绿色
		FloatingTextStyle.MISS:
			return Color(0.5, 0.5, 0.5)  # 灰色
		_:
			return Color.WHITE
