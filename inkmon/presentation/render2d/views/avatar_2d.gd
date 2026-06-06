class_name InkMonRender2DAvatar
extends Node2D

## 共享 2D avatar 视图件（adr/0007）——RenderWorld 的 ActorRenderState **哑投影**。
## battle 单位 / overworld 玩家 / overworld NPC 三者共用,差异由 Style 描述:
## 队伍/角色配色圆盘 Body（+可选 脚下椭圆影 / 头 / 名字 / HP 条 / idle 浮动）。
## **Seedance 烘帧管线落地后,Body 占位 Polygon2D 只在此一处换 AnimatedSprite2D。**
##
## 位移/血条/闪白/死亡由 RenderWorld 算好,driver 每帧 set_world_pos + update_from_state。
## 唯一自驱的是 idle 浮动（纯 cosmetic，由 style.idle_bob 开关，仅 overworld 用）。

const HP_BAR_WIDTH := 40.0
const HP_BAR_HEIGHT := 5.0


## avatar 外观描述。RefCounted 数据袋 + 预设工厂。
class Style extends RefCounted:
	var radius := 18.0
	var base_color := Color.WHITE
	var has_shadow := false
	var has_head := false
	var has_name := true
	var has_hp_bar := true
	var lift := 0.0          # VisualRoot 上抬（直立站格心上方，脚底落格心）
	var idle_bob := false
	var idle_amp := 4.0
	var idle_speed := 3.2

	static func battle_unit(team: int) -> Style:
		var s := Style.new()
		s.radius = 18.0
		s.base_color = Color(0.30, 0.55, 0.95) if team == 0 else Color(0.92, 0.36, 0.32)
		s.has_shadow = false
		s.has_head = false
		s.has_name = true
		s.has_hp_bar = true
		s.lift = 0.0
		s.idle_bob = false
		return s

	static func overworld_player() -> Style:
		var s := Style.new()
		s.radius = 16.0
		s.base_color = Color(0.08, 0.28, 0.58)
		s.has_shadow = true
		s.has_head = true
		s.has_name = false
		s.has_hp_bar = false
		s.lift = -14.0
		s.idle_bob = true
		s.idle_amp = 4.0
		s.idle_speed = 3.2
		return s

	static func overworld_npc(color: Color) -> Style:
		var s := Style.new()
		s.radius = 15.0
		s.base_color = color
		s.has_shadow = true
		s.has_head = false
		s.has_name = true
		s.has_hp_bar = false
		s.lift = -12.0
		s.idle_bob = true
		s.idle_amp = 3.0
		s.idle_speed = 2.1
		return s


var actor_id := ""

var _style: Style
var _max_hp := 1.0
var _body: Polygon2D
var _base_color := Color.WHITE
var _hp_fill: ColorRect
var _visual_root: Node2D
var _idle_time := 0.0
var _idle_phase := 0.0


func initialize(p_actor_id: String, display_name: String, p_max_hp: float, style: Style) -> void:
	actor_id = p_actor_id
	_style = style
	_max_hp = maxf(1.0, p_max_hp)
	_base_color = style.base_color
	_idle_phase = float(absi(p_actor_id.hash()) % 100) / 100.0 * TAU

	if style.has_shadow:
		var shadow := _make_disc("Shadow", style.radius * 0.95, Color(0.0, 0.0, 0.0, 0.26), InkMonRender2DIsoHexGrid.ISO_SQUISH)
		add_child(shadow)

	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.position = Vector2(0.0, style.lift)
	add_child(_visual_root)

	_body = _make_disc("Body", style.radius, _base_color)
	_visual_root.add_child(_body)

	if style.has_head:
		var head := _make_disc("Head", style.radius * 0.55, Color(0.86, 0.70, 0.54))
		head.position = Vector2(0.0, -style.radius * 0.95)
		_visual_root.add_child(head)

	if style.has_name:
		var label := Label.new()
		label.name = "NameLabel"
		label.text = display_name
		label.position = Vector2(-style.radius, -style.radius * 2.8)
		label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
		_visual_root.add_child(label)

	if style.has_hp_bar:
		var hp_bg := ColorRect.new()
		hp_bg.name = "HpBg"
		hp_bg.color = Color(0.0, 0.0, 0.0, 0.6)
		hp_bg.position = Vector2(-HP_BAR_WIDTH * 0.5, -style.radius - HP_BAR_HEIGHT - 6.0)
		hp_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
		add_child(hp_bg)
		_hp_fill = ColorRect.new()
		_hp_fill.name = "HpFill"
		_hp_fill.color = Color(0.36, 0.86, 0.40)
		_hp_fill.position = hp_bg.position
		_hp_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
		add_child(_hp_fill)


func _process(delta: float) -> void:
	if _style == null or not _style.idle_bob or _visual_root == null:
		return
	_idle_time += delta
	_visual_root.position.y = _style.lift + sin(_idle_time * _style.idle_speed + _idle_phase) * _style.idle_amp


## 直接设像素位置（driver 由 RenderWorld 逻辑 axial 转像素后调用）。无自驱 lerp。
func set_world_pos(p: Vector2) -> void:
	position = p


## 把 ActorRenderState 投影到视觉：血条 / 受击闪白 / 死亡淡出。纯投影。
func update_from_state(state: InkMonRender2DActorRenderState) -> void:
	if _hp_fill != null:
		var ratio := clampf(state.visual_hp / state.max_hp, 0.0, 1.0) if state.max_hp > 0.0 else 0.0
		_hp_fill.size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	if _body != null:
		_body.color = _base_color.lerp(Color.WHITE, clampf(state.flash_progress, 0.0, 1.0))
	if state.is_alive:
		modulate.a = 1.0
	else:
		modulate.a = clampf(1.0 - state.death_progress, 0.0, 1.0)


## NPC 高亮缩放（view-local：driver 不管，overworld view 直接调）
func set_highlight(scale_factor: float) -> void:
	scale = Vector2.ONE * scale_factor


## idle 浮动当前偏移（debug：player_idle_offset_y / npc_idle_sample_y）
func get_idle_offset_y() -> float:
	return _visual_root.position.y if _visual_root != null else 0.0


func _make_disc(disc_name: String, radius: float, color: Color, y_scale: float = 1.0) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = disc_name
	poly.color = color
	poly.polygon = _ellipse_points(radius, radius * y_scale, 24)
	return poly


func _ellipse_points(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := float(i) * TAU / float(segments)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
