## InkMonBattle2DDeathAction - 死亡动作
##
## 角色死亡的视觉效果（淡出 / 下沉，progress 驱动）。平移自 hex frontend（见 docs/adr/0006）。
class_name InkMonBattle2DDeathAction
extends InkMonBattle2DVisualAction


## 击杀者 ID（可选）
var killer_id: String


func _init(
	p_actor_id: String,
	p_duration: float,
	p_killer_id: String = "",
	p_delay: float = 0.0
) -> void:
	super._init(ActionType.DEATH, p_duration, p_delay)
	actor_id = p_actor_id
	killer_id = p_killer_id


## 计算淡出透明度
func get_fade_alpha(progress: float) -> float:
	return 1.0 - progress


## 计算下沉偏移
func get_sink_offset(progress: float) -> float:
	return -progress * 0.5
