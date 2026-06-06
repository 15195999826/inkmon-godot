class_name InkMonRender2DFloatingText2D
extends Node2D

## 战斗回放飘字(占位):上浮 + 淡出,自销毁。必须先 add_child 进树再 initialize(create_tween 需在树内)。

func initialize(text: String, color: Color, world_pos: Vector2, duration: float = 0.8) -> void:
	position = world_pos
	var label := Label.new()
	label.text = text
	label.position = Vector2(-12.0, -10.0)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position", world_pos + Vector2(0.0, -40.0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
