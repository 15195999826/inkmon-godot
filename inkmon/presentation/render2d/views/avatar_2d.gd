class_name InkMonRender2DAvatar
extends Node2D

## 共享 2D avatar 视图件（adr/0007）——RenderWorld 的 ActorRenderState **哑投影**。
## battle 单位 / overworld 玩家 / overworld NPC 三者共用,差异由 Style 描述:
## 队伍/角色配色圆盘 Body（+可选 脚下椭圆影 / 头 / 名字 / HP 条 / idle 浮动）。
##
## **T7 M4 单位动画落地（唯一替换位兑现）**：Style 注入 `unit_visual`
## （InkMonUnitSetLoader.UnitVisual）时,Body = AnimatedSprite2D（6 向三形态:
## 真帧 / alias / mirror=flip_h+offset.x 取反）+ 程序影 AnimatedSprite2D
## （loader 预推,影斜向不随镜像[mirror 向播翻转剪影影动画],帧跟随本体）;
## 未注入沿用占位 Polygon2D 圆盘
## （渐进迁移:battle/NPC 未接单位素材前不变）。三处调用方共用此件,一次换全生效。
##
## 位移/血条/闪白/死亡由 RenderWorld 算好,driver 每帧 set_world_pos + update_from_state。
## 唯一自驱的是 idle 浮动（纯 cosmetic，由 style.idle_bob 开关，仅 overworld 用）。

const HP_BAR_WIDTH := 40.0
const HP_BAR_HEIGHT := 5.0
## 走格 speed_scale 封顶（T7 M4 裁定:走格 220ms/格 vs walk 自然步速 0.382 w/s
## 直乘 ≈20×,快放失真;v1 默认封顶接受滑步,观感终审归验收任务——三候选:
## ①全速跟随(去掉 cap) ②本值封顶 ③放慢走格(OVERWORLD_MOVE_DURATION)）。
const UNIT_WALK_SPEED_SCALE_CAP := 3.0
## 闪白目标（AnimatedSprite2D 无 Polygon2D.color,用 self_modulate 增亮）。
const UNIT_FLASH_MODULATE := Color(2.5, 2.5, 2.5, 1.0)


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
	## T7 M4:单位动画注入位（null = 占位圆盘）。
	var unit_visual: InkMonUnitSetLoader.UnitVisual = null
	## 显示密度换算（= 地图 edge_px / manifest unit_px_per_unit,调用方算好）。
	var unit_scale := 1.0
	## 初始朝向（六向;3 = 前左母版向）。
	var unit_dir := 3

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
## T7 M4 单位动画模式（unit_visual 注入时;否则全 null,走占位圆盘路径）。
var _unit_visual: InkMonUnitSetLoader.UnitVisual = null
var _body_sprite: AnimatedSprite2D = null
var _shadow_sprite: AnimatedSprite2D = null
var _unit_action := ""
var _unit_dir := 3


