class_name InkMonUnit2DView
extends Node2D

## 战斗回放占位单位(2D，adr/0005）:队伍配色圆盘 + 名字 + HP 条;位置 lerp / 受击闪白 / 死亡 fade。
## 待 Seedance 烘帧管线落地后,Body 占位 Polygon2D 换 AnimatedSprite2D。

const RADIUS := 18.0
const HP_BAR_WIDTH := 40.0
const HP_BAR_HEIGHT := 5.0
const MOVE_LERP_SPEED := 8.0
const FLASH_DURATION_MS := 160.0
const DEATH_FADE_PER_SEC := 2.0

var actor_id := ""
var team := 0

var _max_hp := 1.0
var _hp := 1.0
var _alive := true
var _target_pos := Vector2.ZERO
var _flash_ms := 0.0

var _body: Polygon2D
var _base_color := Color.WHITE
var _hp_fill: ColorRect


func initialize(p_actor_id: String, display_name: String, p_team: int, p_max_hp: float, p_hp: float) -> void:
	actor_id = p_actor_id
	team = p_team
	_max_hp = maxf(1.0, p_max_hp)
	_hp = clampf(p_hp, 0.0, _max_hp)
	_base_color = Color(0.30, 0.55, 0.95) if team == 0 else Color(0.92, 0.36, 0.32)

	_body = Polygon2D.new()
	_body.name = "Body"
	_body.color = _base_color
	_body.polygon = _circle_points(RADIUS, 24)
	add_child(_body)

	var label := Label.new()
	label.name = "NameLabel"
	label.text = display_name
	label.position = Vector2(-RADIUS, -RADIUS * 2.8)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	add_child(label)

	var hp_bg := ColorRect.new()
	hp_bg.name = "HpBg"
	hp_bg.color = Color(0.0, 0.0, 0.0, 0.6)
	hp_bg.position = Vector2(-HP_BAR_WIDTH * 0.5, -RADIUS - HP_BAR_HEIGHT - 6.0)
	hp_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	add_child(hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.name = "HpFill"
	_hp_fill.color = Color(0.36, 0.86, 0.40)
	_hp_fill.position = hp_bg.position
	_hp_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	add_child(_hp_fill)
	_update_hp_bar()


func snap_world_pos(p: Vector2) -> void:
	_target_pos = p
	position = p


func set_target_world_pos(p: Vector2) -> void:
	_target_pos = p


func set_hp(value: float) -> void:
	_hp = clampf(value, 0.0, _max_hp)
	_update_hp_bar()


func flash_hit() -> void:
	_flash_ms = FLASH_DURATION_MS


func play_death() -> void:
	_alive = false


func revive() -> void:
	_alive = true
	_hp = _max_hp
	_flash_ms = 0.0
	modulate = Color.WHITE
	visible = true
	if _body != null:
		_body.color = _base_color
	_update_hp_bar()


func is_alive() -> bool:
	return _alive


func get_hp() -> float:
	return _hp


func tick_visual(delta_ms: float) -> void:
	var dt := delta_ms / 1000.0
	position = position.lerp(_target_pos, clampf(dt * MOVE_LERP_SPEED, 0.0, 1.0))
	if _body != null:
		if _flash_ms > 0.0:
			_flash_ms = maxf(0.0, _flash_ms - delta_ms)
			_body.color = _base_color.lerp(Color.WHITE, _flash_ms / FLASH_DURATION_MS)
		elif _alive:
			_body.color = _base_color
	if not _alive:
		modulate.a = maxf(0.0, modulate.a - dt * DEATH_FADE_PER_SEC)


func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	_hp_fill.size = Vector2(HP_BAR_WIDTH * (_hp / _max_hp), HP_BAR_HEIGHT)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := float(i) * TAU / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
