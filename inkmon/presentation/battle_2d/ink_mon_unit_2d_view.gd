class_name InkMonUnit2DView
extends Node2D

## 战斗回放单位视图(2D)：队伍配色圆盘 + 名字 + HP 条。
##
## 表演框架平移后（adr/0006）：本视图是 RenderWorld 的 ActorRenderState **哑投影**——
## 自己不跑任何插值/计时。位移、血条收敛、受击闪白、死亡淡出全由 RenderWorld 算好，
## animator 每帧读 state、设像素位置（set_world_pos）、调 update_from_state(state)。
## 待 Seedance 烘帧管线落地后，Body 占位 Polygon2D 换 AnimatedSprite2D。

const RADIUS := 18.0
const HP_BAR_WIDTH := 40.0
const HP_BAR_HEIGHT := 5.0

var actor_id := ""
var team := 0

var _max_hp := 1.0
var _body: Polygon2D
var _base_color := Color.WHITE
var _hp_fill: ColorRect


func initialize(p_actor_id: String, display_name: String, p_team: int, p_max_hp: float) -> void:
	actor_id = p_actor_id
	team = p_team
	_max_hp = maxf(1.0, p_max_hp)
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


## 直接设像素位置（animator 由 RenderWorld 的逻辑 axial 转像素后调用）。无自驱 lerp。
func set_world_pos(p: Vector2) -> void:
	position = p


## 把 ActorRenderState 投影到视觉：血条 / 受击闪白 / 死亡淡出。纯投影，无副作用。
func update_from_state(state: InkMonBattle2DActorRenderState) -> void:
	# 血条
	if _hp_fill != null:
		var ratio := clampf(state.visual_hp / state.max_hp, 0.0, 1.0) if state.max_hp > 0.0 else 0.0
		_hp_fill.size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	# 身体颜色：base 朝白闪烁（flash_progress 0=base / 1=全白）
	if _body != null:
		_body.color = _base_color.lerp(Color.WHITE, clampf(state.flash_progress, 0.0, 1.0))
	# 死亡淡出：alive → 不透明；dead → 按 death_progress 淡出
	if state.is_alive:
		modulate.a = 1.0
	else:
		modulate.a = clampf(1.0 - state.death_progress, 0.0, 1.0)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := float(i) * TAU / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