func initialize(p_actor_id: String, display_name: String, p_max_hp: float, style: Style) -> void:
	actor_id = p_actor_id
	_style = style
	_max_hp = maxf(1.0, p_max_hp)
	_base_color = style.base_color
	_idle_phase = float(absi(p_actor_id.hash()) % 100) / 100.0 * TAU

	_unit_visual = style.unit_visual
	if _unit_visual != null and _unit_visual.shadow_frames != null:
		# 程序影（契约四参预推,影不随镜像）:挂根节点（VisualRoot 外,不吃
		# lift/idle_bob——贴地),从不自走,帧跟随本体（frame_changed 同拍）。
		_shadow_sprite = AnimatedSprite2D.new()
		_shadow_sprite.name = "Shadow"
		_shadow_sprite.centered = true
		_shadow_sprite.sprite_frames = _unit_visual.shadow_frames
		_shadow_sprite.scale = Vector2(style.unit_scale, style.unit_scale)
		add_child(_shadow_sprite)
	elif style.has_shadow:
		# 贴地椭圆压扁系数 = 冻结相机 pitch 35.26° 的 sin(pitch)（与 baked 地图层同投影；
		# 旧 InkMonRender2DIsoHexGrid.ISO_SQUISH=0.55 随该件退役）。
		var shadow := _make_disc("Shadow", style.radius * 0.95, Color(0.0, 0.0, 0.0, 0.26), InkMonRender2DIsoProjection.squish_of(35.26))
		add_child(shadow)

	_visual_root = Node2D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.position = Vector2(0.0, style.lift)
	add_child(_visual_root)

	if _unit_visual != null:
		# T7 M4 唯一替换位兑现:Body = AnimatedSprite2D（探针定案装配:
		# centered + offset = size/2 − anchor + 显示密度 scale）。
		_body_sprite = AnimatedSprite2D.new()
		_body_sprite.name = "Body"
		_body_sprite.centered = true
		_body_sprite.sprite_frames = _unit_visual.sprite_frames
		_body_sprite.scale = Vector2(style.unit_scale, style.unit_scale)
		_visual_root.add_child(_body_sprite)
		if _shadow_sprite != null:
			_body_sprite.frame_changed.connect(func() -> void:
				if _shadow_sprite.visible:
					_shadow_sprite.frame = _body_sprite.frame)
		_unit_dir = style.unit_dir
		set_unit_animation("idle", style.unit_dir, 1.0)
	else:
		_body = _make_disc("Body", style.radius, _base_color)
		_visual_root.add_child(_body)

	if style.has_head and _unit_visual == null:
		# Head 是占位圆盘的部件 —— 单位动画模式下 sprite 自带完整形象。
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
	var flash := clampf(state.flash_progress, 0.0, 1.0)
	if _body_sprite != null:
		_body_sprite.self_modulate = Color.WHITE.lerp(UNIT_FLASH_MODULATE, flash)
	elif _body != null:
		_body.color = _base_color.lerp(Color.WHITE, flash)
	if state.is_alive:
		modulate.a = 1.0
	else:
		modulate.a = clampf(1.0 - state.death_progress, 0.0, 1.0)


## T7 M4:是否处于单位动画模式（driver 据此决定要不要喂 locomotion）。
func has_unit_visual() -> bool:
	return _unit_visual != null


## T7 M4:切单位动画（action × 六向 × speed_scale）。同动画重复调用只更新
## speed_scale（走格期间每帧喂不重启）;未知 action/向 保持现状（fail-soft:
## 素材没有该动作时不闪黑）。镜像规则 = flip_h + offset.x 取反（loader entry
## 已算好);程序影恒不 flip（世界光向恒定）——mirror 向播 loader 从翻转剪影
## 重推的独立影动画（entry.shadow_animation,二轮验收修正）。
func set_unit_animation(action: String, dir: int, speed_scale: float = 1.0) -> void:
	if _body_sprite == null or _unit_visual == null:
		return
	var entry := _unit_visual.entry(action, dir)
	if entry.is_empty():
		return
	_unit_dir = dir
	var anim := str(entry["animation"])
	# 属性无条件跟随 entry（offset/flip/影随向变;codex M4 review medium:
	# guard 只护 play() 重启,避免走格期间每帧重置动画进度）。
	_body_sprite.speed_scale = speed_scale
	_body_sprite.flip_h = bool(entry["mirrored"])
	_body_sprite.offset = entry["offset"] as Vector2
	if _shadow_sprite != null:
		_shadow_sprite.animation = StringName(str(entry.get("shadow_animation", anim)))
		_shadow_sprite.flip_h = false
		_shadow_sprite.offset = entry["shadow_offset"] as Vector2
		_shadow_sprite.stop()
	var same_anim := _unit_action == action and _body_sprite.animation == StringName(anim)
	_unit_action = action
	if not (same_anim and _body_sprite.is_playing()):
		_body_sprite.play(anim)
	if _shadow_sprite != null:
		_shadow_sprite.frame = _body_sprite.frame


## T7 M4:走格 locomotion（driver 每帧喂物理事实,表演策略归本件）:
## moving → walk（speed_scale = 走速/自然步速,封顶 UNIT_WALK_SPEED_SCALE_CAP）;
## 停 → idle（保持最后朝向,素材原生踏步率）。
func sync_unit_locomotion(moving: bool, dir: int, walk_speed_world: float) -> void:
	if _unit_visual == null:
		return
	if moving:
		var nat := _unit_visual.natural_speed("walk", dir)
		var speed_scale := 1.0
		if nat > 0.0:
			speed_scale = clampf(walk_speed_world / nat, 0.1, UNIT_WALK_SPEED_SCALE_CAP)
		set_unit_animation("walk", dir, speed_scale)
	else:
		set_unit_animation("idle", _unit_dir, 1.0)


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
